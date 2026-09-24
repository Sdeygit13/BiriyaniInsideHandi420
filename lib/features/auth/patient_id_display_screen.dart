import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Shown ONCE immediately after a patient registers.
/// Gives the patient (and their family) the ID they must write down.
class PatientIdDisplayScreen extends StatelessWidget {
  final String patientId;

  const PatientIdDisplayScreen({super.key, required this.patientId});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: patientId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Patient ID copied'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _continue(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Force the user to acknowledge
      child: Scaffold(
        backgroundColor: cBg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Center(child: Logo(size: 64)),
                const SizedBox(height: 22),
                const Text(
                  'Your Patient ID',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: cDeep,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Write this down. You will need it later to connect '
                  'a caregiver or family member to your Smaran account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.5,
                    color: cMuted,
                  ),
                ),
                const SizedBox(height: 32),

                // ID card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: cWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: cPrimaryDark.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A7A694E),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'SMARAN PATIENT ID',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                          color: cPrimaryDark,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SelectableText(
                        patientId,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                          color: cDeep,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _copy(context),
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('Copy'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cPrimaryDark,
                              side: const BorderSide(color: cPrimaryDark),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Reminder note
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE8B84C),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF8A6212),
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'If you lose this ID, you can view it again from your Profile.',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Color(0xFF4A3503),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                primaryButton(
                  "I've written it down",
                  () => _continue(context),
                  icon: Icons.check_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}