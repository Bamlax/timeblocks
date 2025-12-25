import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../data_manager.dart';

class TagManagementPage extends StatelessWidget {
  const TagManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final DataManager dataManager = DataManager();

    return Scaffold(
      appBar: AppBar(title: const Text('标签管理'), centerTitle: true),
      body: ListenableBuilder(
        listenable: dataManager,
        builder: (context, _) {
          if (dataManager.tags.isEmpty) {
            return const Center(child: Text("暂无标签"));
          }
          return ListView.separated(
            itemCount: dataManager.tags.length,
            separatorBuilder: (c, i) => const Divider(height: 1, indent: 16, endIndent: 16),
            itemBuilder: (context, index) {
              final tag = dataManager.tags[index];
              return Slidable(
                key: Key(tag.id),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (context) {
                        dataManager.removeTag(tag.id);
                      },
                      backgroundColor: Colors.red,
                      icon: Icons.delete,
                    ),
                  ],
                ),
                child: ListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: const Icon(Icons.label_outline, size: 18, color: Colors.grey),
                  title: Text(tag.name, style: const TextStyle(fontSize: 14)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(context, dataManager),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTagDialog(BuildContext context, DataManager manager) {
    String name = "";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新建标签'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: '标签名称', border: OutlineInputBorder()),
          onChanged: (v) => name = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty) {
                manager.addTag(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }
}