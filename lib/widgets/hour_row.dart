import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_manager.dart';
import '../models/project.dart';
import '../models/time_entry.dart';

class HourRow extends StatelessWidget {
  final int hourIndex;
  final Map<int, TimeEntry> timeData;
  final Set<int> selectedMinutes;
  final bool isCurrentHourRow;
  final DateTime now;
  final int timeBlockDuration; // 【新增】接收间隔

  const HourRow({
    super.key,
    required this.hourIndex,
    required this.timeData,
    required this.selectedMinutes,
    required this.isCurrentHourRow,
    required this.now,
    required this.timeBlockDuration, // 【新增】
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

    // 【新增】计算一小时有多少个块
    final int blocksPerHour = 60 ~/ timeBlockDuration;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 45, 
            child: Center(
              child: isNewDay
                  ? Text(
                      _formatDate(currentRowTime),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        height: 1.1,
                      ),
                    )
                  : Text(
                      "${currentHour.toString().padLeft(2, '0')}:00",
                      style: TextStyle(
                        fontSize: 11,
                        color: isCurrentHourRow ? Colors.black : Colors.grey.shade500,
                        fontWeight: isCurrentHourRow ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double totalWidth = constraints.maxWidth;
                // 【修改】根据块数动态计算宽度
                final double blockWidth = totalWidth / blocksPerHour;

                return Stack(
                  children: [
                    // 1. 基础网格线
                    Row(
                      // 【修改】使用 blocksPerHour
                      children: List.generate(blocksPerHour, (_) => Container(
                        width: blockWidth,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200, width: 0.5),
                        ),
                      )),
                    ),
                    // 2. 颜色项目层
                    ..._buildMergedProjectBlocks(rowBaseMinute, blockWidth, blocksPerHour),
                    // 3. 选中状态层
                    Row(
                      children: List.generate(blocksPerHour, (i) {
                        // 【修改】计算分钟数
                        final isSelected = selectedMinutes.contains(rowBaseMinute + i * timeBlockDuration);
                        return Container(
                          width: blockWidth,
                          height: double.infinity,
                          color: isSelected ? Colors.black.withOpacity(0.15) : Colors.transparent,
                        );
                      }),
                    ),
                    // 4. 当前时间小竖条
                    if (isCurrentHourRow)
                      Builder(
                        builder: (context) {
                          const double barWidth = 2.0; 
                          final double ratio = (now.minute * 60 + now.second) / 3600.0;
                          final double leftPos = (ratio * totalWidth) - (barWidth / 2);

                          return Positioned(
                            left: leftPos,
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Container(
                                width: barWidth,
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(1.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.8),
                                      blurRadius: 3,
                                      spreadRadius: 1,
                                    )
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
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

  // 【修改】合并逻辑适配动态间隔
  List<Widget> _buildMergedProjectBlocks(int rowBaseMinute, double blockWidth, int blocksPerHour) {
    List<Widget> blocks = [];
    int i = 0;
    final DataManager dm = DataManager();

    while (i < blocksPerHour) {
      final int currentMinute = rowBaseMinute + (i * timeBlockDuration);
      final TimeEntry? entry = timeData[currentMinute];
      
      if (entry != null) {
        int j = i + 1;
        while (j < blocksPerHour) {
          final int nextMinute = rowBaseMinute + (j * timeBlockDuration);
          final TimeEntry? nextEntry = timeData[nextMinute];
          
          if (nextEntry == null || nextEntry.uniqueId != entry.uniqueId) {
            break; 
          }
          j++;
        }
        
        final int blockCount = j - i;
        final tag = dm.getTagById(entry.tagId);

        blocks.add(Positioned(
          left: i * blockWidth,
          top: 0, bottom: 0,
          width: blockCount * blockWidth,
          child: Container(
            decoration: BoxDecoration(
              color: entry.project.color,
              border: const Border(
                right: BorderSide(color: Colors.white, width: 1.0),
              ),
            ),
            alignment: Alignment.center,
            child: blockCount >= 1 // 原来是>1，现在可能块很大，>=1 也可以显示
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        entry.displayName, 
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(0, 1))]
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      if (tag != null)
                        Text(
                          "#${tag.name}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 9,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                    ],
                  )
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