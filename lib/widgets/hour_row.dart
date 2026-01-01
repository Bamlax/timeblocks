import 'package:flutter/material.dart';
import '../constants.dart';
import '../data_manager.dart'; // 需要引入 DataManager 查找 Tag
import '../models/project.dart';
import '../models/time_entry.dart';

class HourRow extends StatelessWidget {
  final int hourIndex;
  final Map<int, TimeEntry> timeData;
  final Set<int> selectedMinutes;
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
          // 左侧：时间标签 (宽度45)
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
          // 右侧：展示网格
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
                    // 2. 颜色项目层 (包含标签显示)
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
                    // 4. 当前时间小竖条 (修复版)
                    if (isCurrentHourRow)
                      Builder(
                        builder: (context) {
                          // 定义竖条宽度
                          const double barWidth = 3.0; 
                          
                          // 计算精确的时间比例 (秒级)
                          final double ratio = (now.minute * 60 + now.second) / 3600.0;
                          
                          // 【核心修正】减去宽度的一半，实现中心对齐
                          final double leftPos = (ratio * totalWidth) - (barWidth / 2);

                          return Positioned(
                            left: leftPos,
                            top: 0,
                            bottom: 0,
                            child: IgnorePointer(
                              child: Container(
                                width: barWidth,
                                decoration: BoxDecoration(
                                  color: Colors.black, // 纯黑
                                  borderRadius: BorderRadius.circular(1.0),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(0.8), // 白色光晕，增强对比
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

  List<Widget> _buildMergedProjectBlocks(int rowBaseMinute, double blockWidth) {
    List<Widget> blocks = [];
    int i = 0;
    final DataManager dm = DataManager(); // 用于查找 Tag

    while (i < 12) {
      final int currentMinute = rowBaseMinute + (i * 5);
      final TimeEntry? entry = timeData[currentMinute];
      if (entry != null) {
        int j = i + 1;
        while (j < 12) {
          final int nextMinute = rowBaseMinute + (j * 5);
          final TimeEntry? nextEntry = timeData[nextMinute];
          // 合并条件：uniqueId 必须一致 (包含 projectId, taskId, tagId)
          if (nextEntry == null || nextEntry.uniqueId != entry.uniqueId) break;
          j++;
        }
        final int blockCount = j - i;
        
        // 查找标签对象
        final tag = dm.getTagById(entry.tagId);

        blocks.add(Positioned(
          left: i * blockWidth,
          top: 0, bottom: 0,
          width: blockCount * blockWidth,
          child: Container(
            // 使用 BoxDecoration 添加右侧白边分割线
            decoration: BoxDecoration(
              color: entry.project.color,
              border: const Border(
                right: BorderSide(color: Colors.white, width: 1.0),
              ),
            ),
            alignment: Alignment.center,
            // 使用 Column 显示 项目名 + 标签
            child: blockCount > 1
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
                      // 如果有标签，显示小字
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