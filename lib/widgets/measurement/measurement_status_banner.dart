import 'package:flutter/material.dart';

/// Индикатор ● Пауза / ● Идёт замер + номер цикла в одну строку.
class MeasurementStatusBanner extends StatelessWidget {
  const MeasurementStatusBanner({
    super.key,
    required this.started,
    required this.paused,
    required this.cycleNumber,
  });

  final bool started;
  final bool paused;
  final int cycleNumber;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (!started) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              'Цикл не начат',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final running = !paused;
    final dotColor = running ? const Color(0xFF43A047) : scheme.primary;
    final label = running ? 'Идёт замер' : 'Пауза';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.circle, size: 9, color: dotColor),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: dotColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('·', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
          Text(
            'Цикл $cycleNumber',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
