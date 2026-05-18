import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/chat_message.dart';
import '../models/ai_assistant.dart';
import '../services/ai_chat_manager.dart';
import '../providers/theme_provider.dart';
import '../widgets/chat_message_bubble.dart';

const String _conversationsKey = 'conversations';
const String _currentConversationKey = 'current_conversation';

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
    return [
      id,
      preview,
      createdAt.toIso8601String(),
      updatedAt.toIso8601String(),
      messageCount,
    ];
  }
}

class AIChatPage extends StatefulWidget {
  final AIAssistant assistant;

  const AIChatPage({super.key, this.assistant = AIAssistant.xiaoNuan});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> with WidgetsBindingObserver {
  late Box<List<dynamic>> _chatBox;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final AIChatManager _chatManager = AIChatManager();

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

    WidgetsBinding.instance.addObserver(this);

    // 监听AIChatManager的状态变化
    _chatManager.addLoadingListener((isLoading) {
      if (mounted) {
        setState(() {
          _isLoading = isLoading;
        });
      }
    });

    _chatManager.addResponseListener((response) {
      if (mounted) {
        _handleAIResponse(response);
      }
    });

    _chatManager.addErrorListener((error) {
      if (mounted) {
        _handleAIError(error);
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = View.of(context).viewInsets.bottom;
    if (bottomInset > 0) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _scrollToBottom();
      });
    }
  }

  Future<void> _initChatBox() async {
    _chatBox = await Hive.openBox<List<dynamic>>(widget.assistant.chatBoxName);
    _loadMessages();
  }

  void _loadMessages() {
    // 加载对话记录列表
    final convStored = _chatBox.get(
      _conversationsKey,
      defaultValue: <dynamic>[],
    );
    _conversations = (convStored as List<dynamic>)
        .map((e) => ConversationInfo.fromList(e as List))
        .toList();

    // 加载当前对话
    final stored = _chatBox.get(
      _currentConversationKey,
      defaultValue: <dynamic>[],
    );
    _messages = (stored as List<dynamic>)
        .map((e) => ChatMessage.fromList(e as List))
        .toList();

    // 如果没有历史消息，添加欢迎语
    if (_messages.isEmpty) {
      _messages.add(
        ChatMessage(
          isUser: false,
          content: widget.assistant.welcomeMessage,
          timestamp: DateTime.now(),
        ),
      );
      _saveCurrentConversation();
    }
    setState(() {});
  }

  Future<void> _saveCurrentConversation() async {
    await _chatBox.put(
      _currentConversationKey,
      _messages.map((e) => e.toList()).toList(),
    );
  }

  Future<void> _saveConversationList() async {
    await _chatBox.put(
      _conversationsKey,
      _conversations.map((e) => e.toList()).toList(),
    );
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
      final sortedIndexes = _selectedIndexes.toList()
        ..sort((a, b) => b.compareTo(a));

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
        _messages.add(
          ChatMessage(
            isUser: false,
            content: widget.assistant.welcomeMessage,
            timestamp: DateTime.now(),
          ),
        );
      }

      await _saveCurrentConversation();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已删除 $count 条消息')));
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
    buffer.writeln('${widget.assistant.emoji} ${widget.assistant.name}对话分享');
    buffer.writeln('═══════════════════');
    buffer.writeln();

    for (final msg in selectedMessages) {
      final sender = msg.isUser ? '我' : widget.assistant.name;
      final timeStr = _formatTimeForShare(msg.timestamp);
      buffer.writeln('[$timeStr] $sender：');
      buffer.writeln(msg.content);
      buffer.writeln();
    }

    buffer.writeln('═══════════════════');
    buffer.writeln('来自：心情日记·${widget.assistant.name}对话');
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
      _messages.add(
        ChatMessage(isUser: true, content: text, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });

    _controller.clear();
    _scrollToBottom();

    // 构建历史消息
    final history = <List<String>>[];
    for (final msg in _messages) {
      if (!msg.isUser) {
        history.add(['1', msg.content]); // 1 表示 AI 助手
      } else {
        history.add(['0', msg.content]); // 0 表示用户
      }
    }

