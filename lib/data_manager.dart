import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/project.dart';
import 'models/task.dart';
import 'models/time_entry.dart';
import 'models/tag.dart';

class DataManager extends ChangeNotifier {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  final Map<int, TimeEntry> timeData = {};

  List<Project> projects = [
    Project(id: '1', name: '工作', color: Colors.blue.shade600),
    Project(id: '2', name: '会议', color: Colors.indigo.shade400),
    Project(id: '3', name: '深爱', color: Colors.pink.shade300),
    Project(id: '4', name: '运动', color: Colors.orange.shade400),
    Project(id: '5', name: '阅读', color: Colors.teal.shade400),
    Project(id: '6', name: '休息', color: Colors.blueGrey.shade300),
  ];

  List<Task> tasks = [];
  List<Tag> tags = [];
  int timeBlockDuration = 5;

  // --- 初始化 ---
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    timeBlockDuration = prefs.getInt('timeBlockDuration') ?? 5;

    final String? projectsJson = prefs.getString('projects');
    if (projectsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(projectsJson);
        projects = decoded.map((e) => Project.fromJson(e)).toList();
        projects.removeWhere((p) => p.id == 'clear');
      } catch (e) { debugPrint("Error projects: $e"); }
    }

    final String? tasksJson = prefs.getString('tasks');
    if (tasksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tasksJson);
        tasks = decoded.map((e) => Task.fromJson(e)).toList();
      } catch (e) { debugPrint("Error tasks: $e"); }
    }

    final String? tagsJson = prefs.getString('tags');
    if (tagsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tagsJson);
        tags = decoded.map((e) => Tag.fromJson(e)).toList();
      } catch (e) { debugPrint("Error tags: $e"); }
    }

    final String? timeDataJson = prefs.getString('timeData');
    if (timeDataJson != null) {
      try {
        final Map<String, dynamic> decodedMap = jsonDecode(timeDataJson);
        timeData.clear();
        decodedMap.forEach((keyStr, value) {
          final int index = int.parse(keyStr);
          final String projectId = value['projectId'];
          final String? taskId = value['taskId'];
          final String? tagId = value['tagId'];

          final Project? project = getProjectById(projectId);
          if (project != null) {
            Task? task;
            if (taskId != null) {
              try { task = tasks.firstWhere((t) => t.id == taskId); } catch (_) {}
            }
            timeData[index] = TimeEntry(project: project, task: task, tagId: tagId);
          }
        });
      } catch (e) { debugPrint("Error timeData: $e"); }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('projects', jsonEncode(projects.map((p) => p.toJson()).toList()));
    await prefs.setString('tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
    await prefs.setString('tags', jsonEncode(tags.map((t) => t.toJson()).toList()));
    await prefs.setInt('timeBlockDuration', timeBlockDuration);

    final Map<String, dynamic> timeDataMap = {};
    timeData.forEach((key, entry) {
      timeDataMap[key.toString()] = entry.toJson();
    });
    await prefs.setString('timeData', jsonEncode(timeDataMap));
  }

  // --- 时间块操作 ---
  void updateTimeBlockDuration(int newDuration) {
    if (timeBlockDuration == newDuration) return;
    timeBlockDuration = newDuration;
    _save();
    notifyListeners();
  }

  void batchUpdate(Map<int, TimeEntry?> updates) {
    updates.forEach((index, entry) {
      if (entry == null) {
        timeData.remove(index);
      } else {
        timeData[index] = entry;
      }
    });
    _save();
    notifyListeners();
  }

  // --- Project 操作 ---
  void addProject(String name, Color color) {
    projects.add(Project(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, color: color));
    _save();
    notifyListeners();
  }

  void updateProject(String id, String newName, Color newColor) {
    final index = projects.indexWhere((p) => p.id == id);
    if (index != -1) {
      final newProject = Project(id: id, name: newName, color: newColor);
      projects[index] = newProject;
      timeData.forEach((key, entry) {
        if (entry.project.id == id) {
          timeData[key] = TimeEntry(project: newProject, task: entry.task, tagId: entry.tagId);
        }
      });
      _save();
      notifyListeners();
    }
  }

  void removeProject(String id) {
    projects.removeWhere((p) => p.id == id);
    tasks.removeWhere((t) => t.projectId == id);
    timeData.removeWhere((key, value) => value.project.id == id);
    _save();
    notifyListeners();
  }

  void reorderProjects(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final Project item = projects.removeAt(oldIndex);
    projects.insert(newIndex, item);
    _save();
    notifyListeners();
  }

  void mergeProjects(String sourceId, String targetId) {
    final targetProject = getProjectById(targetId);
    if (targetProject == null) return;
    for (int i = 0; i < tasks.length; i++) {
      if (tasks[i].projectId == sourceId) {
        tasks[i] = Task(id: tasks[i].id, name: tasks[i].name, projectId: targetId);
      }
    }
    timeData.forEach((key, entry) {
      if (entry.project.id == sourceId) {
        timeData[key] = TimeEntry(project: targetProject, task: entry.task, tagId: entry.tagId);
      }
    });
    projects.removeWhere((p) => p.id == sourceId);
    _save();
    notifyListeners();
  }

  Project? getProjectById(String id) {
    try { return projects.firstWhere((p) => p.id == id); } catch (_) { return null; }
  }

  // --- Task 操作 ---
  void addTask(String name, String projectId) {
    tasks.add(Task(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, projectId: projectId));
    _save();
    notifyListeners();
  }

  void updateTask(String taskId, String newName, String newProjectId) {
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final newTask = Task(id: taskId, name: newName, projectId: newProjectId);
      tasks[index] = newTask;
      final newParentProject = getProjectById(newProjectId);
      if (newParentProject != null) {
        timeData.forEach((key, entry) {
          if (entry.task?.id == taskId) {
            timeData[key] = TimeEntry(project: newParentProject, task: newTask, tagId: entry.tagId);
          }
        });
      }
      _save();
      notifyListeners();
    }
  }

  void removeTask(String taskId) {
    tasks.removeWhere((t) => t.id == taskId);
    _save();
    notifyListeners();
  }

  // 【核心修复】添加了之前遗漏的 reorderProjectTasks 方法
  void reorderProjectTasks(String projectId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final projectTasks = tasks.where((t) => t.projectId == projectId).toList();
    if (oldIndex >= projectTasks.length) return;

    final Task item = projectTasks.removeAt(oldIndex);
    projectTasks.insert(newIndex, item);

    final otherTasks = tasks.where((t) => t.projectId != projectId).toList();
    tasks = [...otherTasks, ...projectTasks];

    _save();
    notifyListeners();
  }

  void mergeTasks(String sourceTaskId, String targetTaskId) {
    Task? targetTask;
    try { targetTask = tasks.firstWhere((t) => t.id == targetTaskId); } catch (_) {}
    if (targetTask == null) return;
    final targetParentProject = getProjectById(targetTask.projectId);
    if (targetParentProject == null) return;
    timeData.forEach((key, entry) {
      if (entry.task?.id == sourceTaskId) {
        timeData[key] = TimeEntry(project: targetParentProject, task: targetTask, tagId: entry.tagId);
      }
    });
    tasks.removeWhere((t) => t.id == sourceTaskId);
    _save();
    notifyListeners();
  }

  List<Task> getTasksForProject(String projectId) {
    return tasks.where((t) => t.projectId == projectId).toList();
  }

  // --- Tag 操作 ---
  void addTag(String name) {
    tags.add(Tag(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name));
    _save();
    notifyListeners();
  }
  
  void updateTag(String id, String newName) {
    final index = tags.indexWhere((t) => t.id == id);
    if (index != -1) { tags[index] = Tag(id: id, name: newName); _save(); notifyListeners(); }
  }

  void mergeTags(String sourceId, String targetId) {
    timeData.forEach((key, entry) {
      if (entry.tagId == sourceId) {
        timeData[key] = TimeEntry(project: entry.project, task: entry.task, tagId: targetId);
      }
    });
    tags.removeWhere((t) => t.id == sourceId);
    _save();
    notifyListeners();
  }

  void removeTag(String id) {
    tags.removeWhere((t) => t.id == id);
    _save();
    notifyListeners();
  }
  
  Tag? getTagById(String? id) {
    if (id == null) return null;
    try { return tags.firstWhere((t) => t.id == id); } catch (_) { return null; }
  }
}