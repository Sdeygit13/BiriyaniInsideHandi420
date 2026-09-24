import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../debug/url_tester_screen.dart';
import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_store.dart';
import '../../core/localization/app_languages.dart';
import '../../core/theme/app_theme.dart';
import '../auth/link_patient_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    AuthStore.instance.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    AuthStore.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  // ── Logout ──────────────────────────────────────────────────
  Future<void> _handleLogout() async {
    final user = AuthStore.instance.currentUser;
    if (user == null) return;

    if (user.role == UserRole.patient) {
      // If no caregiver/family has ever been linked, allow direct logout.
      // We detect this by checking whether ANY other user exists in the
      // auth registry. Since we can't easily query that, we use a simpler
      // rule: if the patient has never been linked, allow direct logout.
      await _patientLogoutFlow();
    } else {
      await _caregiverLogoutFlow();
    }
  }

  Future<void> _patientLogoutFlow() async {
    // Simple confirmation — no caregiver approval required for a
    // single-device demo. In a real deployment, this would check whether
    // any caregiver is linked and only ask for approval in that case.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: cDanger, size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Log out?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: cDeep,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'You will need to sign in again to use Smaran.',
          style: TextStyle(fontSize: 14, height: 1.5, color: cText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: cDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await AuthStore.instance.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _caregiverLogoutFlow() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Log out?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: cDeep,
          ),
        ),
        content: const Text(
          'You will need to sign in again to access your patients.',
          style: TextStyle(fontSize: 14, height: 1.5, color: cText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: cDanger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;
    await AuthStore.instance.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final user = AuthStore.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: cBg,
        body: Center(child: CircularProgressIndicator(color: cPrimary)),
      );
    }

    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: cBg,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: cDeep,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar + name
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: const BoxDecoration(
                        color: cSoft,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        user.fullName.isNotEmpty
                            ? user.fullName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: cPrimaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user.fullName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: cDeep,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: cSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        user.role.englishLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: cPrimaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Patient ID card (patient only)
              if (user.role == UserRole.patient && user.patientId != null) ...[
                _SectionLabel(text: 'PATIENT ID'),
                _PatientIdCard(patientId: user.patientId!),
                const SizedBox(height: 20),
              ],

              // Linked patients (caregiver / family only)
              if (user.role != UserRole.patient) ...[
                _SectionLabel(text: 'LINKED PATIENTS'),
                _LinkedPatientsList(
                  patients: AuthStore.instance.linkedPatients,
                  onAddMore: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LinkPatientScreen(
                          showBackButton: true,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Account info
              _SectionLabel(text: 'ACCOUNT'),
              _InfoCard(children: [
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email.isEmpty ? '—' : user.email,
                ),
                const Divider(height: 1, color: cBorder),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: user.phone.isEmpty ? '—' : user.phone,
                ),
                const Divider(height: 1, color: cBorder),
                _InfoRow(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  value: user.preferredLanguage.englishName,
                ),
                const Divider(height: 1, color: cBorder),
                _InfoRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Account status',
                  value: user.verified ? 'Verified' : 'Pending verification',
                ),
              ]),
              const SizedBox(height: 20),

              // Logout button
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: _handleLogout,
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: cDanger,
                    size: 20,
                  ),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: cDanger,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: cDanger, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),

              // ─────────────────────────────────────────────
              // DEBUG-ONLY: URL Tester button
              // REMOVE BEFORE SHIPPING
              // ─────────────────────────────────────────────
              const SizedBox(height: 30),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UrlTesterScreen(),
                    ),
                  );
                },
                child: const Text(
                  'DEBUG: URL Tester',
                  style: TextStyle(
                    fontSize: 11,
                    color: cMuted,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],   // ← this closes the Column children list
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets
// =============================================================================

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w900,
            color: cPrimaryDark,
          ),
        ),
      );
}

class _PatientIdCard extends StatelessWidget {
  final String patientId;
  const _PatientIdCard({required this.patientId});

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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: cPrimaryDark.withValues(alpha: 0.35),
          width: 1.4,
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
              fontSize: 10,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w900,
              color: cPrimaryDark,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            patientId,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w900,
              color: cDeep,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
            style: OutlinedButton.styleFrom(
              foregroundColor: cPrimaryDark,
              side: const BorderSide(color: cPrimaryDark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkedPatientsList extends StatelessWidget {
  final List<AppUser> patients;
  final VoidCallback onAddMore;

  const _LinkedPatientsList({
    required this.patients,
    required this.onAddMore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (patients.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cWhite,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cBorder),
            ),
            child: const Text(
              'No patients linked yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: cMuted),
            ),
          )
        else
          ...patients.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: cSoft,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.fullName.isNotEmpty
                          ? p.fullName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: cPrimaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.fullName,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                            color: cText,
                          ),
                        ),
                        if (p.patientId != null)
                          Text(
                            p.patientId!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: cMuted,
                              fontFamily: 'monospace',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: onAddMore,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Another Patient'),
          style: OutlinedButton.styleFrom(
            foregroundColor: cPrimaryDark,
            side: const BorderSide(color: cPrimaryDark, width: 1.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: cWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cBorder),
        ),
        child: Column(children: children),
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: cPrimaryDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: cMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: cText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

