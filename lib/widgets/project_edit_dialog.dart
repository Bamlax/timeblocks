import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_manager.dart';
import '../models/project.dart';
import '../models/task.dart';
import 'color_picker.dart'; // 复用之前的取色器

class ProjectEditDialog extends StatefulWidget {
  final Project project;

  const ProjectEditDialog({super.key, required this.project});

  @override
  State<ProjectEditDialog> createState() => _ProjectEditDialogState();
}

class _ProjectEditDialogState extends State<ProjectEditDialog> {
  final DataManager _dataManager = DataManager();
  late TextEditingController _nameController;
  late Color _selectedColor;
  bool _isCustomColorMode = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project.name);
    _selectedColor = widget.project.color;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 保存基础信息（名、色）
  void _saveBasicInfo() {
    if (_nameController.text.trim().isNotEmpty) {
      _dataManager.updateProject(
        widget.project.id,
        _nameController.text.trim(),
        _selectedColor,
      );
      Navigator.pop(context);
    }
  }

  // 删除项目
  void _deleteProject() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除 "${widget.project.name}" 及其所有内容吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              _dataManager.removeProject(widget.project.id);
              Navigator.pop(ctx); // 关确认框
              Navigator.pop(context); // 关编辑框
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // 添加子任务
  void _addTask() {
    String newTaskName = "";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加内容'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(labelText: '内容名称'),
          onChanged: (v) => newTaskName = v,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (newTaskName.trim().isNotEmpty) {
                _dataManager.addTask(newTaskName.trim(), widget.project.id);
                Navigator.pop(ctx);
                setState(() {}); // 刷新列表
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前项目的任务列表（用于排序显示）
    final subTasks = _dataManager.getTasksForProject(widget.project.id);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.maxFinite,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("编辑事件", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _deleteProject,
                  tooltip: "删除事件",
                ),
              ],
            ),
            const Divider(),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. 修改名称
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '事件名称',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. 修改颜色
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("事件颜色", style: TextStyle(fontWeight: FontWeight.bold)),
                        if (_isCustomColorMode)
                          TextButton(
                            onPressed: () => setState(() => _isCustomColorMode = false),
                            child: const Text("返回预设"),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isCustomColorMode)
                      ColorPicker(
                        initialColor: _selectedColor,
                        onColorChanged: (c) => setState(() => _selectedColor = c),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ...kDefaultColorPalette.map((color) => _buildColorCircle(color)),
                          GestureDetector(
                            onTap: () => setState(() => _isCustomColorMode = true),
                            child: Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Colors.red, Colors.blue]),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Icon(Icons.colorize, size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // 3. 子内容管理 (排序 + 新增)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("事件内容 (长按拖拽排序)", style: TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          onPressed: _addTask,
                          icon: const Icon(Icons.add_circle, color: Colors.blue),
                          tooltip: "添加内容",
                        ),
                      ],
                    ),
                    Container(
                      height: 150, // 固定高度给列表
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: subTasks.isEmpty 
                        ? const Center(child: Text("暂无内容", style: TextStyle(color: Colors.grey)))
                        : ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            shrinkWrap: true,
                            itemCount: subTasks.length,
                            onReorder: (oldIndex, newIndex) {
                              _dataManager.reorderProjectTasks(widget.project.id, oldIndex, newIndex);
                              setState(() {}); // 刷新界面
                            },
                            itemBuilder: (context, index) {
                              final task = subTasks[index];
                              return ListTile(
                                key: Key(task.id),
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: const Icon(Icons.circle, size: 8, color: Colors.grey),
                                title: Text(task.name),
                                trailing: ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle, color: Colors.grey, size: 18),
                                ),
                              );
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            // 底部按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveBasicInfo,
                  child: const Text('保存修改'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorCircle(Color color) {
    final bool isSelected = _selectedColor.value == color.value;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.black, width: 2.5) : null,
        ),
        child: isSelected ? const Icon(Icons.check, size: 20, color: Colors.white) : null,
      ),
    );
  }
}