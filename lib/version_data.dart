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
    version: '0.2.0',
    date: '2025-12-25',
    updates: [
      '新增合并功能',
      '修复标签能左滑多个的问题',
    ],
    isLatest: true,
  ),
    VersionRecord(
    version: '0.1.1',
    date: '2025-12-25',
    updates: [
      '新建app图标',
    ],
    isLatest: true,
  ),
  VersionRecord(
    version: '0.1.0',
    date: '2025-12-24',
    updates: [
      '初始版发布',
    ],
    isLatest: true,
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