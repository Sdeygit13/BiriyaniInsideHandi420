import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_languages.dart';
import 'auth_models.dart';
import 'auth_service.dart';
import 'patient_id.dart';

/// Central state holder for authentication.
///
/// - Holds the currently signed-in [AppUser] and active [AuthSession]
/// - Persists users + session to SharedPreferences
/// - Exposes [ChangeNotifier] so the UI can rebuild on change
class AuthStore extends ChangeNotifier {
  AuthStore._();
  static final AuthStore instance = AuthStore._();

  // ── Persistence keys ─────────────────────────────────────────
  static const _kUsers = 'auth_users_v1';
  static const _kSession = 'auth_session_v1';
  static const _kLanguage = 'auth_language_v1';

  // ── State ────────────────────────────────────────────────────
  AppUser? _currentUser;
  AuthSession? _session;
  AppLanguage _preferredLanguage = AppLanguage.english;
  bool _booted = false;
  bool _hasChosenLanguage = false;

  // ── Getters ──────────────────────────────────────────────────
  AppUser? get currentUser => _currentUser;
  AuthSession? get session => _session;
  AppLanguage get preferredLanguage => _preferredLanguage;
  bool get isBooted => _booted;
  bool get isLoggedIn => _currentUser != null && _session != null;
  bool get hasChosenLanguage => _hasChosenLanguage;

