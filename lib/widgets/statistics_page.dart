import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../constants.dart';
import '../data_manager.dart';
import '../models/time_entry.dart';

enum TimeRange { today, week, month, quarter, year, last7, last30, all, custom }

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TimeRange _selectedRange = TimeRange.today;
  DateTimeRange? _customDateRange;
  
  bool _showPieChart = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  // --- 筛选逻辑 ---
  DateTimeRange _getDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_selectedRange) {
      case TimeRange.today:
        return DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
      case TimeRange.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: monday, end: monday.add(const Duration(days: 7)));
      case TimeRange.month:
        final startOfMonth = DateTime(today.year, today.month, 1);
        final nextMonth = DateTime(today.year, today.month + 1, 1);
        return DateTimeRange(start: startOfMonth, end: nextMonth);
      case TimeRange.quarter:
        int quarterMonth = ((today.month - 1) ~/ 3) * 3 + 1;
        final startOfQuarter = DateTime(today.year, quarterMonth, 1);
        final nextQuarter = DateTime(today.year, quarterMonth + 3, 1);
        return DateTimeRange(start: startOfQuarter, end: nextQuarter);
      case TimeRange.year:
         final startOfYear = DateTime(today.year, 1, 1);
         final nextYear = DateTime(today.year + 1, 1, 1);
         return DateTimeRange(start: startOfYear, end: nextYear);
      case TimeRange.last7:
        return DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today.add(const Duration(days: 1)));
      case TimeRange.last30:
        return DateTimeRange(start: today.subtract(const Duration(days: 29)), end: today.add(const Duration(days: 1)));
      case TimeRange.all:
        final dataManager = DataManager();
        if (dataManager.timeData.isEmpty) {
          return DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
        }
        final int firstMinuteIndex = dataManager.timeData.keys.reduce(math.min);
        final DateTime firstRecordDate = kAnchorDate.add(Duration(minutes: firstMinuteIndex));
        final DateTime start = DateTime(firstRecordDate.year, firstRecordDate.month, firstRecordDate.day);
        return DateTimeRange(start: start, end: today.add(const Duration(days: 1)));
      case TimeRange.custom:
        return _customDateRange ?? DateTimeRange(start: today, end: today.add(const Duration(days: 1)));
    }
  }

  String _getRangeLabel() {
    switch (_selectedRange) {
      case TimeRange.today: return "今日";
      case TimeRange.week: return "本周";
      case TimeRange.month: return "本月";
      case TimeRange.quarter: return "本季";
      case TimeRange.year: return "本年";
      case TimeRange.last7: return "近7天";
      case TimeRange.last30: return "近30天";
      case TimeRange.all: return "有史以来";
      case TimeRange.custom:
        if (_customDateRange == null) return "自定义";
        return "${_customDateRange!.start.month}/${_customDateRange!.start.day} - ${_customDateRange!.end.subtract(const Duration(seconds: 1)).month}/${_customDateRange!.end.subtract(const Duration(seconds: 1)).day}";
    }
  }

  Future<void> _selectCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      currentDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedRange = TimeRange.custom;
        _customDateRange = DateTimeRange(start: picked.start, end: picked.end.add(const Duration(days: 1)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DataManager dataManager = DataManager();

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _showPieChart ? "切换列表视图" : "切换饼图视图",
            icon: Icon(
              _showPieChart ? Icons.format_list_bulleted : Icons.pie_chart,
              color: Colors.blue,
            ),
            onPressed: () {
              setState(() {
                _showPieChart = !_showPieChart;
              });
            },
          ),
          
          PopupMenuButton<TimeRange>(
            icon: Row(
              children: [
                Text(_getRangeLabel(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                const Icon(Icons.calendar_today, size: 20),
              ],
            ),
            onSelected: (value) {
              if (value == TimeRange.custom) {
                _selectCustomRange();
              } else {
                setState(() => _selectedRange = value);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: TimeRange.today, child: Text("今日")),
              const PopupMenuItem(value: TimeRange.week, child: Text("本周")),
              const PopupMenuItem(value: TimeRange.month, child: Text("本月")),
              const PopupMenuItem(value: TimeRange.quarter, child: Text("本季")),
              const PopupMenuItem(value: TimeRange.year, child: Text("本年")),
              const PopupMenuDivider(),
              const PopupMenuItem(value: TimeRange.last7, child: Text("最近七天")),
              const PopupMenuItem(value: TimeRange.last30, child: Text("最近30天")),
              const PopupMenuItem(value: TimeRange.all, child: Text("有史以来")),
              const PopupMenuDivider(),
              const PopupMenuItem(value: TimeRange.custom, child: Text("自定义时间...")),
            ],
          ),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "事件类别"),
            Tab(text: "事件内容"),
            Tab(text: "标签"),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: dataManager,
        builder: (context, _) {
          return TabBarView(
            controller: _tabController,
            children: [
              _StatView(
                range: _getDateRange(),
                timeRangeType: _selectedRange,
                type: _StatType.project, 
                showPieChart: _showPieChart
              ),
              _StatView(
                range: _getDateRange(),
                timeRangeType: _selectedRange,
                type: _StatType.task, 
                showPieChart: _showPieChart
              ),
              _StatView(
                range: _getDateRange(),
                timeRangeType: _selectedRange,
                type: _StatType.tag, 
                showPieChart: _showPieChart
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _StatType { project, task, tag }

class _StatItem {
  final String id;
  final String name;
  final Color color;
  final int minutes;
  final double percentage;
  final int previousMinutes;

  _StatItem({
    required this.id,
    required this.name,
    required this.color,
    required this.minutes,
    required this.percentage,
    required this.previousMinutes,
  });
}

// --- 辅助方法：获取上一周期 ---
DateTimeRange? _calculatePreviousRange(TimeRange timeRangeType, DateTimeRange currentRange) {
  if (timeRangeType == TimeRange.all || timeRangeType == TimeRange.custom) {
    return null; 
  }

  final start = currentRange.start;
  switch (timeRangeType) {
    case TimeRange.today:
      return DateTimeRange(start: start.subtract(const Duration(days: 1)), end: start);
    case TimeRange.week:
      return DateTimeRange(start: start.subtract(const Duration(days: 7)), end: start);
    case TimeRange.month:
      final prevStart = DateTime(start.year, start.month - 1, 1);
      return DateTimeRange(start: prevStart, end: start);
    case TimeRange.quarter:
      final prevStart = DateTime(start.year, start.month - 3, 1);
      return DateTimeRange(start: prevStart, end: start);
    case TimeRange.year:
      final prevStart = DateTime(start.year - 1, 1, 1);
      return DateTimeRange(start: prevStart, end: start);
    case TimeRange.last7:
      return DateTimeRange(start: start.subtract(const Duration(days: 7)), end: start);
    case TimeRange.last30:
      return DateTimeRange(start: start.subtract(const Duration(days: 30)), end: start);
    default:
      return null;
  }
}

// --- 主统计视图 ---
class _StatView extends StatelessWidget {
  final DateTimeRange range;
  final TimeRange timeRangeType;
  final _StatType type;
  final bool showPieChart;

  const _StatView({
    super.key,
    required this.range, 
    required this.timeRangeType,
    required this.type,
    required this.showPieChart,
  });

  @override
  Widget build(BuildContext context) {
    final DataManager dataManager = DataManager();
    final Map<String, int> durationMap = {};
    final Map<String, int> prevDurationMap = {};
    final Map<String, Color> colorMap = {};
    final Map<String, String> nameMap = {};
    
    int totalMinutesInRange = 0;

    final int startMin = range.start.difference(kAnchorDate).inMinutes;
    final int endMin = range.end.difference(kAnchorDate).inMinutes;

    final prevRange = _calculatePreviousRange(timeRangeType, range);
    int? prevStartMin;
    int? prevEndMin;
    if (prevRange != null) {
      prevStartMin = prevRange.start.difference(kAnchorDate).inMinutes;
      prevEndMin = prevRange.end.difference(kAnchorDate).inMinutes;
    }

    dataManager.timeData.forEach((minuteIndex, entry) {
      String id;
      String name;
      Color color;

      if (type == _StatType.project) {
        id = entry.project.id;
        name = entry.project.name;
        color = entry.project.color;
      } else if (type == _StatType.task) {
        if (entry.task != null) {
          id = entry.task!.id;
          name = entry.task!.name;
          color = entry.project.color;
        } else {
          return; 
        }
      } else { // Tag
        if (entry.tagId != null) {
          id = entry.tagId!;
          final tag = dataManager.getTagById(id);
          name = tag?.name ?? "未知标签";
          color = Colors.blue; 
        } else {
          return; 
        }
      }

      // 统计当前
      if (minuteIndex >= startMin && minuteIndex < endMin) {
        durationMap[id] = (durationMap[id] ?? 0) + 1;
        colorMap[id] = color;
        nameMap[id] = name;
        totalMinutesInRange += 5; 
      }

      // 统计上期
      if (prevStartMin != null && prevEndMin != null && minuteIndex >= prevStartMin && minuteIndex < prevEndMin) {
        prevDurationMap[id] = (prevDurationMap[id] ?? 0) + 1;
      }
    });

    if (durationMap.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("该时间段无记录", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    List<_StatItem> items = durationMap.keys.map((id) {
      final int blocks = durationMap[id]!;
      final int prevBlocks = prevDurationMap[id] ?? 0;
      final int minutes = blocks * 5;
      final int prevMinutes = prevBlocks * 5;
      final double percentage = minutes / totalMinutesInRange;
      
      return _StatItem(
        id: id,
        name: nameMap[id]!,
        color: colorMap[id]!,
        minutes: minutes,
        percentage: percentage,
        previousMinutes: prevMinutes,
      );
    }).toList();

    items.sort((a, b) => b.minutes.compareTo(a.minutes));

    if (type == _StatType.tag && items.isNotEmpty) {
      items = List.generate(items.length, (index) {
        final item = items[index];
        final double t = items.length > 1 ? index / (items.length - 1) : 0.0;
        final Color gradientColor = Color.lerp(Colors.blue.shade900, Colors.blue.shade100, t)!;
        return _StatItem(
          id: item.id,
          name: item.name,
          color: gradientColor,
          minutes: item.minutes,
          percentage: item.percentage,
          previousMinutes: item.previousMinutes,
        );
      });
    }

    final int days = range.duration.inDays;

    return Column(
      children: [
        // 顶部总时长
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          color: Colors.grey.shade50,
          width: double.infinity,
          child: Center(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: "总时长: ", style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: _formatDuration(totalMinutesInRange),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        
        Expanded(
          child: showPieChart 
              ? _PieChartView(items: items, days: days, type: type, timeRangeType: timeRangeType, range: range, showPieChart: showPieChart) 
              : _BarListView(items: items, days: days, type: type, timeRangeType: timeRangeType, range: range, showPieChart: showPieChart),
        ),
      ],
    );
  }
}

// --- 项目详情统计页面 ---
class ProjectDetailStatisticsPage extends StatelessWidget {
  final String projectId;
  final String projectName;
  final Color projectColor;
  final DateTimeRange range;
  final TimeRange timeRangeType; // 新增
  final bool showPieChart;

  const ProjectDetailStatisticsPage({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.projectColor,
    required this.range,
    required this.timeRangeType,
    required this.showPieChart,
  });

  @override
  Widget build(BuildContext context) {
    final DataManager dataManager = DataManager();
    final Map<String, int> durationMap = {};
    final Map<String, int> prevDurationMap = {}; // 上期数据
    final Map<String, String> nameMap = {};
    
    int totalProjectMinutes = 0;

    final int startMin = range.start.difference(kAnchorDate).inMinutes;
    final int endMin = range.end.difference(kAnchorDate).inMinutes;

    final prevRange = _calculatePreviousRange(timeRangeType, range);
    int? prevStartMin;
    int? prevEndMin;
    if (prevRange != null) {
      prevStartMin = prevRange.start.difference(kAnchorDate).inMinutes;
      prevEndMin = prevRange.end.difference(kAnchorDate).inMinutes;
    }

    dataManager.timeData.forEach((minuteIndex, entry) {
      // 筛选当前项目
      if (entry.project.id == projectId) {
        final String taskId = entry.task?.id ?? "uncategorized";
        final String taskName = entry.task?.name ?? "（无内容）";

        // 当前周期
        if (minuteIndex >= startMin && minuteIndex < endMin) {
          durationMap[taskId] = (durationMap[taskId] ?? 0) + 1;
          nameMap[taskId] = taskName;
          totalProjectMinutes += 5;
        }

        // 上个周期
        if (prevStartMin != null && prevEndMin != null && minuteIndex >= prevStartMin && minuteIndex < prevEndMin) {
          prevDurationMap[taskId] = (prevDurationMap[taskId] ?? 0) + 1;
        }
      }
    });

    if (durationMap.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(projectName)),
        body: const Center(child: Text("该项目在选定时间内无记录")),
      );
    }

    List<_StatItem> items = durationMap.keys.map((id) {
      final int blocks = durationMap[id]!;
      final int prevBlocks = prevDurationMap[id] ?? 0;
      final int minutes = blocks * 5;
      final int prevMinutes = prevBlocks * 5;
      final double percentage = minutes / totalProjectMinutes;
      
      return _StatItem(
        id: id,
        name: nameMap[id]!,
        color: Colors.transparent, // 占位
        minutes: minutes,
        percentage: percentage,
        previousMinutes: prevMinutes,
      );
    }).toList();

    items.sort((a, b) => b.minutes.compareTo(a.minutes));

    // 详情页颜色渐变
    if (items.isNotEmpty) {
      items = List.generate(items.length, (index) {
        final item = items[index];
        final double t = items.length > 1 ? index / (items.length - 1) : 0.0;
        final Color gradientColor = Color.lerp(projectColor, projectColor.withOpacity(0.3), t)!;
        
        return _StatItem(
          id: item.id,
          name: item.name,
          color: gradientColor,
          minutes: item.minutes,
          percentage: item.percentage,
          previousMinutes: item.previousMinutes,
        );
      });
    }

    final int days = range.duration.inDays;

    return Scaffold(
      appBar: AppBar(
        title: Text(projectName),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 详情页这里去掉了顶部的总览面板
          Expanded(
            child: showPieChart
                ? _PieChartView(items: items, days: days)
                : _BarListView(items: items, days: days),
          ),
        ],
      ),
    );
  }
}

// --- 复用组件 ---

class _BarListView extends StatelessWidget {
  final List<_StatItem> items;
  final int days;
  final _StatType? type; // 可选，用于判断点击事件
  final TimeRange? timeRangeType;
  final DateTimeRange? range;
  final bool? showPieChart;

  const _BarListView({
    required this.items, 
    required this.days, 
    this.type,
    this.timeRangeType,
    this.range,
    this.showPieChart,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (c, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        // 只有在主页面且类型为 Project 时才允许点击
        final bool canTap = type == _StatType.project && timeRangeType != null && range != null && showPieChart != null;

        return InkWell(
          onTap: canTap ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProjectDetailStatisticsPage(
                  projectId: item.id,
                  projectName: item.name,
                  projectColor: item.color,
                  range: range!,
                  timeRangeType: timeRangeType!,
                  showPieChart: showPieChart!,
                ),
              ),
            );
          } : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (canTap) const Icon(Icons.keyboard_arrow_right, size: 16, color: Colors.grey),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatDuration(item.minutes), style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                      if (days > 1) 
                        Text("日均: ${_formatDuration(item.minutes ~/ days)}", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.percentage,
                  backgroundColor: item.color.withOpacity(0.1),
                  color: item.color,
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(), // Spacer
                  Row(
                    children: [
                      // 显示对比
                      _ComparisonWidget(item: item),
                      const SizedBox(width: 8),
                      Text(
                        "${(item.percentage * 100).toStringAsFixed(1)}%",
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PieChartView extends StatelessWidget {
  final List<_StatItem> items;
  final int days;
  final _StatType? type;
  final TimeRange? timeRangeType;
  final DateTimeRange? range;
  final bool? showPieChart;

  const _PieChartView({
    required this.items, 
    required this.days,
    this.type,
    this.timeRangeType,
    this.range,
    this.showPieChart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: SizedBox(
            height: 200, width: 200,
            child: CustomPaint(painter: _PieChartPainter(items)),
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              final bool canTap = type == _StatType.project && timeRangeType != null && range != null && showPieChart != null;

              return ListTile(
                dense: true,
                onTap: canTap ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectDetailStatisticsPage(
                        projectId: item.id,
                        projectName: item.name,
                        projectColor: item.color,
                        range: range!,
                        timeRangeType: timeRangeType!,
                        showPieChart: showPieChart!,
                      ),
                    ),
                  );
                } : null,
                leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
                title: Row(
                  children: [
                    Text(item.name),
                    if (canTap) const Icon(Icons.keyboard_arrow_right, size: 14, color: Colors.grey),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("${_formatDuration(item.minutes)}  (${(item.percentage * 100).toStringAsFixed(1)}%)", style: const TextStyle(fontSize: 12)),
                    if (days > 1)
                      Text("日均: ${_formatDuration(item.minutes ~/ days)}", style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    if (item.previousMinutes > 0)
                      _ComparisonWidget(item: item, fontSize: 9),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ComparisonWidget extends StatelessWidget {
  final _StatItem item;
  final double fontSize;

  const _ComparisonWidget({required this.item, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    if (item.previousMinutes == 0) return const SizedBox.shrink();

    final int diff = item.minutes - item.previousMinutes;
    if (diff == 0) {
      return Text("持平", style: TextStyle(fontSize: fontSize, color: Colors.grey));
    }

    final bool isIncrease = diff > 0;
    final double percentChange = (diff.abs() / item.previousMinutes);
    String percentText = (percentChange * 100).toStringAsFixed(0);
    if (percentChange > 9.99) percentText = ">999";

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isIncrease ? Icons.arrow_drop_up : Icons.arrow_drop_down,
          size: fontSize + 4,
          color: isIncrease ? Colors.green : Colors.red,
        ),
        Text(
          "$percentText%",
          style: TextStyle(
            fontSize: fontSize,
            color: isIncrease ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

String _formatDuration(int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (h > 0) return "${h}h ${m}m";
  return "${m}m";
}

class _PieChartPainter extends CustomPainter {
  final List<_StatItem> items;
  _PieChartPainter(this.items);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    double startAngle = -math.pi / 2; 
    for (var item in items) {
      final sweepAngle = 2 * math.pi * item.percentage;
      final paint = Paint()..style = PaintingStyle.fill..color = item.color;
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      final borderPaint = Paint()..style = PaintingStyle.stroke..color = Colors.white..strokeWidth = 2.0;
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);
      startAngle += sweepAngle;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}