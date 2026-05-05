import 'package:flutter/material.dart';

import '../../models/analytics_models.dart';
import '../../utils/analytics/duration_format.dart';
import 'time_bar.dart';

class OperationAnalyticsCard extends StatelessWidget {
  const OperationAnalyticsCard({
    super.key,
    required this.data,
    required this.maxAverageMs,
  });

  final OperationAnalytics data;
  final int maxAverageMs;

  (Color, String) _importanceStyle(ColorScheme scheme) {
    switch (data.importanceLabel) {
      case 'узкое место':
        return (scheme.error, 'узкое место');
      case 'существенно':
        return (scheme.primary, 'существенно');
      default:
        return (const Color(0xFF43A047), 'норма');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (badgeColor, badgeText) = _importanceStyle(scheme);
    final ratio = maxAverageMs <= 0 ? 0.0 : data.averageMs / maxAverageMs;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.operationName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDurationMs(data.averageMs)} · ${data.percentOfCycle.toStringAsFixed(0)}% цикла',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Мин ${formatDurationMs(data.minMs)} · Макс ${formatDurationMs(data.maxMs)} · '
              'Разброс ${formatDurationMs(data.spreadMs)} · n=${data.count}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.stabilityLabel,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            TimeBar(ratio: ratio.toDouble(), color: badgeColor),
          ],
        ),
      ),
    );
  }
}
