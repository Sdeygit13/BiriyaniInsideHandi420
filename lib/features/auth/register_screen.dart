import 'package:flutter/material.dart';

import '../../core/auth/auth_models.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/auth_store.dart';
import '../../core/theme/app_theme.dart';
import 'otp_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  final UserRole role;
  const RegisterScreen({super.key, required this.role});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _pin = TextEditingController();
  final _trustedName = TextEditingController();
  final _trustedPhone = TextEditingController();
  final _relationship = TextEditingController();

  bool _busy = false;
  String _error = '';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    _pin.dispose();
    _trustedName.dispose();
    _trustedPhone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = '';
      _busy = true;
    });

    try {
      if (widget.role == UserRole.patient) {
        if (_pin.text.length != 4) {
          throw AuthException('PIN must be 4 digits.');
        }
      } else {
        if (_password.text.length < 8) {
          throw AuthException('Password must be at least 8 characters.');
        }
        if (_password.text != _confirm.text) {
          throw AuthException('Passwords do not match.');
        }
      }

      await AuthStore.instance.register(
        fullName: _name.text,
        email: _email.text,
        phone: _phone.text,
        password: _password.text,
        role: widget.role,
        pin: widget.role == UserRole.patient ? _pin.text : null,
        trustedContactName: _trustedName.text.isEmpty ? null : _trustedName.text,
        trustedContactPhone:
            _trustedPhone.text.isEmpty ? null : _trustedPhone.text,
        relationship:
            _relationship.text.isEmpty ? null : _relationship.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const OtpVerificationScreen(mode: OtpMode.registration),
        ),
      );
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPatient = widget.role == UserRole.patient;

    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: cBg,
        elevation: 0,
        title: Text(
          'Create ${widget.role.englishLabel} Account',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: cDeep,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Logo(size: 64)),
              const SizedBox(height: 20),

              TextField(
                controller: _name,
                decoration: inputDec('Full Name *'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: inputDec('Phone Number *'),
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: inputDec('Email'),
              ),
              const SizedBox(height: 12),

              if (isPatient) ...[
                TextField(
                  controller: _pin,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  decoration: inputDec('4-Digit PIN *').copyWith(
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _trustedName,
                  decoration: inputDec('Trusted Contact Name'),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _trustedPhone,
                  keyboardType: TextInputType.phone,
                  decoration: inputDec('Trusted Contact Phone'),
                ),
              ] else ...[
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: inputDec('Password * (min 8 characters)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirm,
                  obscureText: true,
                  decoration: inputDec('Confirm Password *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _relationship,
                  decoration: inputDec(
                    widget.role == UserRole.caregiver
                        ? 'Relationship to Patient'
                        : 'Relationship to Patient',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
              ],

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

              const SizedBox(height: 20),
              primaryButton(
                _busy ? 'Creating…' : 'Create Account',
                _busy ? null : _submit,
                icon: Icons.person_add_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}