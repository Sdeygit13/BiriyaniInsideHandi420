import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final WidgetBuilder onFinished;
  const SplashScreen({super.key, required this.onFinished});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AudioPlayer _player = AudioPlayer();
  Timer? _timer;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource('audio/dhakk_beat.mp3'));
    } catch (_) {}

    const totalTicks = 50;
    var ticks = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      ticks++;
      setState(() => _progress = ticks / totalTicks);
      if (ticks >= totalTicks) {
        timer.cancel();
        _finish();
      }
    });
  }

  Future<void> _finish() async {
    await _player.stop();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: widget.onFinished));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: cBg,
        body: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoSize = constraints.maxWidth.clamp(110.0, 190.0).toDouble();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Image.asset(
                          'assets/images/durga-puja-splash.png',
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Exactly one Smaran logo. The old duplicate small S overlay is removed.
                    Image.asset(
                      'assets/images/smaran-splash-icon.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 5,
                        color: cPrimaryDark,
                        backgroundColor: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('Smaran', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, color: cDeep)),
                    const SizedBox(height: 20),
                  ],
                );
              },
            ),
          ),
        ),
      );
}
