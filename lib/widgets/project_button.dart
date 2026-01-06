import 'package:flutter/material.dart';
import '../models/project.dart';

class ProjectButton extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isTracking;

  const ProjectButton({
    super.key, 
    required this.project, 
    required this.onTap,
    this.onLongPress,
    this.isTracking = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isClear = project.id == 'clear';
    
    return Material(
      color: isClear ? Colors.white : project.color,
      borderRadius: BorderRadius.circular(6),
      elevation: isClear ? 0 : 1,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: isClear ? Border.all(color: Colors.grey.shade300) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 【修复】静态圆点 (只要 isTracking 为 true 就显示)
              if (isTracking) 
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.fiber_manual_record, size: 10, color: Colors.white),
                ),
              Flexible(
                child: Text(
                  project.name,
                  style: TextStyle(
                    color: isClear ? Colors.grey.shade700 : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
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