class MeasurementSessionModel {
  const MeasurementSessionModel({
    required this.id,
    required this.templateId,
    required this.startedAt,
    this.endedAt,
    this.comment,
  });

  final int id;
  final int templateId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? comment;

  Map<String, Object?> toMap() => {
        'id': id,
        'templateId': templateId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'comment': comment,
      };

  factory MeasurementSessionModel.fromMap(Map<String, Object?> map) {
    return MeasurementSessionModel(
      id: map['id']! as int,
      templateId: map['templateId']! as int,
      startedAt: DateTime.parse(map['startedAt']! as String),
      endedAt: map['endedAt'] != null
          ? DateTime.parse(map['endedAt']! as String)
          : null,
      comment: map['comment'] as String?,
    );
  }
}
