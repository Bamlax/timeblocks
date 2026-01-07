import 'package:flutter/material.dart';
import '../version_data.dart';

class VersionHistoryPage extends StatelessWidget {
  const VersionHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('版本历史'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: appVersionHistory.length,
        itemBuilder: (context, index) {
          final record = appVersionHistory[index];
          // 【核心修改】如果是列表第一个 (index 0)，就是最新版
          final bool isLatest = (index == 0);
          
          return _VersionItem(
            record: record, 
            isLatest: isLatest,
          );
        },
      ),
    );
  }
}

class _VersionItem extends StatelessWidget {
  final VersionRecord record;
  final bool isLatest; // 从外部传入

  const _VersionItem({
    required this.record, 
    required this.isLatest,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              record.version,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            // 如果是最新版，显示标签
            if (isLatest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Latest',
                  style: TextStyle(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                ),
              ),
            const Spacer(),
            Text(
              record.date,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...record.updates.map((u) => Padding(
          padding: const EdgeInsets.only(bottom: 4, left: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("• ", style: TextStyle(color: Colors.grey)),
              Expanded(child: Text(u, style: TextStyle(color: Colors.grey.shade800))),
            ],
          ),
        )),
        const Divider(height: 30),
      ],
    );
  }
}