import 'package:flutter/material.dart';
import '../data_manager.dart';

class EventManagementPage extends StatelessWidget {
  const EventManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DataManager dataManager = DataManager();

    return Scaffold(
      appBar: AppBar(
        title: const Text('事件管理'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: dataManager,
        builder: (context, _) {
          final displayProjects = dataManager.projects.where((p) => p.id != 'clear').toList();

          if (displayProjects.isEmpty) {
            return const Center(child: Text("暂无事件，请在首页添加"));
          }

          return ReorderableListView.builder(
            // 【关键修复】关闭默认手柄，防止 Web/Desktop 端出现两个图标
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: displayProjects.length,
            onReorder: (oldIndex, newIndex) {
              dataManager.reorderProjects(oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              final project = displayProjects[index];
              
              return Column(
                key: Key(project.id),
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: project.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      project.name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 删除按钮
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () {
                            _showDeleteConfirm(context, dataManager, project.id, project.name);
                          },
                        ),
                        // 【关键修复】显式包裹拖拽监听器，这才是唯一生效的手柄
                        ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.only(left: 8, right: 8),
                            child: Icon(Icons.drag_handle, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 分隔线
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, DataManager manager, String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除事件'),
        content: Text('确定要删除 "$name" 吗？\n该事件下的所有子内容也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              manager.removeProject(id);
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