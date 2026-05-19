import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
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
  Timer? _pollTimer;
  Map<String, dynamic>? _friendMood;
  String? _pendingImagePath;
  String? _pendingImageName;

  String get _cacheKey => 'chat_${widget.friend.userId}';

  @override
  void initState() {
    super.initState();
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

  Future<void> _initChatBox() async {
    _chatBox = await Hive.openBox<List<dynamic>>(_friendChatBoxName);
    _loadFromCache();
    _loadFromServer();
    _startPolling();
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _pollNewMessages();
    });
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
        setState(() {
          _messages.add(ChatMessage(
            isUser: true,
            content: text,
            imageUrl: imageUrl,
            timestamp: DateTime.now(),
          ));
          _isSending = false;
        });
        _saveToCache();
        _scrollToBottom();
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
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

    return Scaffold(
      appBar: AppBar(
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
              child: Text(
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
                        return RepaintBoundary(
                          child: ChatMessageBubble(
                            message: _messages[index],
                            theme: theme,
                            index: index,
                            isSelectionMode: false,
                            isSelected: false,
                            onLongPress: () {},
                            onImageTap: (url) => _showFullScreenImage(url),
                            showSenderHeader: false,
                            userBubbleColor: tp.$2,
                            otherBubbleColor: tp.$3,
                          ),
                        );
                      },
                    ),
            ),
          ),

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
                      (_isSending || _isUploading) ? null : _pickImage,
                  tooltip: '发送图片',
                ),
                const SizedBox(width: 4),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, value, child) {
                    final hasContent = value.text.trim().isNotEmpty ||
                        _pendingImagePath != null;
                    return FloatingActionButton(
                      onPressed: (_isSending || _isUploading || !hasContent)
                          ? null
                          : _sendMessage,
                      mini: true,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: hasContent ? 0.9 : 0.3,
                      ),
                      foregroundColor: Colors.white,
                      child: Icon(
                        Icons.send,
                        color: (_isSending || _isUploading)
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
