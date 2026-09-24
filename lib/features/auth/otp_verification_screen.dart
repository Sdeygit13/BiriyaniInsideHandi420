import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_store.dart';
import '../../core/theme/app_theme.dart';
import 'patient_id_display_screen.dart';
import 'reset_password_screen.dart';

enum OtpMode { registration, passwordReset }

class OtpVerificationScreen extends StatefulWidget {
  final OtpMode mode;
  final String? resetUserId;

  const OtpVerificationScreen({
    super.key,
    this.mode = OtpMode.registration,
    this.resetUserId,
  });

  @override
  State<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  static const int _codeLength = 6;

  final _masterController = TextEditingController();
  final _masterFocus = FocusNode();

  String _code = '';
  int _secondsLeft = 45;
  Timer? _timer;
  bool _busy = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _masterFocus.requestFocus();
    });
  }

  void _startTimer() {
    _secondsLeft = 45;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _masterController.dispose();
    _masterFocus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.length != _codeLength) {
      setState(() => _error = 'Enter all 6 digits.');
      return;
    }

    _masterFocus.unfocus();
    setState(() {
      _busy = true;
      _error = '';
    });

    try {
      if (widget.mode == OtpMode.registration) {
        await AuthStore.instance.verifyOtp(code: _code);
        if (!mounted) return;

        // If a patient just registered, show their new Patient ID once.
        final user = AuthStore.instance.currentUser;
        if (user != null &&
            user.role == UserRole.patient &&
            user.patientId != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => PatientIdDisplayScreen(
                patientId: user.patientId!,
              ),
            ),
          );
          return;
        }

        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        if (widget.resetUserId != null &&
            widget.resetUserId != '__no_user__') {
          await AuthService.instance.verifyOtp(
            userId: widget.resetUserId!,
            code: _code,
          );
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(
                userId: widget.resetUserId!,
              ),
            ),
          );
        } else {
          if (!mounted) return;
          setState(() => _error = 'This account is not available.');
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    try {
      if (widget.mode == OtpMode.registration) {
        await AuthStore.instance.resendOtp();
      } else if (widget.resetUserId != null) {
        await AuthService.instance.resendOtp(widget.resetUserId!);
      }
      if (!mounted) return;
      _startTimer();
      _masterController.clear();
      setState(() => _code = '');
      _masterFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A new code has been sent.'),
          backgroundColor: cPrimaryDark,
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  Future<void> _copyOtp() async {
    final otp = AuthService.instance.debugLastOtp;
    if (otp == null) return;
    await Clipboard.setData(ClipboardData(text: otp));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final devOtp = AuthService.instance.debugLastOtp;

    return Scaffold(
      backgroundColor: cBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: cBg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: cDeep),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: Logo(size: 64)),
                    const SizedBox(height: 20),
                    const Text(
                      'Verify Your Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: cDeep,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter the 6-digit code sent to your contact.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: cMuted),
                    ),
                    const SizedBox(height: 20),

                    if (devOtp != null)
                      _DevOtpBanner(otp: devOtp, onCopy: _copyOtp),

                    if (devOtp != null) const SizedBox(height: 16),

                    _buildOtpRow(),

                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: cDanger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    primaryButton(
                      _busy ? 'Verifying…' : 'Verify',
                      _busy ? null : _verify,
                      icon: Icons.check_rounded,
                    ),

                    const SizedBox(height: 16),
                    Center(
                      child: _secondsLeft > 0
                          ? Text(
                              'Resend available in ${_secondsLeft}s',
                              style: const TextStyle(color: cMuted),
                            )
                          : TextButton(
                              onPressed: _resend,
                              child: const Text('Resend Code'),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOtpRow() {
    return SizedBox(
      height: 56,
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_codeLength, (i) {
              final char = i < _code.length ? _code[i] : '';
              final isActive =
                  i == _code.length && _masterFocus.hasFocus;
              return _visualBox(char: char, active: isActive);
            }),
          ),
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _masterFocus.requestFocus(),
              child: TextField(
                controller: _masterController,
                focusNode: _masterFocus,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                maxLength: _codeLength,
                autofocus: false,
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                  height: 1,
                ),
                cursorColor: Colors.transparent,
                cursorWidth: 0,
                showCursor: false,
                enableInteractiveSelection: true,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_codeLength),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  counterText: '',
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (value) {
                  setState(() => _code = value);
                  if (value.length == _codeLength) {
                    _verify();
                  }
                },
                onSubmitted: (_) => _verify(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visualBox({required String char, required bool active}) {
    final filled = char.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: cWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? cPrimaryDark
              : filled
                  ? cPrimaryDark.withValues(alpha: 0.35)
                  : cBorder,
          width: active ? 2 : 1.2,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: cPrimaryDark.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        char,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: cDeep,
        ),
      ),
    );
  }
}

// =============================================================================
// DEV MODE OTP BANNER — remove before shipping
// =============================================================================

class _DevOtpBanner extends StatelessWidget {
  final String otp;
  final VoidCallback onCopy;

  const _DevOtpBanner({required this.otp, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8B84C), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE8B84C),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.construction_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DEV MODE — OTP',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF8A6212),
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  otp,
                  style: const TextStyle(
                    fontSize: 22,
                    letterSpacing: 6,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4A3503),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(10),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.copy_rounded,
                  size: 20,
                  color: Color(0xFF8A6212),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}