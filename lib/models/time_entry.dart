import 'project.dart';
import 'task.dart';

class TimeEntry {
  final Project project;
  final Task? task;
  final String? tagId; // 【新增】标签ID

  TimeEntry({
    required this.project, 
    this.task, 
    this.tagId, // 【新增】
  });

  String get displayName => task?.name ?? project.name;
  
  // uniqueId 加入 tagId，确保不同标签的块不会被合并（或者你可以决定同项目同任务不同标签是否合并，这里假设不合并）
  String get uniqueId => "${project.id}_${task?.id ?? 'root'}_${tagId ?? 'none'}";

  Map<String, dynamic> toJson() {
    return {
      'projectId': project.id,
      'taskId': task?.id,
      'tagId': tagId, // 【新增】
    };
  }
  
  // 复制并修改的方法
  TimeEntry copyWith({String? tagId, bool clearTag = false}) {
    return TimeEntry(
      project: project,
      task: task,
      tagId: clearTag ? null : (tagId ?? this.tagId),
    );
  }
}