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

  // --- 初始化 ---
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Load Projects
    final String? projectsJson = prefs.getString('projects');
    if (projectsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(projectsJson);
        projects = decoded.map((e) => Project.fromJson(e)).toList();
      } catch (e) { debugPrint("Error projects: $e"); }
    }

    // 2. Load Tasks
    final String? tasksJson = prefs.getString('tasks');
    if (tasksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tasksJson);
        tasks = decoded.map((e) => Task.fromJson(e)).toList();
      } catch (e) { debugPrint("Error tasks: $e"); }
    }

    // 3. Load Tags
    final String? tagsJson = prefs.getString('tags');
    if (tagsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tagsJson);
        tags = decoded.map((e) => Tag.fromJson(e)).toList();
      } catch (e) { debugPrint("Error tags: $e"); }
    }

    // 4. Load TimeData
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

  // --- 保存 ---
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('projects', jsonEncode(projects.map((p) => p.toJson()).toList()));
    await prefs.setString('tasks', jsonEncode(tasks.map((t) => t.toJson()).toList()));
    await prefs.setString('tags', jsonEncode(tags.map((t) => t.toJson()).toList()));
    
    final Map<String, dynamic> timeDataMap = {};
    timeData.forEach((key, entry) {
      timeDataMap[key.toString()] = entry.toJson();
    });
    await prefs.setString('timeData', jsonEncode(timeDataMap));
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

  // --- 项目 (Project) 操作 ---

  void addProject(String name, Color color) {
    projects.add(Project(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, color: color));
    _save();
    notifyListeners();
  }

  // 【修改点】更新项目时，同步更新 timeData 中所有引用该项目的块
  void updateProject(String id, String newName, Color newColor) {
    final index = projects.indexWhere((p) => p.id == id);
    if (index != -1) {
      // 1. 更新项目列表
      final newProject = Project(id: id, name: newName, color: newColor);
      projects[index] = newProject;

      // 2. 遍历 timeData，替换所有引用旧项目的条目
      timeData.forEach((key, entry) {
        if (entry.project.id == id) {
          // 创建新的 Entry，保持原有的 Task 和 Tag，但替换 Project
          timeData[key] = TimeEntry(
            project: newProject, // 使用新项目对象(含新颜色/新名称)
            task: entry.task,
            tagId: entry.tagId
          );
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

  Project? getProjectById(String id) {
    try { return projects.firstWhere((p) => p.id == id); } catch (_) { return null; }
  }

  // --- 任务 (Task) 操作 ---

  void addTask(String name, String projectId) {
    tasks.add(Task(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, projectId: projectId));
    _save();
    notifyListeners();
  }

  // 【修改点】更新任务时，同步更新 timeData
  void updateTask(String taskId, String newName, String newProjectId) {
    final index = tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      // 1. 更新任务列表
      final newTask = Task(id: taskId, name: newName, projectId: newProjectId);
      tasks[index] = newTask;

      // 2. 获取该任务对应的新父级项目 (因为父级可能也改了)
      final newParentProject = getProjectById(newProjectId);

      if (newParentProject != null) {
        // 3. 遍历 timeData，替换所有引用旧任务的条目
        timeData.forEach((key, entry) {
          if (entry.task?.id == taskId) {
            // 如果改了归属，不仅 Task 变了，Project 也得变，颜色也要跟着变
            timeData[key] = TimeEntry(
              project: newParentProject, // 更新为新的父级项目
              task: newTask,             // 更新为新的任务信息
              tagId: entry.tagId         // 保持标签不变
            );
          }
        });
      }

      _save();
      notifyListeners();
    }
  }

  void removeTask(String taskId) {
    tasks.removeWhere((t) => t.id == taskId);
    // 可选：清除 timeData 中引用该 task 的数据，或者降级为仅显示项目
    // timeData.removeWhere((k, v) => v.task?.id == taskId); 
    _save();
    notifyListeners();
  }

  List<Task> getTasksForProject(String projectId) {
    return tasks.where((t) => t.projectId == projectId).toList();
  }

  // --- 标签 (Tag) 操作 ---

  void addTag(String name) {
    tags.add(Tag(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name));
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