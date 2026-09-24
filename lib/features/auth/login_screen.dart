import 'package:flutter/material.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_store.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final UserRole role;
  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _contactController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _error = '';
      _busy = true;
    });

    try {
      await AuthStore.instance.login(
        contact: _contactController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _goRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterScreen(role: widget.role),
      ),
    );
  }

  void _goForgot() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ForgotPasswordScreen(role: widget.role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = L.current;
    final isPatient = widget.role == UserRole.patient;

    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: cBg,
        elevation: 0,
        title: Text(
          isPatient ? l.patient : (widget.role == UserRole.caregiver ? l.caregiver : l.familyMember),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: cDeep,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Logo(size: 64)),
              const SizedBox(height: 18),
              Text(
                l.welcomeBack,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: cDeep,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isPatient ? l.pin : l.signInContinue,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: cMuted),
              ),
              const SizedBox(height: 26),

              TextField(
                controller: _contactController,
                keyboardType: TextInputType.emailAddress,
                decoration: inputDec(l.emailOrPhone),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _passwordController,
                obscureText: !_showPassword,
                decoration: inputDec(isPatient ? l.pin : l.password).copyWith(
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                    icon: Icon(
                      _showPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
              ),

              if (_error.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: cDanger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _error,
                    style: const TextStyle(
                      color: cDanger,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _goForgot,
                  child: Text(l.forgotPasswordQ),
                ),
              ),

              const SizedBox(height: 4),
              primaryButton(
                _busy ? '...' : l.loginBtn,
                _busy ? null : _login,
                icon: Icons.login_rounded,
              ),

              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : _goRegister,
                  child: Text(l.newToSmaran),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}