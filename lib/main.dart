import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:local_auth/local_auth.dart';

import 'core/domain/app_models.dart';
import 'core/services/alarm_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/reminders/reminder_screen.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.initialize();
  runApp(const SmaranApp());
}

class SmaranApp extends StatefulWidget {
  const SmaranApp({super.key});
  @override
  State<SmaranApp> createState() => _SmaranAppState();
}

class _SmaranAppState extends State<SmaranApp> {
  late final SmaranStore store;
  bool ready = false;
  @override
  void initState() {
    super.initState();
    store = SmaranStore();
    _boot();
  }

  Future<void> _boot() async {
    await store.load();
    await AlarmService.rescheduleAll(store.reminders);
    if (mounted) {
      setState(() => ready = true);
      await AlarmService.openPendingAlarm();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
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
    home: ready
        ? SplashScreen(onFinished: (_) => LoginScreen(store: store))
        : const Scaffold(
            body: Center(child: CircularProgressIndicator(color: cPrimary)),
          ),
  );
}

class LoginScreen extends StatefulWidget {
  final SmaranStore store;
  const LoginScreen({super.key, required this.store});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final id = TextEditingController(text: '');
  final pass = TextEditingController();
  bool show = false;
  String error = '';
  bool busy = false;
  Future<void> login() async {
    setState(() => error = '');
    final v = id.text.trim();
    if (v.isEmpty || pass.text.isEmpty) {
      setState(() => error = 'Enter your email/phone and password.');
      return;
    }
    if (v == 'caregiver@smaran.app' && pass.text == 'Smaran123' ||
        v == widget.store.caregiverName) {
      setState(() => busy = true);
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingOrHome(store: widget.store),
          ),
        );
    } else {
      setState(
        () => error =
            'Invalid credentials. Demo: caregiver@smaran.app / Smaran123',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Logo(size: 82)),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Welcome back to Smaran',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: cDeep,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'A gentle place for memories, routines and support.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cMuted, fontSize: 15),
              ),
            ),
            const SizedBox(height: 34),
            TextField(
              controller: id,
              keyboardType: TextInputType.emailAddress,
              decoration: inputDec('Email or phone'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pass,
              obscureText: !show,
              decoration: inputDec('Password').copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setState(() => show = !show),
                  icon: Icon(show ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                error,
                style: const TextStyle(
                  color: cDanger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
            primaryButton(
              busy ? 'Signing in…' : 'Sign in',
              busy ? null : login,
              icon: Icons.lock_open_rounded,
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ForgotScreen()),
                ),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SignupScreen(store: widget.store),
                  ),
                ),
                child: const Text('Create a new Smaran account'),
              ),
            ),
            const SizedBox(height: 25),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cMint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Demo access\nEmail: caregiver@smaran.app\nPassword: Smaran123',
                style: TextStyle(color: cDeep, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SignupScreen extends StatefulWidget {
  final SmaranStore store;
  const SignupScreen({super.key, required this.store});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final patient = TextEditingController();
  final caregiver = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  String relation = 'Adult Child';
  String language = 'English';
  Future<void> submit() async {
    if (patient.text.trim().isEmpty ||
        caregiver.text.trim().isEmpty ||
        pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete the required fields.')),
      );
      return;
    }
    widget.store.patientName = patient.text.trim();
    widget.store.caregiverName = caregiver.text.trim();
    await widget.store.save();
    if (mounted)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BiometricScreen(store: widget.store)),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: cBg,
      title: const Text(
        'Create Account',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Logo(size: 70),
          const SizedBox(height: 10),
          Text(
            'Set up a caring Smaran profile',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900, color: cDeep),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: patient,
            decoration: inputDec('Patient name *'),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: caregiver,
            decoration: inputDec('Caregiver name *'),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: inputDec('Caregiver mobile'),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: inputDec('Email'),
          ),
          const SizedBox(height: 13),
          TextField(
            controller: pass,
            obscureText: true,
            decoration: inputDec('Password *'),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            initialValue: relation,
            decoration: inputDec('Relationship'),
            items: [
              'Spouse',
              'Adult Child',
              'Professional Nurse',
              'Relative',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => relation = v!),
          ),
          const SizedBox(height: 13),
          DropdownButtonFormField<String>(
            initialValue: language,
            decoration: inputDec('Preferred language'),
            items: [
              'English',
              'বাংলা',
              'हिन्दी',
              'অসমীয়া',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => language = v!),
          ),
          const SizedBox(height: 24),
          primaryButton(
            'Continue to security',
            submit,
            icon: Icons.security_rounded,
          ),
        ],
      ),
    ),
  );
}

