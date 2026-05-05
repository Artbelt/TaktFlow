import 'package:flutter/material.dart';

import '../../models/measurement_record_model.dart';

/// Компактный лог последних отсечек (до [maxEntries] строк).
class LastTicksList extends StatelessWidget {
  const LastTicksList({
    super.key,
    required this.recordsNewestFirst,
    this.maxEntries = 3,
  });

  final List<MeasurementRecordModel> recordsNewestFirst;
  final int maxEntries;

  String _durSimple(MeasurementRecordModel r) {
    final s = r.durationMs / 1000.0;
    return '${s.toStringAsFixed(1)}с';
  }

  String _timeShort(DateTime d) {
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final n = recordsNewestFirst.length.clamp(0, maxEntries);
    if (n == 0) {
      return const SizedBox.shrink();
    }

    final slice = recordsNewestFirst.take(maxEntries).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...slice.map((r) {
            final line =
                '${_durSimple(r)} • Ц${r.cycleNumber} • ${_timeShort(r.endedAt)}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.operationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: muted.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    line,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: muted.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
