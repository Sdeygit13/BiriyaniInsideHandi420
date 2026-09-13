import 'package:flutter/material.dart';

import 'core/domain/app_models.dart';
import 'core/services/alarm_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/reminders/reminder_screen.dart';
import 'features/splash/splash_screen.dart';
import 'features/talk/talking_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.initialize();
  runApp(const SmaranApp());
}

// =============================================================================
// ROOT — boot, store, then SplashScreen → Login
// =============================================================================
class SmaranApp extends StatefulWidget {
  const SmaranApp({super.key});

  @override
  State<SmaranApp> createState() => _SmaranAppState();
}

class _SmaranAppState extends State<SmaranApp> {
  late final SmaranStore store;
  bool _booted = false;

  @override
  void initState() {
    super.initState();
    store = SmaranStore();
    _boot();
  }

  Future<void> _boot() async {
    await store.load();
    await AlarmService.rescheduleAll(store.reminders);
    if (!mounted) return;
    setState(() => _booted = true);
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
      home: _booted
          ? SplashScreen(
              onFinished: (_) => _RootFlow(store: store),
            )
          : const Scaffold(
              backgroundColor: cBg,
              body: _BootLoading(),
            ),
    );
  }
}

class _BootLoading extends StatelessWidget {
  const _BootLoading();

  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: cPrimary),
      );
}

// =============================================================================
// ROOT FLOW — replaces App.js screen state machine
//
// The flow is:
//   SplashScreen → _RootFlow
//     _RootFlow decides: Login | Signup | Biometric | Onboarding | Shell
//       Navigation handled via Navigator.push / pushReplacement
// =============================================================================
class _RootFlow extends StatelessWidget {
  final SmaranStore store;
  const _RootFlow({required this.store});

  @override
  Widget build(BuildContext context) {
    return LoginScreen(store: store);
  }
}

// =============================================================================
// LOGIN
// =============================================================================
class LoginScreen extends StatefulWidget {
  final SmaranStore store;
  const LoginScreen({super.key, required this.store});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController();
  final _passController = TextEditingController();
  bool _showPass = false;
  bool _busy = false;
  String _error = '';

  static const _demoEmail = 'caregiver@smaran.app';
  static const _demoPass = 'Smaran123';

  @override
  void dispose() {
    _idController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = '');

    final id = _idController.text.trim();
    final pass = _passController.text;