class BiometricScreen extends StatefulWidget {
  final SmaranStore store;
  const BiometricScreen({super.key, required this.store});
  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  bool busy = false;
  String msg = '';
  Future<void> go() async {
    setState(() => busy = true);
    try {
      final auth = LocalAuthentication();
      final ok = await auth.authenticate(
        localizedReason: 'Secure your Smaran account',
      );
      if (ok) {
        await widget.store.save();
        if (mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OnboardingScreen(store: widget.store),
            ),
          );
      } else {
        setState(() => msg = 'Biometric verification was not completed.');
      }
    } catch (e) {
      setState(
        () => msg = 'Biometric is unavailable on this device. You can continue for development.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cWhite,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: cBorder),
            ),
            child: Column(
              children: [
                Container(
                  width: 78,
                  height: 78,
                  decoration: const BoxDecoration(
                    color: cSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    size: 45,
                    color: cPrimaryDark,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Secure your Smaran account',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                    color: cDeep,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Use your device fingerprint, face or other biometric to protect caregiver access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cMuted, fontSize: 15),
                ),
                if (msg.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      msg,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: cDanger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                primaryButton(
                  busy ? 'Verifying…' : 'Verify & continue',
                  busy ? null : go,
                  icon: Icons.verified_user_rounded,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OnboardingScreen(store: widget.store),
                    ),
                  ),
                  child: const Text('Continue without biometric (development)'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class OnboardingOrHome extends StatelessWidget {
  final SmaranStore store;
  const OnboardingOrHome({super.key, required this.store});
  @override
  Widget build(BuildContext c) => OnboardingScreen(store: store);
}

class OnboardingScreen extends StatefulWidget {
  final SmaranStore store;
  const OnboardingScreen({super.key, required this.store});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int i = 0;
  final slides = [
    [
      'Keep your people close',
      'Save familiar faces, moments and stories in one gentle space.',
      'Because familiar memories can make ordinary days feel warmer.',
      Icons.people_alt_rounded,
    ],
    [
      'A little activity every day',
      'Enjoy simple cognitive games designed for calm, comfortable practice.',
      'Recall • Focus • Recognise • Smile',
      Icons.extension_rounded,
    ],
    [
      'Support when you need it',
      'Get reminders, helpful conversations and trusted connections from one app.',
      'Private • Caring • Connected',
      Icons.favorite_rounded,
    ],
  ];
  @override
  Widget build(BuildContext context) {
    final s = slides[i];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${i + 1} / 3',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: cMuted,
                    ),
                  ),
                  const Logo(size: 48),
                ],
              ),
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: (i + 1) / 3,
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
                child: Icon(s[3] as IconData, size: 100, color: cPrimaryDark),
              ),
              const SizedBox(height: 30),
              Text(
                s[0] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                  color: cDeep,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s[1] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: cText, height: 1.4),
              ),
              const SizedBox(height: 10),
              Text(
                s[2] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: cMuted),
              ),
              const Spacer(),
              primaryButton(
                i == 2 ? 'Open Smaran' : 'Continue',
                () => i == 2
                    ? Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Shell(store: widget.store),
                        ),
                      )
                    : setState(() => i++),
                icon: i == 2 ? Icons.home_rounded : Icons.arrow_forward_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  final SmaranStore store;
  const Shell({super.key, required this.store});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  String route = 'home';
  void nav(String r) => setState(() => route = r);
  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (route) {
      case 'family':
        page = FamilyScreen(store: widget.store);
        break;
      case 'photos':
        page = PhotosScreen(store: widget.store);
        break;
      case 'music':
        page = MusicScreen();
        break;
      case 'relax':
        page = RelaxScreen();
        break;
      case 'profile':
        page = ProfileScreen(store: widget.store);
        break;
      default:
        page = HomeScreen(
          store: widget.store,
          onNavigate: nav,
          onOpenFeature: (r) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FeatureRoute(store: widget.store, route: r),
            ),
          ),
        );
    }
    return Scaffold(
      body: SafeArea(child: page),
      bottomNavigationBar: BottomNav(active: route, onNavigate: nav),
    );
  }
}

