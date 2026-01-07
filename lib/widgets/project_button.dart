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
    
    // 加深 50%
    final Color displayColor = isClear 
        ? Colors.white 
        : (isTracking 
            ? Color.lerp(project.color, Colors.black, 0.5)! 
            : project.color);

    return Material(
      color: displayColor,
      borderRadius: BorderRadius.circular(6),
      elevation: isTracking ? 4 : (isClear ? 0 : 1),
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
            // 追踪时加白框，普通时无框(除非是clear)
            border: isTracking 
                ? Border.all(color: Colors.white, width: 2)
                : (isClear ? Border.all(color: Colors.grey.shade300) : null),
          ),
          child: Text(
            project.name,
            style: TextStyle(
              color: isClear ? Colors.grey.shade700 : Colors.white,
              fontSize: 12,
              fontWeight: isTracking ? FontWeight.w900 : FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

// AddProjectButton 保持不变
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