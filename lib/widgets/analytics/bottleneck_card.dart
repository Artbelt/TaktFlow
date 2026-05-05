import 'package:flutter/material.dart';

import '../../utils/analytics/duration_format.dart';

class BottleneckCard extends StatelessWidget {
  const BottleneckCard({
    super.key,
    required this.operationName,
    required this.averageMs,
  });

  final String operationName;
  final int averageMs;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Узкое место',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    operationName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatDurationMs(averageMs),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
