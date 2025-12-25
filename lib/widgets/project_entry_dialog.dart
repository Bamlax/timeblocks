import 'package:flutter/material.dart';
import '../constants.dart';
import 'color_picker.dart'; // 确保你之前创建了 color_picker.dart

class ProjectEntryDialog extends StatefulWidget {
  final String? initialName;
  final Color? initialColor;
  final String title;
  final String confirmText;
  final Function(String name, Color color) onSubmit;

  const ProjectEntryDialog({
    super.key,
    this.initialName,
    this.initialColor,
    this.title = '新增事件',
    this.confirmText = '添加',
    required this.onSubmit,
  });

  @override
  State<ProjectEntryDialog> createState() => _ProjectEntryDialogState();
}

class _ProjectEntryDialogState extends State<ProjectEntryDialog> {
  late TextEditingController _nameController;
  late Color _selectedColor;
  bool _isCustomMode = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? "");
    _selectedColor = widget.initialColor ?? kDefaultColorPalette[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 名称输入
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '事件名称',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 20),
            
            // 2. 颜色选择标题区
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isCustomMode ? '自定义颜色' : '选择预设颜色', 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
                if (_isCustomMode)
                  TextButton.icon(
                    onPressed: () => setState(() => _isCustomMode = false),
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text("返回预设"),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. 颜色选择区域
            if (_isCustomMode)
              ColorPicker(
                initialColor: _selectedColor,
                onColorChanged: (c) => setState(() => _selectedColor = c),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...kDefaultColorPalette.map((color) => _buildPresetColorCircle(color)),
                  // 自定义入口
                  GestureDetector(
                    onTap: () => setState(() => _isCustomMode = true),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.red, Colors.green, Colors.blue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))
                        ],
                      ),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) return;
            widget.onSubmit(_nameController.text.trim(), _selectedColor);
            Navigator.pop(context);
          },
          child: Text(widget.confirmText),
        ),
      ],
    );
  }

  Widget _buildPresetColorCircle(Color color) {
    final bool isSelected = _selectedColor.value == color.value;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.black, width: 2.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 2,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: isSelected ? const Icon(Icons.check, size: 22, color: Colors.white) : null,
      ),
    );
  }
}