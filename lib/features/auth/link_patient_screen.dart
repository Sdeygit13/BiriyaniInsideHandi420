import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_store.dart';
import '../../core/theme/app_theme.dart';

/// Shown to caregivers/family who have no linked patients yet.
/// Can also be pushed later to add another patient.
class LinkPatientScreen extends StatefulWidget {
  final bool showBackButton;

  const LinkPatientScreen({super.key, this.showBackButton = false});

  @override
  State<LinkPatientScreen> createState() => _LinkPatientScreenState();
}

class _LinkPatientScreenState extends State<LinkPatientScreen> {
  final _controller = TextEditingController();
  bool _busy = false;
  String _error = '';
  String? _successName;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    FocusScope.of(context).unfocus();

    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter a Patient ID.');
      return;
    }

    setState(() {
      _error = '';
      _busy = true;
      _successName = null;
    });

    try {
      await AuthStore.instance.linkPatientById(raw);

      // Look up the patient we just linked to show a friendly confirmation.
      final patient = AuthService.instance.findByPatientId(raw);

      if (!mounted) return;
      setState(() {
        _busy = false;
        _successName = patient?.fullName ?? 'Patient';
        _controller.clear();
      });

      // Give the user a moment to read the confirmation, then leave.
      await Future.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = widget.showBackButton &&
        Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: cBg,
      appBar: canGoBack
          ? AppBar(
              backgroundColor: cBg,
              elevation: 0,
              leading: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: cDeep,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!canGoBack) const SizedBox(height: 24),
              const Center(child: Logo(size: 64)),
              const SizedBox(height: 24),
              const Text(
                'Link a Patient',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: cDeep,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter the SMRN Patient ID shown on your family member\'s '
                'Smaran account. It looks like SMRN-XXXX-XXXX.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: cMuted,
                ),
              ),
              const SizedBox(height: 32),

              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _link(),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(14),
                  _PatientIdFormatter(),
                ],
                style: const TextStyle(
                  fontSize: 22,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                  color: cDeep,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'SMRN-XXXX-XXXX',
                  hintStyle: TextStyle(
                    fontSize: 20,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: cMuted.withValues(alpha: 0.5),
                    fontFamily: 'monospace',
                  ),
                  filled: true,
                  fillColor: cWhite,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: cBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: cBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: cPrimaryDark,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                ),
              ),

              if (_error.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cDanger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: cDanger,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],

              if (_successName != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cPrimaryDark,
                      width: 1.4,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: cPrimaryDark,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Linked to $_successName.',
                          style: const TextStyle(
                            color: cDeep,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              primaryButton(
                _busy ? 'Linking…' : 'Link Patient',
                _busy ? null : _link,
                icon: Icons.link_rounded,
              ),

              const SizedBox(height: 16),
              const Text(
                'Don\'t have a Patient ID yet? Ask the patient or their family '
                'to open their Smaran account — the ID is shown during setup '
                'and again in their Profile.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: cMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Auto-inserts hyphens and upper-cases input.
/// SMRN7K3P9X2Q  →  SMRN-7K3P-9X2Q
class _PatientIdFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final truncated = raw.length > 12 ? raw.substring(0, 12) : raw;

    final buf = StringBuffer();
    for (int i = 0; i < truncated.length; i++) {
      if (i == 4 || i == 8) buf.write('-');
      buf.write(truncated[i]);
    }
    final formatted = buf.toString();

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}