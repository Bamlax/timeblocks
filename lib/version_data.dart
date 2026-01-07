// lib/version_data.dart

class VersionRecord {
  final String version;
  final String date;
  final List<String> updates;

  const VersionRecord({
    required this.version,
    required this.date,
    required this.updates,
  });
}

// --- 在这里维护你的版本历史 ---
// 【规则】新版本请永远加在列表的第一个位置 (index 0)
// UI 会自动将第一个识别为 "Latest"

const List<VersionRecord> appVersionHistory = [
    VersionRecord(
    version: '0.8.1',
    date: '2026-1-7',
    updates: [
      '修复趋势界面的错误统计时长',
    ],
  ),
  VersionRecord(
    version: '0.8.0',
    date: '2026-1-7',
    updates: [
      '新增按事件选取的功能',
      '优化自动填充块的内容功能',
    ],
  ),
  VersionRecord(
    version: '0.7.1',
    date: '2026-1-7',
    updates: [
      '修复新版时间块错误显示为1分钟',
      '修复双指缩放的逻辑',
      '修复统计的错误统计',
    ],
  ),
  VersionRecord(
    version: '0.7.0',
    date: '2026-1-7',
    updates: [
      '新增自动填充块的内容功能',
      '优化块大小的调整逻辑（双指捏合）',
      '修复调整块大小时数据丢失的问题',
    ],
  ),
  VersionRecord(
    version: '0.6.0',
    date: '2026-1-6',
    updates: [
      '新增可调整块的大小',
      '新增长按事件可编辑的功能',
      '调整趋势中全部的逻辑',
    ],
  ),
  VersionRecord(
    version: '0.5.0',
    date: '2026-1-5',
    updates: [
      '新增查看所有时间的趋势',
      '优化统计图的绘制粗细',
      '优化撤回的隐藏逻辑',
      '去除Timeblocks旁的符号',
    ],
  ),
  VersionRecord(
    version: '0.4.0',
    date: '2026-1-4',
    updates: [
      '新增趋势功能',
    ],
  ),
  VersionRecord(
    version: '0.3.2',
    date: '2026-1-1',
    updates: [
      '修复时间小竖条错位的问题',
    ],
  ),
  VersionRecord(
    version: '0.3.1',
    date: '2025-12-29',
    updates: [
      '修复可以重复添加事件，事件内容和标签的bug',
    ],
  ),
  VersionRecord(
    version: '0.3.0',
    date: '2025-12-27',
    updates: [
      '新增撤回功能',
      '新增事件的详细内容的统计',
      '新增时长对比',
    ],
  ),
  VersionRecord(
    version: '0.2.0',
    date: '2025-12-25',
    updates: [
      '新增合并功能',
      '修复标签能左滑多个的问题',
    ],
  ),
  VersionRecord(
    version: '0.1.1',
    date: '2025-12-25',
    updates: [
      '新建app图标',
    ],
  ),
  VersionRecord(
    version: '0.1.0',
    date: '2025-12-24',
    updates: [
      '初始版发布',
    ],
  ),
];