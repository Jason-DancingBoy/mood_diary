import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../enums/mood_type.dart';
import '../providers/friend_provider.dart';
import '../providers/theme_provider.dart';
import '../services/remote_mood_service.dart';
import '../utils/time_utils.dart';
import 'add_friend_page.dart';
import 'friend_request_page.dart';
import 'friend_chat_page.dart';

class FriendListPage extends StatefulWidget {
  const FriendListPage({super.key});

  @override
  State<FriendListPage> createState() => _FriendListPageState();
}

class _FriendListPageState extends State<FriendListPage> {
  @override
  void initState() {
    super.initState();
    RemoteMoodService.friendMoodsNotifier.addListener(_onMoodsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initData();
    });
  }

  void _onMoodsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initData() async {
    final fp = context.read<FriendProvider>();
    await fp.loadFriends();
    fp.startFriendListRealtime();
    if (!mounted) return;
    await _ensureRealtime();
  }

  Future<void> _ensureRealtime() async {
    final friends = context.read<FriendProvider>().friends;
    final userIds = friends.map((f) => f.userId).toList();
    await RemoteMoodService.ensureFriendMoodRealtime(userIds);
  }

  Widget? _buildMoodSubtitle(String friendUserId, ThemeData theme) {
    final moodData =
        RemoteMoodService.friendMoodsNotifier.value[friendUserId];
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

  Color _getCorrectColor(ThemeProvider themeProvider, ThemeData theme) {
    if (themeProvider.followSystem) {
      return theme.colorScheme.onSurface;
    }
    return themeProvider.fontColor;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appBarColor =
        theme.colorScheme.inversePrimary ?? theme.colorScheme.primary;
    final appBarTextColor =
        theme.colorScheme.onPrimaryContainer ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('好友'),
        backgroundColor: appBarColor,
        foregroundColor: appBarTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddFriendPage()),
              );
              if (mounted) {
                context.read<FriendProvider>().loadFriends();
                _ensureRealtime();
              }
            },
            tooltip: '添加好友',
          ),
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FriendRequestPage()),
              );
              if (mounted) {
                context.read<FriendProvider>().loadFriends();
                _ensureRealtime();
              }
            },
            tooltip: '好友请求',
          ),
        ],
      ),
      body: Consumer<FriendProvider>(
        builder: (context, friendProvider, child) {
          if (friendProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (friendProvider.friends.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: 64,
                      color: theme.colorScheme.outline
                          .withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(
                    '还没有好友',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右上角 + 添加好友',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await friendProvider.loadFriends();
              await _ensureRealtime();
            },
            child: ListView.builder(
              itemCount: friendProvider.friends.length,
              itemBuilder: (context, index) {
                final friend = friendProvider.friends[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        theme.colorScheme.primaryContainer,
                    backgroundImage: friend.avatarUrl != null
                        ? CachedNetworkImageProvider(friend.avatarUrl!)
                        : null,
                    child: friend.avatarUrl != null
                        ? null
                        : Text(
                            friend.nickname.isNotEmpty
                                ? friend.nickname[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color:
                                  theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                  ),
                  title: Text(
                    friend.nickname,
                    style: TextStyle(
                      color: _getCorrectColor(themeProvider, theme),
                    ),
                  ),
                  subtitle: _buildMoodSubtitle(friend.userId, theme) ??
                      Text(
                        '好友',
                        style: TextStyle(
                          color: _getCorrectColor(themeProvider, theme)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FriendChatPage(friend: friend),
                      ),
                    );
                  },
                  onLongPress: () => _confirmRemoveFriend(
                      context, friend.id, friend.nickname),
                );
              },
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    context.read<FriendProvider>().stopFriendListRealtime();
    RemoteMoodService.friendMoodsNotifier.removeListener(_onMoodsChanged);
    super.dispose();
  }

  void _confirmRemoveFriend(
      BuildContext context, String friendshipId, String nickname) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除好友'),
        content: Text('确定要删除好友 "$nickname" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context
                  .read<FriendProvider>()
                  .removeFriend(friendshipId)
                  .then((_) => _ensureRealtime());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
