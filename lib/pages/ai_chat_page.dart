import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/chat_message.dart';
import '../models/ai_assistant.dart';
import '../services/ai_chat_manager.dart';
import '../services/ai_service.dart' hide ChatMessage;
import '../services/knowledge_base_service.dart';
import '../services/tts_service.dart';
import '../services/realtime_voice_service.dart';
import '../services/voice_service.dart';
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

  // 多消息分段发送中
  bool _isStaggering = false;

  // 主动搭话
  Timer? _nudgeTimer;
  bool _hasSentProactiveGreeting = false;
  static const _greetingInterval = Duration(minutes: 30);
  static const _nudgeInterval = Duration(minutes: 3);

  // 语音播放相关
  final AudioPlayer _audioPlayer = AudioPlayer();
  int _playingMessageIndex = -1;

  // 对话记录列表
  List<ConversationInfo> _conversations = [];

  // 选择模式相关状态
  bool _isSelectionMode = false;
  final Set<int> _selectedIndexes = {};

  // 保存监听器引用以便在 dispose 中正确移除
  late final void Function(bool) _loadingListener;
  late final void Function(String) _responseListener;
  late final void Function(Exception) _errorListener;

  @override
  void initState() {
    super.initState();
    _initChatBox();

    // 预加载知识库（仅魔魔胡胡胡萝卜需要，但提前加载避免首次延迟）
    KnowledgeBaseService().load();

    WidgetsBinding.instance.addObserver(this);

    // 保存监听器引用，确保 dispose 时能正确移除
    _loadingListener = (isLoading) {
      if (mounted) {
        setState(() {
          _isLoading = isLoading;
        });
      }
    };
    _responseListener = (response) {
      if (mounted) {
        _handleAIResponse(response);
      }
    };
    _errorListener = (error) {
      if (mounted) {
        _handleAIError(error);
      }
    };

    _chatManager.addLoadingListener(_loadingListener);
    _chatManager.addResponseListener(_responseListener);
    _chatManager.addErrorListener(_errorListener);

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingMessageIndex = -1;
        });
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkProactiveGreeting();
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

  /// 复制选中的消息
  Future<void> _copySelected() async {
    if (_selectedIndexes.isEmpty) return;

    final sortedIndexes = _selectedIndexes.toList()..sort();
    final buffer = StringBuffer();
    for (final i in sortedIndexes) {
      final msg = _messages[i];
      final sender = msg.isUser ? '我' : widget.assistant.name;
      buffer.writeln('$sender：${msg.content}');
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    _exitSelectionMode();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已复制 ${sortedIndexes.length} 条消息')),
      );
    }
  }

  String _formatTimeForShare(DateTime time) {
    return '${time.year}/${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    _cancelNudgeTimer();

    final themeProvider = context.read<ThemeProvider>();
    if (themeProvider.offlineMode) {
      _showSnackBar('当前处于离线模式，无法发送消息');
      return;
    }

    final noEssayMode = themeProvider.noEssayMode;

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

    // 根据防小作文模式选择系统提示词
    String systemPrompt = noEssayMode
        ? widget.assistant.noEssaySystemPrompt
        : widget.assistant.systemPrompt;
    bool enableSearch = false;
    if (widget.assistant.id == 'luobo') {
      enableSearch = true;
      // 注入当前日期，让 AI 能理解"昨天""今天""最近"等时间概念
      final now = DateTime.now();
      final dateStr = '${now.year}年${now.month}月${now.day}日';
      systemPrompt = '$systemPrompt\n\n今天的日期是$dateStr。如果用户问到时间相关问题（如"昨天""今天""最近"），你可以使用搜索功能查找最新信息后再回答。';

      // 繁/简体中文偏好
      if (themeProvider.useTraditionalChinese) {
        systemPrompt = '$systemPrompt\n\n请使用繁体中文（正體中文）回复。';
      } else {
        systemPrompt = '$systemPrompt\n\n请使用简体中文（简体中文）回复。';
      }

      final kbContext = KnowledgeBaseService().search(text);
      if (kbContext != null) {
        systemPrompt = '$systemPrompt\n\n---\n\n$kbContext';
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
        systemPrompt: systemPrompt,
        enableSearch: enableSearch,
        noEssayMode: noEssayMode,
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

  // ── 主动搭话 ──

  void _startNudgeTimer() {
    _cancelNudgeTimer();
    if (!mounted) return;
    final tp = context.read<ThemeProvider>();
    if (!tp.proactiveChatEnabled) return;
    _nudgeTimer = Timer(_nudgeInterval, _sendNudge);
  }

  void _cancelNudgeTimer() {
    _nudgeTimer?.cancel();
    _nudgeTimer = null;
  }

  void _sendNudge() {
    if (!mounted || _isLoading || _isStaggering) return;
    if (widget.assistant.id != 'luobo') return;
    final tp = context.read<ThemeProvider>();
    if (!tp.proactiveChatEnabled) return;

    const nudges = [
      '还在吗？',
      '是不是去忙啦？',
      '哈喽？还在不？',
      '喂～人呢？',
      '还在吗？有什么事随时找我～',
    ];
    final nudge = nudges[Random().nextInt(nudges.length)];
    debugPrint('[萝卜·追问] $nudge');
    _addTextMessage(nudge);
    if (widget.assistant.id == 'luobo') {
      _generateVoiceForResponse(nudge);
    }
    // 再设一个新的 nudge timer
    _startNudgeTimer();
  }

  void _checkProactiveGreeting() {
    if (!mounted) return;
    if (_isLoading || _isStaggering) return;
    if (_hasSentProactiveGreeting) return;
    if (widget.assistant.id != 'luobo') return;
    final tp = context.read<ThemeProvider>();
    if (!tp.proactiveChatEnabled) return;

    // 检查是否已有 AI 回复
    final aiMessages = _messages.where((m) => !m.isUser).toList();
    if (aiMessages.isEmpty) return;

    final lastAiTime = aiMessages.last.timestamp;
    final elapsed = DateTime.now().difference(lastAiTime);
    if (elapsed < _greetingInterval) return;

    _hasSentProactiveGreeting = true;
    debugPrint('[萝卜·主动问候] 距上次互动 ${elapsed.inMinutes} 分钟，发送问候');
    _sendProactiveGreeting();
  }

  Future<void> _sendProactiveGreeting() async {
    final tp = context.read<ThemeProvider>();
    if (tp.offlineMode || tp.apiKey.isEmpty) return;

    _isStaggering = true;
    try {
      final history = <List<String>>[];
      // 取最近 4 条消息作为上下文
      final recent = _messages.length > 4
          ? _messages.sublist(_messages.length - 4)
          : _messages;
      for (final msg in recent) {
        history.add(msg.isUser ? ['0', msg.content] : ['1', msg.content]);
      }

      final noEssayMode = tp.noEssayMode;
      final systemPrompt = noEssayMode
          ? '你是五月天阿信，在微信上和朋友聊天。朋友刚回到聊天界面。'
              '像朋友一样自然地打个招呼，不超过20字。不要说"欢迎回来"。'
          : '你是五月天的主唱阿信。朋友刚回到聊天界面。'
              '像老朋友一样自然地关心一下，不超过30字。'
              '不要说"欢迎回来"，可以根据一天中的时间段问候。'
              '只发一条消息，不要用 [MSG] 分隔。';

      final greeting = await AIService.chat(
        history,
        noEssayMode ? '（刚回来）' : '（朋友刚回到聊天界面，和阿信打个招呼吧）',
        apiKey: tp.apiKey,
        systemPrompt: systemPrompt,
      );

      if (!mounted) return;
      _handleAIResponse(greeting);
    } catch (e) {
      debugPrint('[萝卜·主动问候] 失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isStaggering = false);
      }
    }
  }

  // ── AI 响应处理 ──

  void _handleAIResponse(String response) {
    if (!mounted) return;
    // 检查是否已经添加了这条AI响应（避免重复添加）
    final isAlreadyAdded = _messages.any(
      (msg) =>
          !msg.isUser &&
          msg.content == response &&
          msg.timestamp.isAfter(
            DateTime.now().subtract(const Duration(seconds: 5)),
          ),
    );

    if (isAlreadyAdded) return;

    // 按 [MSG] 拆分为多条消息
    final segments = response
        .split('[MSG]')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (segments.isEmpty) return;

    if (segments.length == 1) {
      // 单条消息：走原有逻辑
      _addTextMessage(segments[0]);
      if (widget.assistant.id == 'luobo') {
        _generateVoiceForResponse(segments[0]);
      }
      _startNudgeTimer();
    } else {
      // 多条消息：追加第一条，其余错开延时
      debugPrint('[萝卜·分段] 收到 ${segments.length} 段消息');
      _addSegmentedMessages(segments);
    }
  }

  /// 添加一条 AI 文本消息（不含语音）
  void _addTextMessage(String text) {
    setState(() {
      _messages.add(
        ChatMessage(
          isUser: false,
          content: text,
          timestamp: DateTime.now(),
        ),
      );
    });
    _saveCurrentConversation();
    _scrollToBottom();
  }

  /// 分段追加消息，带自然延时
  Future<void> _addSegmentedMessages(List<String> segments) async {
    _isStaggering = true;

    // 第一条立即追加
    _addTextMessage(segments[0]);
    if (widget.assistant.id == 'luobo') {
      _generateVoiceForResponse(segments[0]);
    }

    // 后续消息错开 1.5~3 秒
    for (int i = 1; i < segments.length; i++) {
      final delayMs = 1500 + Random().nextInt(1500);
      await Future.delayed(Duration(milliseconds: delayMs));
      if (!mounted) return;

      _addTextMessage(segments[i]);
      if (widget.assistant.id == 'luobo') {
        _generateVoiceForResponse(segments[i]);
      }
    }

    if (mounted) {
      setState(() {
        _isStaggering = false;
        _isLoading = false;
      });
      _startNudgeTimer();
    }
  }

  /// 去掉括号内的表情/动作描述，避免语音读出 "(笑)" 之类的内容
  static final RegExp _bracketExpr = RegExp(r'[（(][^）)]*[）)]');

  String _cleanTextForVoice(String text) {
    return text.replaceAll(_bracketExpr, '').trim();
  }

  Future<void> _generateVoiceForResponse(String text) async {
    final tp = context.read<ThemeProvider>();
    if (!tp.ttsEnabled) {
      debugPrint('[萝卜语音] ttsEnabled=false，跳过语音生成');
      return;
    }
    text = _cleanTextForVoice(text);
    if (text.isEmpty) return;
    if (tp.ttsVoiceId.isEmpty) {
      debugPrint('[萝卜语音] ttsVoiceId 为空，跳过语音生成');
      return;
    }

    // 优先使用实时语音 API（支持唱歌），降级到传统 TTS
    if (tp.realtimeAppId.isNotEmpty && tp.realtimeAccessToken.isNotEmpty) {
      await _generateVoiceWithRealtime(text, tp);
    } else {
      await _generateVoiceWithTts(text, tp);
    }
  }

  Future<void> _generateVoiceWithRealtime(String text, ThemeProvider tp) async {
    debugPrint('[萝卜语音·Realtime] 开始调用实时语音 API，text=${text.length}字');
    final result = await RealtimeVoiceService.synthesize(
      text: text,
      speakerId: tp.ttsVoiceId,
      appId: tp.realtimeAppId,
      accessToken: tp.realtimeAccessToken,
      characterManifest: _buildRealtimeCharacterManifest(),
    );

    if (!result.isSuccess || result.filePath == null) {
      debugPrint('[萝卜语音·Realtime] 失败: ${result.error}');
      return;
    }
    if (!mounted) return;

    debugPrint('[萝卜语音·Realtime] 成功，ttsTypes=${result.ttsTypes}，开始上传');
    final audioUrl = await VoiceService.uploadVoice(result.filePath!);
    if (audioUrl == null) {
      debugPrint('[萝卜语音·Realtime] 上传语音文件失败');
      try { File(result.filePath!).delete(); } catch (_) {}
      return;
    }
    if (!mounted) return;

    final duration = TtsService.estimateDuration(result.filePath!);
    try { File(result.filePath!).delete(); } catch (_) {}

    if (!mounted) return;

    debugPrint('[萝卜语音·Realtime] 语音消息生成成功，audioUrl=$audioUrl, duration=${duration}s');
    setState(() {
      _messages.add(
        ChatMessage(
          isUser: false,
          isAiMessage: true,
          content: '',
          audioUrl: audioUrl,
          audioDuration: duration,
          timestamp: DateTime.now(),
        ),
      );
    });
    _saveCurrentConversation();
    _scrollToBottom();
  }

  String _buildRealtimeCharacterManifest() {
    return '你是五月天的主唱阿信（陈信宏），1975年12月6日出生，台北人。'
        '你说话像写歌词一样有诗意，温暖而真诚，偶尔幽默自嘲。'
        '你相信青春不是年龄而是一种状态，相信梦想值得坚持，友情值得守护。'
        '重要：当你回复中包含歌词时，请自然地唱出来。歌曲部分要有旋律和节奏感。'
        '普通内容用自然、温暖、真诚的语气说话，像老朋友一样。'
        '不要用说教的口吻，只说"我觉得"、"我发现"。';
  }

  /// 根据对话上下文分析情绪，返回 (contextText, baseSpeechRate, basePitch)
  (String, int, int) _analyzeEmotion(String aiResponse) {
    final userMessages = _messages.where((m) => m.isUser).toList();
    final userMsg = userMessages.isNotEmpty ? userMessages.last.content : '';
    final combined = '$userMsg $aiResponse';
    bool match(List<String> ks) => ks.any((k) => combined.contains(k));

    // 安抚/安慰：用户表达负面情绪
    if (match(['难过', '伤心', '哭', '痛苦', '焦虑', '担心', '压力', '累',
        '疲惫', '失眠', '分手', '失去', '失败', '委屈', '害怕', '无助', '烦躁',
        '郁闷', '低落', '崩溃', '难受', '绝望', '孤独', '迷茫'])) {
      return ('用温柔、安慰的语气说话，语速稍慢', -4, -2);
    }

    // 开心/兴奋
    if (match(['太棒了', '开心', '恭喜', '好消息', '哈哈', '庆祝', '成功', '赢了',
        '厉害', '太好了', '快乐', '幸福', '激动', '惊喜', '优秀', '完美', '赞',
        '牛', '绝了'])) {
      return ('用开心、活泼的语气说话', 12, 4);
    }

    // 鼓励/打气
    if (match(['加油', '你可以', '相信', '坚持', '努力', '勇敢', '试试', '别放弃',
        '一定', '能行', '支持', '前进', '站起来', '不怕', '没事的'])) {
      return ('用鼓励、充满力量的语气说话', 6, 3);
    }

    // 好奇/探讨
    if (match(['为什么', '怎么', '你觉得', '想知道', '好奇', '了解', '聊聊',
        '说说', '问问', '请教', '探讨', '思考'])) {
      return ('用好奇、轻松的语气说话', 3, 1);
    }

    // 平静/沉思
    if (match(['安静', '放松', '冥想', '平静', '慢慢', '安心', '放下', '深呼吸',
        '休息', '晚安', '早点睡'])) {
      return ('用平静、舒缓的语气说话，语速稍慢', -2, -1);
    }

    // 默认：温暖略带开心
    return ('用温暖、略带开心的语气说话', 5, 2);
  }

  Future<void> _generateVoiceWithTts(String text, ThemeProvider tp) async {
    final apiKey = tp.ttsApiKey.isNotEmpty ? tp.ttsApiKey : tp.apiKey;
    if (apiKey.isEmpty) {
      debugPrint('[萝卜语音] apiKey 为空，跳过语音生成');
      return;
    }

    final ttsText = text.replaceAll(RegExp(r'\[歌词\][\s\S]*?\[/歌词\]'), '');
    if (ttsText.trim().isEmpty) {
      debugPrint('[萝卜语音] 全文为歌词，跳过 TTS');
      return;
    }

    debugPrint('[萝卜语音·TTS] 开始调用 TTS API，text=${ttsText.length}字 speakerId=${tp.ttsVoiceId}');
    debugPrint('[萝卜语音·TTS] apiKey 长度=${apiKey.length} 前8位=${apiKey.substring(0, apiKey.length > 8 ? 8 : apiKey.length)}...');

    String? contextText;
    int speechRate = 0;
    int pitch = 0;
    if (tp.voiceEmotionEnabled) {
      final (ct, sr, p) = _analyzeEmotion(ttsText);
      contextText = ct;
      speechRate = sr + Random().nextInt(4);
      pitch = p + Random().nextInt(3);
      debugPrint('[萝卜语音·TTS] 情绪分析: $contextText speechRate=$speechRate pitch=$pitch');
    } else {
      debugPrint('[萝卜语音·TTS] 语音情绪已关闭，使用默认语气');
    }

    final audioPath = await TtsService.textToSpeech(
      text: ttsText,
      speakerId: tp.ttsVoiceId,
      apiKey: apiKey,
      contextText: contextText,
      speechRate: speechRate,
      pitch: pitch,
    );

    if (audioPath == null) {
      debugPrint('[萝卜语音·TTS] API 返回 null');
      return;
    }
    if (!mounted) return;

    debugPrint('[萝卜语音·TTS] 成功，开始上传');
    final audioUrl = await VoiceService.uploadVoice(audioPath);
    if (audioUrl == null) {
      debugPrint('[萝卜语音·TTS] 上传语音文件失败');
      try { File(audioPath).delete(); } catch (_) {}
      return;
    }
    if (!mounted) {
      try { File(audioPath).delete(); } catch (_) {}
      return;
    }

    final duration = TtsService.estimateDuration(audioPath);
    try { File(audioPath).delete(); } catch (_) {}
    if (!mounted) return;

    debugPrint('[萝卜语音·TTS] 完成，duration=${duration}s');
    setState(() {
      _messages.add(
        ChatMessage(
          isUser: false,
          isAiMessage: true,
          content: '',
          audioUrl: audioUrl,
          audioDuration: duration,
          timestamp: DateTime.now(),
        ),
      );
    });
    _saveCurrentConversation();
    _scrollToBottom();
  }

  Future<void> _toggleVoicePlayback(int index) async {
    final message = _messages[index];
    if (message.audioUrl == null) return;

    if (_playingMessageIndex == index) {
      await _audioPlayer.stop();
      setState(() {
        _playingMessageIndex = -1;
      });
    } else {
      if (_playingMessageIndex >= 0) {
        await _audioPlayer.stop();
      }
      try {
        debugPrint('[萝卜语音] 开始播放 url=${message.audioUrl}');
        await _audioPlayer.play(UrlSource(message.audioUrl!));
        setState(() {
          _playingMessageIndex = index;
        });
      } catch (e) {
        debugPrint('[萝卜语音] 播放失败: $e');
      }
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

    // 移除监听器（使用保存的引用）
    _chatManager.removeLoadingListener(_loadingListener);
    _chatManager.removeResponseListener(_responseListener);
    _chatManager.removeErrorListener(_errorListener);

    // 取消当前AI请求（如果不希望用户切换页面时取消，可以注释掉这一行）
    // _chatManager.cancelCurrentRequest();

    _cancelNudgeTimer();
    _audioPlayer.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _chatBox.close();
    super.dispose();
  }

  Widget _buildKebabMenu(ThemeData theme) {
    return IconButton(
      icon: Icon(Icons.more_vert, color: theme.colorScheme.onPrimaryContainer),
      tooltip: '更多设置',
      onPressed: () => _showChatSettings(),
    );
  }

  void _showChatSettings() {
    final tp = context.read<ThemeProvider>();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('语音消息'),
                    subtitle: const Text('萝卜用语音回复每条消息'),
                    value: tp.ttsEnabled,
                    onChanged: (v) {
                      setDialogState(() {});
                      tp.setTtsEnabled(v);
                    },
                  ),
                  if (widget.assistant.id == 'luobo') ...[
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('语音情绪'),
                      subtitle: const Text('根据语境自动调整语气'),
                      value: tp.voiceEmotionEnabled,
                      onChanged: (v) {
                        setDialogState(() {});
                        tp.setVoiceEmotionEnabled(v);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('主动搭话'),
                      subtitle: const Text('长时间未回复时主动问候'),
                      value: tp.proactiveChatEnabled,
                      onChanged: (v) {
                        setDialogState(() {});
                        tp.setProactiveChatEnabled(v);
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('防小作文模式'),
                    subtitle: const Text('限制 AI 回复长度，更像微信聊天'),
                    value: tp.noEssayMode,
                    onChanged: (v) {
                      setDialogState(() {});
                      tp.setNoEssayMode(v);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
                  icon: const Icon(Icons.copy),
                  tooltip: '复制选中',
                  onPressed: _selectedIndexes.isEmpty ? null : _copySelected,
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
                      final hasAvatar = widget.assistant.avatarAssetPath != null;
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: followSystem
                            ? theme.colorScheme.primary
                            : theme.brightness == Brightness.dark
                            ? assistantColor.withValues(alpha: 0.7)
                            : assistantColor,
                        backgroundImage: hasAvatar
                            ? AssetImage(widget.assistant.avatarAssetPath!)
                            : null,
                        child: hasAvatar
                            ? null
                            : Text(widget.assistant.emoji, style: const TextStyle(fontSize: 16)),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.assistant.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: theme.colorScheme.inversePrimary,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              actions: [
                if (widget.assistant.id == 'luobo')
                  Selector<ThemeProvider, bool>(
                    selector: (_, tp) => tp.useTraditionalChinese,
                    builder: (context, useTraditional, child) {
                      return IconButton(
                        icon: Text(
                          useTraditional ? '繁' : '簡',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        tooltip: useTraditional ? '切换为简体中文' : '切换为繁体中文',
                        onPressed: () {
                          context.read<ThemeProvider>().toggleTraditionalChinese();
                        },
                      );
                    },
                  ),
                _buildKebabMenu(theme),
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
                    onVoiceTap: message.isVoiceMessage
                        ? () => _toggleVoicePlayback(index)
                        : null,
                    isVoicePlaying: _playingMessageIndex == index,
                    userBubbleColor: tp.$2,
                    otherBubbleColor: tp.$3,
                    aiName: widget.assistant.name,
                    aiEmoji: widget.assistant.emoji,
                    aiAvatarAssetPath: widget.assistant.avatarAssetPath,
                  ),
                );
              },
            ),
            ),
          ),

          // 加载指示器
          if (_isLoading || _isStaggering)
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
