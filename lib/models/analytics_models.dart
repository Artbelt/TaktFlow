class SessionAnalytics {
  const SessionAnalytics({
    required this.averageCycleMs,
    required this.completedCyclesCount,
    required this.bottleneckOperationName,
    required this.bottleneckAverageMs,
    required this.averageSpreadMs,
    required this.operations,
  });

  final int averageCycleMs;
  final int completedCyclesCount;
  final String bottleneckOperationName;
  final int bottleneckAverageMs;
  final int averageSpreadMs;
  final List<OperationAnalytics> operations;
}

class OperationAnalytics {
  const OperationAnalytics({
    required this.operationName,
    required this.averageMs,
    required this.minMs,
    required this.maxMs,
    required this.spreadMs,
    required this.count,
    required this.percentOfCycle,
    required this.stabilityLabel,
    required this.importanceLabel,
  });

  final String operationName;
  final int averageMs;
  final int minMs;
  final int maxMs;
  final int spreadMs;
  final int count;
  final double percentOfCycle;
  final String stabilityLabel;
  final String importanceLabel;
}
