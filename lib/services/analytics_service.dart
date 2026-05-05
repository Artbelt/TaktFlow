import '../models/analytics_models.dart';
import '../models/measurement_record_model.dart';
import '../models/operation_model.dart';

class AnalyticsService {
  static SessionAnalytics calculateSessionAnalytics({
    required List<MeasurementRecordModel> records,
    required List<OperationModel> templateOperations,
  }) {
    final opIds = templateOperations.map((o) => o.id).toSet();
    final requiredOpsCount = opIds.length;
    final byCycle = <int, List<MeasurementRecordModel>>{};

    for (final r in records) {
      byCycle.putIfAbsent(r.cycleNumber, () => []).add(r);
    }

    final completedCycleRecords = <MeasurementRecordModel>[];
    for (final entry in byCycle.entries) {
      final cycleOps = entry.value.map((r) => r.operationId).toSet();
      if (cycleOps.length == requiredOpsCount && cycleOps.containsAll(opIds)) {
        completedCycleRecords.addAll(entry.value);
      }
    }

    final completedCycles = completedCycleRecords.map((r) => r.cycleNumber).toSet().length;
    if (completedCycleRecords.isEmpty) {
      return const SessionAnalytics(
        averageCycleMs: 0,
        completedCyclesCount: 0,
        bottleneckOperationName: '—',
        bottleneckAverageMs: 0,
        averageSpreadMs: 0,
        operations: [],
      );
    }

    final byOperation = <int, List<MeasurementRecordModel>>{};
    for (final r in completedCycleRecords) {
      byOperation.putIfAbsent(r.operationId, () => []).add(r);
    }

    final cycleTotals = <int, int>{};
    for (final r in completedCycleRecords) {
      cycleTotals.update(r.cycleNumber, (v) => v + r.durationMs, ifAbsent: () => r.durationMs);
    }
    final averageCycleMs =
        cycleTotals.values.fold<int>(0, (sum, v) => sum + v) ~/ cycleTotals.length;

    final operationsAnalytics = <OperationAnalytics>[];
    var spreadSum = 0;
    final sortedOps = List<OperationModel>.from(templateOperations)
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    for (final op in sortedOps) {
      final rows = byOperation[op.id] ?? const [];
      if (rows.isEmpty) continue;
      final durations = rows.map((r) => r.durationMs).toList()..sort();
      final sum = durations.fold<int>(0, (a, b) => a + b);
      final avg = sum ~/ durations.length;
      final min = durations.first;
      final max = durations.last;
      final spread = max - min;
      spreadSum += spread;
      final percent = averageCycleMs == 0 ? 0 : avg / averageCycleMs;

      final variation = avg == 0 ? 0 : spread / avg;
      final stability = variation < 0.15
          ? 'стабильно'
          : variation <= 0.35
              ? 'средний разброс'
              : 'нестабильно';

      final importance = percent > 0.40
          ? 'узкое место'
          : percent >= 0.20
              ? 'существенно'
              : 'норма';

      operationsAnalytics.add(
        OperationAnalytics(
          operationName: op.name,
          averageMs: avg,
          minMs: min,
          maxMs: max,
          spreadMs: spread,
          count: durations.length,
          percentOfCycle: percent * 100,
          stabilityLabel: stability,
          importanceLabel: importance,
        ),
      );
    }

    operationsAnalytics.sort((a, b) => b.averageMs.compareTo(a.averageMs));
    final bottleneck = operationsAnalytics.isEmpty ? null : operationsAnalytics.first;
    final avgSpread =
        operationsAnalytics.isEmpty ? 0 : spreadSum ~/ operationsAnalytics.length;

    return SessionAnalytics(
      averageCycleMs: averageCycleMs,
      completedCyclesCount: completedCycles,
      bottleneckOperationName: bottleneck?.operationName ?? '—',
      bottleneckAverageMs: bottleneck?.averageMs ?? 0,
      averageSpreadMs: avgSpread,
      operations: operationsAnalytics,
    );
  }
}
