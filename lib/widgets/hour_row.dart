import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/project.dart';
import '../models/time_entry.dart';

class HourRow extends StatelessWidget {
  final int hourIndex;
  final Map<int, TimeEntry> timeData;
  final Set<int> selectedMinutes;
  // 删除 onSelect 回调，因为不由内部控制了
  final bool isCurrentHourRow;
  final DateTime now;

  const HourRow({
    super.key,
    required this.hourIndex,
    required this.timeData,
    required this.selectedMinutes,
    required this.isCurrentHourRow,
    required this.now,
  });

  String _formatDate(DateTime date) {
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return "${date.month}/${date.day}\n${weekdays[date.weekday - 1]}";
  }

  @override
  Widget build(BuildContext context) {
    final DateTime currentRowTime = kAnchorDate.add(Duration(hours: hourIndex));
    final int currentHour = currentRowTime.hour;
    final bool isNewDay = currentHour == 0;
    final int rowBaseMinute = hourIndex * 60;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // 左侧：时间标签
          SizedBox(
            width: 60,
            child: Center(
              child: isNewDay
                  ? Text(
                      _formatDate(currentRowTime),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    )
                  : Text(
                      "${currentHour.toString().padLeft(2, '0')}:00",
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrentHourRow ? Colors.black : Colors.grey.shade500,
                        fontWeight: isCurrentHourRow ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
            ),
          ),
          // 右侧：纯展示网格 (移除 GestureDetector)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                final double blockWidth = totalWidth / 12;

                return Stack(
                  children: [
                    // 1. 基础网格线
                    Row(
                      children: List.generate(12, (_) => Container(
                        width: blockWidth,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200, width: 0.5),
                        ),
                      )),
                    ),
                    // 2. 颜色项目层
                    ..._buildMergedProjectBlocks(rowBaseMinute, blockWidth),
                    // 3. 选中状态层
                    Row(
                      children: List.generate(12, (i) {
                        final isSelected = selectedMinutes.contains(rowBaseMinute + i * 5);
                        return Container(
                          width: blockWidth,
                          height: double.infinity,
                          color: isSelected ? Colors.black.withOpacity(0.15) : Colors.transparent,
                        );
                      }),
                    ),
                    // 4. 当前时间小竖条
                    if (isCurrentHourRow)
                      Positioned(
                        left: ((now.minute * 60 + now.second) / 3600.0) * totalWidth,
                        top: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            width: 3,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.5),
                                  blurRadius: 2,
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMergedProjectBlocks(int rowBaseMinute, double blockWidth) {
    List<Widget> blocks = [];
    int i = 0;
    while (i < 12) {
      final int currentMinute = rowBaseMinute + (i * 5);
      final TimeEntry? entry = timeData[currentMinute];
      if (entry != null) {
        int j = i + 1;
        while (j < 12) {
          final int nextMinute = rowBaseMinute + (j * 5);
          final TimeEntry? nextEntry = timeData[nextMinute];
          if (nextEntry == null || nextEntry.uniqueId != entry.uniqueId) break;
          j++;
        }
        final int blockCount = j - i;
        blocks.add(Positioned(
          left: i * blockWidth,
          top: 0, bottom: 0,
          width: blockCount * blockWidth,
          child: Container(
            color: entry.project.color,
            alignment: Alignment.center,
            child: blockCount > 1
                ? Text(entry.displayName,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(0, 1))]),
                    overflow: TextOverflow.ellipsis, maxLines: 1)
                : null,
          ),
        ));
        i = j;
      } else {
        i++;
      }
    }
    return blocks;
  }
}