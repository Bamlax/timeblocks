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
      borderRadius: BorderRadius.circular(8),
      elevation: isClear ? 0 : 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isClear ? Border.all(color: Colors.grey.shade300) : null,
          ),
          child: Text(
            project.name,
            style: TextStyle(
              color: isClear ? Colors.grey.shade700 : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade400, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                "添加项目",
                style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}