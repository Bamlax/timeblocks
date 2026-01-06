import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'data_manager.dart';
import 'models/time_entry.dart';
import 'models/project.dart';
import 'models/task.dart';
import 'widgets/hour_row.dart';
import 'widgets/project_entry_dialog.dart'; // 用于新增
import 'widgets/project_edit_dialog.dart';  // 【新增】用于长按编辑
import 'widgets/project_button.dart';
import 'widgets/app_drawer.dart';

void main() async {
  // 1. 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. 启动前先加载本地保存的数据
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
  
  // 用于手动控制 Scaffold (打开侧边栏)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final Set<int> _selectedMinutes = {};
  
  // 记录拖拽开始时的分钟索引 (用于范围选择)
  int? _dragStartIndex;
  
  // 撤销功能相关
  Map<int, TimeEntry?>? _undoSnapshot; 
  bool _showUndoButton = false;        

  late ScrollController _scrollController;
  Timer? _timer;
  final GlobalKey _listViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _dataManager.addListener(_onDataChanged);
    _scrollController = ScrollController(initialScrollOffset: _calculateInitialOffset());
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
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
    // 视觉修正：让当前时间位于屏幕上方约 300 像素处
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

  // --- 手势计算逻辑 ---
  int? _calculateMinuteFromOffset(Offset localPosition) {
    final RenderBox? renderBox = _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    
    // 必须与 HourRow 中的设置保持一致 (当前是 45.0)
    const double timeLabelWidth = 45.0; 
    if (localPosition.dx <= timeLabelWidth) return null;

    final double gridX = localPosition.dx - timeLabelWidth;
    final double gridY = localPosition.dy + _scrollController.offset;

    final int hourIndex = (gridY / kHourHeight).floor();
    if (hourIndex < 0) return null;

    final double totalGridWidth = renderBox.size.width - timeLabelWidth;
    
    // 动态计算列数
    final int duration = _dataManager.timeBlockDuration;
    final int blocksPerHour = 60 ~/ duration;
    final double blockWidth = totalGridWidth / blocksPerHour;
    
    int blockIndex = (gridX / blockWidth).floor();
    if (blockIndex < 0) blockIndex = 0;
    if (blockIndex >= blocksPerHour) blockIndex = blocksPerHour - 1;

    return hourIndex * 60 + blockIndex * duration;
  }

  // --- 撤销逻辑 ---

  void _recordUndoSnapshot() {
    _undoSnapshot = {};
    for (var index in _selectedMinutes) {
      _undoSnapshot![index] = _dataManager.timeData[index];
    }
  }

  void _showUndo() {
    setState(() {
      _showUndoButton = true;
    });
  }

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
        const SnackBar(
          content: Text("已撤销更改"), 
          duration: Duration(milliseconds: 600),
          behavior: SnackBarBehavior.floating,
        )
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
    if (isStart) {
      _dismissUndo(); 
    }

    final int? currentMinute = _calculateMinuteFromOffset(localPosition);
    if (currentMinute == null) return;

    // 获取当前间隔步长
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
    if (_selectedMinutes.isEmpty) return;
    
    _recordUndoSnapshot();

    Map<int, TimeEntry?> updates = {};
    for (var index in _selectedMinutes) {
      if (project == null) {
        updates[index] = null;
      } else {
        updates[index] = TimeEntry(project: project, task: task);
      }
    }
    
    _dataManager.batchUpdate(updates);
    
    setState(() {
      _selectedMinutes.clear();
      _dragStartIndex = null;
    });
    
    _showUndo();
  }

  void _applyTag(String? tagId) {
    if (_selectedMinutes.isEmpty) return;

    _recordUndoSnapshot();

    Map<int, TimeEntry?> updates = {};
    for (var index in _selectedMinutes) {
      final existingEntry = _dataManager.timeData[index];
      if (existingEntry != null) {
        updates[index] = existingEntry.copyWith(tagId: tagId, clearTag: tagId == null);
      }
    }
    
    if (updates.isNotEmpty) {
      _dataManager.batchUpdate(updates);
    }
    
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
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              _dismissUndo();
              if (value == 'block_size') {
                _showBlockSizeDialog();
              }
            },
            itemBuilder: (context) => [
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
          // 1. 主体内容
          GestureDetector(
            onTap: _clearSelection, 
            behavior: HitTestBehavior.translucent,
            child: Row(
              children: [
                // 左侧：时间网格
                Expanded(
                  flex: 70,
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
                
                // 右侧：项目列表
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
                        // 底部新增按钮
                        if (index == _dataManager.projects.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildSimpleAddButton(),
                          );
                        }

                        final project = _dataManager.projects[index];
                        final subTasks = _dataManager.getTasksForProject(project.id);

                        // 1. 无子项，显示单个按钮
                        if (subTasks.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ProjectButton(
                              project: project,
                              onTap: () => _applyEntry(project),
                              // 【关键点】长按编辑项目
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (c) => ProjectEditDialog(project: project),
                                );
                              },
                            ),
                          );
                        }

                        // 2. 有子项，显示列表
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ProjectButton(
                                project: project,
                                onTap: () => _applyEntry(project),
                                // 【关键点】长按编辑项目
                                onLongPress: () {
                                  showDialog(
                                    context: context,
                                    builder: (c) => ProjectEditDialog(project: project),
                                  );
                                },
                              ),
                            ),
                            ...subTasks.map((task) => Padding(
                              padding: const EdgeInsets.only(left: 12, right: 4, top: 4),
                              child: _buildSubTaskButton(task, project),
                            )),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. 底部弹出操作栏
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

          // 3. 底部弹出：撤销按钮
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
            // 获取已有名称用于查重
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

  Widget _buildSubTaskButton(Task task, Project parentProject) {
    return Material(
      color: parentProject.color,
      borderRadius: BorderRadius.circular(4),
      elevation: 1, 
      child: InkWell(
        onTap: () => _applyEntry(parentProject, task),
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