import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // 引入 dart:ui 以使用 PointerDeviceKind
import 'package:flutter/gestures.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'constants.dart';
import 'data_manager.dart';
import 'models/time_entry.dart';
import 'models/project.dart';
import 'models/task.dart';
import 'widgets/hour_row.dart';
import 'widgets/project_entry_dialog.dart';
import 'widgets/project_edit_dialog.dart'; 
import 'widgets/project_button.dart';
import 'widgets/app_drawer.dart';

enum SelectionMode { block, event }

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DataManager().init();
  runApp(const TimeBlockApp());
}

class TimeBlockApp extends StatelessWidget {
  const TimeBlockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TimeBlocks',
      debugShowCheckedModeBanner: false,
      scrollBehavior: MyCustomScrollBehavior(),
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black, 
            fontSize: 20, 
            fontWeight: FontWeight.bold
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DataManager _dataManager = DataManager();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final Set<int> _selectedMinutes = {};
  
  int? _dragStartIndex;
  Map<int, TimeEntry?>? _undoSnapshot; 
  bool _showUndoButton = false;        
  SelectionMode _selectionMode = SelectionMode.block;

  late ScrollController _scrollController;
  Timer? _timer;
  final GlobalKey _listViewKey = GlobalKey();

  final List<int> _zoomLevels = [1, 2, 5, 10];
  int _baseDuration = 5;

