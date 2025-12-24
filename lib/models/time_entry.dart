import 'project.dart';
import 'task.dart';

class TimeEntry {
  final Project project;
  final Task? task;

  TimeEntry({required this.project, this.task});

  String get displayName => task?.name ?? project.name;
  String get uniqueId => "${project.id}_${task?.id ?? 'root'}";

  // --- 新增：保存时只存 ID ---
  Map<String, dynamic> toJson() {
    return {
      'projectId': project.id,
      'taskId': task?.id, // 可能为 null
    };
  }
  
  // 恢复逻辑将在 DataManager 中处理，因为需要访问 projects 列表
}