import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'features/caregiver/caregiver_shell.dart';
import 'core/auth/auth_models.dart';
import 'core/auth/auth_store.dart';
import 'core/domain/app_models.dart';
import 'core/services/alarm_service.dart';
import 'core/services/radio_player_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/language_selection_screen.dart';
import 'features/auth/link_patient_screen.dart';
import 'features/auth/role_selection_screen.dart';
import 'features/shell/shell.dart';
import 'features/splash/splash_screen.dart';
import 'core/services/radio_browser_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Radio background init — MUST be before runApp().
  // Now safe because every AudioSource carries a MediaItem tag.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.smaran_flutter.radio',
      androidNotificationChannelName: 'Smaran Radio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
    await RadioPlayerService.instance.init();
    // ignore: avoid_print
    print('[Smaran] Radio background initialized.');
  } catch (e) {
    // ignore: avoid_print
    print('[Smaran] Radio init failed: $e');
    // App continues — radio will work foreground-only.
  }

  await AlarmService.initialize();
  await AuthStore.instance.boot();
  await RadioBrowserService.instance.init();

  runApp(const SmaranApp());
}

class SmaranApp extends StatefulWidget {
  const SmaranApp({super.key});

  @override
  State<SmaranApp> createState() => _SmaranAppState();
}

class _SmaranAppState extends State<SmaranApp> {
  late final SmaranStore _smaranStore;
  bool _smaranReady = false;

  @override
  void initState() {
    super.initState();
    _smaranStore = SmaranStore();
    _bootSmaranStore();
  }

  Future<void> _bootSmaranStore() async {
    await _smaranStore.load();
    await AlarmService.rescheduleAll(_smaranStore.reminders);
    if (!mounted) return;
    setState(() => _smaranReady = true);
    await AlarmService.openPendingAlarm();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smaran',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cBg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: cPrimary,
          brightness: Brightness.light,
        ),
        fontFamily: 'sans-serif',
      ),
      navigatorKey: smaranNavigatorKey,
      home: !_smaranReady
          ? const Scaffold(
              backgroundColor: cBg,
              body: Center(
                child: CircularProgressIndicator(color: cPrimary),
              ),
            )
          : SplashScreen(
              onFinished: (_) => _RootRouter(store: _smaranStore),
            ),
    );
  }
}

class _RootRouter extends StatefulWidget {
  final SmaranStore store;
  const _RootRouter({required this.store});

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
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

  @override
  Widget build(BuildContext context) {
    final auth = AuthStore.instance;

    if (!auth.hasChosenLanguage) {
      return const LanguageSelectionScreen();
    }

    if (auth.isLoggedIn) {
      final user = auth.currentUser;

      if (user != null &&
          user.role == UserRole.patient &&
          user.patientId == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AuthStore.instance.ensurePatientId();
        });
      }

      // Caregiver / Family with no linked patient yet — must link first.
      if (user != null &&
          user.role != UserRole.patient &&
          user.linkedPatientIds.isEmpty) {
        return const LinkPatientScreen();
      }

      // Role-based routing:
      //   Patient  → normal Shell (games, reminders, radio, ...)
      //   Caregiver / Family → CaregiverShell (dashboard + analytics)
      if (user?.role == UserRole.patient) {
        return Shell(store: widget.store);
      }
      return CaregiverShell(store: widget.store);
    }

    return const RoleSelectionScreen();
  }
}