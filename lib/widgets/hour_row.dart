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
  final int timeBlockDuration;

  const HourRow({
    super.key,
    required this.hourIndex,
    required this.timeData,
    required this.selectedMinutes,
    required this.isCurrentHourRow,
    required this.now,
    required this.timeBlockDuration,
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

    // 当前设置下的块数 (用于网格绘制)
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
                
                // 1. 用于【显示内容和选中】的最小单位宽度 (1分钟)
                final double oneMinuteWidth = totalWidth / 60.0;
                
                // 2. 用于【网格】的块宽度 (当前间隔)
                final double blockWidth = totalWidth / blocksPerHour;

                return Stack(
                  children: [
                    // Layer 1: 基础网格线 (遵循 timeBlockDuration)
                    Row(
                      children: List.generate(blocksPerHour, (_) => Container(
                        width: blockWidth,
                        height: double.infinity,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200, width: 0.5),
                        ),
                      )),
                    ),
                    
                    // Layer 2: 颜色项目层 (始终按 1分钟 精度渲染)
                    ..._buildHighFidelityBlocks(rowBaseMinute, oneMinuteWidth),
                    
                    // Layer 3: 选中状态层 (【核心修改】按 1分钟 精度渲染)
                    ..._buildSelectionLayer(rowBaseMinute, oneMinuteWidth),
                    
                    // Layer 4: 当前时间线
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

  // 高保真渲染项目块
  List<Widget> _buildHighFidelityBlocks(int rowBaseMinute, double oneMinuteWidth) {
    List<Widget> blocks = [];
    int i = 0;
    final DataManager dm = DataManager();

    while (i < 60) {
      final int currentMinute = rowBaseMinute + i;
      final TimeEntry? entry = timeData[currentMinute];
      
      if (entry != null) {
        int j = i + 1;
        while (j < 60) {
          final int nextMinute = rowBaseMinute + j;
          final TimeEntry? nextEntry = timeData[nextMinute];
          
          if (nextEntry == null || nextEntry.uniqueId != entry.uniqueId) {
            break; 
          }
          j++;
        }
        
        final int durationInMinutes = j - i;
        final tag = dm.getTagById(entry.tagId);

        blocks.add(Positioned(
          left: i * oneMinuteWidth,
          top: 0, bottom: 0,
          width: durationInMinutes * oneMinuteWidth,
          child: Container(
            decoration: BoxDecoration(
              color: entry.project.color,
              // 分割线
              border: (j < 60) ? const Border(
                right: BorderSide(color: Colors.white, width: 1.0),
              ) : null,
            ),
            alignment: Alignment.center,
            child: durationInMinutes >= 2 
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          entry.displayName, 
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(blurRadius: 2, color: Colors.black26, offset: Offset(0, 1))]
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (tag != null)
                        Flexible(
                          child: Text(
                            "#${tag.name}",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 8,
                              fontStyle: FontStyle.italic,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
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

  // 【新增】高保真选中层渲染
  List<Widget> _buildSelectionLayer(int rowBaseMinute, double oneMinuteWidth) {
    List<Widget> blocks = [];
    int i = 0;
    while (i < 60) {
      final int currentMinute = rowBaseMinute + i;
      if (selectedMinutes.contains(currentMinute)) {
        // 找到连续选中的区域
        int j = i + 1;
        while (j < 60 && selectedMinutes.contains(rowBaseMinute + j)) {
          j++;
        }
        
        blocks.add(Positioned(
          left: i * oneMinuteWidth,
          top: 0, bottom: 0,
          width: (j - i) * oneMinuteWidth,
          child: Container(
            color: Colors.black.withOpacity(0.15),
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