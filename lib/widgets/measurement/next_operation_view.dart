import 'package:flutter/material.dart';

class NextOperationView extends StatelessWidget {
  const NextOperationView({
    super.key,
    required this.nextNameOrDash,
    required this.displayKey,
  });

  final String nextNameOrDash;
  final Key displayKey;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.52);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Text(
        'Далее: $nextNameOrDash',
        key: displayKey,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: muted, height: 1.2),
      ),
    );
  }
}
