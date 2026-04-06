import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../enums/message_frequency.dart';
import '../enums/message_log_range.dart';
import '../models/mood_log.dart';
import '../providers/theme_provider.dart';
import '../services/message_service.dart';
import '../services/message_scheduler.dart';

const String _moodLogBox = 'mood_logs_box';
const String _messageBoxName = 'mail_messages_box';
const String _messageCountKey = 'daily_message_count';
const String _messageLastSentAtKey = 'daily_message_last_sent';

/// 邮件消息模型
class MailMessage {
  final String id;
  final String subject;
  final String content;
  final DateTime receivedAt;
  final bool isRead;

  MailMessage({
    required this.id,
    required this.subject,
    required this.content,
    required this.receivedAt,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'subject': subject,
        'content': content,
        'receivedAt': receivedAt.toIso8601String(),
        'isRead': isRead,
      };

  factory MailMessage.fromMap(Map<dynamic, dynamic> map) {
    return MailMessage(
      id: map['id'] as String,
      subject: map['subject'] as String,
      content: map['content'] as String,
      receivedAt: DateTime.parse(map['receivedAt'] as String),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  MailMessage copyWith({bool? isRead}) {
    return MailMessage(
      id: id,
      subject: subject,
      content: content,
      receivedAt: receivedAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  late Box<Map<dynamic, dynamic>> _logBox;
  late Box<Map<dynamic, dynamic>> _mailBox;
  List<MailMessage> _messages = [];
  bool _isLoading = true;
  int _unreadCount = 0;
  bool _isSelectionMode = false;
  final Set<String> _selectedMessages = {};

  @override
  void initState() {
    super.initState();
    _ensureBoxesOpen();
  }

  Future<void> _ensureBoxesOpen() async {
    if (!Hive.isBoxOpen(_moodLogBox)) {
      _logBox = await Hive.openBox<Map<dynamic, dynamic>>(_moodLogBox);
    } else {
      _logBox = Hive.box<Map<dynamic, dynamic>>(_moodLogBox);
    }

    if (!Hive.isBoxOpen(_messageBoxName)) {
      _mailBox = await Hive.openBox<Map<dynamic, dynamic>>(_messageBoxName);
    } else {
      _mailBox = Hive.box<Map<dynamic, dynamic>>(_messageBoxName);
    }

    await _loadMessages();
    await _checkAndGenerateMessage();
  }

  Future<void> _loadMessages() async {
    final List<MailMessage> messages = [];
    for (final key in _mailBox.keys) {
      // 跳过元数据键
      if (key == _messageLastSentAtKey || key == _messageCountKey) continue;
      final map = _mailBox.get(key);
      if (map != null) {
        try {
          messages.add(MailMessage.fromMap(map));
        } catch (e) {
          // 忽略格式错误的条目
        }
      }
    }
    // 按时间倒序排列
    messages.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

    setState(() {
      _messages = messages;
      _unreadCount = messages.where((m) => !m.isRead).length;
      _isLoading = false;
    });
  }

  Future<void> _checkAndGenerateMessage() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final frequency = themeProvider.messageFrequency;

    if (frequency == MessageFrequency.never) return;

    final lastSentAtStr = _mailBox.get(_messageLastSentAtKey)?['value'] as String?;
    final lastSentAt = lastSentAtStr != null ? DateTime.parse(lastSentAtStr) : null;
    final countToday = (_mailBox.get(_messageCountKey)?['value'] as int?) ?? 0;
    final now = DateTime.now();

    bool shouldGenerate = false;

    if (frequency == MessageFrequency.hourly) {
      // 一小时一次：检查间隔是否至少1小时
      final diff = now.difference(lastSentAt ?? DateTime.fromMillisecondsSinceEpoch(0)).inHours;
      shouldGenerate = diff >= 1;
    } else if (frequency == MessageFrequency.twiceDaily) {
      if (_sameDay(now, lastSentAt)) {
        shouldGenerate = countToday < 2;
      } else {
        shouldGenerate = true;
      }
    } else if (frequency == MessageFrequency.onceDaily) {
      shouldGenerate = !_sameDay(now, lastSentAt);
    } else if (frequency == MessageFrequency.everyTwoDays) {
      final diff = now.difference(lastSentAt ?? DateTime.fromMillisecondsSinceEpoch(0)).inDays;
      shouldGenerate = diff >= 2;
    } else if (frequency == MessageFrequency.everyThreeDays) {
      final diff = now.difference(lastSentAt ?? DateTime.fromMillisecondsSinceEpoch(0)).inDays;
      shouldGenerate = diff >= 3;
    }

    if (shouldGenerate) {
      final logRange = themeProvider.messageLogRange;
      await _generateAndSaveMessage(now, logRange);
    }
  }

  Future<void> _generateAndSaveMessage(DateTime now, MessageLogRange range) async {
    final logs = _loadRecentLogs();
    final content = MessageService.generateDailyMessage(logs, range);

    if (content.isEmpty) return;

    // 生成邮件主题
    String subject = '来自小暖的问候';
    if (content.contains('提醒') || content.contains('注意')) {
      subject = '一条温暖的提醒';
    } else if (content.contains('鼓励') || content.contains('加油')) {
      subject = '给你的鼓励信';
    } else if (content.contains('感谢') || content.contains('记录')) {
      subject = '感谢你的记录';
    }

    final mail = MailMessage(
      id: now.millisecondsSinceEpoch.toString(),
      subject: subject,
      content: content,
      receivedAt: now,
      isRead: false,
    );

    await _mailBox.put(mail.id, mail.toMap());
    await _mailBox.put(_messageLastSentAtKey, {'value': now.toIso8601String()});

    final countToday = (_mailBox.get(_messageCountKey)?['value'] as int?) ?? 0;
    final lastSentAt = _mailBox.get(_messageLastSentAtKey)?['value'] as String?;
    if (lastSentAt != null && _sameDay(now, DateTime.parse(lastSentAt))) {
      await _mailBox.put(_messageCountKey, {'value': countToday + 1});
    } else {
      await _mailBox.put(_messageCountKey, {'value': 1});
    }

    await _loadMessages();
  }

  List<MoodLog> _loadRecentLogs() {
    final keys = _logBox.keys.toList();
    keys.sort((a, b) {
      final mapA = _logBox.get(a)!;
      final mapB = _logBox.get(b)!;
      final timeA = mapA['createdAt'] as DateTime;
      final timeB = mapB['createdAt'] as DateTime;
      return timeB.compareTo(timeA);
    });

    return keys
        .map((key) => MoodLog.fromMap(_logBox.get(key)!, key as String))
        .toList();
  }

  bool _sameDay(DateTime a, DateTime? b) {
    if (b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _markAsRead(String messageId) async {
    final map = _mailBox.get(messageId);
    if (map != null) {
      final mail = MailMessage.fromMap(map);
      if (!mail.isRead) {
        await _mailBox.put(messageId, mail.copyWith(isRead: true).toMap());
        await _loadMessages();
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedMessages.clear();
      }
    });
  }

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessages.contains(messageId)) {
        _selectedMessages.remove(messageId);
      } else {
        _selectedMessages.add(messageId);
      }
      if (_selectedMessages.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedMessages.length == _messages.length) {
        _selectedMessages.clear();
      } else {
        _selectedMessages.addAll(_messages.map((m) => m.id));
      }
    });
  }

  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessages.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedMessages.length} 封邮件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      for (final id in _selectedMessages) {
        await _mailBox.delete(id);
      }
      setState(() {
        _selectedMessages.clear();
        _isSelectionMode = false;
      });
      await _loadMessages();
    }
  }

  void _showMessageDetail(BuildContext context, MailMessage mail) async {
    await _markAsRead(mail.id);

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _MailDetailPage(mail: mail),
      ),
    );
  }

  void _showFrequencyPicker(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择小暖消息频率', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              ...MessageFrequency.values.map((frequency) {
                final selected = themeProvider.messageFrequency == frequency;
                return ListTile(
                  title: Text(frequency.label),
                  trailing: selected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () async {
                    await themeProvider.setMessageFrequency(frequency);
                    MessageScheduler.updateFrequency(frequency);
                    await MessageScheduler.triggerCheck(frequency);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('已选择 ${_selectedMessages.length} 项')
            : Row(
                children: [
                  const Icon(Icons.mail_outline, size: 24),
                  const SizedBox(width: 8),
                  const Text('收件箱'),
                  if (_unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
        backgroundColor: theme.colorScheme.inversePrimary,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: Icon(
                _selectedMessages.length == _messages.length
                    ? Icons.deselect
                    : Icons.select_all,
              ),
              tooltip: '全选',
              onPressed: _toggleSelectAll,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: '删除',
              onPressed: _selectedMessages.isEmpty ? null : _deleteSelectedMessages,
            ),
          ] else ...[
            Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) => IconButton(
                icon: const Icon(Icons.settings),
                tooltip: '设置',
                onPressed: () => _showFrequencyPicker(context, themeProvider),
              ),
            ),
          ],
        ],
      ),
      body: ValueListenableBuilder<Box<Map<dynamic, dynamic>>>(
        valueListenable: _mailBox.listenable(),
        builder: (context, box, _) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 80,
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '收件箱为空',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '小暖会根据你的心情记录\n给你发送温暖的邮件',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final mail = _messages[index];
              return _MailListItem(
                mail: mail,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedMessages.contains(mail.id),
                onTap: () {
                  if (_isSelectionMode) {
                    _toggleMessageSelection(mail.id);
                  } else {
                    _showMessageDetail(context, mail);
                  }
                },
                onLongPress: () {
                  if (!_isSelectionMode) {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedMessages.add(mail.id);
                    });
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// 邮件列表项组件
class _MailListItem extends StatelessWidget {
  final MailMessage mail;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const _MailListItem({
    required this.mail,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          color: mail.isRead
              ? null
              : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 选择框
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
                activeColor: theme.colorScheme.primary,
              )
            else if (!mail.isRead)
              Container(
                margin: const EdgeInsets.only(right: 4),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            // 发件人头像
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('🌻', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 12),
            // 邮件内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mail.subject,
                          style: TextStyle(
                            fontWeight: mail.isRead ? FontWeight.normal : FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(mail.receivedAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '发件人：小暖 🌻',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    mail.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: mail.isRead
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 邮件详情页面
class _MailDetailPage extends StatelessWidget {
  final MailMessage mail;

  const _MailDetailPage({required this.mail});

  String _formatDateTime(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日 '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('邮件'),
        backgroundColor: theme.colorScheme.inversePrimary,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 邮件头部
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 发件人信息
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Center(
                          child: Text('🌻', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '小暖',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'xiaonuan@mooddiary.app',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 收件人
                  Row(
                    children: [
                      Text(
                        '收件人：',
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '我',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 主题
            Text(
              mail.subject,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // 时间
            Text(
              _formatDateTime(mail.receivedAt),
              style: TextStyle(
                color: theme.colorScheme.outline,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            // 正文
            Text(
              mail.content,
              style: TextStyle(
                fontSize: 16,
                height: 1.8,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            // 签名
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🌻 小暖',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '你的专属心情陪伴',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
