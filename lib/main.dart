import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'data_manager.dart';
import 'models/time_entry.dart';
import 'models/project.dart';
import 'models/task.dart';
import 'widgets/hour_row.dart';
import 'widgets/project_entry_dialog.dart';
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
  
  // 选中的分钟集合
  final Set<int> _selectedMinutes = {};
  
  // 拖拽起点
  int? _dragStartIndex;
  
  // --- 撤销功能相关变量 ---
  Map<int, TimeEntry?>? _undoSnapshot; // 记录修改前的数据
  bool _showUndoButton = false;        // 是否显示撤销按钮
  Timer? _undoHideTimer;               // 2秒倒计时器

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
    _undoHideTimer?.cancel();
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
    final double blockWidth = totalGridWidth / 12;
    
    int blockIndex = (gridX / blockWidth).floor();
    if (blockIndex < 0) blockIndex = 0;
    if (blockIndex > 11) blockIndex = 11;

    return hourIndex * 60 + blockIndex * 5;
  }

  // --- 撤销逻辑 ---

  // 1. 记录当前选区的数据快照
  void _recordUndoSnapshot() {
    _undoSnapshot = {};
    for (var index in _selectedMinutes) {
      _undoSnapshot![index] = _dataManager.timeData[index]; // 记录引用
    }
  }

  // 2. 显示撤销按钮，并启动定时器
  void _showUndo() {
    setState(() {
      _showUndoButton = true;
    });
    
    // 重置定时器
    _undoHideTimer?.cancel();
    _undoHideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showUndoButton = false;
          _undoSnapshot = null; // 超时清除快照
        });
      }
    });
  }

  // 3. 执行撤销
  void _performUndo() {
    if (_undoSnapshot != null) {
      // 恢复数据
      _dataManager.batchUpdate(_undoSnapshot!);
      
      setState(() {
        _showUndoButton = false;
        _undoSnapshot = null;
      });
      
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

  void _handleDrag(Offset localPosition, {bool isStart = false}) {
    final int? currentMinute = _calculateMinuteFromOffset(localPosition);
    if (currentMinute == null) return;

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
        for (int i = start; i <= end; i += 5) {
          _selectedMinutes.add(i);
        }
      }
    });
  }

  void _clearSelection() {
    if (_selectedMinutes.isNotEmpty) {
      setState(() {
        _selectedMinutes.clear();
        _dragStartIndex = null;
      });
    }
  }

  // 应用项目/任务
  void _applyEntry(Project? project, [Task? task]) {
    if (_selectedMinutes.isEmpty) return;
    
    // 1. 记录快照
    _recordUndoSnapshot();

    // 2. 执行更新
    Map<int, TimeEntry?> updates = {};
    for (var index in _selectedMinutes) {
      if (project == null) {
        updates[index] = null;
      } else {
        updates[index] = TimeEntry(project: project, task: task);
      }
    }
    _dataManager.batchUpdate(updates);
    
    // 3. 清除选区并显示撤回
    setState(() {
      _selectedMinutes.clear();
      _dragStartIndex = null;
    });
    _showUndo();
  }

  // 应用标签
  void _applyTag(String? tagId) {
    if (_selectedMinutes.isEmpty) return;

    // 1. 记录快照
    _recordUndoSnapshot();

    // 2. 执行更新
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
    
    // 3. 清除选区并显示撤回
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

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool hasSelection = _selectedMinutes.isNotEmpty;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: GestureDetector(
          onTap: _scrollToToday,
          child: const Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Text('Timeblocks'),
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_up, size: 16, color: Colors.grey),
            ],
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Stack(
        children: [
          // 1. 主体内容 (网格 + 列表)
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
                    onLongPressStart: (details) => _handleDrag(details.localPosition, isStart: true),
                    onLongPressMoveUpdate: (details) => _handleDrag(details.localPosition, isStart: false),
                    
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
                        if (index == _dataManager.projects.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildSimpleAddButton(),
                          );
                        }

                        final project = _dataManager.projects[index];
                        final subTasks = _dataManager.getTasksForProject(project.id);

                        if (subTasks.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ProjectButton(
                              project: project,
                              onTap: () => _applyEntry(project),
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
                                onTap: () => _applyEntry(project),
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

          // 2. 底部弹出：选择操作栏
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
                    "已选 ${_selectedMinutes.length * 5} 分钟",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(width: 16),
                  
                  // 标签按钮
                  TextButton.icon(
                    onPressed: _showTagSelector,
                    icon: const Icon(Icons.label_outline, size: 20),
                    label: const Text("标签"),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
                  ),

                  const Spacer(),
                  
                  // 清除按钮
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

          // 3. 底部弹出：撤销按钮 (右下角)
          // 只有当没有选区，且 _showUndoButton 为 true 时显示
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            right: 20,
            // 如果有选区操作栏，撤销按钮藏起来，否则显示
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
        onTap: () {
          // 【修改点】获取所有现有项目名称
          final existingNames = _dataManager.projects
              .where((p) => p.id != 'clear')
              .map((p) => p.name)
              .toList();

          showDialog(
            context: context,
            builder: (c) => ProjectEntryDialog(
              title: '新增事件',
              confirmText: '添加',
              existingNames: existingNames, // 传入查重列表
              onSubmit: (name, color) {
                _dataManager.addProject(name, color);
              },
            ),
          );
        },
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