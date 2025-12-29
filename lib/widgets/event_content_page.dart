import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../data_manager.dart';
import '../models/project.dart';
import '../models/task.dart';
import 'merge_dialog.dart';

class EventContentPage extends StatefulWidget {
  const EventContentPage({super.key});

  @override
  State<EventContentPage> createState() => _EventContentPageState();
}

class _EventContentPageState extends State<EventContentPage> {
  final DataManager _dataManager = DataManager();

  @override
  Widget build(BuildContext context) {
    final validProjects = _dataManager.projects.where((p) => p.id != 'clear').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('事件内容管理'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _dataManager,
        builder: (context, _) {
          if (_dataManager.tasks.isEmpty) {
            return const Center(child: Text("暂无事件内容，点击右下角添加"));
          }
          
          return SlidableAutoCloseBehavior(
            child: ListView.separated(
              itemCount: _dataManager.tasks.length,
              separatorBuilder: (c, i) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final task = _dataManager.tasks[index];
                final parentProject = _dataManager.getProjectById(task.projectId);
                final Color projectColor = parentProject?.color ?? Colors.grey;

                return Slidable(
                  key: Key(task.id),
                  groupTag: 'task_list',
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.45,
                    children: [
                      SlidableAction(
                        onPressed: (context) => _showMergeTaskDialog(context, task),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        icon: Icons.merge,
                      ),
                      SlidableAction(
                        onPressed: (context) => _showEditTaskDialog(context, task, validProjects),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                      ),
                      SlidableAction(
                        onPressed: (context) {
                          _dataManager.removeTask(task.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已删除 ${task.name}')),
                          );
                        },
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                      ),
                    ],
                  ),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        color: projectColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(task.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                    subtitle: Row(
                      children: [
                        const Text("所属: ", style: TextStyle(color: Colors.grey, fontSize: 11)),
                        Container(
                          width: 8, height: 8,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: projectColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          parentProject?.name ?? '未知',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context, validProjects),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showMergeTaskDialog(BuildContext context, Task sourceTask) {
    final targets = _dataManager.tasks.where((t) => t.id != sourceTask.id).toList();

    showDialog(
      context: context,
      builder: (ctx) => MergeDialog<Task>(
        title: '将 "${sourceTask.name}" 合并到...',
        items: targets,
        getName: (t) {
          final p = _dataManager.getProjectById(t.projectId);
          return "${t.name} (${p?.name ?? '未知'})";
        },
        getLeading: (t) {
          final p = _dataManager.getProjectById(t.projectId);
          return Container(width: 10, height: 10, decoration: BoxDecoration(color: p?.color ?? Colors.grey, shape: BoxShape.circle));
        },
        onSelected: (target) {
          _dataManager.mergeTasks(sourceTask.id, target.id);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已合并到 ${target.name}')));
        },
      ),
    );
  }

  // 【新增】包含查重逻辑的新增弹窗
  void _showAddTaskDialog(BuildContext context, List<Project> projects) {
    String name = "";
    Project? selectedProject = projects.isNotEmpty ? projects.first : null;
    String? errorText; // 错误信息状态

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('新建事件内容'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: '内容名称', 
                      border: const OutlineInputBorder(),
                      errorText: errorText, // 显示错误
                    ),
                    onChanged: (v) {
                      name = v;
                      // 输入时清除错误
                      if (errorText != null) setState(() => errorText = null);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Project>(
                    value: selectedProject,
                    decoration: const InputDecoration(labelText: '归属项目', border: OutlineInputBorder()),
                    items: projects.map((p) => DropdownMenuItem(
                      value: p,
                      child: Row(
                        children: [
                          Container(width: 12, height: 12, color: p.color),
                          const SizedBox(width: 8),
                          Text(p.name),
                        ],
                      ),
                    )).toList(),
                    onChanged: (p) => setState(() => selectedProject = p),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    final trimmedName = name.trim();
                    
                    if (trimmedName.isEmpty) {
                      setState(() => errorText = "名称不能为空");
                      return;
                    }

                    // 【查重逻辑】
                    if (_dataManager.tasks.any((t) => t.name == trimmedName)) {
                      setState(() => errorText = "该内容名称已存在");
                      return;
                    }

                    if (selectedProject != null) {
                      _dataManager.addTask(trimmedName, selectedProject!.id);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('创建'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 【编辑】包含查重逻辑的编辑弹窗
  void _showEditTaskDialog(BuildContext context, Task task, List<Project> projects) {
    String name = task.name;
    Project? selectedProject = projects.firstWhere(
      (p) => p.id == task.projectId, 
      orElse: () => projects.isNotEmpty ? projects.first : projects[0]
    );
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('编辑事件内容'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: TextEditingController(text: name),
                    decoration: InputDecoration(
                      labelText: '内容名称', 
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    onChanged: (v) {
                      name = v;
                      if (errorText != null) setState(() => errorText = null);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Project>(
                    value: selectedProject,
                    decoration: const InputDecoration(labelText: '归属项目', border: OutlineInputBorder()),
                    items: projects.map((p) => DropdownMenuItem(
                      value: p,
                      child: Row(
                        children: [
                          Container(width: 12, height: 12, color: p.color),
                          const SizedBox(width: 8),
                          Text(p.name),
                        ],
                      ),
                    )).toList(),
                    onChanged: (p) => setState(() => selectedProject = p),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    final trimmedName = name.trim();

                    if (trimmedName.isEmpty) {
                      setState(() => errorText = "名称不能为空");
                      return;
                    }

                    // 【查重逻辑】排除自己
                    if (_dataManager.tasks.any((t) => t.name == trimmedName && t.id != task.id)) {
                      setState(() => errorText = "该内容名称已存在");
                      return;
                    }

                    if (selectedProject != null) {
                      _dataManager.updateTask(task.id, trimmedName, selectedProject!.id);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}