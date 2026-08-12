class Exercise {
  const Exercise({required this.id, required this.name, required this.isCustom});

  final String id;
  final String name;
  final bool isCustom;

  Map<String, dynamic> toJson() => {'name': name, 'isCustom': isCustom};

  factory Exercise.fromJson(String id, Map<String, dynamic> json) {
    return Exercise(
      id: id,
      name: json['name'] as String,
      isCustom: json['isCustom'] as bool,
    );
  }
}