  @override
  void initState() {
    super.initState();
    _dataManager.addListener(_onDataChanged);
    _scrollController = ScrollController(initialScrollOffset: _calculateInitialOffset());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {}); 
        // 这里的自动填充交给了 DataManager 内部逻辑，UI 只负责刷新显示
        _dataManager.checkAndFillCurrentMinute();
      }
    });
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _dataManager.removeListener(_onDataChanged);
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  double _calculateInitialOffset() {
    final now = DateTime.now();
    final int hoursDiff = now.difference(kAnchorDate).inHours;
    double offset = hoursDiff * kHourHeight;
    offset -= 300; 
    return offset < 0 ? 0 : offset;
  }

  void _scrollToToday() {
    final double offset = _calculateInitialOffset();
    _scrollController.animateTo(
      offset,
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
    );
  }

  int? _calculateMinuteFromOffset(Offset localPosition) {
    final RenderBox? renderBox = _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    const double timeLabelWidth = 45.0; 
    if (localPosition.dx <= timeLabelWidth) return null;

    final double gridX = localPosition.dx - timeLabelWidth;
    final double gridY = localPosition.dy + _scrollController.offset;

    final int hourIndex = (gridY / kHourHeight).floor();
    if (hourIndex < 0) return null;

    final double totalGridWidth = renderBox.size.width - timeLabelWidth;
    final int duration = _dataManager.timeBlockDuration;
    final int blocksPerHour = 60 ~/ duration;
    final double blockWidth = totalGridWidth / blocksPerHour;
    
    int blockIndex = (gridX / blockWidth).floor();
    if (blockIndex < 0) blockIndex = 0;
    if (blockIndex >= blocksPerHour) blockIndex = blocksPerHour - 1;

    return hourIndex * 60 + blockIndex * duration;
  }

  int? _calculateExactMinuteFromOffset(Offset localPosition) {
    final RenderBox? renderBox = _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    const double timeLabelWidth = 45.0; 
    if (localPosition.dx <= timeLabelWidth) return null;

    final double gridX = localPosition.dx - timeLabelWidth;
    final double gridY = localPosition.dy + _scrollController.offset;

    final int hourIndex = (gridY / kHourHeight).floor();
    if (hourIndex < 0) return null;

    final double totalGridWidth = renderBox.size.width - timeLabelWidth;
    final double oneMinuteWidth = totalGridWidth / 60.0;
    
    int minuteIndex = (gridX / oneMinuteWidth).floor();
    if (minuteIndex < 0) minuteIndex = 0;
    if (minuteIndex > 59) minuteIndex = 59;

    return hourIndex * 60 + minuteIndex;
  }

  // --- 手势缩放 ---
  void _onScaleStart(ScaleStartDetails details) {
    _baseDuration = _dataManager.timeBlockDuration;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if ((details.scale - 1.0).abs() < 0.05) return;
    _updateZoom(details.scale);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final keys = HardwareKeyboard.instance.logicalKeysPressed;
      if (keys.contains(LogicalKeyboardKey.controlLeft) || keys.contains(LogicalKeyboardKey.controlRight)) {
        final double scale = event.scrollDelta.dy < 0 ? 1.5 : 0.5;
        _baseDuration = _dataManager.timeBlockDuration;
        _updateZoom(scale);
      }
    }
  }

  void _updateZoom(double scale) {
    int currentIndex = _zoomLevels.indexOf(_baseDuration);
    if (currentIndex == -1) currentIndex = 2; 

    int targetIndex = currentIndex;
    if (scale > 1.2) {
      targetIndex = (currentIndex - 1).clamp(0, _zoomLevels.length - 1);
    } else if (scale < 0.8) {
      targetIndex = (currentIndex + 1).clamp(0, _zoomLevels.length - 1);
    }
    final int newDuration = _zoomLevels[targetIndex];
    if (newDuration != _dataManager.timeBlockDuration) {
      _dataManager.updateTimeBlockDuration(newDuration);
      _clearSelection();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("时间粒度：$newDuration 分钟"),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(50), 
        ),
      );
    }
  }

  // --- 选取逻辑 ---

  void _selectByEventLogic(int tappedMinute) {
    final now = DateTime.now();
    final int nowMinuteIndex = now.difference(kAnchorDate).inMinutes;

    if (tappedMinute > nowMinuteIndex) return;

    final TimeEntry? clickedEntry = _dataManager.timeData[tappedMinute];

    setState(() {
      _selectedMinutes.clear();
      _dragStartIndex = null;
    });

    if (clickedEntry != null) {
      final String targetUniqueId = clickedEntry.uniqueId;
      
      int start = tappedMinute;
      while (true) {
        if (start <= 0) break;
        final prevEntry = _dataManager.timeData[start - 1];
        if (prevEntry?.uniqueId != targetUniqueId) break;
        start--;
      }
      
      int end = tappedMinute;
      while (true) {
        final nextEntry = _dataManager.timeData[end + 1];
        if (nextEntry?.uniqueId != targetUniqueId) break;
        end++;
      }

      setState(() {
        for (int i = start; i <= end; i++) {
          _selectedMinutes.add(i);
        }
      });
      return;
    }

    final keys = _dataManager.timeData.keys.toList()..sort();
    if (keys.isEmpty) return;

    int? prevEventEnd;
    try {
      prevEventEnd = keys.lastWhere((k) => k < tappedMinute);
    } catch (e) {
      return; 
    }

    int start = prevEventEnd + 1;
    int end = tappedMinute;
    
    int? nextEventStart;
    try {
      nextEventStart = keys.firstWhere((k) => k > tappedMinute);
    } catch (e) {
      nextEventStart = null;
    }

    if (nextEventStart != null && nextEventStart <= nowMinuteIndex) {
      end = nextEventStart - 1;
    } else {
      end = nowMinuteIndex;
    }
    
    setState(() {
      for (int i = start; i <= end; i++) {
        if (i > nowMinuteIndex) continue;
        _selectedMinutes.add(i);
      }
    });
  }

  // --- 手势与应用逻辑 ---

  void _handleTap(Offset localPosition) {
    _dismissUndo(); 

    if (_selectionMode == SelectionMode.event) {
      final int? exactMinute = _calculateExactMinuteFromOffset(localPosition);
      if (exactMinute != null) {
        _selectByEventLogic(exactMinute);
      } else {
        _clearSelection();
      }
    } else {
      final int? minute = _calculateMinuteFromOffset(localPosition);
      if (minute == null) {
        _clearSelection();
        return;
      }
      
      setState(() {
        final int duration = _dataManager.timeBlockDuration;
        bool isSelected = _selectedMinutes.contains(minute);
        for (int i = 0; i < duration; i++) {
          if (isSelected) {
            _selectedMinutes.remove(minute + i);
          } else {
            _selectedMinutes.add(minute + i);
          }
        }
      });
    }
  }

  void _handleGlobalGesture(Offset localPosition, {bool isStart = false}) {
    if (isStart) _dismissUndo(); 
    if (_selectionMode == SelectionMode.event) return;

    final int? currentMinute = _calculateMinuteFromOffset(localPosition);
    if (currentMinute == null) return;
    
    final int step = _dataManager.timeBlockDuration;

    setState(() {
      if (isStart) {
        _selectedMinutes.clear(); 
        _dragStartIndex = currentMinute;
        for (int i = 0; i < step; i++) _selectedMinutes.add(currentMinute + i);
      } else {
        if (_dragStartIndex == null) return;
        _selectedMinutes.clear(); 
        int start = _dragStartIndex!;
        int end = currentMinute;
        if (start > end) {
          final temp = start; start = end; end = temp;
        }
        for (int i = start; i <= end + step - 1; i++) {
           _selectedMinutes.add(i);
        }
      }
    });
  }

  void _recordUndoSnapshot() {
    _undoSnapshot = {};
    for (var minute in _selectedMinutes) {
      _undoSnapshot![minute] = _dataManager.timeData[minute];
    }
  }

  void _showUndo() => setState(() => _showUndoButton = true);

  void _dismissUndo() {
    if (_showUndoButton) {
      setState(() {
        _showUndoButton = false;
        _undoSnapshot = null;
      });
    }
  }

  void _performUndo() {
    if (_undoSnapshot != null) {
      _dataManager.batchUpdate(_undoSnapshot!);
      _dismissUndo();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("已撤销更改"), duration: Duration(milliseconds: 600), behavior: SnackBarBehavior.floating)
      );
    }
  }

  void _clearSelection() {
    _dismissUndo(); 
    if (_selectedMinutes.isNotEmpty) {
      setState(() {
        _selectedMinutes.clear();
        _dragStartIndex = null;
      });
    }
  }

  void _applyEntry(Project? project, [Task? task]) {
    // 1. 批量填充模式
    if (_selectedMinutes.isNotEmpty) {
      _recordUndoSnapshot();
      Map<int, TimeEntry?> updates = {};
      
      for (var exactMinute in _selectedMinutes) {
        if (project == null) {
          updates[exactMinute] = null;
        } else {
          updates[exactMinute] = TimeEntry(project: project, task: task);
        }
      }
      
      _dataManager.batchUpdate(updates);
      setState(() {
        _selectedMinutes.clear();
        _dragStartIndex = null;
      });
      _showUndo();
      return;
    }

    // 2. 实时追踪模式
    if (project != null) {
      final newEntry = TimeEntry(project: project, task: task);
      
      // 判断是否已经在这个状态
      final activeEntry = _dataManager.activeTrackingEntry;
      if (activeEntry?.uniqueId == newEntry.uniqueId) {
        // 停止追踪
        _dataManager.stopTracking();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已停止自动填充"), duration: Duration(seconds: 1)));
      } else {
        // 开始追踪
        _dataManager.startTracking(newEntry);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("开始自动填充: ${newEntry.displayName}"), 
            duration: const Duration(seconds: 1),
            backgroundColor: project.color,
          )
        );
      }
      // UI 会通过 ListenableBuilder 自动更新，因为 DataManager 通知了 Listeners
    }
  }

  void _applyTag(String? tagId) {
    if (_selectedMinutes.isEmpty) {
      if (_dataManager.activeTrackingEntry != null) {
         _showTrackingTagSelector();
      }
      return;
    }

    _recordUndoSnapshot();
    Map<int, TimeEntry?> updates = {};
    for (var exactMinute in _selectedMinutes) {
      final existingEntry = _dataManager.timeData[exactMinute];
      if (existingEntry != null) {
        updates[exactMinute] = existingEntry.copyWith(tagId: tagId, clearTag: tagId == null);
      }
    }
    if (updates.isNotEmpty) _dataManager.batchUpdate(updates);
    setState(() {
      _selectedMinutes.clear();
      _dragStartIndex = null;
    });
    _showUndo();
  }

  void _showTagSelector() {
    if (_dataManager.tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请先在侧边栏创建标签")));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("选择标签", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ..._dataManager.tags.map((tag) => ListTile(
                      leading: const Icon(Icons.label, size: 18),
                      title: Text(tag.name),
                      onTap: () {
                        Navigator.pop(context);
                        _applyTag(tag.id);
                      },
                    )),
                    ListTile(
                      leading: const Icon(Icons.label_off, size: 18, color: Colors.red),
                      title: const Text("移除标签", style: TextStyle(color: Colors.red)),
                      onTap: () {
                        Navigator.pop(context);
                        _applyTag(null);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTrackingTagSelector() {
    final activeEntry = _dataManager.activeTrackingEntry;
    if (activeEntry == null) return;

    if (_dataManager.tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请先在侧边栏创建标签")));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("为当前专注添加标签", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ..._dataManager.tags.map((tag) => ListTile(
                      leading: const Icon(Icons.label, size: 18),
                      title: Text(tag.name),
                      trailing: activeEntry.tagId == tag.id ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () {
                        final newEntry = activeEntry.copyWith(tagId: tag.id);
                        _dataManager.startTracking(newEntry);
                        Navigator.pop(context);
                      },
                    )),
                    ListTile(
                      leading: const Icon(Icons.label_off, size: 18, color: Colors.red),
                      title: const Text("移除标签", style: TextStyle(color: Colors.red)),
                      onTap: () {
                        final newEntry = activeEntry.copyWith(clearTag: true);
                        _dataManager.startTracking(newEntry);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSelectionModeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("选择选取方式"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("按时间块"),
              subtitle: const Text("手动点击或拖拽选择"),
              leading: Radio<SelectionMode>(
                value: SelectionMode.block,
                groupValue: _selectionMode,
                onChanged: (val) {
                  setState(() => _selectionMode = val!);
                  _clearSelection();
                  Navigator.pop(ctx);
                },
              ),
              onTap: () {
                setState(() => _selectionMode = SelectionMode.block);
                _clearSelection();
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text("按事件"),
              subtitle: const Text("智能选中连续的相同事件"),
              leading: Radio<SelectionMode>(
                value: SelectionMode.event,
                groupValue: _selectionMode,
                onChanged: (val) {
                  setState(() => _selectionMode = val!);
                  _clearSelection();
                  Navigator.pop(ctx);
                },
              ),
              onTap: () {
                setState(() => _selectionMode = SelectionMode.event);
                _clearSelection();
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockSizeDialog() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("调整时间块大小", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...[1, 2, 5, 10, 20, 30].map((minutes) => ListTile(
                title: Text("$minutes 分钟"),
                trailing: _dataManager.timeBlockDuration == minutes 
                    ? const Icon(Icons.check, color: Colors.blue) 
                    : null,
                onTap: () {
                  _dataManager.updateTimeBlockDuration(minutes);
                  _clearSelection();
                  Navigator.pop(ctx);
                },
              )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool hasSelection = _selectedMinutes.isNotEmpty;
    // 【核心修复】直接从 DataManager 获取，不使用本地 State 变量
    final activeEntry = _dataManager.activeTrackingEntry;

    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: "导航栏",
          onPressed: () {
            _dismissUndo();
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        title: GestureDetector(
          onTap: () {
            _dismissUndo();
            _scrollToToday();
          },
          child: const Text('Timeblocks'),
        ),
        centerTitle: true,
        actions: [
          if (activeEntry != null)
            IconButton(
              tooltip: "为当前专注添加标签",
              icon: Icon(
                activeEntry.tagId != null ? Icons.label : Icons.label_outline,
                color: activeEntry.tagId != null ? Colors.blue : Colors.grey,
              ),
              onPressed: _showTrackingTagSelector,
            ),
            
          PopupMenuButton<String>(
            tooltip: "菜单", 
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              _dismissUndo();
              if (value == 'block_size') {
                _showBlockSizeDialog();
              } else if (value == 'selection_mode') {
                _showSelectionModeDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'selection_mode',
                child: Row(
                  children: [
                    Icon(Icons.select_all, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('选取方式'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'block_size',
                child: Row(
                  children: [
                    Icon(Icons.grid_view, size: 20, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('调整块大小'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        flexibleSpace: GestureDetector(
          onTap: () {
            _dismissUndo();
            _scrollToToday();
          },
          behavior: HitTestBehavior.translucent,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Stack(
        children: [
          Listener(
            onPointerSignal: _onPointerSignal,
            child: GestureDetector(
              onTap: _clearSelection, 
              behavior: HitTestBehavior.translucent,
              child: Row(
                children: [
                  Expanded(
                    flex: 70,
                    child: GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      child: GestureDetector(
                        onTapUp: (details) => _handleTap(details.localPosition),
                        onLongPressStart: (details) => _handleGlobalGesture(details.localPosition, isStart: true),
                        onLongPressMoveUpdate: (details) => _handleGlobalGesture(details.localPosition, isStart: false),
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                          child: ListenableBuilder(
                            listenable: _dataManager,
                            builder: (context, _) {
                              return ListView.builder(
                                key: _listViewKey,
                                controller: _scrollController,
                                itemCount: 200000 * 24,
                                itemExtent: kHourHeight,
                                itemBuilder: (context, index) {
                                  final DateTime currentRowTime = kAnchorDate.add(Duration(hours: index));
                                  final bool isCurrentHourRow = currentRowTime.year == now.year &&
                                      currentRowTime.month == now.month &&
                                      currentRowTime.day == now.day &&
                                      currentRowTime.hour == now.hour;
                        
                                  return HourRow(
                                    hourIndex: index,
                                    timeData: _dataManager.timeData,
                                    selectedMinutes: _selectedMinutes,
                                    isCurrentHourRow: isCurrentHourRow,
                                    now: now,
                                    timeBlockDuration: _dataManager.timeBlockDuration,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  Expanded(
                    flex: 30,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border(left: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
                        itemCount: _dataManager.projects.length + 1,
                        separatorBuilder: (c, i) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          if (index == _dataManager.projects.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _buildSimpleAddButton(),
                            );
                          }
                          final project = _dataManager.projects[index];
                          final subTasks = _dataManager.getTasksForProject(project.id);
                          final String projectUniqueId = "${project.id}_root_${null}";

                          // 【核心修改】isTracking 判断逻辑
                          final bool isProjectTracking = activeEntry?.uniqueId == projectUniqueId;

                          if (subTasks.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ProjectButton(
                                project: project,
                                isTracking: isProjectTracking,
                                onTap: () => _applyEntry(project),
                                onLongPress: () {
                                  showDialog(
                                    context: context,
                                    builder: (c) => ProjectEditDialog(project: project),
                                  );
                                },
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ProjectButton(
                                  project: project,
                                  isTracking: isProjectTracking,
                                  onTap: () => _applyEntry(project),
                                  onLongPress: () {
                                    showDialog(
                                      context: context,
                                      builder: (c) => ProjectEditDialog(project: project),
                                    );
                                  },
                                ),
                              ),
                              ...subTasks.map((task) {
                                final String taskUniqueId = "${project.id}_${task.id}_${null}";
                                // 【核心修改】子任务 isTracking 判断
                                final bool isTaskTracking = activeEntry?.uniqueId == taskUniqueId;
                                return Padding(
                                  padding: const EdgeInsets.only(left: 12, right: 4, top: 4),
                                  child: _buildSubTaskButton(task, project, 
                                    isTracking: isTaskTracking
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: 0,
            right: 0,
            bottom: hasSelection ? 0 : -80,
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                children: [
                  Text(
                    "已选 ${_selectedMinutes.length} 分钟",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _showTagSelector,
                    icon: const Icon(Icons.label_outline, size: 20),
                    label: const Text("标签"),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () => _applyEntry(null),
                    icon: const Icon(Icons.cleaning_services, size: 16),
                    label: const Text("清除"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      elevation: 0,
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ],
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            right: 20,
            bottom: (!hasSelection && _showUndoButton) ? 30 : -80, 
            child: FloatingActionButton.extended(
              onPressed: _performUndo,
              icon: const Icon(Icons.undo),
              label: const Text("撤回"),
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleAddButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (c) => ProjectEntryDialog(
            title: '新增事件',
            confirmText: '添加',
            existingNames: _dataManager.projects.map((p) => p.name).toList(),
            onSubmit: (name, color) {
              _dataManager.addProject(name, color);
            },
          ),
        ),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey.shade400),
          ),
          child: Icon(Icons.add, size: 20, color: Colors.grey.shade600),
        ),
      ),
    );
  }

  Widget _buildSubTaskButton(Task task, Project parentProject, {bool isTracking = false}) {
    return _SubTaskButton(
      task: task,
      parentProject: parentProject,
      isTracking: isTracking,
      onTap: () => _applyEntry(parentProject, task),
    );
  }
}

class _SubTaskButton extends StatelessWidget {
  final Task task;
  final Project parentProject;
  final bool isTracking;
  final VoidCallback onTap;

  const _SubTaskButton({
    required this.task,
    required this.parentProject,
    required this.isTracking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color displayColor = isTracking 
        ? Color.lerp(parentProject.color, Colors.black, 0.3)! 
        : parentProject.color;

    return Material(
      color: displayColor,
      borderRadius: BorderRadius.circular(4),
      elevation: isTracking ? 3 : 1, 
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: double.infinity,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
             borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.subdirectory_arrow_right, size: 12, color: Colors.white70),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  task.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: isTracking ? FontWeight.bold : FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}