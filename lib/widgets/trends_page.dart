import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart'; 
import 'dart:math' as math;
import '../constants.dart';
import '../data_manager.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/tag.dart';

enum TrendPeriod { week, month, year, all }

enum TargetType { project, task, tag }

class TrendTarget {
  final String id;
  final String name;
  final Color color;
  final TargetType type;

  TrendTarget({
    required this.id,
    required this.name,
    required this.color,
    required this.type,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendTarget &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type;

  @override
  int get hashCode => id.hashCode ^ type.hashCode;
}

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  TrendPeriod _selectedPeriod = TrendPeriod.week;
  DateTime _anchorDate = DateTime.now();
  final List<TrendTarget> _selectedTargets = [];

  @override
  void initState() {
    super.initState();
  }

  // --- 时间导航 ---

  void _moveDate(int offset) {
    setState(() {
      if (_selectedPeriod == TrendPeriod.week) {
        _anchorDate = _anchorDate.add(Duration(days: 7 * offset));
      } else if (_selectedPeriod == TrendPeriod.month) {
        _anchorDate = DateTime(_anchorDate.year, _anchorDate.month + offset, _anchorDate.day);
      } else if (_selectedPeriod == TrendPeriod.year) {
        _anchorDate = DateTime(_anchorDate.year + offset, _anchorDate.month, _anchorDate.day);
      }
      // "all" 模式不需要移动
    });
  }

  String _getDateLabel() {
    final DateFormat formatter = DateFormat('yyyy/MM/dd');
    
    if (_selectedPeriod == TrendPeriod.week) {
      final start = _anchorDate.subtract(Duration(days: _anchorDate.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return "${formatter.format(start)} - ${formatter.format(end)}";
    } else if (_selectedPeriod == TrendPeriod.month) {
      return "${_anchorDate.year}年${_anchorDate.month}月";
    } else if (_selectedPeriod == TrendPeriod.year) {
      return "${_anchorDate.year}年";
    } else {
      return "有史以来 (按天)";
    }
  }

  // --- 弹窗添加统计项 ---

  void _showAddTargetDialog(DataManager dm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DefaultTabController(
          length: 3,
          child: SizedBox(
            height: 500,
            child: Column(
              children: [
                const TabBar(
                  tabs: [
                    Tab(text: "事件"),
                    Tab(text: "内容"),
                    Tab(text: "标签"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // 1. 项目
                      _buildSelectionList<Project>(
                        items: dm.projects.where((p) => p.id != 'clear').toList(),
                        getName: (p) => p.name,
                        getColor: (p) => p.color,
                        onSelect: (p) => _addTarget(TrendTarget(id: p.id, name: p.name, color: p.color, type: TargetType.project)),
                      ),
                      // 2. 任务
                      _buildSelectionList<Task>(
                        items: dm.tasks,
                        getName: (t) {
                          final p = dm.getProjectById(t.projectId);
                          return "${t.name} (${p?.name ?? '-'})";
                        },
                        getColor: (t) => dm.getProjectById(t.projectId)?.color ?? Colors.grey,
                        onSelect: (t) {
                          final p = dm.getProjectById(t.projectId);
                          _addTarget(TrendTarget(id: t.id, name: t.name, color: p?.color ?? Colors.blue, type: TargetType.task));
                        },
                      ),
                      // 3. 标签
                      _buildSelectionList<Tag>(
                        items: dm.tags,
                        getName: (t) => t.name,
                        getColor: (t) => Colors.primaries[t.id.hashCode % Colors.primaries.length],
                        onSelect: (t) => _addTarget(TrendTarget(
                          id: t.id, 
                          name: t.name, 
                          color: Colors.primaries[t.id.hashCode % Colors.primaries.length], 
                          type: TargetType.tag
                        )),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionList<T>({
    required List<T> items,
    required String Function(T) getName,
    required Color Function(T) getColor,
    required Function(T) onSelect,
  }) {
    if (items.isEmpty) return const Center(child: Text("无数据"));
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: Container(width: 12, height: 12, decoration: BoxDecoration(color: getColor(item), shape: BoxShape.circle)),
          title: Text(getName(item)),
          onTap: () {
            onSelect(item);
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _addTarget(TrendTarget target) {
    if (!_selectedTargets.contains(target)) {
      setState(() {
        _selectedTargets.add(target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final DataManager dataManager = DataManager();

    return Scaffold(
      appBar: AppBar(
        title: const Text('趋势分析'),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: dataManager,
        builder: (context, _) {
          return Column(
            children: [
              _buildTopPanel(),
              _buildSelectedChips(),
              const Divider(height: 1),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 24, left: 12, top: 32, bottom: 12),
                  child: _buildChart(dataManager),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTargetDialog(dataManager),
        tooltip: "添加对比项",
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTopPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // 周期切换
          SegmentedButton<TrendPeriod>(
            segments: const [
              ButtonSegment(value: TrendPeriod.week, label: Text("周")),
              ButtonSegment(value: TrendPeriod.month, label: Text("月")),
              ButtonSegment(value: TrendPeriod.year, label: Text("年")),
              ButtonSegment(value: TrendPeriod.all, label: Text("全部")),
            ],
            selected: {_selectedPeriod},
            onSelectionChanged: (newSelection) {
              setState(() => _selectedPeriod = newSelection.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(height: 12),
          
          // 日期导航 (选中“全部”时隐藏)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectedPeriod != TrendPeriod.all)
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _moveDate(-1),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(_getDateLabel(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              if (_selectedPeriod != TrendPeriod.all)
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _moveDate(1),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedChips() {
    if (_selectedTargets.isEmpty) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: _selectedTargets.map((target) {
          return Chip(
            avatar: CircleAvatar(backgroundColor: target.color),
            label: Text(target.name),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () {
              setState(() {
                _selectedTargets.remove(target);
              });
            },
            visualDensity: VisualDensity.compact,
            backgroundColor: Colors.white,
            side: BorderSide(color: Colors.grey.shade300),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChart(DataManager dm) {
    if (_selectedTargets.isEmpty) {
      return const Center(child: Text("点击右下角 + 添加统计对象"));
    }

    DateTime startRange;
    DateTime endRange;
    int maxX; 
    
    // 获取数据中的最早时间 (用于 All 模式的起点)
    DateTime? firstRecordDate;
    if (_selectedPeriod == TrendPeriod.all && dm.timeData.isNotEmpty) {
      final int firstMin = dm.timeData.keys.reduce(math.min);
      firstRecordDate = kAnchorDate.add(Duration(minutes: firstMin));
    }

    if (_selectedPeriod == TrendPeriod.week) {
      startRange = DateTime(_anchorDate.year, _anchorDate.month, _anchorDate.day).subtract(Duration(days: _anchorDate.weekday - 1));
      endRange = startRange.add(const Duration(days: 7));
      maxX = 6; 
    } else if (_selectedPeriod == TrendPeriod.month) {
      startRange = DateTime(_anchorDate.year, _anchorDate.month, 1);
      endRange = DateTime(_anchorDate.year, _anchorDate.month + 1, 1);
      maxX = DateUtils.getDaysInMonth(_anchorDate.year, _anchorDate.month);
    } else if (_selectedPeriod == TrendPeriod.year) {
      startRange = DateTime(_anchorDate.year, 1, 1);
      endRange = DateTime(_anchorDate.year + 1, 1, 1);
      maxX = 12;
    } else {
      // 【修改点】All 模式 - 按天统计
      if (firstRecordDate == null) {
        startRange = DateTime.now(); 
        endRange = DateTime.now();
        maxX = 1;
      } else {
        // 从最早的那一天 00:00 开始
        startRange = DateTime(firstRecordDate.year, firstRecordDate.month, firstRecordDate.day);
        final now = DateTime.now();
        // 结束于今天 23:59 (即明天 00:00)
        endRange = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
        
        // 计算总天数
        maxX = endRange.difference(startRange).inDays;
        if (maxX <= 0) maxX = 1;
      }
    }

    final int startMin = startRange.difference(kAnchorDate).inMinutes;
    final int endMin = endRange.difference(kAnchorDate).inMinutes;

    double maxY = 0;
    List<LineChartBarData> lineBarsData = [];

    for (var target in _selectedTargets) {
      Map<int, int> spotsMap = {}; 

      dm.timeData.forEach((minuteIndex, entry) {
        if (minuteIndex >= startMin && minuteIndex < endMin) {
          bool isMatch = false;
          if (target.type == TargetType.project && entry.project.id == target.id) isMatch = true;
          if (target.type == TargetType.task && entry.task?.id == target.id) isMatch = true;
          if (target.type == TargetType.tag && entry.tagId == target.id) isMatch = true;

          if (isMatch) {
            final DateTime blockTime = kAnchorDate.add(Duration(minutes: minuteIndex));
            int xKey;
            
            if (_selectedPeriod == TrendPeriod.week) {
              xKey = blockTime.weekday - 1; 
            } else if (_selectedPeriod == TrendPeriod.month) {
              xKey = blockTime.day; 
            } else if (_selectedPeriod == TrendPeriod.year) {
              xKey = blockTime.month; 
            } else {
              // 【修改点】All 模式：xKey 是距离开始日期的天数
              xKey = blockTime.difference(startRange).inDays;
            }
            
            spotsMap[xKey] = (spotsMap[xKey] ?? 0) + 5; // 如果时间块粒度变了，这里最好用 duration，但暂定5
          }
        }
      });

      List<FlSpot> spots = [];
      
      int loopMax = (_selectedPeriod == TrendPeriod.week) ? 6 : maxX;
      // All 模式从 0 开始 (第0天), month/year 从 1 开始 (1号/1月)
      int loopStart = (_selectedPeriod == TrendPeriod.month || _selectedPeriod == TrendPeriod.year) ? 1 : 0;
      
      // 如果是 All 模式，loopMax 是总天数，注意边界
      if (_selectedPeriod == TrendPeriod.all) loopMax = maxX - 1; // index 从 0 到 count-1

      for (int i = loopStart; i <= loopMax; i++) {
        double hours = (spotsMap[i] ?? 0) / 60.0;
        spots.add(FlSpot(i.toDouble(), hours));
        if (hours > maxY) maxY = hours;
      }

      lineBarsData.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true, 
        color: target.color,
        // 【修改点】线条变细
        barWidth: 1.5, 
        isStrokeCapRound: true,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false), 
      ));
    }

    if (maxY == 0) maxY = 1;
    double interval = _calculateInterval(maxY);

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.black87,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final targetName = _selectedTargets[barSpot.barIndex].name;
                return LineTooltipItem(
                  '$targetName\n${barSpot.y.toStringAsFixed(1)} h',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              // 【修改点】传入动态间隔算法
              interval: _calculateXInterval(maxX), 
              getTitlesWidget: (value, meta) => _bottomTitleWidgets(value, meta, startRange),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: interval,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text("");
                return Text("${value.toStringAsFixed(1)}h", style: const TextStyle(color: Colors.grey, fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: (_selectedPeriod == TrendPeriod.month || _selectedPeriod == TrendPeriod.year) ? 1 : 0,
        // All 模式下 maxX 是天数
        maxX: (_selectedPeriod == TrendPeriod.all) ? maxX.toDouble() - 1 : maxX.toDouble(),
        minY: 0,
        maxY: maxY * 1.1,
        lineBarsData: lineBarsData,
      ),
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta, DateTime startRange) {
    const style = TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10);
    String text = '';
    int index = value.toInt();

    if (_selectedPeriod == TrendPeriod.week) {
      const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
      if (index >= 0 && index < 7) text = weekdays[index];
    } else if (_selectedPeriod == TrendPeriod.month) {
      if (index == 1 || index % 5 == 0) text = '$index日';
    } else if (_selectedPeriod == TrendPeriod.year) {
      text = '$index月';
    } else {
      // 【修改点】All 模式 - 显示日期 MM/dd
      final date = startRange.add(Duration(days: index));
      // 如果间隔很大，显示年份，否则显示月日
      // 这里简化处理：首尾显示完整，中间显示月日
      if (index == 0 || date.month == 1 && date.day == 1) {
        text = DateFormat('yy/MM/dd').format(date);
      } else {
        text = DateFormat('MM/dd').format(date);
      }
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(text, style: style),
    );
  }

  double _calculateInterval(double maxY) {
    if (maxY <= 1) return 0.2;
    if (maxY <= 5) return 1;
    if (maxY <= 10) return 2;
    return 5;
  }

  // 【修改点】动态计算 X 轴标签间隔，防止文字重叠
  double _calculateXInterval(int maxX) {
    if (_selectedPeriod == TrendPeriod.month) return 5;
    if (_selectedPeriod == TrendPeriod.all) {
      // 假设屏幕宽度能容纳 6-7 个标签
      if (maxX <= 7) return 1;
      return (maxX / 6).floorToDouble();
    }
    return 1;
  }
}