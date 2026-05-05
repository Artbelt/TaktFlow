import 'package:flutter/material.dart';

class TimeBar extends StatelessWidget {
  const TimeBar({super.key, required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final safe = ratio.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: safe,
        minHeight: 10,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