class BottomNav extends StatelessWidget {
  final String active;
  final ValueChanged<String> onNavigate;
  const BottomNav({super.key, required this.active, required this.onNavigate});
  final items = const [
    ('home', 'Home', Icons.home_rounded),
    ('family', 'Family', Icons.people_alt_rounded),
    ('photos', 'Photos', Icons.photo_library_rounded),
    ('music', 'Music', Icons.music_note_rounded),
    ('relax', 'Relax', Icons.water_drop_rounded),
  ];
  @override
  Widget build(BuildContext c) => Container(
    color: cBg,
    padding: const EdgeInsets.fromLTRB(12, 5, 12, 9),
    child: Container(
      height: 73,
      decoration: BoxDecoration(
        color: cWhite,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: cBorder),
        boxShadow: [
          const BoxShadow(
            color: Color(0x1A7A694E),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: items.map((it) {
          final sel = active == it.$1;
          return Expanded(
            child: InkWell(
              onTap: () => onNavigate(it.$1),
              borderRadius: BorderRadius.circular(18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 34,
                    decoration: BoxDecoration(
                      color: sel ? const Color(0xFFF3E8CF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      it.$3,
                      color: sel ? cPrimaryDark : const Color(0xFF7E827B),
                      size: 21,
                    ),
                  ),
                  Text(
                    it.$2,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: sel ? FontWeight.w900 : FontWeight.w700,
                      color: sel ? cText : cMuted,
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 3,
                    margin: const EdgeInsets.only(top: 3),
                    decoration: BoxDecoration(
                      color: sel ? cPrimaryDark : Colors.transparent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

class FeatureRoute extends StatelessWidget {
  final SmaranStore store;
  final String route;
  const FeatureRoute({super.key, required this.store, required this.route});
  @override
  Widget build(BuildContext c) {
    final Widget w = switch (route) {
      'games' => GamesScreen(store: store),
      'reminders' => RemindersScreen(store: store),
      'talk' => TalkingScreen(store: store),
      'photos' => PhotosScreen(store: store),
      _ => HomeScreen(store: store, onNavigate: (_) {}, onOpenFeature: (_) {}),
    };
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cBg,
        title: Text(
          route[0].toUpperCase() + route.substring(1),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(child: w),
    );
  }
}

class GamesScreen extends StatefulWidget {
  final SmaranStore store;
  const GamesScreen({super.key, required this.store});
  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  int score = 0;
  String message = 'Choose a gentle activity to begin.';
  final games = [
    ['🧠', 'Memory Match', 'Match familiar pairs and exercise recall.'],
    ['123', 'Daily Recall', 'Remember a short sequence.'],
    ['🔎', 'Find the Difference', 'Focus on small visual details.'],
    ['🌸', 'Word & Picture', 'Connect familiar words and images.'],
  ];
  void play(int i) {
    setState(() {
      message =
          'Great! You completed ${games[i][1]}. Your daily practice is recorded locally.';
      score++;
    });
  }

  @override
  Widget build(BuildContext c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Column(
        children: [
          PageHeader(
            title: 'Cognitive Games',
            subtitle: 'Calm, simple activities for recall and focus.',
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cDeep,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(Icons.stars_rounded, color: cSoft, size: 38),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Today: $score / 5 activities',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          ...games.asMap().entries.map((e) {
            return InkWell(
              onTap: () => play(e.key),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.only(bottom: 11),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cBorder),
                ),
                child: Row(
                  children: [
                    Text(e.value[0], style: const TextStyle(fontSize: 32)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.value[1],
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: cText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e.value[2],
                            style: const TextStyle(color: cMuted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: cPrimaryDark,
                      size: 34,
                    ),
                  ],
                ),
              ),
            );
          }),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cMint,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              message,
              style: const TextStyle(color: cDeep, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class PhotosScreen extends StatefulWidget {
  final SmaranStore store;
  const PhotosScreen({super.key, required this.store});
  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final picker = ImagePicker();
  Future<void> add() async {
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    setState(
      () => widget.store.memories.add(
        Memory(title: 'A familiar memory', path: x.path),
      ),
    );
    await widget.store.save();
  }

  @override
  Widget build(BuildContext c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Column(
        children: [
          PageHeader(
            title: 'Memory Garden',
            subtitle: 'Keep familiar moments close.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: add,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Add memory'),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.store.memories.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cWhite,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: cBorder),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 52,
                    color: cPrimaryDark,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Your Memory Garden is empty',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  Text(
                    'Add familiar photos from the phone gallery.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cMuted),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: .9,
              ),
              itemCount: widget.store.memories.length,
              itemBuilder: (context, index) {
                final m = widget.store.memories[index];
                return Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: cWhite,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Image.file(
                          File(m.path),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          m.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class FamilyScreen extends StatefulWidget {
  final SmaranStore store;
  const FamilyScreen({super.key, required this.store});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  Future<void> add() async {
    final n = TextEditingController(),
        r = TextEditingController(text: 'Family');
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add trusted person'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: n, decoration: inputDec('Name')),
            const SizedBox(height: 10),
            TextField(controller: r, decoration: inputDec('Relationship')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (n.text.isNotEmpty) {
                setState(
                  () => widget.store.people.add(
                    Person(name: n.text.trim(), relation: r.text.trim()),
                  ),
                );
                widget.store.save();
                Navigator.pop(c);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Column(
        children: [
          PageHeader(
            title: 'Family Circle',
            subtitle: 'People who help make Smaran feel familiar.',
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: add,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add person'),
            ),
          ),
          const SizedBox(height: 12),
          ...widget.store.people.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cWhite,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cBorder),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: cSoft,
                    child: Icon(Icons.person, color: cPrimaryDark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                          ),
                        ),
                        Text(p.relation, style: const TextStyle(color: cMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => widget.store.people.remove(p));
                      widget.store.save();
                    },
                    icon: const Icon(Icons.delete_outline, color: cDanger),
                  ),
                ],
              ),
            ),
          ),
          if (widget.store.people.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text(
                'No trusted people added yet.',
                style: TextStyle(color: cMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class TalkingScreen extends StatefulWidget {
  final SmaranStore store;
  const TalkingScreen({super.key, required this.store});
  @override
  State<TalkingScreen> createState() => _TalkingScreenState();
}

class _TalkingScreenState extends State<TalkingScreen> {
  final input = TextEditingController();
  final tts = FlutterTts();
  final msgs = <Map<String, String>>[
    {
      'who': 'Smaran',
      'text': 'Hello! I am here with you. You can ask about your reminders or simply talk to me.',
    },
  ];
  Future<void> send() async {
    final q = input.text.trim();
    if (q.isEmpty) return;
    setState(() {
      msgs.add({'who': 'You', 'text': q});
      input.clear();
    });
    String a = 'I am here to help. Let’s take one step at a time.';
    final l = q.toLowerCase();
    if (l.contains('reminder') || l.contains('medicine')) {
      a = widget.store.reminders.isEmpty
          ? 'You have no saved reminders yet.'
          : 'Your next saved routine is ${widget.store.reminders.first.title} at ${widget.store.reminders.first.time}.';
    } else if (l.contains('name')) {
      a = 'Your Smaran profile is for ${widget.store.patientName}.';
    }
    setState(() => msgs.add({'who': 'Smaran', 'text': a}));
    try {
      await tts.setLanguage('en-IN');
      await tts.speak(a);
    } catch (_) {}
  }

  @override
  void dispose() {
    input.dispose();
    tts.stop();
    super.dispose();
  }

  Widget message(Map<String, String> m) {
    final me = m['who'] == 'You';
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(maxWidth: 330),
        decoration: BoxDecoration(
          color: me ? cPrimaryDark : cWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: me ? cPrimaryDark : cBorder),
        ),
        child: Text(
          m['text']!,
          style: TextStyle(color: me ? Colors.white : cText, height: 1.35),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext c) {
    final list = msgs.map(message).toList();
    return Column(
      children: [
        Expanded(
          child: ListView(padding: const EdgeInsets.all(18), children: list),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          color: cBg,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  decoration: inputDec(
                    'Talk to Smaran',
                    hint: 'Ask about a reminder…',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: cPrimaryDark,
                child: IconButton(
                  onPressed: send,
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});
  @override
  State<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends State<MusicScreen> {
  bool playing = false;
  final p = AudioPlayer();
  Future<void> toggle() async {
    if (playing) {
      await p.stop();
      setState(() => playing = false);
    } else {
      try {
        await p.setReleaseMode(ReleaseMode.loop);
        await p.play(AssetSource('audio/dhakk_beat.mp3'));
        setState(() => playing = true);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    p.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => SimpleFeature(
    title: 'Music',
    subtitle: 'Familiar sounds for a calm moment.',
    icon: Icons.music_note_rounded,
    child: Column(
      children: [
        const Text(
          'Gentle audio can be part of a familiar daily routine.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cMuted, fontSize: 16),
        ),
        const SizedBox(height: 22),
        Container(
          width: 150,
          height: 150,
          decoration: const BoxDecoration(color: cSoft, shape: BoxShape.circle),
          child: const Icon(
            Icons.music_note_rounded,
            size: 80,
            color: cPrimaryDark,
          ),
        ),
        const SizedBox(height: 22),
        primaryButton(
          playing ? 'Stop dhak beat' : 'Play dhak beat',
          toggle,
          icon: playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
        ),
      ],
    ),
  );
}

class RelaxScreen extends StatefulWidget {
  const RelaxScreen({super.key});
  @override
  State<RelaxScreen> createState() => _RelaxScreenState();
}

class _RelaxScreenState extends State<RelaxScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
      lowerBound: .75,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => SimpleFeature(
    title: 'Relax',
    subtitle: 'Slow down and breathe.',
    icon: Icons.water_drop_rounded,
    child: Column(
      children: [
        const Text(
          'Take a comfortable breath in… and slowly breathe out.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: cText, height: 1.5),
        ),
        const SizedBox(height: 30),
        AnimatedBuilder(
          animation: controller,
          builder: (c, _) => Container(
            width: 160 * controller.value,
            height: 160 * controller.value,
            decoration: const BoxDecoration(
              color: cSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.air_rounded, size: 70, color: cPrimaryDark),
          ),
        ),
        const SizedBox(height: 25),
        const Text(
          'There is no rush.',
          style: TextStyle(color: cMuted, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class SimpleFeature extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Widget child;
  const SimpleFeature({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });
  @override
  Widget build(BuildContext c) => SingleChildScrollView(
    padding: const EdgeInsets.all(22),
    child: Column(
      children: [
        PageHeader(title: title, subtitle: subtitle),
        const SizedBox(height: 25),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cWhite,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: cBorder),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: cSoft,
                child: Icon(icon, size: 48, color: cPrimaryDark),
              ),
              const SizedBox(height: 25),
              child,
            ],
          ),
        ),
      ],
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  final SmaranStore store;
  const ProfileScreen({super.key, required this.store});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController p, c;
  late String lang;
  @override
  void initState() {
    super.initState();
    p = TextEditingController(text: widget.store.patientName);
    c = TextEditingController(text: widget.store.caregiverName);
    lang = widget.store.language;
  }

  @override
  void dispose() {
    p.dispose();
    c.dispose();
    super.dispose();
  }

  Future<void> save() async {
    widget.store.patientName = p.text.trim().isEmpty
        ? 'Patient'
        : p.text.trim();
    widget.store.caregiverName = c.text.trim().isEmpty
        ? 'Caregiver'
        : c.text.trim();
    widget.store.language = lang;
    await widget.store.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: cBg,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Logo(size: 75),
            const SizedBox(height: 15),
            TextField(controller: p, decoration: inputDec('Patient name')),
            const SizedBox(height: 12),
            TextField(controller: c, decoration: inputDec('Caregiver name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: lang,
              decoration: inputDec('Language'),
              items: [
                'English',
                'বাংলা',
                'हिन्दी',
                'অসমীয়া',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => lang = v!),
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              title: const Text(
                'Guardian mode',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Keep caregiver-oriented controls enabled.'),
              value: widget.store.guardian,
              onChanged: (v) {
                setState(() => widget.store.guardian = v);
                widget.store.save();
              },
            ),
            const SizedBox(height: 18),
            primaryButton('Save profile', save, icon: Icons.save_rounded),
          ],
        ),
      ),
    );
  }
}

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final x = TextEditingController();
  String msg = '';
  @override
  void dispose() {
    x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    appBar: AppBar(
      backgroundColor: cBg,
      title: const Text(
        'Password recovery',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Logo(size: 70),
          const SizedBox(height: 20),
          const Text(
            'Forgot your password?',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: cDeep,
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: x, decoration: inputDec('Email or phone')),
          const SizedBox(height: 20),
          primaryButton('Start recovery', () {
            setState(
              () => msg = 'If the account exists, recovery instructions will be sent to the registered contact.',
            );
          }),
          if (msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(
                msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: cPrimaryDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
