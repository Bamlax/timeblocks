import 'package:flutter/material.dart';
import '../models/project.dart';

class ProjectButton extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const ProjectButton({super.key, required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isClear = project.id == 'clear';
    return Material(
      color: isClear ? Colors.white : project.color,
      borderRadius: BorderRadius.circular(6), // 圆角稍微减小一点以匹配小尺寸
      elevation: isClear ? 0 : 1, // 阴影变浅一点
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          height: 32, // 【修改点】高度减小 (44 -> 32)
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: isClear ? Border.all(color: Colors.grey.shade300) : null,
          ),
          child: Text(
            project.name,
            style: TextStyle(
              color: isClear ? Colors.grey.shade700 : Colors.white,
              fontSize: 12, // 【修改点】字体减小
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis, // 防止溢出
          ),
        ),
      ),
    );
  }
}

class AddProjectButton extends StatelessWidget {
  final VoidCallback onTap;

  const AddProjectButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          height: 32, // 【修改点】高度减小
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Icon(Icons.add, size: 20, color: Colors.grey.shade600), // 图标也稍微小一点
        ),
      ),
    );
  }
}