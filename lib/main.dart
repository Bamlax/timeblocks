import 'dart:async';
import 'package:flutter/material.dart';
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
  TimeEntry? _activeTrackingEntry;

  late ScrollController _scrollController;
  Timer? _timer;
  final GlobalKey _listViewKey = GlobalKey();

  // 【恢复】缩放相关变量
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
        _checkAndFillCurrentMinute();
      }
    });
  }

  void _checkAndFillCurrentMinute() {
    if (_activeTrackingEntry == null) return;
    final now = DateTime.now();
    final int currentMinuteIndex = now.difference(kAnchorDate).inMinutes;
    final TimeEntry? existing = _dataManager.timeData[currentMinuteIndex];
    if (existing?.uniqueId != _activeTrackingEntry!.uniqueId) {
      _dataManager.batchUpdate({
        currentMinuteIndex: _activeTrackingEntry
      });
    }
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

  // --- 【恢复】手势缩放逻辑 ---
  void _onScaleStart(ScaleStartDetails details) {
    _baseDuration = _dataManager.timeBlockDuration;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    int currentIndex = _zoomLevels.indexOf(_baseDuration);
    if (currentIndex == -1) currentIndex = 2; 

    int targetIndex = currentIndex;
    // 调整灵敏度
    if (details.scale > 1.3) {
      targetIndex = (currentIndex - 1).clamp(0, _zoomLevels.length - 1);
    } else if (details.scale < 0.7) {
      targetIndex = (currentIndex + 1).clamp(0, _zoomLevels.length - 1);
    }
    final int newDuration = _zoomLevels[targetIndex];
    if (newDuration != _dataManager.timeBlockDuration) {
      _dataManager.updateTimeBlockDuration(newDuration);
      _clearSelection();
    }
  }

  // --- 撤销逻辑 ---
  void _recordUndoSnapshot() {
    _undoSnapshot = {};
    final int duration = _dataManager.timeBlockDuration;
    for (var startIndex in _selectedMinutes) {
      for (int i = 0; i < duration; i++) {
        final int exactMinute = startIndex + i;
        _undoSnapshot![exactMinute] = _dataManager.timeData[exactMinute];
      }
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

  // --- 手势与应用逻辑 ---
  void _handleTap(Offset localPosition) {
    _dismissUndo(); 
    final int? minute = _calculateMinuteFromOffset(localPosition);
    if (minute == null) {
      _clearSelection();
      return;
    }
    setState(() {
      if (_selectedMinutes.contains(minute)) {
        _selectedMinutes.remove(minute);
      } else {
        _selectedMinutes.add(minute);
      }
    });
  }

  void _handleGlobalGesture(Offset localPosition, {bool isStart = false}) {
    if (isStart) _dismissUndo(); 
    final int? currentMinute = _calculateMinuteFromOffset(localPosition);
    if (currentMinute == null) return;
    final int step = _dataManager.timeBlockDuration;
    setState(() {
      if (isStart) {
        _selectedMinutes.clear(); 
        _dragStartIndex = currentMinute;
        _selectedMinutes.add(currentMinute);
      } else {
        if (_dragStartIndex == null) return;
        _selectedMinutes.clear(); 
        int start = _dragStartIndex!;
        int end = currentMinute;
        if (start > end) {
          final temp = start; start = end; end = temp;
        }
        for (int i = start; i <= end; i += step) {
          _selectedMinutes.add(i);
        }
      }
    });
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
    if (_selectedMinutes.isNotEmpty) {
      _recordUndoSnapshot();
      final int duration = _dataManager.timeBlockDuration;
      Map<int, TimeEntry?> updates = {};
      for (var startIndex in _selectedMinutes) {
        for (int i = 0; i < duration; i++) {
          final int exactMinute = startIndex + i;
          if (project == null) {
            updates[exactMinute] = null;
          } else {
            updates[exactMinute] = TimeEntry(project: project, task: task);
          }
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

    if (project != null) {
      final newEntry = TimeEntry(project: project, task: task);
      setState(() {
        if (_activeTrackingEntry?.uniqueId == newEntry.uniqueId) {
          _activeTrackingEntry = null;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已停止自动填充"), duration: Duration(seconds: 1)));
        } else {
          _activeTrackingEntry = newEntry;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("开始自动填充: ${newEntry.displayName}"), 
              duration: const Duration(seconds: 1),
              backgroundColor: project.color,
            )
          );
          _checkAndFillCurrentMinute();
        }
      });
    }
  }

  void _applyTag(String? tagId) {
    if (_selectedMinutes.isEmpty) return;
    _recordUndoSnapshot();
    final int duration = _dataManager.timeBlockDuration;
    Map<int, TimeEntry?> updates = {};
    for (var startIndex in _selectedMinutes) {
      for (int i = 0; i < duration; i++) {
        final int exactMinute = startIndex + i;
        final existingEntry = _dataManager.timeData[exactMinute];
        if (existingEntry != null) {
          updates[exactMinute] = existingEntry.copyWith(tagId: tagId, clearTag: tagId == null);
        }
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
    if (_activeTrackingEntry == null) return;
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
                      trailing: _activeTrackingEntry!.tagId == tag.id ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () {
                        setState(() {
                          _activeTrackingEntry = _activeTrackingEntry!.copyWith(tagId: tag.id);
                        });
                        _checkAndFillCurrentMinute();
                        Navigator.pop(context);
                      },
                    )),
                    ListTile(
                      leading: const Icon(Icons.label_off, size: 18, color: Colors.red),
                      title: const Text("移除标签", style: TextStyle(color: Colors.red)),
                      onTap: () {
                        setState(() {
                          _activeTrackingEntry = _activeTrackingEntry!.copyWith(clearTag: true);
                        });
                        _checkAndFillCurrentMinute();
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

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool hasSelection = _selectedMinutes.isNotEmpty;

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
          if (_activeTrackingEntry != null)
            IconButton(
              tooltip: "为当前专注添加标签",
              icon: Icon(
                _activeTrackingEntry!.tagId != null ? Icons.label : Icons.label_outline,
                color: _activeTrackingEntry!.tagId != null ? Colors.blue : Colors.grey,
              ),
              onPressed: _showTrackingTagSelector,
            ),
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
          GestureDetector(
            onTap: _clearSelection, 
            behavior: HitTestBehavior.translucent,
            child: Row(
              children: [
                Expanded(
                  flex: 70,
                  // 【核心修改】恢复了双指缩放功能 (GestureDetector)
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
                        
                        // 【核心修复】直接比较 ID，不再用字符串拼接，解决小圆点不显示问题
                        final bool isProjectTracking = _activeTrackingEntry?.project.id == project.id && _activeTrackingEntry?.task == null;

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
                              // 【核心修复】Task 比较逻辑
                              final bool isTaskTracking = _activeTrackingEntry?.task?.id == task.id;
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
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))
                ],
              ),
              child: Row(
                children: [
                  Text(
                    "已选 ${_selectedMinutes.length * _dataManager.timeBlockDuration} 分钟",
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
    // 【核心修复】改为无状态组件，确保圆点显示
    return _SubTaskButton(
      task: task,
      parentProject: parentProject,
      isTracking: isTracking,
      onTap: () => _applyEntry(parentProject, task),
    );
  }
}

// 无状态组件，显示静态圆点
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
    return Material(
      color: parentProject.color,
      borderRadius: BorderRadius.circular(4),
      elevation: 1, 
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
              // 【核心修复】如果 tracking，显示圆点
              if (isTracking) 
                const Padding(
                  padding: EdgeInsets.only(right: 2), 
                  child: Icon(Icons.fiber_manual_record, size: 8, color: Colors.white),
                ),
              const Icon(Icons.subdirectory_arrow_right, size: 12, color: Colors.white70),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  task.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
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