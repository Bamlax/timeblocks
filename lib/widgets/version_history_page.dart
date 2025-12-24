import 'package:flutter/material.dart';
import '../version_data.dart'; // 引入数据文件

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
          return _VersionItem(record: record);
        },
      ),
    );
  }
}

class _VersionItem extends StatelessWidget {
  final VersionRecord record;

  const _VersionItem({required this.record});

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
            if (record.isLatest)
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