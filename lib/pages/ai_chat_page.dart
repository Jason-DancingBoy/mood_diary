import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/ai_service.dart';
import '../providers/theme_provider.dart';

const String _chatBoxName = 'ai_chat_history';
const String _conversationsKey = 'conversations';
const String _currentConversationKey = 'current_conversation';

const String _welcomeMessage = '''
你好呀，我是小暖 🌻

很高兴能和你相遇在这里。

无论你此刻心情如何，是开心、焦虑、迷茫还是平静，我都在这里陪伴着你。

有时候，把心里的话说出口，就是疗愈的开始。

今天，有什么想和我聊聊的吗？我会用心倾听每一句话。
''';

/// 对话记录信息类
class ConversationInfo {
  final String id;
  final String preview;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int messageCount;

  ConversationInfo({
    required this.id,
    required this.preview,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
  });

  factory ConversationInfo.fromList(List list) {
    return ConversationInfo(
      id: list[0] as String,
      preview: list[1] as String,
      createdAt: DateTime.parse(list[2] as String),
      updatedAt: DateTime.parse(list[3] as String),
      messageCount: list[4] as int,
    );
  }

  List<dynamic> toList() {
    return [id, preview, createdAt.toIso8601String(), updatedAt.toIso8601String(), messageCount];
  }
}

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  late Box<List<dynamic>> _chatBox;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;

  // 对话记录列表
  List<ConversationInfo> _conversations = [];

  // 选择模式相关状态
  bool _isSelectionMode = false;
  final Set<int> _selectedIndexes = {};

  @override
  void initState() {
    super.initState();
    _initChatBox();
  }

  Future<void> _initChatBox() async {
    _chatBox = await Hive.openBox<List<dynamic>>(_chatBoxName);
    _loadMessages();
  }

  void _loadMessages() {
    // 加载对话记录列表
    final convStored = _chatBox.get(_conversationsKey, defaultValue: <dynamic>[]);
    _conversations = (convStored as List<dynamic>)
        .map((e) => ConversationInfo.fromList(e as List))
        .toList();

    // 加载当前对话
    final stored = _chatBox.get(_currentConversationKey, defaultValue: <dynamic>[]);
    _messages = (stored as List<dynamic>)
        .map((e) => ChatMessage.fromList(e as List))
        .toList();

    // 如果没有历史消息，添加欢迎语
    if (_messages.isEmpty) {
      _messages.add(ChatMessage(
        isUser: false,
        content: _welcomeMessage,
        timestamp: DateTime.now(),
      ));
      _saveCurrentConversation();
    }
    setState(() {});
  }

  Future<void> _saveCurrentConversation() async {
    await _chatBox.put(_currentConversationKey, _messages.map((e) => e.toList()).toList());
  }

  Future<void> _saveConversationList() async {
    await _chatBox.put(_conversationsKey, _conversations.map((e) => e.toList()).toList());
  }

  /// 进入选择模式
  void _enterSelectionMode(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedIndexes.add(index);
    });
  }

  /// 退出选择模式
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndexes.clear();
    });
  }

  /// 切换选中状态
  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
        if (_selectedIndexes.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIndexes.add(index);
      }
    });
  }

  /// 全选
  void _selectAll() {
    setState(() {
      _selectedIndexes.addAll(List.generate(_messages.length, (i) => i));
    });
  }

  /// 取消全选
  void _deselectAll() {
    setState(() {
      _selectedIndexes.clear();
    });
  }

  /// 删除选中消息
  Future<void> _deleteSelected() async {
    if (_selectedIndexes.isEmpty) return;

    final count = _selectedIndexes.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 $count 条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 按索引从大到小排序，确保删除时不影响其他索引
      final sortedIndexes = _selectedIndexes.toList()..sort((a, b) => b.compareTo(a));

      setState(() {
        for (final index in sortedIndexes) {
          if (index >= 0 && index < _messages.length) {
            _messages.removeAt(index);
          }
        }
        _selectedIndexes.clear();
        _isSelectionMode = false;
      });

      // 如果删除后为空，重新添加欢迎语
      if (_messages.isEmpty) {
        _messages.add(ChatMessage(
          isUser: false,
          content: _welcomeMessage,
          timestamp: DateTime.now(),
        ));
      }

      await _saveCurrentConversation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除 $count 条消息')),
        );
      }
    }
  }

  /// 分享选中的消息
  Future<void> _shareSelected() async {
    if (_selectedIndexes.isEmpty) return;

    // 按时间顺序整理选中的消息
    final sortedIndexes = _selectedIndexes.toList()..sort();
    final selectedMessages = sortedIndexes.map((i) => _messages[i]).toList();

    // 构建分享文本
    final buffer = StringBuffer();
    buffer.writeln('🌻 小暖心理咨询对话分享');
    buffer.writeln('═══════════════════');
    buffer.writeln();

    for (final msg in selectedMessages) {
      final sender = msg.isUser ? '我' : '小暖';
      final timeStr = _formatTimeForShare(msg.timestamp);
      buffer.writeln('[$timeStr] $sender：');
      buffer.writeln(msg.content);
      buffer.writeln();
    }

    buffer.writeln('═══════════════════');
    buffer.writeln('来自：心情日记·小暖对话');
    buffer.writeln();
    buffer.writeln('想和我聊聊吗？打开心情日记 App，一起探索内心~');

    await Share.share(buffer.toString());
  }

  String _formatTimeForShare(DateTime time) {
    return '${time.year}/${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    final themeProvider = context.read<ThemeProvider>();
    if (themeProvider.offlineMode) {
      _showSnackBar('当前处于离线模式，无法发送消息');
      return;
    }

    // 添加用户消息
    setState(() {
      _messages.add(ChatMessage(
        isUser: true,
        content: text,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    // 构建历史消息
    final history = <List<String>>[];
    for (final msg in _messages) {
      if (!msg.isUser) {
        history.add([AIService.roleAssistant.toString(), msg.content]);
      } else {
        history.add([AIService.roleUser.toString(), msg.content]);
      }
    }

    // 调用 AI
    try {
      final response = await AIService.chat(history, text);
      setState(() {
        _messages.add(ChatMessage(
          isUser: false,
          content: response,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      await _saveCurrentConversation();
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('发送失败，请稍后重试');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// 开启新对话（保存当前对话到历史）
  Future<void> _startNewConversation() async {
    // 获取对话预览（第一条用户消息或AI欢迎语的前20字）
    String preview = '新对话';
    for (final msg in _messages) {
      if (msg.isUser) {
        preview = msg.content.length > 20 ? '${msg.content.substring(0, 20)}...' : msg.content;
        break;
      }
    }

    // 保存当前对话到历史记录
    final conversation = ConversationInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      preview: preview,
      createdAt: _messages.isNotEmpty ? _messages.first.timestamp : DateTime.now(),
      updatedAt: DateTime.now(),
      messageCount: _messages.length,
    );
    _conversations.insert(0, conversation);
    await _saveConversationList();

    // 保存当前对话内容
    await _chatBox.put('conversation_${conversation.id}', _messages.map((e) => e.toList()).toList());

    // 清空并开启新对话
    setState(() {
      _messages = [
        ChatMessage(
          isUser: false,
          content: _welcomeMessage,
          timestamp: DateTime.now(),
        ),
      ];
    });
    await _saveCurrentConversation();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('对话已保存，开启新对话')),
      );
    }
  }

  /// 显示对话历史记录
  void _showConversationHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  const Text(
                    '对话记录',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_conversations.length} 条记录',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 对话列表
            Expanded(
              child: _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            '暂无对话记录',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: _conversations.length,
                      itemBuilder: (context, index) {
                        final conv = _conversations[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            conv.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_formatDate(conv.createdAt)} · ${conv.messageCount} 条消息',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _deleteConversation(ctx, index),
                          ),
                          onTap: () => _loadConversation(ctx, index),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 加载历史对话
  Future<void> _loadConversation(BuildContext context, int index) async {
    final conv = _conversations[index];
    final stored = _chatBox.get('conversation_${conv.id}', defaultValue: <dynamic>[]);
    final messages = (stored as List<dynamic>)
        .map((e) => ChatMessage.fromList(e as List))
        .toList();

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _messages = messages;
    });
    await _saveCurrentConversation();

    if (!context.mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('已加载对话')),
    );
  }

  /// 删除历史对话
  Future<void> _deleteConversation(BuildContext context, int index) async {
    final conv = _conversations[index];
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除对话'),
        content: const Text('确定要删除这条对话记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _chatBox.delete('conversation_${conv.id}');
      _conversations.removeAt(index);
      await _saveConversationList();
      setState(() {});
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('对话已删除')),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text('已选择 ${_selectedIndexes.length} 项'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedIndexes.length == _messages.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: '全选',
                  onPressed: () {
                    if (_selectedIndexes.length == _messages.length) {
                      _deselectAll();
                    } else {
                      _selectAll();
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: '删除选中',
                  onPressed: _selectedIndexes.isEmpty ? null : _deleteSelected,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: '分享选中',
                  onPressed: _selectedIndexes.isEmpty ? null : _shareSelected,
                ),
              ],
            )
          : AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.orange,
                    child: Text('🌻', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  const Text('小暖'),
                ],
              ),
              backgroundColor: theme.colorScheme.inversePrimary,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: '对话记录',
                  onPressed: _showConversationHistory,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: '开启新对话',
                  onPressed: _startNewConversation,
                ),
              ],
            ),
      body: Column(
        children: [
          // 聊天消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isSelected = _selectedIndexes.contains(index);
                return _MessageBubble(
                  message: message,
                  theme: theme,
                  index: index,
                  isSelectionMode: _isSelectionMode,
                  isSelected: isSelected,
                  onLongPress: () => _enterSelectionMode(index),
                  onTap: _isSelectionMode ? () => _toggleSelection(index) : null,
                );
              },
            ),
          ),

          // 加载指示器
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '小暖正在思考...',
                    style: TextStyle(color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),

          // 选择模式底部删除按钮
          if (_isSelectionMode && _selectedIndexes.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete),
                    label: Text('删除选中 (${_selectedIndexes.length})'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            )
          // 输入区域
          else if (!_isSelectionMode)
            Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: '和小暖说点什么...',
                        hintStyle: TextStyle(color: theme.colorScheme.outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    mini: true,
                    child: Icon(
                      Icons.send,
                      color: _isLoading ? theme.disabledColor : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 聊天消息类
class ChatMessage {
  final bool isUser;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.isUser,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromList(List list) {
    return ChatMessage(
      isUser: list[0] as bool,
      content: list[1] as String,
      timestamp: DateTime.parse(list[2] as String),
    );
  }

  List<dynamic> toList() {
    return [isUser, content, timestamp.toIso8601String()];
  }
}

/// 消息气泡组件
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ThemeData theme;
  final int index;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  const _MessageBubble({
    required this.message,
    required this.theme,
    required this.index,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      // 用户消息 - 右侧
      return GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap?.call(),
                activeColor: theme.colorScheme.primary,
              ),
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomRight: const Radius.circular(4),
                  ),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.content,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // AI 消息 - 左侧
      return GestureDetector(
        onLongPress: onLongPress,
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode)
              Checkbox(
                value: isSelected,
                onChanged: (_) => onTap?.call(),
                activeColor: theme.colorScheme.primary,
              ),
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomLeft: const Radius.circular(4),
                  ),
                  border: isSelected
                      ? Border.all(color: theme.colorScheme.primary, width: 2)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🌻', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          '小暖',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.content,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
