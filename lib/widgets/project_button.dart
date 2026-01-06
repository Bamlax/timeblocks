import 'package:flutter/material.dart';
import '../models/project.dart';

class ProjectButton extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final VoidCallback? onLongPress; // 【新增】

  const ProjectButton({
    super.key, 
    required this.project, 
    required this.onTap,
    this.onLongPress, // 【新增】
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: project.color,
      borderRadius: BorderRadius.circular(6),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress, // 【新增】
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            project.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// AddProjectButton 保持不变...
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
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Icon(Icons.add, size: 20, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}