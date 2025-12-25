import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'event_content_page.dart';
import 'event_management_page.dart';
import 'tag_management_page.dart'; // 【新增】
import 'version_history_page.dart';
import 'statistics_page.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = info.version.isNotEmpty ? info.version : "1.0.0";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _version = "1.0.0";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: Column(
        children: [
          // 1. 头部信息
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            accountName: const Text(
              "Timeblocks",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            accountEmail: const Text("让时间井井有条"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.access_time_filled, size: 36, color: Colors.blue),
            ),
          ),
          
          // 2. 菜单列表
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  context,
                  icon: Icons.bar_chart,
                  title: '统计',
                  subtitle: '查看时间分布',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const StatisticsPage()),
                    );
                  },
                ),
                
                const Divider(),
                
                _buildMenuItem(
                  context,
                  icon: Icons.folder_open,
                  title: '事件',
                  subtitle: '管理首页项目分类',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const EventManagementPage()),
                    );
                  },
                ),
                
                _buildMenuItem(
                  context,
                  icon: Icons.list_alt,
                  title: '事件内容',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const EventContentPage()),
                    );
                  },
                ),

                // 【新增】标签管理入口
                _buildMenuItem(
                  context,
                  icon: Icons.label,
                  title: '标签',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (c) => const TagManagementPage()),
                    );
                  },
                ),
                
                const Divider(),
                
                _buildMenuItem(
                  context,
                  icon: Icons.settings,
                  title: '设置',
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('设置功能开发中...')),
                    );
                  },
                ),
                
                _buildMenuItem(
                  context,
                  icon: Icons.info_outline,
                  title: '关于 Timeblocks',
                  onTap: () {
                    Navigator.pop(context);
                    _showCustomAboutDialog(context, _version.isEmpty ? "1.0.0" : _version);
                  },
                ),
              ],
            ),
          ),
          
          // 3. 底部版本号
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _version.isEmpty ? "Loading..." : "Version $_version",
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomAboutDialog(BuildContext context, String version) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.access_time, size: 32, color: Colors.blue),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Timeblocks', style: TextStyle(fontSize: 20)),
                  Text("v$version", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('一个帮助你规划时间块的高效工具。'),
              SizedBox(height: 12),
              Text('© 2025 Timeblocks Team'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (c) => const VersionHistoryPage())
                );
              },
              child: const Text('版本历史'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, String? subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
      onTap: onTap,
    );
  }
}