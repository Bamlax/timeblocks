import 'package:flutter/material.dart';

// T 可以是 Project, Task 或 Tag
class MergeDialog<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) getName;
  final Widget Function(T)? getLeading;
  final Function(T) onSelected;

  const MergeDialog({
    super.key,
    required this.title,
    required this.items,
    required this.getName,
    this.getLeading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        height: 300, // 限制高度
        child: items.isEmpty 
          ? const Center(child: Text("没有可合并的目标"))
          : ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: getLeading != null ? getLeading!(item) : null,
                  title: Text(getName(item)),
                  onTap: () {
                    // 【关键修复】先关闭弹窗！
                    Navigator.of(context).pop(); 
                    
                    // 然后再执行合并逻辑
                    onSelected(item);
                  },
                );
              },
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}