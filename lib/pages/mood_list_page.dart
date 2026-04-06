import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/mood_log.dart';
import '../services/image_manager.dart';
import '../widgets/log_editor_dialog.dart';
import '../widgets/mood_log_card.dart';
import '../enums/mood_type.dart';
import '../providers/theme_provider.dart';
import 'mood_calendar_page.dart';
import 'mood_details_page.dart';

const String boxName = 'mood_logs_box';

class MoodListPage extends StatefulWidget {
  const MoodListPage({super.key});

  @override
  State<MoodListPage> createState() => _MoodListPageState();
}

class _MoodListPageState extends State<MoodListPage> {
  late Box<Map<dynamic, dynamic>> _box;
  List<MoodLog> _logs = [];

  // 批量选择相关状态
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _box = Hive.box<Map<dynamic, dynamic>>(boxName);
    _loadLogs();
  }

  void _loadLogs() {
    final keys = _box.keys.toList();
    keys.sort((a, b) {
      final mapA = _box.get(a)!;
      final mapB = _box.get(b)!;
      final timeA = mapA['createdAt'] as DateTime;
      final timeB = mapB['createdAt'] as DateTime;
      return timeB.compareTo(timeA);
    });

    setState(() {
      _logs = keys
          .map((key) => MoodLog.fromMap(_box.get(key)!, key as String))
          .toList();
    });
  }

  List<MoodLog> _currentLogs() {
    final keys = _box.keys.toList();
    keys.sort((a, b) {
      final mapA = _box.get(a)!;
      final mapB = _box.get(b)!;
      final timeA = mapA['createdAt'] as DateTime;
      final timeB = mapB['createdAt'] as DateTime;
      return timeB.compareTo(timeA);
    });

    return keys
        .map((key) => MoodLog.fromMap(_box.get(key)!, key as String))
        .toList();
  }

  void _addLog(
    MoodType mood,
    String note,
    bool aiEnabled, {
    List<String>? imageFileNames,
    String? customEmoji,
    int? customColorValue,
    String? customEmojiLabel,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newLog = MoodLog(
      id: id,
      mood: mood,
      note: note,
      imageFileNames: imageFileNames,
      customEmoji: customEmoji,
      customEmojiLabel: customEmojiLabel,
      customColorValue: customColorValue,
      createdAt: DateTime.now(),
      aiEnabled: aiEnabled,
    );
    await _box.put(id, newLog.toMap());
  }

  /// 进入批量选择模式
  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
    });
  }

  /// 退出批量选择模式
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  /// 切换选中状态
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  /// 全选
  void _selectAll(List<MoodLog> logs) {
    setState(() {
      _selectedIds.addAll(logs.map((log) => log.id));
    });
  }

  /// 取消全选
  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
    });
  }

  /// 批量删除选中记录
  void _batchDelete() async {
    if (_selectedIds.isEmpty) return;

    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认批量删除'),
        content: Text('确定要删除选中的 $count 条心情记录吗？此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 获取要删除的记录
      final logsToDelete = _logs.where((log) => _selectedIds.contains(log.id)).toList();

      // 删除图片和记录
      for (final log in logsToDelete) {
        // 删除所有图片
        if (log.imageFileNames != null) {
          for (final fileName in log.imageFileNames!) {
            await ImageManager.deleteImage(fileName);
          }
        }
        await _box.delete(log.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 $count 条记录')),
        );
      }

      _exitSelectionMode();
    }
  }

  /// 分享选中的心情记录
  Future<void> _shareSelected() async {
    if (_selectedIds.isEmpty) return;

    final selectedLogs = _logs.where((log) => _selectedIds.contains(log.id)).toList();
    if (selectedLogs.isEmpty) return;

    // 按时间倒序排列
    selectedLogs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final buffer = StringBuffer();
    buffer.writeln('📔 我的心情日记');
    buffer.writeln('═══════════════════');
    buffer.writeln();

    for (final log in selectedLogs) {
      final moodLabel = log.displayLabel;
      final timeStr = '${log.createdAt.year}/${log.createdAt.month}/${log.createdAt.day} ${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';

      buffer.writeln('⏰ $timeStr');
      buffer.writeln('💭 $moodLabel');
      buffer.writeln();
      buffer.writeln(log.note);
      buffer.writeln();
      buffer.writeln('───────────────────');
      buffer.writeln();
    }

    buffer.writeln('═══════════════════');
    buffer.writeln('来自：心情日记 App');
    buffer.writeln();
    buffer.writeln('记录你的每一天，感受内心的变化~');

    await Share.share(buffer.toString());
  }

  String _getTodaySummary(List<MoodLog> logs) {
    final now = DateTime.now();
    final todayLogs = logs
        .where(
          (log) =>
              log.createdAt.year == now.year &&
              log.createdAt.month == now.month &&
              log.createdAt.day == now.day,
        )
        .toList();

    if (todayLogs.isEmpty) return "今天还没有记录心情哦";

    // 统计每个心情的出现次数
    final moodCounts = <String, int>{};
    for (final log in todayLogs) {
      final moodLabel = log.mood.label;
      moodCounts[moodLabel] = (moodCounts[moodLabel] ?? 0) + 1;
    }

    // 按出现顺序构建显示字符串
    final summaryList = moodCounts.entries
        .map(
          (entry) =>
              entry.value > 1 ? '${entry.key}(${entry.value})' : entry.key,
        )
        .join('、');
    return "今天心情：$summaryList (共记录 ${todayLogs.length} 条)";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appBarColor =
        theme.colorScheme.inversePrimary ?? theme.colorScheme.primary;
    final appBarTextColor =
        theme.colorScheme.onPrimaryContainer ?? Colors.white;

    return Column(
      children: [
        // 批量选择模式的 AppBar
        if (_isSelectionMode)
          AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _exitSelectionMode,
            ),
            title: Text('已选择 ${_selectedIds.length} 项'),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.select_all),
                tooltip: '全选',
                onPressed: () {
                  final logs = _currentLogs();
                  if (_selectedIds.length == logs.length) {
                    _deselectAll();
                  } else {
                    _selectAll(logs);
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                tooltip: '删除选中',
                onPressed: _selectedIds.isEmpty ? null : _batchDelete,
              ),
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: '分享选中',
                onPressed: _selectedIds.isEmpty ? null : _shareSelected,
              ),
            ],
          )
        else
          AppBar(
            title: const Text('心情日记'),
            backgroundColor: appBarColor,
            foregroundColor: appBarTextColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: '批量选择',
                onPressed: () {
                  final logs = _currentLogs();
                  if (logs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('暂无记录可选择')),
                    );
                    return;
                  }
                  _enterSelectionMode();
                },
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month),
                tooltip: '查看心情日历',
                onPressed: () {
                  final logs = _currentLogs();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => MoodCalendarPage(logs: logs),
                    ),
                  );
                },
              ),
            ],
          ),
        Expanded(
          child: ValueListenableBuilder<Box<Map<dynamic, dynamic>>>(
            valueListenable: _box.listenable(),
            builder: (context, box, _) {
              final keys = box.keys.toList();
              keys.sort((a, b) {
                final mapA = box.get(a)!;
                final mapB = box.get(b)!;
                final timeA = mapA['createdAt'] as DateTime;
                final timeB = mapB['createdAt'] as DateTime;
                return timeB.compareTo(timeA);
              });

              final logs = keys
                  .map((key) => MoodLog.fromMap(box.get(key)!, key as String))
                  .toList();
              final todaySummary = _getTodaySummary(logs);

              return CustomScrollView(
                slivers: [
                  // 今日概览卡片
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '今日概览',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.fontColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            todaySummary,
                            style: TextStyle(
                              fontSize: 14,
                              color: themeProvider.fontColor.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 空状态
                  if (logs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.sentiment_neutral,
                              size: 72,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '暂无心情记录，快去写一条吧~',
                              style: TextStyle(
                                color: themeProvider.fontColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    // 心情记录列表
                    _isSelectionMode
                        ? _buildSelectionModeList(logs, theme)
                        : _buildNormalModeList(logs, theme),
                    // 底部间距，防止 FAB 遮挡
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        // 批量选择模式的底部删除按钮
        if (_isSelectionMode && _selectedIds.isNotEmpty)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _batchDelete,
                  icon: const Icon(Icons.delete),
                  label: Text('删除选中 (${_selectedIds.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          )
        else if (!_isSelectionMode)
          Padding(
            padding: const EdgeInsets.all(16),
            child: FloatingActionButton.extended(
              onPressed: () => _showAddLogDialog(context),
              icon: const Icon(Icons.edit_note),
              label: const Text('记录心情'),
            ),
          ),
      ],
    );
  }

  /// 构建批量选择模式的列表
  Widget _buildSelectionModeList(List<MoodLog> logs, ThemeData theme) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final log = logs[index];
          final isSelected = _selectedIds.contains(log.id);
          return Column(
            children: [
              ListTile(
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(log.id),
                  activeColor: theme.colorScheme.primary,
                ),
                title: Text(
                  log.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  log.displayLabel,
                  style: TextStyle(color: log.displayColor),
                ),
                trailing: CircleAvatar(
                  backgroundColor: log.displayColor,
                  radius: 16,
                  child: log.customEmoji != null
                      ? Text(log.customEmoji!, style: const TextStyle(fontSize: 14))
                      : Icon(log.mood.icon, size: 18, color: Colors.white),
                ),
                onTap: () => _toggleSelection(log.id),
              ),
              const Divider(height: 1),
            ],
          );
        },
        childCount: logs.length,
      ),
    );
  }

  /// 构建正常模式的列表（滑动删除）
  Widget _buildNormalModeList(List<MoodLog> logs, ThemeData theme) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final log = logs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Dismissible(
              key: ValueKey(log.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerRight,
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                final confirmDelete = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('确认删除'),
                    content: const Text('确认删除这条记录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );

                if (confirmDelete == true) {
                  if (log.imageFileNames != null) {
                    for (final fileName in log.imageFileNames!) {
                      await ImageManager.deleteImage(fileName);
                    }
                  }
                  await _box.delete(log.id);
                }
                return confirmDelete == true;
              },
              child: MoodLogCard(
                key: ValueKey(log.id),
                log: log,
                onView: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (ctx) => MoodDetailPage(log: log, box: _box),
                  ),
                ),
                theme: theme,
              ),
            ),
          );
        },
        childCount: logs.length,
      ),
    );
  }

  void _showAddLogDialog(BuildContext context) async {
    // 直接显示编辑器，图片选择功能已在编辑器内部实现
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        enableDrag: true,
        barrierColor: Colors.black.withValues(alpha: 0.3),
        backgroundColor: Colors.transparent,
        builder: (context) => LogEditorDialog(
          initialLog: null,
          onSave:
              (
                mood,
                note,
                aiEnabled,
                customEmoji,
                customColorValue,
                customEmojiLabel,
                imageFileNames,
              ) =>
                  _addLog(
                mood,
                note,
                aiEnabled,
                imageFileNames: imageFileNames,
                customEmoji: customEmoji,
                customColorValue: customColorValue,
                customEmojiLabel: customEmojiLabel,
              ),
        ),
      );
    }
  }
}
