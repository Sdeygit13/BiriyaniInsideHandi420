import 'package:flutter/material.dart';

import '../../core/auth/auth_models.dart';
import '../../core/theme/app_theme.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  void _select(BuildContext context, UserRole role) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(role: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Logo ─────────────────────────────────────
                  const Center(child: Logo(size: 72)),
                  const SizedBox(height: 28),

                  // ── Heading ──────────────────────────────────
                  const Text(
                    'How will you use Smaran?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.2,
                      letterSpacing: -0.4,
                      fontWeight: FontWeight.w900,
                      color: cDeep,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Subtitle ─────────────────────────────────
                  const Text(
                    'Choose the option that describes you best.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF5C6360),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // ── Role cards ───────────────────────────────
                  _RoleCard(
                    role: UserRole.patient,
                    icon: Icons.person_rounded,
                    accent: const Color(0xFFE5F0D8),
                    onTap: () => _select(context, UserRole.patient),
                  ),
                  const SizedBox(height: 14),

                  _RoleCard(
                    role: UserRole.caregiver,
                    icon: Icons.medical_services_rounded,
                    accent: const Color(0xFFF5E6C7),
                    onTap: () => _select(context, UserRole.caregiver),
                  ),
                  const SizedBox(height: 14),

                  _RoleCard(
                    role: UserRole.family,
                    icon: Icons.groups_rounded,
                    accent: const Color(0xFFF6DCDD),
                    onTap: () => _select(context, UserRole.family),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ROLE CARD
// =============================================================================

class _RoleCard extends StatefulWidget {
  final UserRole role;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.role.englishLabel}. ${widget.role.tagline}',
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOutCubic,
        child: Material(
          color: cWhite,
          borderRadius: BorderRadius.circular(22),
          elevation: 2,
          shadowColor: const Color(0x0F7A694E),
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => _setPressed(true),
            onTapUp: (_) => _setPressed(false),
            onTapCancel: () => _setPressed(false),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              constraints: const BoxConstraints(minHeight: 104),
              padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFF0E9DD),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: widget.accent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      widget.icon,
                      color: cPrimaryDark,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Title + tagline
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.role.englishLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.15,
                            letterSpacing: -0.2,
                            fontWeight: FontWeight.w900,
                            color: cText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.role.tagline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF5C6360),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Arrow in soft circle
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F7EE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: cPrimaryDark,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}