class OperationModel {
  const OperationModel({
    required this.id,
    required this.templateId,
    required this.name,
    required this.orderIndex,
  });

  final int id;
  final int templateId;
  final String name;
  final int orderIndex;

  Map<String, Object?> toMap() => {
        'id': id,
        'templateId': templateId,
        'name': name,
        'orderIndex': orderIndex,
      };

  factory OperationModel.fromMap(Map<String, Object?> map) {
    return OperationModel(
      id: map['id']! as int,
      templateId: map['templateId']! as int,
      name: map['name']! as String,
      orderIndex: map['orderIndex']! as int,
    );
  }
}
