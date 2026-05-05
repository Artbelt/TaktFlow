class TemplateModel {
  const TemplateModel({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TemplateModel.fromMap(Map<String, Object?> map) {
    return TemplateModel(
      id: map['id']! as int,
      name: map['name']! as String,
      createdAt: DateTime.parse(map['createdAt']! as String),
    );
  }
}