  // ── Boot ─────────────────────────────────────────────────────
  Future<void> boot() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Rehydrate the user registry
    final rawUsers = prefs.getString(_kUsers);
    if (rawUsers != null) {
      try {
        final list = (jsonDecode(rawUsers) as List)
            .whereType<Map>()
            .map((e) => AppUser.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        AuthService.instance.hydrateUsers(list);
      } catch (_) {}
    }

    // 2. Rehydrate the session
    final rawSession = prefs.getString(_kSession);
    if (rawSession != null) {
      try {
        final s = AuthSession.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawSession) as Map),
        );
        if (!s.isExpired) {
          _session = s;
          _currentUser = AuthService.instance.findById(s.userId);
        } else {
          await prefs.remove(_kSession);
        }
      } catch (_) {}
    }

    // 3. Rehydrate the language preference
    final rawLang = prefs.getString(_kLanguage);
    _hasChosenLanguage = rawLang != null;
    _preferredLanguage = parseLanguage(rawLang);

    _booted = true;
    notifyListeners();
  }

  // ── Language ─────────────────────────────────────────────────
  Future<void> setLanguage(AppLanguage language) async {
    _preferredLanguage = language;
    _hasChosenLanguage = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, language.key);

    final user = _currentUser;
    if (user != null) {
      _currentUser = user.copyWith(
        preferredLanguage: language,
        updatedAt: DateTime.now(),
      );
      await _persistUsers();
    }
  }

  // ── Registration ─────────────────────────────────────────────
  Future<AppUser> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required UserRole role,
    DateTime? dateOfBirth,
    String? trustedContactName,
    String? trustedContactPhone,
    String? pin,
    String? relationship,
  }) async {
    final user = await AuthService.instance.register(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      role: role,
      preferredLanguageKey: _preferredLanguage.key,
      dateOfBirth: dateOfBirth,
      trustedContactName: trustedContactName,
      trustedContactPhone: trustedContactPhone,
      pin: pin,
      relationship: relationship,
    );

    _currentUser = user;
    notifyListeners();

    await _persistUsers();
    return user;
  }

  // ── Login ────────────────────────────────────────────────────
  Future<AppUser> login({
    required String contact,
    required String password,
  }) async {
    final user = await AuthService.instance.login(
      contact: contact,
      password: password,
    );

    _currentUser = user;
    _session = AuthService.instance.issueSession(user.id);
    notifyListeners();

    await _persistUsers();
    await _persistSession();
    return user;
  }

  Future<AppUser> loginWithPin({
    required String contact,
    required String pin,
  }) async {
    final user = await AuthService.instance.loginWithPin(
      contact: contact,
      pin: pin,
    );

    _currentUser = user;
    _session = AuthService.instance.issueSession(user.id);
    notifyListeners();

    await _persistUsers();
    await _persistSession();
    return user;
  }

  // ── OTP ──────────────────────────────────────────────────────
  Future<bool> verifyOtp({required String code}) async {
    final user = _currentUser;
    if (user == null) throw AuthException('No pending registration.');

    final ok = await AuthService.instance.verifyOtp(
      userId: user.id,
      code: code,
    );

    _currentUser = AuthService.instance.findById(user.id) ?? user;

    if (ok) {
      _session = AuthService.instance.issueSession(_currentUser!.id);
      await _persistSession();
    }

    notifyListeners();
    await _persistUsers();
    return ok;
  }

  Future<void> resendOtp() async {
    final user = _currentUser;
    if (user == null) throw AuthException('No pending registration.');
    await AuthService.instance.resendOtp(user.id);
  }

  // ── Password recovery ────────────────────────────────────────
  Future<String> startPasswordReset(String contact) async {
    return AuthService.instance.startPasswordReset(contact);
  }

  Future<void> completePasswordReset({
    required String userId,
    required String newPassword,
  }) async {
    await AuthService.instance.completePasswordReset(
      userId: userId,
      newPassword: newPassword,
    );
    await _persistUsers();
  }

  // ── Logout ───────────────────────────────────────────────────
  Future<void> logout() async {
    _currentUser = null;
    _session = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSession);
  }

  // ─────────────────────────────────────────────────────────────
  // LINKED PATIENTS
  // ─────────────────────────────────────────────────────────────

  /// Full [AppUser] records of patients linked to the current user.
  /// For patient role, returns a single-item list containing themselves.
  List<AppUser> get linkedPatients {
    final user = _currentUser;
    if (user == null) return const [];

    if (user.role == UserRole.patient) {
      return [user];
    }

    return AuthService.instance.resolvePatients(user.linkedPatientIds);
  }

  /// Link a patient by raw ID. Updates the current caregiver/family user.
  Future<void> linkPatientById(String rawId) async {
    final user = _currentUser;
    if (user == null) {
      throw AuthException('You are not signed in.');
    }
    if (!PatientId.isValid(rawId)) {
      throw AuthException(
        'Please enter a valid ID in the format SMRN-XXXX-XXXX.',
      );
    }

    final updated = await AuthService.instance.linkPatient(
      caregiverUserId: user.id,
      patientIdRaw: rawId,
    );

    _currentUser = updated;
    notifyListeners();
    await _persistUsers();
  }

  /// Unlink a patient by raw ID.
  Future<void> unlinkPatientById(String rawId) async {
    final user = _currentUser;
    if (user == null) return;

    final updated = await AuthService.instance.unlinkPatient(
      caregiverUserId: user.id,
      patientIdRaw: rawId,
    );

    _currentUser = updated;
    notifyListeners();
    await _persistUsers();
  }

  /// Ensure the signed-in patient has a Patient ID.
  /// For accounts created before this feature existed.
  Future<void> ensurePatientId() async {
    final user = _currentUser;
    if (user == null || user.role != UserRole.patient) return;
    if (user.patientId != null) return;

    final newId = PatientId.generate();
    final updated = user.copyWith(patientId: newId);
    _currentUser = updated;
    notifyListeners();
    await _persistUsers();
  }

  // ── Persist ──────────────────────────────────────────────────
  Future<void> _persistUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(
      AuthService.instance.exportUsers().map((u) => u.toJson()).toList(),
    );
    await prefs.setString(_kUsers, raw);
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    final s = _session;
    if (s == null) {
      await prefs.remove(_kSession);
      return;
    }
    await prefs.setString(_kSession, jsonEncode(s.toJson()));
  }

  /// Update the current user (e.g. after editing profile).
  Future<void> updateCurrentUser(AppUser updated) async {
    _currentUser = updated;
    notifyListeners();
    await _persistUsers();
  }
}