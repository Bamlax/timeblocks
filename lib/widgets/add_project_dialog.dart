import 'package:flutter/material.dart';
import '../constants.dart';
import 'color_picker.dart';

class AddProjectDialog extends StatefulWidget {
  final Function(String name, Color color) onAdd;

  const AddProjectDialog({super.key, required this.onAdd});

  @override
  State<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends State<AddProjectDialog> {
  String _name = "";
  Color _selectedColor = kDefaultColorPalette[0];
  bool _isCustomMode = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('新增项目'),
      // 【核心修复】：包裹 SizedBox(width: double.maxFinite)
      // 这打破了 IntrinsicWidth 的死循环，让内容直接撑满 Dialog 的宽度
      content: SizedBox(
        width: double.maxFinite, 
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 项目名称输入
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '项目名称',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onChanged: (v) => _name = v,
            ),
            const SizedBox(height: 20),
            
            // 2. 标题行
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

            // 3. 颜色选择区
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
            if (_name.trim().isEmpty) return;
            widget.onAdd(_name, _selectedColor);
            Navigator.pop(context);
          },
          child: const Text('添加'),
        ),
      ],
    );
  }

  Widget _buildPresetColorCircle(Color color) {
    final bool isSelected = _selectedColor == color;
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