import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Full-screen splash with rotating loader.
///
/// Runs for exactly 5 seconds from mount, plays the dhak beat for the
/// full duration, and transitions smoothly. Audio and animation are
/// started in parallel — nothing is awaited before the first frame.
class SplashScreen extends StatefulWidget {
  final Widget Function(BuildContext context) onFinished;

  const SplashScreen({
    super.key,
    required this.onFinished,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const double _artW = 768;
  static const double _artH = 1364;
  static const double _loaderCenterX = 384;
  static const double _loaderCenterY = 978;
  static const double _loaderSize = 104;

  static const Duration _splashDuration = Duration(seconds: 5);

  final AudioPlayer _audioPlayer = AudioPlayer();
  late final AnimationController _rotation;
  Timer? _finishTimer;
  bool _finished = false;

  @override
  void initState() {
    super.initState();

    // 1. Kick off the loader rotation immediately (no awaits).
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    // 2. Start audio in the background — DO NOT await.
    //    If it fails, splash still runs.
    unawaited(_startAudio());

    // 3. Start the 5-second timer immediately.
    //    Total splash time is 5 seconds from mount, guaranteed.
    _finishTimer = Timer(_splashDuration, _finish);
  }

  Future<void> _startAudio() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(0.8);
      await _audioPlayer.play(AssetSource('audio/dhakk_beat.mp3'));
    } catch (_) {
      // Silent — splash continues without audio.
    }
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;

    try {
      await _audioPlayer.stop();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: widget.onFinished),
    );
  }

  @override
  void dispose() {
    _finishTimer?.cancel();
    _rotation.dispose();
    try {
      _audioPlayer.stop();
      _audioPlayer.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8E7BF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenW = constraints.maxWidth;
          final screenH = constraints.maxHeight;

          final scale = (screenW / _artW).clamp(0.0, screenH / _artH);
          final displayedW = _artW * scale;
          final displayedH = _artH * scale;
          final imageLeft = (screenW - displayedW) / 2;
          final imageTop = (screenH - displayedH) / 2;

          final loaderPx = _loaderSize * scale;
          final loaderLeft =
              imageLeft + (_loaderCenterX * scale) - (loaderPx / 2);
          final loaderTop =
              imageTop + (_loaderCenterY * scale) - (loaderPx / 2);

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/durga-puja-splash.png',
                  width: displayedW,
                  height: displayedH,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFF8E7BF),
                  ),
                ),
              ),
              Positioned(
                left: loaderLeft,
                top: loaderTop,
                width: loaderPx,
                height: loaderPx,
                child: IgnorePointer(
                  child: RotationTransition(
                    turns: _rotation,
                    child: CustomPaint(
                      painter: _ArcLoaderPainter(
                        strokeWidth: (loaderPx * 0.075).clamp(4.0, 8.0),
                        color: const Color(0xFFC58A22),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ArcLoaderPainter extends CustomPainter {
  final double strokeWidth;
  final Color color;

  _ArcLoaderPainter({required this.strokeWidth, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width / 2) - (strokeWidth / 2);
    final center = Offset(size.width / 2, size.height / 2);

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const startAngle = -1.5708;
    const sweepAngle = 4.7124;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcLoaderPainter old) =>
      old.strokeWidth != strokeWidth || old.color != color;
}