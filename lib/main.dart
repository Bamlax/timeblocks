import 'dart:async';
import 'package:flutter/material.dart';
import 'constants.dart';
import 'data_manager.dart';
import 'models/time_entry.dart';
import 'models/project.dart';
import 'models/task.dart';
import 'widgets/hour_row.dart';
import 'widgets/add_project_dialog.dart';
import 'widgets/project_button.dart';
import 'widgets/app_drawer.dart';

void main() async {
  // 1. 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. 启动前先加载数据
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
  int? _dragStartIndex;
  
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

  // ... 后面的代码保持不变 ...
  // ... _calculateInitialOffset, _scrollToToday, _handleGlobalGesture 等 ...
  // ... build 方法 ...
  
  // 这里为了完整性，把之前实现的关键方法贴一下，确保你复制时不会漏掉逻辑
  
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

  void _handleGlobalGesture(Offset localPosition, {bool isStart = false}) {
    final RenderBox? renderBox = _listViewKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    const double timeLabelWidth = 60.0;
    if (localPosition.dx <= timeLabelWidth) return;

    final double gridX = localPosition.dx - timeLabelWidth;
    final double gridY = localPosition.dy + _scrollController.offset;

    final int hourIndex = (gridY / kHourHeight).floor();
    if (hourIndex < 0) return;

    final double totalGridWidth = renderBox.size.width - timeLabelWidth;
    final double blockWidth = totalGridWidth / 12;
    
    int blockIndex = (gridX / blockWidth).floor();
    if (blockIndex < 0) blockIndex = 0;
    if (blockIndex > 11) blockIndex = 11;

    final int currentMinute = hourIndex * 60 + blockIndex * 5;
    
    setState(() {
      if (isStart) {
        _dragStartIndex = currentMinute;
        _selectedMinutes.clear();
        _selectedMinutes.add(currentMinute);
      } else {
        if (_dragStartIndex == null) return;
        _selectedMinutes.clear();
        int start = _dragStartIndex!;
        int end = currentMinute;
        if (start > end) {
          final temp = start;
          start = end;
          end = temp;
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

  void _applyEntry(Project project, [Task? task]) {
    if (_selectedMinutes.isEmpty) return;
    
    Map<int, TimeEntry?> updates = {};
    for (var index in _selectedMinutes) {
      if (project.id == 'clear') {
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
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();

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
      body: GestureDetector(
        onTap: _clearSelection,
        behavior: HitTestBehavior.translucent,
        child: Row(
          children: [
            Expanded(
              flex: 75,
              child: GestureDetector(
                onLongPressStart: (details) {
                  _handleGlobalGesture(details.localPosition, isStart: true);
                },
                onLongPressMoveUpdate: (details) {
                  _handleGlobalGesture(details.localPosition, isStart: false);
                },
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
            
            Expanded(
              flex: 25,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(left: BorderSide(color: Colors.grey.shade200)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                  itemCount: _dataManager.projects.length + 1,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index == _dataManager.projects.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: AddProjectButton(
                          onTap: () => showDialog(
                            context: context,
                            builder: (c) => AddProjectDialog(onAdd: _dataManager.addProject),
                          ),
                        ),
                      );
                    }

                    final project = _dataManager.projects[index];
                    final subTasks = _dataManager.getTasksForProject(project.id);
                    final isClear = project.id == 'clear';

                    if (isClear || subTasks.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: ProjectButton(
                            project: project,
                            onTap: () => _applyEntry(project),
                          ),
                        ),
                        ...subTasks.map((task) => Padding(
                          padding: const EdgeInsets.only(left: 20, right: 8, top: 6),
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
    );
  }

  Widget _buildSubTaskButton(Task task, Project parentProject) {
    return Material(
      color: parentProject.color,
      borderRadius: BorderRadius.circular(6),
      elevation: 1, 
      child: InkWell(
        onTap: () => _applyEntry(parentProject, task),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: double.infinity,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
             borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.white70),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  task.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
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