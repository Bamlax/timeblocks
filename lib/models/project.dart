import 'package:flutter/material.dart';

class Project {
  final String id;
  final String name;
  final Color color;

  Project({
    required this.id,
    required this.name,
    required this.color,
  });

  // --- 新增：转为 JSON Map ---
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color.value, // 保存颜色的整数值
    };
  }

  // --- 新增：从 JSON Map 创建对象 ---
  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'],
      name: json['name'],
      color: Color(json['color']), // 从整数恢复颜色
    );
  }
}