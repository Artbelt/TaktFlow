class MeasurementRecordModel {
  const MeasurementRecordModel({
    required this.id,
    required this.sessionId,
    required this.templateId,
    required this.operationId,
    required this.operationName,
    required this.cycleNumber,
    required this.startedAt,
    required this.endedAt,
    required this.durationMs,
    this.comment,
  });

  final int id;
  final int sessionId;
  final int templateId;
  final int operationId;
  final String operationName;
  final int cycleNumber;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMs;
  final String? comment;

  Map<String, Object?> toMap() => {
        'id': id,
        'sessionId': sessionId,
        'templateId': templateId,
        'operationId': operationId,
        'operationName': operationName,
        'cycleNumber': cycleNumber,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt.toIso8601String(),
        'durationMs': durationMs,
        'comment': comment,
      };

  factory MeasurementRecordModel.fromMap(Map<String, Object?> map) {
    return MeasurementRecordModel(
      id: map['id']! as int,
      sessionId: map['sessionId']! as int,
      templateId: map['templateId']! as int,
      operationId: map['operationId']! as int,
      operationName: map['operationName']! as String,
      cycleNumber: map['cycleNumber']! as int,
      startedAt: DateTime.parse(map['startedAt']! as String),
      endedAt: DateTime.parse(map['endedAt']! as String),
      durationMs: map['durationMs']! as int,
      comment: map['comment'] as String?,
    );
  }
}
