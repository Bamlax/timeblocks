import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart'; // 需要引用常量获取 kAnchorDate
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

  // 【新增】当前正在追踪的条目
  TimeEntry? activeTrackingEntry;

  // --- 初始化与保存 ---
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    timeBlockDuration = prefs.getInt('timeBlockDuration') ?? 5;

    // 1. 加载基础数据 (Projects, Tasks, Tags)
    await _loadBasicData(prefs);

    // 2. 加载 TimeData
    final String? timeDataJson = prefs.getString('timeData');
    if (timeDataJson != null) {
      try {
        final Map<String, dynamic> decodedMap = jsonDecode(timeDataJson);
        timeData.clear();
        decodedMap.forEach((keyStr, value) {
          final int index = int.parse(keyStr);
          final entry = _parseTimeEntry(value);
          if (entry != null) timeData[index] = entry;
        });
      } catch (e) { debugPrint("Error loading timeData: $e"); }
    }

    // 3. 【核心新增】恢复追踪状态并补全数据
    await _restoreTrackingState(prefs);

    notifyListeners();
  }

  // 辅助：加载基础列表
  Future<void> _loadBasicData(SharedPreferences prefs) async {
    final String? projectsJson = prefs.getString('projects');
    if (projectsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(projectsJson);
        projects = decoded.map((e) => Project.fromJson(e)).toList();
        projects.removeWhere((p) => p.id == 'clear');
      } catch (_) {}
    }
    final String? tasksJson = prefs.getString('tasks');
    if (tasksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tasksJson);
        tasks = decoded.map((e) => Task.fromJson(e)).toList();
      } catch (_) {}
    }
    final String? tagsJson = prefs.getString('tags');
    if (tagsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(tagsJson);
        tags = decoded.map((e) => Tag.fromJson(e)).toList();
      } catch (_) {}
    }
  }

  // 辅助：解析 TimeEntry
  TimeEntry? _parseTimeEntry(dynamic value) {
    final String projectId = value['projectId'];
    final String? taskId = value['taskId'];
    final String? tagId = value['tagId'];
    final Project? project = getProjectById(projectId);
    if (project != null) {
      Task? task;
      if (taskId != null) {
        try { task = tasks.firstWhere((t) => t.id == taskId); } catch (_) {}
      }
      return TimeEntry(project: project, task: task, tagId: tagId);
    }
    return null;
  }

  // 【核心新增】恢复追踪逻辑
  Future<void> _restoreTrackingState(SharedPreferences prefs) async {
    // 检查是否有保存的追踪信息
    final String? trackingJson = prefs.getString('active_tracking_entry');
    final int? lastActiveTime = prefs.getInt('active_tracking_timestamp'); // 毫秒时间戳

    if (trackingJson != null && lastActiveTime != null) {
      try {
        final entryMap = jsonDecode(trackingJson);
        final entry = _parseTimeEntry(entryMap);
        
        if (entry != null) {
          activeTrackingEntry = entry;
          
          // 计算空缺时间：从上次活跃到现在的每一分钟
          final DateTime lastTime = DateTime.fromMillisecondsSinceEpoch(lastActiveTime);
          final DateTime now = DateTime.now();
          
          // 转换为绝对分钟索引
          final int lastMinuteIndex = lastTime.difference(kAnchorDate).inMinutes;
          final int currentMinuteIndex = now.difference(kAnchorDate).inMinutes;

          // 补全 gaps (从上次记录的下一分钟开始，直到当前分钟)
          if (currentMinuteIndex > lastMinuteIndex) {
            for (int i = lastMinuteIndex + 1; i <= currentMinuteIndex; i++) {
              timeData[i] = entry;
            }
            debugPrint("Restored tracking: Filled ${currentMinuteIndex - lastMinuteIndex} minutes.");
            _save(); // 保存补全的数据
          }
        }
      } catch (e) {
        debugPrint("Error restoring tracking state: $e");
        // 出错则清除状态
        prefs.remove('active_tracking_entry');
        prefs.remove('active_tracking_timestamp');
      }
    }
  }

  // --- 追踪控制 ---

  // 开始追踪
  void startTracking(TimeEntry entry) async {
    activeTrackingEntry = entry;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_tracking_entry', jsonEncode(entry.toJson()));
    await prefs.setInt('active_tracking_timestamp', DateTime.now().millisecondsSinceEpoch);
    
    // 立即填充当前这 1 分钟
    checkAndFillCurrentMinute();
  }

  // 停止追踪
  void stopTracking() async {
    activeTrackingEntry = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_tracking_entry');
    await prefs.remove('active_tracking_timestamp');
  }

  // 检查并填充当前分钟 (由 Timer 调用)
  // 同时更新最后活跃时间，作为“心跳”
  void checkAndFillCurrentMinute() async {
    if (activeTrackingEntry == null) return;

    final now = DateTime.now();
    final int currentMinuteIndex = now.difference(kAnchorDate).inMinutes;
    final TimeEntry? existing = timeData[currentMinuteIndex];

    // 如果当前分钟数据不一致，或者是空的，强制覆盖
    if (existing?.uniqueId != activeTrackingEntry!.uniqueId) {
      timeData[currentMinuteIndex] = activeTrackingEntry!;
      
      // 保存 TimeData (考虑到性能，这里每次每分钟存一次是可以接受的，
      // 如果非常频繁可以优化为仅更新内存，定期存盘，但为了数据安全这里选择立即存)
      _save(); 
      notifyListeners();
    }

    // 【关键】更新“最后活跃时间”，这样杀后台重启后知道从哪开始补
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_tracking_timestamp', now.millisecondsSinceEpoch);
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

  // --- 其他原有方法 (保持不变) ---
  
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

  void addProject(String name, Color color) { projects.add(Project(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, color: color)); _save(); notifyListeners(); }
  
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
      _save(); notifyListeners();
    }
  }
  
  void removeProject(String id) {
    projects.removeWhere((p) => p.id == id);
    tasks.removeWhere((t) => t.projectId == id);
    timeData.removeWhere((key, value) => value.project.id == id);
    _save(); notifyListeners();
  }
  
  void reorderProjects(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final Project item = projects.removeAt(oldIndex);
    projects.insert(newIndex, item);
    _save(); notifyListeners();
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
    _save(); notifyListeners();
  }
  
  Project? getProjectById(String id) { try { return projects.firstWhere((p) => p.id == id); } catch (_) { return null; } }

  void addTask(String name, String projectId) { tasks.add(Task(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, projectId: projectId)); _save(); notifyListeners(); }
  
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
      _save(); notifyListeners();
    }
  }
  
  void removeTask(String taskId) { tasks.removeWhere((t) => t.id == taskId); _save(); notifyListeners(); }
  
  void reorderProjectTasks(String projectId, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final projectTasks = tasks.where((t) => t.projectId == projectId).toList();
    if (oldIndex >= projectTasks.length) return;
    final Task item = projectTasks.removeAt(oldIndex);
    projectTasks.insert(newIndex, item);
    final otherTasks = tasks.where((t) => t.projectId != projectId).toList();
    tasks = [...otherTasks, ...projectTasks];
    _save(); notifyListeners();
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
    _save(); notifyListeners();
  }
  
  List<Task> getTasksForProject(String projectId) { return tasks.where((t) => t.projectId == projectId).toList(); }

  void addTag(String name) { tags.add(Tag(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name)); _save(); notifyListeners(); }
  
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
    _save(); notifyListeners();
  }
  
  void removeTag(String id) { tags.removeWhere((t) => t.id == id); _save(); notifyListeners(); }
  
  Tag? getTagById(String? id) { if (id == null) return null; try { return tags.firstWhere((t) => t.id == id); } catch (_) { return null; } }
}