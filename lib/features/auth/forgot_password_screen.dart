import 'package:flutter/material.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_store.dart';
import '../../core/theme/app_theme.dart';
import 'otp_verification_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final UserRole role;
  const ForgotPasswordScreen({super.key, required this.role});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _contact = TextEditingController();
  bool _busy = false;
  String _message = '';

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _message = '';
    });

    try {
      final userId = await AuthStore.instance.startPasswordReset(
        _contact.text,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            mode: OtpMode.passwordReset,
            resetUserId: userId,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _message = 'We could not process this request. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: cBg,
        elevation: 0,
        title: const Text(
          'Forgot Password',
          style: TextStyle(fontWeight: FontWeight.w900, color: cDeep),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              const Text(
                'Forgot your password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: cDeep,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter your registered phone number or email. '
                'We will send you a verification code.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: cMuted, height: 1.5),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _contact,
                keyboardType: TextInputType.emailAddress,
                decoration: inputDec('Phone Number or Email'),
              ),
              if (_message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: cDanger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              primaryButton(
                _busy ? 'Sending…' : 'Continue',
                _busy ? null : _continue,
                icon: Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: 20),
              const Text(
                'For security, the app will not reveal whether an account exists.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: cMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}