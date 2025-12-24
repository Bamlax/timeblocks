import 'dart:convert'; // 用于 JSON 编解码
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 引入存储插件
import 'models/project.dart';
import 'models/task.dart';
import 'models/time_entry.dart';

class DataManager extends ChangeNotifier {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  final Map<int, TimeEntry> timeData = {};
  
  // 默认项目（当没有存档时使用）
  List<Project> projects = [
    Project(id: '1', name: '工作', color: Colors.blue.shade600),
    Project(id: '2', name: '会议', color: Colors.indigo.shade400),
    Project(id: '3', name: '深爱', color: Colors.pink.shade300),
    Project(id: '4', name: '运动', color: Colors.orange.shade400),
    Project(id: '5', name: '阅读', color: Colors.teal.shade400),
    Project(id: '6', name: '休息', color: Colors.blueGrey.shade300),
    Project(id: 'clear', name: '清除', color: Colors.transparent),
  ];

  List<Task> tasks = [];

  // --- 持久化核心逻辑 ---

  // 1. 初始化并加载数据
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 加载 Projects
    final String? projectsJson = prefs.getString('projects');
    if (projectsJson != null) {
      final List<dynamic> decoded = jsonDecode(projectsJson);
      projects = decoded.map((e) => Project.fromJson(e)).toList();
    }

    // 加载 Tasks
    final String? tasksJson = prefs.getString('tasks');
    if (tasksJson != null) {
      final List<dynamic> decoded = jsonDecode(tasksJson);
      tasks = decoded.map((e) => Task.fromJson(e)).toList();
    }

    // 加载 TimeData (需要先有 Projects 和 Tasks 才能重建引用)
    final String? timeDataJson = prefs.getString('timeData');
    if (timeDataJson != null) {
      final Map<String, dynamic> decodedMap = jsonDecode(timeDataJson);
      timeData.clear();
      
      decodedMap.forEach((keyStr, value) {
        final int index = int.parse(keyStr);
        final String projectId = value['projectId'];
        final String? taskId = value['taskId'];

        final Project? project = getProjectById(projectId);
        if (project != null) {
          Task? task;
          if (taskId != null) {
            try {
              task = tasks.firstWhere((t) => t.id == taskId);
            } catch (e) {
              // task 可能被删了，忽略
            }
          }
          timeData[index] = TimeEntry(project: project, task: task);
        }
      });
    }
    notifyListeners();
  }

  // 2. 保存数据到本地
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();

    // 保存 Projects
    final String projectsJson = jsonEncode(projects.map((p) => p.toJson()).toList());
    await prefs.setString('projects', projectsJson);

    // 保存 Tasks
    final String tasksJson = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString('tasks', tasksJson);

    // 保存 TimeData
    // Map<int, TimeEntry> -> Map<String, Map> -> JSON String
    final Map<String, dynamic> timeDataMap = {};
    timeData.forEach((key, entry) {
      timeDataMap[key.toString()] = entry.toJson();
    });
    await prefs.setString('timeData', jsonEncode(timeDataMap));
  }


  // --- 下面的操作方法中加入 _save() 调用 ---

  // 时间数据操作
  void batchUpdate(Map<int, TimeEntry?> updates) {
    updates.forEach((index, entry) {
      if (entry == null) {
        timeData.remove(index);
      } else {
        timeData[index] = entry!;
      }
    });
    _save(); // 保存
    notifyListeners();
  }

  // 项目操作
  void addProject(String name, Color color) {
    final clearProject = projects.firstWhere((p) => p.id == 'clear', orElse: () => Project(id: 'clear', name: '清除', color: Colors.transparent));
    if (projects.contains(clearProject)) projects.remove(clearProject);
    projects.add(Project(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, color: color));
    projects.add(clearProject);
    _save(); // 保存
    notifyListeners();
  }

  void removeProject(String id) {
    if (id == 'clear') return;
    projects.removeWhere((p) => p.id == id);
    tasks.removeWhere((t) => t.projectId == id);
    timeData.removeWhere((key, value) => value.project.id == id);
    _save(); // 保存
    notifyListeners();
  }

  void reorderProjects(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final validProjects = projects.where((p) => p.id != 'clear').toList();
    final clearProject = projects.firstWhere((p) => p.id == 'clear');
    final Project item = validProjects.removeAt(oldIndex);
    validProjects.insert(newIndex, item);
    projects = [...validProjects, clearProject];
    _save(); // 保存
    notifyListeners();
  }

  // Task 操作
  void addTask(String name, String projectId) {
    tasks.add(Task(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, projectId: projectId));
    _save(); // 保存
    notifyListeners();
  }

  void removeTask(String taskId) {
    tasks.removeWhere((t) => t.id == taskId);
    // 这里也可以选择清理 timeData 中引用了该 task 的条目
    _save(); // 保存
    notifyListeners();
  }

  List<Task> getTasksForProject(String projectId) {
    return tasks.where((t) => t.projectId == projectId).toList();
  }
  
  Project? getProjectById(String id) {
    try {
      return projects.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }
}