    if (id.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }

    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 500));

    final ok = id.toLowerCase() == _demoEmail && pass == _demoPass;

    if (!mounted) return;
    setState(() => _busy = false);

    if (!ok) {
      setState(() => _error = 'Invalid username or password.');
      return;
    }

    // Successful login → Onboarding
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(store: widget.store),
      ),
    );
  }

  void _goSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignupScreen(store: widget.store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
              decoration: BoxDecoration(
                color: cWhite,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A7A694E),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: Logo(size: 78)),
                  const SizedBox(height: 14),
                  const Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: cText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in to continue caring for the moments that matter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: cMuted, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _idController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: inputDec('Email or Phone Number'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passController,
                    obscureText: !_showPass,
                    decoration: inputDec('Password').copyWith(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _showPass = !_showPass),
                        icon: Icon(
                          _showPass ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: cDanger.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _error,
                        style: const TextStyle(
                          color: cDanger,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  primaryButton(
                    _busy ? 'Signing in…' : 'Log In',
                    _busy ? null : _submit,
                    icon: Icons.login_rounded,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : _goSignup,
                    child: const Text('Create a Smaran account'),
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
// SIGNUP (simplified — connects to existing flow)
// =============================================================================
class SignupScreen extends StatefulWidget {
  final SmaranStore store;
  const SignupScreen({super.key, required this.store});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _caregiver = TextEditingController();
  final _patient = TextEditingController();
  final _pass = TextEditingController();
  String _language = 'English';

  @override
  void dispose() {
    _caregiver.dispose();
    _patient.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_caregiver.text.trim().isEmpty ||
        _patient.text.trim().isEmpty ||
        _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the required fields.')),
      );
      return;
    }

    widget.store.caregiverName = _caregiver.text.trim();
    widget.store.patientName = _patient.text.trim();
    widget.store.language = _language;
    await widget.store.save();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingScreen(store: widget.store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: cBg,
        elevation: 0,
        title: const Text('Create Account',
            style: TextStyle(fontWeight: FontWeight.w900, color: cText)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Logo(size: 70)),
              const SizedBox(height: 14),
              TextField(
                controller: _patient,
                decoration: inputDec('Patient name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _caregiver,
                decoration: inputDec('Caregiver name *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: inputDec('Password *'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: inputDec('Preferred language'),
                items: ['English', 'বাংলা', 'हिन्दी', 'অসমীয়া']
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e, style: const TextStyle(fontSize: 16)),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _language = v);
                },
              ),
              const SizedBox(height: 20),
              primaryButton('Continue', _submit, icon: Icons.arrow_forward),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// ONBOARDING (3 slides)
// =============================================================================
class OnboardingScreen extends StatefulWidget {
  final SmaranStore store;
  const OnboardingScreen({super.key, required this.store});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _index = 0;

  static const _slides = [
    (
      'Keep your people close',
      'Save familiar faces, moments and stories in one gentle space.',
      Icons.people_alt_rounded,
    ),
    (
      'A little activity every day',
      'Enjoy simple cognitive games designed for calm, comfortable practice.',
      Icons.extension_rounded,
    ),
    (
      'Support when you need it',
      'Get reminders, helpful conversations and trusted connections.',
      Icons.favorite_rounded,
    ),
  ];

  void _next() {
    if (_index == _slides.length - 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => Shell(store: widget.store)),
      );
    } else {
      setState(() => _index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _slides[_index];
    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_index + 1} / ${_slides.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, color: cMuted)),
                  const Logo(size: 48),
                ],
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: (_index + 1) / _slides.length,
                color: cPrimary,
                backgroundColor: cSoft,
                minHeight: 7,
                borderRadius: BorderRadius.circular(10),
              ),
              const Spacer(),
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: cMint,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(s.$3, size: 100, color: cPrimaryDark),
              ),
              const SizedBox(height: 30),
              Text(
                s.$1,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: cDeep,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.$2,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: cText,
                  height: 1.5,
                ),
              ),
              const Spacer(),
              primaryButton(
                _index == _slides.length - 1 ? 'Open Smaran' : 'Continue',
                _next,
                icon: _index == _slides.length - 1
                    ? Icons.home_rounded
                    : Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SHELL — bottom nav + IndexedStack
// =============================================================================
class Shell extends StatefulWidget {
  final SmaranStore store;
  const Shell({super.key, required this.store});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tabIndex = 0;

  void _navigate(String route) {
    switch (route) {
      case 'home':
        setState(() => _tabIndex = 0);
        break;
      case 'family':
        setState(() => _tabIndex = 1);
        break;
      case 'photos':
        setState(() => _tabIndex = 2);
        break;
      case 'music':
        setState(() => _tabIndex = 3);
        break;
      case 'relax':
        setState(() => _tabIndex = 4);
        break;
      default:
        break;
    }
  }

  void _openFeature(String route) {
    switch (route) {
      case 'games':
      case 'talk':
      case 'reminders':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => _FeatureRoute(store: widget.store, route: route),
          ),
        ).then((_) {
          // Rebuild home when returning
          if (mounted) setState(() {});
        });
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        store: widget.store,
        onNavigate: _navigate,
        onOpenFeature: _openFeature,
      ),
      const _Placeholder(title: 'Family'),
      const _Placeholder(title: 'Photos'),
      const _Placeholder(title: 'Music'),
      const _Placeholder(title: 'Relax'),
    ];

    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _tabIndex, children: pages),
      ),
      bottomNavigationBar: _BottomNav(
        index: _tabIndex,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          '$title screen — coming soon.',
          style: const TextStyle(fontSize: 18, color: cMuted, fontWeight: FontWeight.w700),
        ),
      );
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.index, required this.onTap});

  static const _items = [
    ('Home', Icons.home_rounded),
    ('Family', Icons.people_alt_rounded),
    ('Photos', Icons.photo_library_rounded),
    ('Music', Icons.music_note_rounded),
    ('Relax', Icons.water_drop_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        color: cBg,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: cWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: cBorder, width: 1.1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A7A694E),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: _items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final selected = index == i;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 26,
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFF3E8CF) : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          item.$2,
                          size: 20,
                          color: selected ? cPrimaryDark : const Color(0xFF7E827B),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        item.$1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                          color: selected ? cText : cMuted,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// FEATURE ROUTE — push for games / talk / reminders
// =============================================================================
class _FeatureRoute extends StatelessWidget {
  final SmaranStore store;
  final String route;
  const _FeatureRoute({required this.store, required this.route});

  @override
  Widget build(BuildContext context) {
    final Widget page = switch (route) {
      'reminders' => RemindersScreen(store: store),
      'talk' => const TalkingScreen(),
      _ => const _Placeholder(title: 'Feature'),
    };

    return Scaffold(
      backgroundColor: cBg,
      appBar: AppBar(
        backgroundColor: cBg,
        elevation: 0,
        title: Text(
          route[0].toUpperCase() + route.substring(1),
          style: const TextStyle(fontWeight: FontWeight.w900, color: cText),
        ),
      ),
      body: SafeArea(child: page),
    );
  }
}