    // 使用AIChatManager发送消息 - 即使页面切换，请求也不会被取消
    // 响应和错误将由监听器处理，这样即使页面切换再返回，也能收到结果
    try {
      await _chatManager.sendMessage(
        history,
        text,
        offlineMode: themeProvider.offlineMode,
        apiKey: themeProvider.apiKey,
        systemPrompt: widget.assistant.systemPrompt,
      );
      // 注意：加载状态、响应和错误现在由监听器处理
    } catch (e) {
      // 这里捕获的异常通常是立即发生的错误（如参数错误）
      if (mounted) {
        _showSnackBar('发送失败，请稍后重试');
      }
    }
  }

  BoxDecoration? _chatBgDecoration(String? chatBgPath) {
    if (chatBgPath == null || !File(chatBgPath).existsSync()) return null;
    return BoxDecoration(
      image: DecorationImage(
        image: FileImage(File(chatBgPath)),
        fit: BoxFit.cover,
        opacity: 0.15,
      ),
    );
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleAIResponse(String response) {
    // 检查是否已经添加了这条AI响应（避免重复添加）
    final isAlreadyAdded = _messages.any(
      (msg) =>
          !msg.isUser &&
          msg.content == response &&
          msg.timestamp.isAfter(
            DateTime.now().subtract(const Duration(seconds: 5)),
          ),
    );

    if (!isAlreadyAdded) {
      setState(() {
        _messages.add(
          ChatMessage(
            isUser: false,
            content: response,
            timestamp: DateTime.now(),
          ),
        );
      });
      _saveCurrentConversation();
      _scrollToBottom();
    }
  }

  void _handleAIError(Exception error) {
    // 如果用户取消了请求，不显示错误消息
    if (error.toString().contains('请求被取消') ||
        error.toString().contains('用户取消了请求')) {
      return;
    }

    _showSnackBar('发送失败，请稍后重试');
  }

  /// 开启新对话（保存当前对话到历史）
  Future<void> _startNewConversation() async {
    // 获取对话预览（第一条用户消息或AI欢迎语的前20字）
    String preview = '新对话';
    for (final msg in _messages) {
      if (msg.isUser) {
        preview = msg.content.length > 20
            ? '${msg.content.substring(0, 20)}...'
            : msg.content;
        break;
      }
    }

    // 保存当前对话到历史记录
    final conversation = ConversationInfo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      preview: preview,
      createdAt: _messages.isNotEmpty
          ? _messages.first.timestamp
          : DateTime.now(),
      updatedAt: DateTime.now(),
      messageCount: _messages.length,
    );
    _conversations.insert(0, conversation);
    await _saveConversationList();

    // 保存当前对话内容
    await _chatBox.put(
      'conversation_${conversation.id}',
      _messages.map((e) => e.toList()).toList(),
    );

    // 清空并开启新对话
    setState(() {
      _messages = [
        ChatMessage(
          isUser: false,
          content: widget.assistant.welcomeMessage,
          timestamp: DateTime.now(),
        ),
      ];
    });
    await _saveCurrentConversation();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('对话已保存，开启新对话')));
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
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[300],
                          ),
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
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(
                            conv.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${_formatDate(conv.createdAt)} · ${conv.messageCount} 条消息',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
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
    final stored = _chatBox.get(
      'conversation_${conv.id}',
      defaultValue: <dynamic>[],
    );
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
    messenger.showSnackBar(const SnackBar(content: Text('已加载对话')));
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
      messenger.showSnackBar(const SnackBar(content: Text('对话已删除')));
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '今天 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // 移除监听器
    _chatManager.removeLoadingListener((_) {});
    _chatManager.removeResponseListener((_) {});
    _chatManager.removeErrorListener((_) {});

    // 取消当前AI请求（如果不希望用户切换页面时取消，可以注释掉这一行）
    // _chatManager.cancelCurrentRequest();

    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _chatBox.close();
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
                  Selector<ThemeProvider, bool>(
                    selector: (_, tp) => tp.followSystem,
                    builder: (context, followSystem, child) {
                      final assistantColor = widget.assistant.color;
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: followSystem
                            ? theme.colorScheme.primary
                            : theme.brightness == Brightness.dark
                            ? assistantColor.withValues(alpha: 0.7)
                            : assistantColor,
                        child: Text(widget.assistant.emoji, style: const TextStyle(fontSize: 16)),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Text(widget.assistant.name),
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
      body: Selector<ThemeProvider, (String?, Color?, Color?)>(
        selector: (_, tp) =>
            (tp.chatBgPath, tp.userBubbleColor, tp.otherBubbleColor),
        builder: (context, tp, child) {
          return Column(
        children: [
          // 聊天消息列表
          Expanded(
            child: Container(
              decoration: _chatBgDecoration(tp.$1),
              child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isSelected = _selectedIndexes.contains(index);
                return RepaintBoundary(
                  child: ChatMessageBubble(
                    message: message,
                    theme: theme,
                    index: index,
                    isSelectionMode: _isSelectionMode,
                    isSelected: isSelected,
                    onLongPress: () => _enterSelectionMode(index),
                    onTap: _isSelectionMode
                        ? () => _toggleSelection(index)
                        : null,
                    userBubbleColor: tp.$2,
                    otherBubbleColor: tp.$3,
                    aiName: widget.assistant.name,
                    aiEmoji: widget.assistant.emoji,
                  ),
                );
              },
            ),
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
                    '${widget.assistant.name}正在思考...',
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
                        hintText: '和${widget.assistant.name}说点什么...',
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
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      final hasContent = value.text.trim().isNotEmpty;
                      return FloatingActionButton(
                        onPressed: (_isLoading || !hasContent)
                            ? null
                            : _sendMessage,
                        mini: true,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: hasContent ? 0.9 : 0.3,
                        ),
                        foregroundColor: Colors.white,
                        child: Icon(
                          Icons.send,
                          color: (_isLoading || !hasContent)
                              ? theme.disabledColor.withValues(alpha: 0.5)
                              : Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      );
    },
  ),
    );
  }
}
