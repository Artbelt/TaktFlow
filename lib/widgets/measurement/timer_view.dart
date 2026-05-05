import 'package:flutter/material.dart';

/// Формат MM:SS.cs (центисекунды), мягкая смена цифр без «дёрганья».
class MeasurementTimerView extends StatelessWidget {
  const MeasurementTimerView({
    super.key,
    required this.elapsedMs,
    required this.tickerKey,
  });

  final int elapsedMs;
  final Key tickerKey;

  static String formatElapsed(int elapsedMs) {
    final clipped = elapsedMs.clamp(0, 359999999);
    final totalSec = clipped ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    final cs = (clipped % 1000) ~/ 10;
    return '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}.'
        '${cs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final text = formatElapsed(elapsedMs);
    final baseStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
          fontWeight: FontWeight.w800,
          fontSize: 40,
          letterSpacing: 0.6,
        ) ??
        const TextStyle(fontSize: 40, fontWeight: FontWeight.w800);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 85),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeOut,
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: Text(
          text,
          key: tickerKey,
          textAlign: TextAlign.center,
          style: baseStyle,
        ),
      ),
    );
  }
}
