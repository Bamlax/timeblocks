import 'package:flutter/material.dart';
import '../data_manager.dart';
import '../models/project.dart';

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
          
          return ListView.separated(
            itemCount: _dataManager.tasks.length,
            // 使用 Divider 作为分隔线，实现列表风格
            separatorBuilder: (c, i) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final task = _dataManager.tasks[index];
              final parentProject = _dataManager.getProjectById(task.projectId);

              return Dismissible(
                key: Key(task.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.red, // 删除背景色
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _dataManager.removeTask(task.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已删除 ${task.name}')),
                  );
                },
                // 去掉了 Container 和 Decoration，直接使用 ListTile
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: parentProject?.color ?? Colors.grey,
                    radius: 8,
                  ),
                  title: Text(task.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text("所属项目: ${parentProject?.name ?? '未知'}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context, validProjects),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, List<Project> projects) {
    String name = "";
    Project? selectedProject = projects.isNotEmpty ? projects.first : null;

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
                    decoration: const InputDecoration(
                      labelText: '内容名称',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => name = v,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<Project>(
                    value: selectedProject,
                    decoration: const InputDecoration(
                      labelText: '归属项目',
                      border: OutlineInputBorder(),
                    ),
                    items: projects.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Row(
                          children: [
                            Container(width: 12, height: 12, color: p.color),
                            const SizedBox(width: 8),
                            Text(p.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (p) => setState(() => selectedProject = p),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    if (name.isNotEmpty && selectedProject != null) {
                      _dataManager.addTask(name, selectedProject!.id);
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
}