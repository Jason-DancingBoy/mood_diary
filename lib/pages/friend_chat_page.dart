import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../enums/mood_type.dart';
import '../models/chat_message.dart';
import '../models/friend.dart';
import '../providers/theme_provider.dart';
import '../services/friend_chat_service.dart';
import '../services/image_manager.dart';
import '../services/image_upload_service.dart';
import '../services/remote_mood_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/ai_service.dart' hide ChatMessage;
import '../services/tts_service.dart';
import '../services/voice_service.dart';
import '../utils/time_utils.dart';
import '../widgets/chat_message_bubble.dart';
import 'full_screen_image_view.dart';

const String _friendChatBoxName = 'friend_chat';

class FriendChatPage extends StatefulWidget {
  final Friend friend;

  const FriendChatPage({super.key, required this.friend});

  @override
  State<FriendChatPage> createState() => _FriendChatPageState();
}

class _FriendChatPageState extends State<FriendChatPage>
    with WidgetsBindingObserver {
  late Box<List<dynamic>> _chatBox;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  bool _isUploading = false;
  Map<String, dynamic>? _friendMood;
  String? _pendingImagePath;
  String? _pendingImageName;

  // 语音录制
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  // 语音播放（全局只有一个，避免多个同时播）
  static final _audioPlayer = AudioPlayer();
  String? _playingAudioUrl;

  // 魔魔胡胡胡萝卜介入
  DateTime? _lastInterventionTime;

  // 多选模式
  bool _isSelectionMode = false;
  final Set<int> _selectedIndexes = {};

  String get _cacheKey => 'chat_${widget.friend.userId}';

  @override
  void initState() {
    super.initState();
    NotificationService.activeChatFriendId = widget.friend.userId;
    _clearUnread();
    RemoteMoodService.friendMoodsNotifier.addListener(_onFriendMoodChanged);
    _initChatBox();
    _loadFriendMood();

    WidgetsBinding.instance.addObserver(this);
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

  void _clearUnread() {
    FriendChatService.clearUnreadFor(widget.friend.userId);
    FriendChatService.updateLastSeen(widget.friend.userId);
  }

  void _onFriendMoodChanged() {
    final mood =
        RemoteMoodService.friendMoodsNotifier.value[widget.friend.userId];
    if (mood != null && mounted) {
      setState(() => _friendMood = mood);
    }
  }

  Future<void> _loadFriendMood() async {
    final mood = await RemoteMoodService.getFriendLatestMood(widget.friend.userId);
    if (mounted) setState(() => _friendMood = mood);
    await RemoteMoodService.addFriendToRealtime(widget.friend.userId);
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('相册'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: source, imageQuality: 85);
    if (xFile == null) return;

    try {
      final fileName = await ImageManager.saveImageToFile(xFile);
      setState(() {
        _pendingImagePath = ImageManager.getImagePath(fileName);
        _pendingImageName = fileName;
      });
    } catch (e) {
      if (mounted) _showSnackBar('图片选择失败');
    }
  }

  // ---- 语音录制 ----

  Future<void> _startRecording() async {
    final hasPermission = await VoiceService.hasPermission();
    if (!hasPermission) {
      if (mounted) _showSnackBar('需要麦克风权限才能发送语音');
      return;
    }

    try {
      final path = await VoiceService.startRecording();
      if (path == null) {
        if (mounted) _showSnackBar('无法获取麦克风权限');
        return;
      }
      setState(() {
        _isRecording = true;
        _recordSeconds = 0;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordSeconds++);
          if (_recordSeconds >= 60) _stopAndSendRecording();
        }
      });
    } catch (e) {
      if (mounted) _showSnackBar('麦克风启动失败：$e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;

    _recordTimer?.cancel();
    setState(() => _isRecording = false);

    final (filePath, duration) = await VoiceService.stopRecording();
    if (filePath == null || duration == 0) return;

    final themeProvider = context.read<ThemeProvider>();
    if (themeProvider.offlineMode) {
      _showSnackBar('当前处于离线模式，无法发送消息');
      return;
    }

    setState(() => _isSending = true);

    try {
      final audioUrl = await VoiceService.uploadVoice(filePath);
      // 删除本地临时文件
      try {
        await File(filePath).delete();
      } catch (_) {}

      if (audioUrl == null) {
        if (mounted) {
          setState(() => _isSending = false);
          _showSnackBar('语音上传失败');
        }
        return;
      }

      await FriendChatService.sendMessage(
        widget.friend.userId,
        '',
        audioUrl: audioUrl,
        audioDuration: duration,
      );
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            isUser: true,
            content: '',
            audioUrl: audioUrl,
            audioDuration: duration,
            timestamp: DateTime.now(),
          ));
          _isSending = false;
        });
        _saveToCache();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _showSnackBar('发送失败');
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    setState(() => _isRecording = false);
    await VoiceService.cancelRecording();
  }

  // ---- 语音播放 ----

  void _togglePlayVoice(String audioUrl) async {
    if (_playingAudioUrl == audioUrl) {
      _audioPlayer.pause();
      setState(() => _playingAudioUrl = null);
    } else {
      _audioPlayer.stop();
      try {
        debugPrint('[语音播放] 开始播放 url=$audioUrl');
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() => _playingAudioUrl = audioUrl);
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _playingAudioUrl = null);
        });
      } catch (e) {
        debugPrint('[语音播放] 失败: $e');
      }
    }
  }

  Future<void> _initChatBox() async {
    _chatBox = await Hive.openBox<List<dynamic>>(_friendChatBoxName);
    _loadFromCache();
    if (_messages.isEmpty) {
      _loadFromServer();
    } else {
      _pollNewMessages();
    }
    // Realtime WebSocket 订阅新消息（替代 5 秒轮询）
    _subscribeToRealtime();
  }

  void _subscribeToRealtime() {
    FriendChatService.subscribeToMessages(
      widget.friend.userId,
      _onRealtimeMessage,
    );
  }

  void _onRealtimeMessage(ChatMessage msg) {
    if (!mounted) return;
    // 去重：已有相同 ID 的消息则跳过
    if (msg.id != null && _messages.any((m) => m.id == msg.id)) return;
    // 自己发的消息本地已添加，跳过（realtime 会收到服务器回显）
    if (msg.isUser && _messages.any((m) =>
        m.isUser &&
        m.content == msg.content &&
        m.timestamp.difference(msg.timestamp).inSeconds.abs() < 10)) {
      return;
    }
    // AI 消息去重：本地添加后 realtime 会回显同一条消息
    if (msg.isAiMessage && _messages.any((m) =>
        m.isAiMessage &&
        m.content == msg.content &&
        m.timestamp.difference(msg.timestamp).inSeconds.abs() < 10)) {
      return;
    }

    setState(() {
      _messages.add(msg);
    });
    _saveToCache();
    _scrollToBottom();
    _checkAndTriggerIntervention([msg]);
  }

  void _loadFromCache() {
    final stored = _chatBox.get(_cacheKey, defaultValue: <dynamic>[]);
    final cached = (stored as List<dynamic>)
        .map((e) => ChatMessage.fromList(e as List))
        .toList();
    if (cached.isNotEmpty) {
      setState(() {
        _messages = cached;
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadFromServer() async {
    setState(() => _isLoading = true);
    try {
      final serverMessages = await FriendChatService.getMessages(
        widget.friend.userId,
      );
      if (mounted) {
        setState(() {
          _messages = serverMessages;
          _isLoading = false;
        });
        _saveToCache();
        _scrollToBottom();
        // 初始加载时也检测介入（取最新的几条消息）
        final latest = serverMessages.isNotEmpty
            ? [serverMessages.last]
            : <ChatMessage>[];
        if (latest.isNotEmpty) {
          _checkAndTriggerIntervention(latest);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkAndTriggerIntervention(List<ChatMessage> newMessages) async {
    final themeProvider = context.read<ThemeProvider>();
    if (!themeProvider.luoBoInterventionEnabled) return;

    // 冷却时间：至少间隔 30 秒
    if (_lastInterventionTime != null &&
        DateTime.now().difference(_lastInterventionTime!).inSeconds < 30) {
      return;
    }

    // 检查新消息是否包含五月天关键词
    String? triggerContent;
    for (final msg in newMessages) {
      if (msg.content.isNotEmpty && AIService.containsMaydayKeywords(msg.content)) {
        triggerContent = msg.content;
        break;
      }
    }
    if (triggerContent == null) return;

    _lastInterventionTime = DateTime.now();

    // 构建上下文：最近几条消息
    final contextMessages = <String>[];
    final recentMessages = _messages.length > 5
        ? _messages.sublist(_messages.length - 5)
        : _messages;
    for (final msg in recentMessages) {
      if (msg.content.isNotEmpty) {
        final prefix = msg.isUser ? '我' : (msg.senderName ?? '好友');
        contextMessages.add('$prefix：${msg.content}');
      }
    }

    final intervention = await AIService.interveneInFriendChat(
      contextMessages: contextMessages,
      triggerMessage: triggerContent,
      apiKey: themeProvider.apiKey,
    );

    if (intervention != null && intervention.isNotEmpty && mounted) {
      // 发送魔魔胡胡胡萝卜介入消息给好友（标记为 AI 消息）
      try {
        await FriendChatService.sendMessage(
          widget.friend.userId,
          intervention,
          isAiMessage: true,
        );
      } catch (_) {
        // 发送失败不影响本地添加
      }

      setState(() {
        _messages.add(ChatMessage(
          isUser: false,
          content: intervention,
          senderName: '魔魔胡胡胡萝卜',
          showSenderHeader: true,
          senderAvatarAssetPath: 'assets/carrot.jpg',
          isAiMessage: true,
          timestamp: DateTime.now(),
        ));
      });
      _saveToCache();
      _scrollToBottom();

      // 生成萝卜语音消息
      if (themeProvider.ttsEnabled && themeProvider.ttsVoiceId.isNotEmpty) {
        _generateVoiceForIntervention(intervention, themeProvider);
      }
    }
  }

  Future<void> _generateVoiceForIntervention(
      String text, ThemeProvider tp) async {
    if (!tp.ttsEnabled) {
      debugPrint('[介入语音] ttsEnabled=false，跳过');
      return;
    }
    if (tp.ttsVoiceId.isEmpty) {
      debugPrint('[介入语音] ttsVoiceId 为空，跳过');
      return;
    }

    final apiKey = tp.ttsApiKey.isNotEmpty ? tp.ttsApiKey : tp.apiKey;
    if (apiKey.isEmpty) {
      debugPrint('[介入语音] apiKey 为空，跳过');
      return;
    }

    final cleanedText = AIService.stripLeadingActions(text);
    debugPrint('[介入语音] 开始 TTS，text=${cleanedText.length}字, speakerId=${tp.ttsVoiceId}');
    final audioPath = await TtsService.textToSpeech(
      text: cleanedText,
      speakerId: tp.ttsVoiceId,
      apiKey: apiKey,
    );

    if (audioPath == null) {
      debugPrint('[介入语音] TTS API 返回 null');
      return;
    }
    if (!mounted) return;

    debugPrint('[介入语音] TTS 成功，audioPath=$audioPath，开始上传');
    final audioUrl = await VoiceService.uploadVoice(audioPath);
    if (audioUrl == null) {
      debugPrint('[介入语音] 上传语音文件失败');
      try {
        File(audioPath).delete();
      } catch (_) {}
      return;
    }
    if (!mounted) {
      try {
        File(audioPath).delete();
      } catch (_) {}
      return;
    }

    final duration = TtsService.estimateDuration(audioPath);
    try {
      File(audioPath).delete();
    } catch (_) {}

    if (!mounted) return;

    debugPrint('[介入语音] 语音消息生成成功，audioUrl=$audioUrl, duration=${duration}s');
    setState(() {
      _messages.add(ChatMessage(
        isUser: false,
        isAiMessage: true,
        content: '',
        audioUrl: audioUrl,
        audioDuration: duration,
        senderName: '魔魔胡胡胡萝卜',
        senderAvatarAssetPath: 'assets/carrot.jpg',
        timestamp: DateTime.now(),
      ));
    });
    _saveToCache();
    _scrollToBottom();
  }

  Future<void> _pollNewMessages() async {
    if (_messages.isEmpty) return;
    final lastTimestamp = _messages.last.timestamp;
    try {
      final newMessages = await FriendChatService.getNewMessages(
        widget.friend.userId,
        lastTimestamp,
      );
      if (newMessages.isNotEmpty && mounted) {
        setState(() {
          _messages.addAll(newMessages);
        });
        _saveToCache();
        _scrollToBottom();
        _checkAndTriggerIntervention(newMessages);
      }
    } catch (_) {
      // Silently ignore polling errors
    }
  }

  Future<void> _saveToCache() async {
    await _chatBox.put(
      _cacheKey,
      _messages.map((e) => e.toList()).toList(),
    );
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingImagePath == null) return;
    if (_isSending || _isUploading) return;

    final themeProvider = context.read<ThemeProvider>();
    if (themeProvider.offlineMode) {
      _showSnackBar('当前处于离线模式，无法发送消息');
      return;
    }

    String? imageUrl;
    if (_pendingImagePath != null) {
      setState(() => _isUploading = true);
      try {
        imageUrl = await ImageUploadService.uploadImage(_pendingImageName!);
      } catch (e) {
        if (mounted) {
          setState(() => _isUploading = false);
          _showSnackBar('图片上传失败');
        }
        return;
      }
    }

    setState(() {
      _isSending = true;
      _isUploading = false;
    });
    _controller.clear();

    final pendingName = _pendingImageName;
    setState(() {
      _pendingImagePath = null;
      _pendingImageName = null;
    });

    try {
      await FriendChatService.sendMessage(widget.friend.userId, text,
          imageUrl: imageUrl);
      if (mounted) {
        final sentMsg = ChatMessage(
          isUser: true,
          content: text,
          imageUrl: imageUrl,
          timestamp: DateTime.now(),
        );
        setState(() {
          _messages.add(sentMsg);
          _isSending = false;
        });
        _saveToCache();
        _scrollToBottom();
        _checkAndTriggerIntervention([sentMsg]);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _pendingImagePath = ImageManager.getImagePath(pendingName);
          _pendingImageName = pendingName;
        });
        _showSnackBar('发送失败: $e');
      }
    }
  }

  Widget? _buildMoodBanner(ThemeData theme) {
    if (_friendMood == null) return null;

    final moodTypeStr = _friendMood!['mood_type'] as String?;
    if (moodTypeStr == null) return null;

    final moodType = MoodType.values.cast<MoodType?>().firstWhere(
          (e) => e!.name == moodTypeStr,
          orElse: () => null,
        );
    if (moodType == null) return null;

    final createdAtStr = _friendMood!['created_at'] as String?;
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: moodType.bgColor,
      child: Row(
        children: [
          Icon(moodType.icon, size: 16, color: moodType.color),
          const SizedBox(width: 6),
          Text(
            createdAt != null
                ? '${widget.friend.nickname}的心情: ${moodType.label} · ${timeAgo(createdAt)}'
                : '${widget.friend.nickname}的心情: ${moodType.label}',
            style: TextStyle(fontSize: 13, color: moodType.color),
          ),
        ],
      ),
    );
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImageView(
          imagePath: '',
          imageUrls: [imageUrl],
        ),
      ),
    );
  }

  void _showMessageMenu(BuildContext context, ChatMessage message,
      LongPressStartDetails details, int index) {
    final items = <PopupMenuEntry<String>>[];

    if (message.content.isNotEmpty) {
      items.add(const PopupMenuItem(
        value: 'copy',
        child: ListTile(
          leading: Icon(Icons.copy),
          title: Text('复制'),
          dense: true,
        ),
      ));
    }
    if (message.isUser && message.content.isNotEmpty) {
      items.add(const PopupMenuItem(
        value: 'edit',
        child: ListTile(
          leading: Icon(Icons.edit),
          title: Text('编辑'),
          dense: true,
        ),
      ));
    }
    if (message.isUser) {
      items.add(const PopupMenuItem(
        value: 'delete',
        child: ListTile(
          leading: Icon(Icons.delete, color: Colors.red),
          title: Text('删除', style: TextStyle(color: Colors.red)),
          dense: true,
        ),
      ));
    }
    items.add(const PopupMenuDivider());
    items.add(const PopupMenuItem(
      value: 'multi_select',
      child: ListTile(
        leading: Icon(Icons.checklist),
        title: Text('多选'),
        dense: true,
      ),
    ));

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx + 1,
        details.globalPosition.dy + 1,
      ),
      items: items,
    ).then((value) {
      if (value == null || !mounted) return;
      switch (value) {
        case 'copy':
          Clipboard.setData(ClipboardData(text: message.content));
          _showSnackBar('已复制');
        case 'edit':
          _showEditDialog(message, index);
        case 'delete':
          _showDeleteConfirmDialog(message, index);
        case 'multi_select':
          _enterSelectionMode(index);
      }
    });
  }

  void _showEditDialog(ChatMessage message, int index) {
    final controller = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑消息'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '输入新内容...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newContent = controller.text.trim();
              if (newContent.isEmpty) return;
              Navigator.pop(ctx);
              await _editMessage(message, newContent, index);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(ChatMessage message, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteMessage(message, index);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(
      ChatMessage message, String newContent, int index) async {
    if (message.id != null) {
      try {
        await FriendChatService.updateMessage(message.id!, newContent);
      } catch (_) {
        if (mounted) _showSnackBar('编辑失败');
        return;
      }
    }
    setState(() {
      _messages[index] = ChatMessage(
        isUser: message.isUser,
        id: message.id,
        content: newContent,
        imageUrl: message.imageUrl,
        audioUrl: message.audioUrl,
        audioDuration: message.audioDuration,
        timestamp: message.timestamp,
        senderName: message.senderName,
      );
    });
    _saveToCache();
  }

  /// 从 Supabase Storage 中删除文件
  Future<void> _deleteStorageFile(String url) async {
    try {
      final uri = Uri.parse(url);
      // URL 格式: /storage/v1/object/public/mood_images/{path}
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('mood_images');
      if (bucketIndex != -1 && bucketIndex + 1 < segments.length) {
        final storagePath = segments.sublist(bucketIndex + 1).join('/');
        await SupabaseService.storage.remove([storagePath]);
      }
    } catch (_) {}
  }

  Future<void> _deleteMessage(ChatMessage message, int index) async {
    // 删除关联的 Storage 文件（图片、语音）
    if (message.imageUrl != null) {
      await _deleteStorageFile(message.imageUrl!);
    }
    if (message.audioUrl != null) {
      await _deleteStorageFile(message.audioUrl!);
    }

    if (message.id != null) {
      try {
        await FriendChatService.deleteMessage(message.id!);
      } catch (_) {
        if (mounted) _showSnackBar('删除失败');
        return;
      }
    }

    setState(() {
      _messages.removeAt(index);
    });
    _saveToCache();

    // 如果消息没有服务器 ID，删除本地副本后，检查并移除对应的服务器同步副本
    if (message.id == null) {
      _removeDuplicateServerCopy(message);
    }
  }

  /// 如果本地无 ID 消息被删除，同时移除服务器同步回来的重复副本
  void _removeDuplicateServerCopy(ChatMessage deletedMsg) {
    final toRemove = <int>[];
    for (int i = 0; i < _messages.length; i++) {
      final msg = _messages[i];
      if (msg.id != null &&
          msg.isUser == deletedMsg.isUser &&
          msg.content == deletedMsg.content &&
          msg.timestamp.difference(deletedMsg.timestamp).inSeconds.abs() < 10) {
        toRemove.add(i);
      }
    }
    if (toRemove.isNotEmpty) {
      setState(() {
        for (final i in toRemove.reversed) {
          _messages.removeAt(i);
        }
      });
      _saveToCache();
    }
  }

  // ---- 多选模式 ----

  void _enterSelectionMode(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedIndexes.add(index);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIndexes.clear();
    });
  }

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

  void _selectAll() {
    setState(() {
      _selectedIndexes.addAll(List.generate(_messages.length, (i) => i));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIndexes.clear();
    });
  }

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

    if (confirm != true) return;

    // 按索引从大到小排序，确保删除时不影响其他索引
    final sortedIndexes = _selectedIndexes.toList()
      ..sort((a, b) => b.compareTo(a));

    // 先尝试从服务器删除所有有 ID 的消息
    for (final index in sortedIndexes) {
      if (index >= 0 && index < _messages.length) {
        final msg = _messages[index];
        if (msg.id != null) {
          try {
            await FriendChatService.deleteMessage(msg.id!);
          } catch (_) {}
        }
      }
    }

    setState(() {
      for (final index in sortedIndexes) {
        if (index >= 0 && index < _messages.length) {
          _messages.removeAt(index);
        }
      }
      _selectedIndexes.clear();
      _isSelectionMode = false;
    });

    _saveToCache();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已删除 $count 条消息')),
      );
    }
  }

  @override
  void dispose() {
    if (NotificationService.activeChatFriendId == widget.friend.userId) {
      NotificationService.activeChatFriendId = null;
    }
    WidgetsBinding.instance.removeObserver(this);
    FriendChatService.unsubscribe();
    _recordTimer?.cancel();
    _audioPlayer.dispose();
    VoiceService.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _chatBox.close();
    RemoteMoodService.friendMoodsNotifier.removeListener(_onFriendMoodChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 录音状态栏覆盖整个输入区
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
                  onPressed:
                      _selectedIndexes.isEmpty ? null : _deleteSelected,
                ),
              ],
            )
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: widget.friend.avatarUrl != null
                        ? CachedNetworkImageProvider(widget.friend.avatarUrl!)
                        : null,
                    child: widget.friend.avatarUrl != null
                        ? null
                        : Text(
                            widget.friend.nickname.isNotEmpty
                                ? widget.friend.nickname[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(widget.friend.nickname),
                ],
              ),
              backgroundColor: theme.colorScheme.inversePrimary,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
            ),
      body: Selector<ThemeProvider, (String?, Color?, Color?)>(
        selector: (_, tp) =>
            (tp.chatBgPath, tp.userBubbleColor, tp.otherBubbleColor),
        builder: (context, tp, child) {
          return Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(color: theme.colorScheme.primary),
          _buildMoodBanner(theme) ?? const SizedBox.shrink(),

          Expanded(
            child: Container(
              decoration: _chatBgDecoration(tp.$1),
              child: _messages.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('暂无消息，开始和 ${widget.friend.nickname} 聊天吧',
                              style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isSelected = _selectedIndexes.contains(index);
                        return RepaintBoundary(
                          child: ChatMessageBubble(
                            message: msg,
                            theme: theme,
                            index: index,
                            isSelectionMode: _isSelectionMode,
                            isSelected: isSelected,
                            onLongPress: _isSelectionMode
                                ? () => _toggleSelection(index)
                                : () {},
                            onLongPressStart: _isSelectionMode
                                ? null
                                : (details) =>
                                    _showMessageMenu(context, msg, details, index),
                            onTap: _isSelectionMode
                                ? () => _toggleSelection(index)
                                : null,
                            onImageTap: (url) => _showFullScreenImage(url),
                            onVoiceTap:
                                msg.audioUrl != null
                                    ? () => _togglePlayVoice(msg.audioUrl!)
                                    : null,
                            isVoicePlaying:
                                msg.audioUrl != null &&
                                _playingAudioUrl == msg.audioUrl,
                            showSenderHeader: false,
                            userBubbleColor: tp.$2,
                            otherBubbleColor: tp.$3,
                          ),
                        );
                      },
                    ),
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
          // 非选择模式显示输入区域
          else if (!_isSelectionMode) ...[
            // 图片预览
            if (_pendingImagePath != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                color: theme.scaffoldBackgroundColor,
                child: Row(
                  children: [
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_pendingImagePath!),
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _pendingImagePath = null;
                              _pendingImageName = null;
                            }),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    if (_isUploading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),

            // 语音录制中指示条
            if (_isRecording)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: Colors.red.withValues(alpha: 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PulsingDot(),
                    const SizedBox(width: 10),
                    Text(
                      '正在录音 ${_recordSeconds}s',
                      style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _cancelRecording,
                      child: const Text('取消', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _stopAndSendRecording,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('发送', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),

            // 输入区域
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
                        hintText: '和 ${widget.friend.nickname} 说点什么...',
                        hintStyle:
                            TextStyle(color: theme.colorScheme.outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.image_outlined,
                        color: theme.colorScheme.primary),
                    onPressed:
                        (_isSending || _isUploading || _isRecording) ? null : _pickImage,
                    tooltip: '发送图片',
                  ),
                  const SizedBox(width: 2),
                  // 语音按钮
                  GestureDetector(
                    onTap: _isRecording ? _stopAndSendRecording : _startRecording,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isRecording
                            ? Colors.red.withValues(alpha: 0.1)
                            : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: _isRecording ? Colors.red : theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, child) {
                      final hasContent = value.text.trim().isNotEmpty ||
                          _pendingImagePath != null;
                      return FloatingActionButton(
                        onPressed: (_isSending || _isUploading || _isRecording || !hasContent)
                            ? null
                            : _sendMessage,
                        mini: true,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: hasContent ? 0.9 : 0.3,
                        ),
                        foregroundColor: Colors.white,
                        child: Icon(
                          Icons.send,
                          color: (_isSending || _isUploading || _isRecording)
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
        ],
      );
    },
  ),
    );
  }
}

/// 录音时闪烁的红点
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
