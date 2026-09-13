import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget Function(BuildContext context) onFinished;

  const SplashScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startSplash();
  }

  Future<void> _startSplash() async {
    /*
     * Dhak starts immediately and loops for the complete
     * splash duration.
     */
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      await _audioPlayer.play(
        AssetSource('audio/dhakk_beat.mp3'),
      );
    } catch (_) {
      // Splash must continue even if audio is unavailable.
    }

    /*
     * EXACTLY 5 SECONDS.
     *
     * No timer.
     * No progress calculation.
     * No CircularProgressIndicator.
     * No loading animation.
     */
    await Future.delayed(
      const Duration(seconds: 5),
    );

    await _finishSplash();
  }

  Future<void> _finishSplash() async {
    if (_finished) return;

    _finished = true;

    /*
     * Stop Dhak before leaving the splash screen.
     */
    try {
      await _audioPlayer.stop();
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: widget.onFinished,
      ),
    );
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /*
       * The image itself covers the entire screen.
       * This is only a fallback color if the image fails.
       */
      backgroundColor: const Color(0xFFFFF6E3),

      body: SizedBox.expand(
        child: Image.asset(
          'assets/images/durga-puja-splash.png',

          /*
           * CRITICAL:
           * Full-screen cover.
           * No contain.
           * No borders.
           * No logo overlay.
           * No loading indicator.
           */
          fit: BoxFit.cover,

          alignment: Alignment.center,

          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return const ColoredBox(
              color: Color(0xFFFFF6E3),
            );
          },
        ),
      ),
    );
  }
}