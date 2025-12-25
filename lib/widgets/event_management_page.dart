import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../data_manager.dart';
import '../models/project.dart';
import 'project_entry_dialog.dart';

class EventManagementPage extends StatefulWidget {
  const EventManagementPage({super.key});

  @override
  State<EventManagementPage> createState() => _EventManagementPageState();
}

class _EventManagementPageState extends State<EventManagementPage> {
  final DataManager _dataManager = DataManager();
  bool _isSorting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('事件管理'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _isSorting ? "完成排序" : "调整顺序",
            onPressed: () {
              setState(() {
                _isSorting = !_isSorting;
              });
            },
            icon: Icon(_isSorting ? Icons.check : Icons.sort),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListenableBuilder(
        listenable: _dataManager,
        builder: (context, _) {
          final displayProjects = _dataManager.projects.where((p) => p.id != 'clear').toList();

          if (displayProjects.isEmpty) {
            return const Center(child: Text("暂无事件，请在首页添加"));
          }

          if (_isSorting) {
            return ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: displayProjects.length,
              onReorder: (oldIndex, newIndex) {
                _dataManager.reorderProjects(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final project = displayProjects[index];
                return ListTile(
                  key: Key(project.id),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Container(
                    width: 16, height: 16, 
                    decoration: BoxDecoration(color: project.color, shape: BoxShape.circle),
                  ),
                  title: Text(project.name, style: const TextStyle(fontSize: 14)),
                  trailing: ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.drag_handle, color: Colors.grey, size: 20),
                    ),
                  ),
                );
              },
            );
          }

          // 【核心修复】将 ListView 包裹起来
          return SlidableAutoCloseBehavior(
            child: ListView.separated(
              itemCount: displayProjects.length,
              separatorBuilder: (c, i) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final project = displayProjects[index];
                
                return Slidable(
                  key: Key(project.id),
                  groupTag: 'project_list', // groupTag 保持不变
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.3,
                    children: [
                      SlidableAction(
                        onPressed: (context) => _showEditDialog(context, project),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                      ),
                      SlidableAction(
                        onPressed: (context) => _showDeleteConfirm(context, project),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        icon: Icons.delete,
                      ),
                    ],
                  ),
                  child: ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      width: 16, height: 16,
                      decoration: BoxDecoration(color: project.color, shape: BoxShape.circle),
                    ),
                    title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ... _showEditDialog 和 _showDeleteConfirm 方法保持不变 ...
  void _showEditDialog(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) => ProjectEntryDialog(
        title: '编辑事件',
        confirmText: '保存',
        initialName: project.name,
        initialColor: project.color,
        onSubmit: (newName, newColor) {
          _dataManager.updateProject(project.id, newName, newColor);
        },
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除事件'),
        content: Text('确定要删除 "${project.name}" 吗？\n该事件下的所有子内容也会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              _dataManager.removeProject(project.id);
              Navigator.pop(ctx);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}