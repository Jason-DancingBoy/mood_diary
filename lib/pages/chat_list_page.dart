import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ai_assistant.dart';
import '../providers/friend_provider.dart';
import '../providers/theme_provider.dart';
import '../enums/mood_type.dart';
import '../services/friend_chat_service.dart';
import '../services/remote_mood_service.dart';
import '../utils/time_utils.dart';
import 'ai_chat_page.dart';
import 'friend_chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  @override
  void initState() {
    super.initState();
    FriendChatService.unreadFriendIds.addListener(_onUnreadChanged);
    RemoteMoodService.friendMoodsNotifier.addListener(_onMoodsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  void _onUnreadChanged() {
    if (mounted) setState(() {});
  }

  Widget _buildFriendTrailing(String friendUserId) {
    final hasUnread =
        FriendChatService.unreadFriendIds.value.contains(friendUserId);
    if (!hasUnread) return const Icon(Icons.chevron_right);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right),
      ],
    );
  }

  void _onMoodsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initData() async {
    FriendChatService.restoreUnreadState();
    await context.read<FriendProvider>().loadFriends();
    if (!mounted) return;
    await _ensureRealtime();
    await _checkOfflineMessages();
  }

  Future<void> _checkOfflineMessages() async {
    final friends = context.read<FriendProvider>().friends;
    final friendIds = friends.map((f) => f.userId).toList();
    final offlineUnread =
        await FriendChatService.checkOfflineMessages(friendIds);
    if (!mounted) return;
    await FriendChatService.mergeUnread(offlineUnread);
  }

  Future<void> _ensureRealtime() async {
    final friends = context.read<FriendProvider>().friends;
    final userIds = friends.map((f) => f.userId).toList();
    await RemoteMoodService.ensureFriendMoodRealtime(userIds);
  }

  Color _getCorrectColor(bool followSystem, Color fontColor, ThemeData theme) {
    if (followSystem) {
      return theme.colorScheme.onSurface;
    }
    return fontColor;
  }

  void _showBubbleColorPicker(
      BuildContext context, ThemeProvider themeProvider, bool isUser) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUser ? '选择我的气泡颜色' : '选择对方气泡颜色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _bubbleColorOption(context, themeProvider, isUser, Colors.blue, '蓝色'),
            _bubbleColorOption(context, themeProvider, isUser, Colors.green, '绿色'),
            _bubbleColorOption(context, themeProvider, isUser, Colors.orange, '橙色'),
            _bubbleColorOption(context, themeProvider, isUser, Colors.purple, '紫色'),
            _bubbleColorOption(context, themeProvider, isUser, Colors.teal, '青色'),
            _bubbleColorOption(context, themeProvider, isUser, Colors.pink, '粉色'),
            ListTile(
              leading: const Icon(Icons.restore, color: Colors.grey),
              title: const Text('恢复默认', style: TextStyle(color: Colors.grey)),
              onTap: () {
                if (isUser) {
                  themeProvider.setUserBubbleColor(null);
                } else {
                  themeProvider.setOtherBubbleColor(null);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Widget _bubbleColorOption(BuildContext context, ThemeProvider themeProvider,
      bool isUser, Color color, String label) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, radius: 12),
      title: Text(label),
      onTap: () {
        if (isUser) {
          themeProvider.setUserBubbleColor(color);
        } else {
          themeProvider.setOtherBubbleColor(color);
        }
        Navigator.of(context).pop();
      },
    );
  }

  Widget? _buildMoodSubtitle(String friendUserId) {
    final moodData = RemoteMoodService.friendMoodsNotifier.value[friendUserId];
    if (moodData == null) return null;

    final moodTypeStr = moodData['mood_type'] as String?;
    if (moodTypeStr == null) return null;

    final moodType = MoodType.values.cast<MoodType?>().firstWhere(
          (e) => e!.name == moodTypeStr,
          orElse: () => null,
        );
    if (moodType == null) return null;

    final createdAtStr = moodData['created_at'] as String?;
    final createdAt = createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: moodType.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            createdAt != null
                ? '${moodType.label} · ${timeAgo(createdAt)}'
                : moodType.label,
            style: TextStyle(fontSize: 12, color: moodType.color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    FriendChatService.unreadFriendIds.removeListener(_onUnreadChanged);
    RemoteMoodService.friendMoodsNotifier.removeListener(_onMoodsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('对话'),
        backgroundColor:
            theme.colorScheme.inversePrimary ?? theme.colorScheme.primary,
        foregroundColor:
            theme.colorScheme.onPrimaryContainer ?? Colors.white,
        actions: [
          Selector<ThemeProvider, (Color?, Color?, bool)>(
            selector: (_, tp) => (tp.userBubbleColor, tp.otherBubbleColor, tp.luoBoInterventionEnabled),
            builder: (context, data, child) {
              final themeProvider = context.read<ThemeProvider>();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case 'my_bubble':
                      _showBubbleColorPicker(context, themeProvider, true);
                    case 'other_bubble':
                      _showBubbleColorPicker(context, themeProvider, false);
                    case 'luobo_intervention':
                      themeProvider.setLuoBoInterventionEnabled(!data.$3);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'luobo_intervention',
                    child: ListTile(
                      leading: Text(
                        '🥕',
                        style: TextStyle(fontSize: data.$3 ? 22 : 18),
                      ),
                      title: const Text('魔魔胡胡胡萝卜介入'),
                      trailing: Switch(
                        value: data.$3,
                        onChanged: (v) {
                          themeProvider.setLuoBoInterventionEnabled(v);
                          Navigator.pop(context);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'my_bubble',
                    child: ListTile(
                      leading: Icon(Icons.chat_bubble,
                          color: data.$1 ??
                              theme.colorScheme.primary),
                      title: const Text('我的气泡颜色'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'other_bubble',
                    child: ListTile(
                      leading: Icon(Icons.chat_bubble_outline,
                          color: data.$2 ??
                              theme.colorScheme.surfaceContainerHighest),
                      title: const Text('对方气泡颜色'),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Selector<ThemeProvider, (bool, Color, Color?)>(
        selector: (_, tp) => (tp.followSystem, tp.fontColor, tp.userBubbleColor),
        builder: (context, tp, child) {
          return ListView(
            children: [
          // AI 助手入口
          ...AIAssistant.all.map((assistant) => ListTile(
            leading: CircleAvatar(
              backgroundColor: tp.$1
                  ? theme.colorScheme.primary
                  : theme.brightness == Brightness.dark
                      ? assistant.color.withValues(alpha: 0.7)
                      : assistant.color,
              backgroundImage: assistant.avatarAssetPath != null
                  ? AssetImage(assistant.avatarAssetPath!)
                  : null,
              child: assistant.avatarAssetPath == null
                  ? Text(assistant.emoji, style: const TextStyle(fontSize: 20))
                  : null,
            ),
            title: Text(
              assistant.name,
              style: TextStyle(
                color: _getCorrectColor(tp.$1, tp.$2, theme),
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              assistant.subtitle,
              style: TextStyle(
                color: _getCorrectColor(tp.$1, tp.$2, theme)
                    .withValues(alpha: 0.6),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AIChatPage(assistant: assistant)),
              );
            },
          )),

          const Divider(),

          // 好友区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '好友',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          Consumer<FriendProvider>(
            builder: (context, friendProvider, child) {
              if (friendProvider.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (friendProvider.friends.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline,
                          size: 48,
                          color: theme.colorScheme.outline
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      Text(
                        '暂无好友，去「我的」页面添加好友吧',
                        style: TextStyle(
                          color: theme.colorScheme.outline
                              .withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: friendProvider.friends.map((friend) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                      backgroundImage: friend.avatarUrl != null
                          ? CachedNetworkImageProvider(friend.avatarUrl!)
                          : null,
                      child: friend.avatarUrl == null
                          ? Text(
                              friend.nickname.isNotEmpty
                                  ? friend.nickname[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      friend.nickname,
                      style: TextStyle(
                        color: _getCorrectColor(tp.$1, tp.$2, theme),
                      ),
                    ),
                    subtitle: _buildMoodSubtitle(friend.userId),
                    trailing: _buildFriendTrailing(friend.userId),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              FriendChatPage(friend: friend),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      );
    },
  ),
    );
  }
}
