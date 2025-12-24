class Task {
  final String id;
  final String name;
  final String projectId;

  Task({
    required this.id,
    required this.name,
    required this.projectId,
  });

  // --- 新增：转为 JSON Map ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'projectId': projectId,
    };
  }

  // --- 新增：从 JSON Map 创建对象 ---
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      name: json['name'],
      projectId: json['projectId'],
    );
  }
}