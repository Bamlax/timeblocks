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
  
  // 【新增】控制当前是显示饼图还是条形图
  bool _showPieChart = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        return DateTimeRange(start: kAnchorDate, end: today.add(const Duration(days: 36500)));
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
          // 【新增】视图切换图标 (饼图/列表)
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
          
          // 日期选择
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
                type: _StatType.project, 
                showPieChart: _showPieChart // 传入视图状态
              ),
              _StatView(
                range: _getDateRange(), 
                type: _StatType.task, 
                showPieChart: _showPieChart
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _StatType { project, task }

// 数据模型类，方便传递
class _StatItem {
  final String id;
  final String name;
  final Color color;
  final int minutes;
  final double percentage;

  _StatItem({
    required this.id,
    required this.name,
    required this.color,
    required this.minutes,
    required this.percentage,
  });
}

class _StatView extends StatelessWidget {
  final DateTimeRange range;
  final _StatType type;
  final bool showPieChart;

  const _StatView({
    required this.range, 
    required this.type,
    required this.showPieChart,
  });

  @override
  Widget build(BuildContext context) {
    final DataManager dataManager = DataManager();
    final Map<String, int> durationMap = {};
    final Map<String, Color> colorMap = {};
    final Map<String, String> nameMap = {};
    
    int totalMinutesInRange = 0;

    // 1. 聚合数据
    final int startMin = range.start.difference(kAnchorDate).inMinutes;
    final int endMin = range.end.difference(kAnchorDate).inMinutes;

    dataManager.timeData.forEach((minuteIndex, entry) {
      if (minuteIndex >= startMin && minuteIndex < endMin) {
        String id;
        String name;
        Color color;

        if (type == _StatType.project) {
          id = entry.project.id;
          name = entry.project.name;
          color = entry.project.color;
        } else {
          if (entry.task != null) {
            id = entry.task!.id;
            name = entry.task!.name;
            color = entry.project.color;
          } else {
            return; 
          }
        }

        durationMap[id] = (durationMap[id] ?? 0) + 1; // 1 block = 5 mins
        colorMap[id] = color;
        nameMap[id] = name;
        totalMinutesInRange += 5; 
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

    // 2. 转换为 List 并排序
    final List<_StatItem> items = durationMap.keys.map((id) {
      final int blocks = durationMap[id]!;
      final int minutes = blocks * 5;
      final double percentage = minutes / totalMinutesInRange;
      return _StatItem(
        id: id,
        name: nameMap[id]!,
        color: colorMap[id]!,
        minutes: minutes,
        percentage: percentage,
      );
    }).toList();

    // 按时长倒序
    items.sort((a, b) => b.minutes.compareTo(a.minutes));

    // 3. 构建界面
    return Column(
      children: [
        // 顶部总时长
        Container(
          padding: const EdgeInsets.all(16),
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
        
        // 内容区域：根据 showPieChart 切换
        Expanded(
          child: showPieChart 
              ? _buildPieChartView(items)
              : _buildBarListView(items),
        ),
      ],
    );
  }

  // --- 视图 A: 条形图列表 ---
  Widget _buildBarListView(List<_StatItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (c, i) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(_formatDuration(item.minutes), style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
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
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                "${(item.percentage * 100).toStringAsFixed(1)}%",
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- 视图 B: 饼图视图 (包含图表 + 图例列表) ---
  Widget _buildPieChartView(List<_StatItem> items) {
    return Column(
      children: [
        // 1. 饼图区域
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: SizedBox(
            height: 200,
            width: 200,
            child: CustomPaint(
              painter: _PieChartPainter(items),
            ),
          ),
        ),
        const Divider(),
        // 2. 底部图例列表 (简单展示，不带进度条)
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                dense: true,
                leading: Container(
                  width: 12, 
                  height: 12, 
                  decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
                ),
                title: Text(item.name),
                trailing: Text(
                  "${_formatDuration(item.minutes)}  (${(item.percentage * 100).toStringAsFixed(1)}%)",
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    final int h = minutes ~/ 60;
    final int m = minutes % 60;
    if (h > 0) return "${h}h ${m}m";
    return "${m}m";
  }
}

// --- 手写饼图绘制器 (无需第三方库) ---
class _PieChartPainter extends CustomPainter {
  final List<_StatItem> items;

  _PieChartPainter(this.items);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    
    // 这是一个空心饼图 (Donut Chart) 还是实心？这里画实心
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2; // 从12点方向开始

    for (var item in items) {
      final sweepAngle = 2 * math.pi * item.percentage;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = item.color;
      
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      
      // 绘制分割线
      final borderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.white
        ..strokeWidth = 2.0;
      canvas.drawArc(rect, startAngle, sweepAngle, true, borderPaint);

      startAngle += sweepAngle;
    }
    
    // 中间挖个洞做成甜甜圈 (可选)
    // final holeRadius = radius * 0.5;
    // canvas.drawCircle(center, holeRadius, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}