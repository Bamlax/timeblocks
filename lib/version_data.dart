// lib/version_data.dart

class VersionRecord {
  final String version;
  final String date;
  final List<String> updates;
  final bool isLatest;

  const VersionRecord({
    required this.version,
    required this.date,
    required this.updates,
    this.isLatest = false,
  });
}

// --- 在这里维护你的版本历史 ---
// 新版本请加在列表最前面

const List<VersionRecord> appVersionHistory = [
    VersionRecord(
    version: '0.4.0',
    date: '2026-1-4',
    updates: [
      '新增趋势功能',
    ],
    isLatest: true,
  ),
    VersionRecord(
    version: '0.3.2',
    date: '2026-1-1',
    updates: [
      '修复时间小竖条错位的问题',
    ],
    isLatest: false,
  ),
    VersionRecord(
    version: '0.3.1',
    date: '2025-12-29',
    updates: [
      '修复可以重复添加事件，事件内容和标签的bug',
    ],
    isLatest: false,
  ),
    VersionRecord(
    version: '0.3.0',
    date: '2025-12-27',
    updates: [
      '新增撤回功能',
      '新增事件的详细内容的统计',
      '新增时长对比',
    ],
    isLatest: false,
  ),
      VersionRecord(
    version: '0.2.0',
    date: '2025-12-25',
    updates: [
      '新增合并功能',
      '修复标签能左滑多个的问题',
    ],
    isLatest: false,
  ),
    VersionRecord(
    version: '0.1.1',
    date: '2025-12-25',
    updates: [
      '新建app图标',
    ],
    isLatest: false,
  ),
  VersionRecord(
    version: '0.1.0',
    date: '2025-12-24',
    updates: [
      '初始版发布',
    ],
    isLatest: false,
  ),
  // 示例旧版本 (以后有新版本时，把上面的 isLatest 改为 false，新加一个在最上面)
  /*
  VersionRecord(
    version: 'v0.0.1',
    date: '2025-12-01',
    updates: [
      'Internal Alpha Test',
    ],
  ),
  */
];