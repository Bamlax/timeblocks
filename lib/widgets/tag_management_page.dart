import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../data_manager.dart';
import '../models/tag.dart';
import 'merge_dialog.dart';

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
          
          return SlidableAutoCloseBehavior(
            child: ListView.separated(
              itemCount: dataManager.tags.length,
              separatorBuilder: (c, i) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final tag = dataManager.tags[index];
                
                return Slidable(
                  key: Key(tag.id),
                  groupTag: 'tag_list',
                  endActionPane: ActionPane(
                    motion: const ScrollMotion(),
                    extentRatio: 0.45,
                    children: [
                      SlidableAction(
                        onPressed: (context) => _showMergeTagDialog(context, dataManager, tag),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        icon: Icons.merge,
                      ),
                      SlidableAction(
                        onPressed: (context) => _showTagDialog(context, dataManager, tag: tag),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        icon: Icons.edit,
                      ),
                      SlidableAction(
                        onPressed: (context) {
                          dataManager.removeTag(tag.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已删除 ${tag.name}')),
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
                    leading: const Icon(Icons.label_outline, size: 18, color: Colors.grey),
                    title: Text(tag.name, style: const TextStyle(fontSize: 14)),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTagDialog(context, dataManager),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showMergeTagDialog(BuildContext context, DataManager manager, Tag sourceTag) {
    final targets = manager.tags.where((t) => t.id != sourceTag.id).toList();

    showDialog(
      context: context,
      builder: (ctx) => MergeDialog<Tag>(
        title: '将 "${sourceTag.name}" 合并到...',
        items: targets,
        getName: (t) => t.name,
        getLeading: (t) => const Icon(Icons.label, size: 16, color: Colors.grey),
        onSelected: (target) {
          manager.mergeTags(sourceTag.id, target.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已合并到 ${target.name}')),
          );
        },
      ),
    );
  }

  void _showTagDialog(BuildContext context, DataManager manager, {Tag? tag}) {
    final bool isEdit = tag != null;
    String name = tag?.name ?? "";
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        // 【关键】使用 StatefulBuilder 使得弹窗内部可以 setState 刷新错误信息
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? '编辑标签' : '新建标签'),
              content: TextFormField(
                initialValue: name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: '标签名称', 
                  border: const OutlineInputBorder(),
                  errorText: errorText, // 绑定错误信息
                ),
                onChanged: (v) {
                  name = v;
                  if (errorText != null) setState(() => errorText = null);
                },
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context), 
                  child: const Text('取消')
                ),
                ElevatedButton(
                  onPressed: () {
                    final trimmedName = name.trim();
                    
                    if (trimmedName.isEmpty) {
                      setState(() => errorText = "名称不能为空");
                      return;
                    }
                    
                    // 【查重逻辑】
                    // 如果存在同名标签，且不是当前正在编辑的标签本身
                    if (manager.tags.any((t) => t.name == trimmedName && t.id != tag?.id)) {
                      setState(() => errorText = "该标签已存在");
                      return;
                    }

                    if (isEdit) {
                      manager.updateTag(tag!.id, trimmedName);
                    } else {
                      manager.addTag(trimmedName);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(isEdit ? '保存' : '添加'),
                ),
              ],
            );
          }
        );
      },
    );
  }
}