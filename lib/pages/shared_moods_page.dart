import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/shared_mood_provider.dart';
import '../providers/theme_provider.dart';
import '../enums/mood_type.dart';
import 'shared_mood_detail_page.dart';

class SharedMoodsPage extends StatefulWidget {
  const SharedMoodsPage({super.key});

  @override
  State<SharedMoodsPage> createState() => _SharedMoodsPageState();
}

class _SharedMoodsPageState extends State<SharedMoodsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<SharedMoodProvider>();
      provider.loadReceived();
      provider.loadSent();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getCorrectColor(bool followSystem, Color fontColor, ThemeData theme) {
    if (followSystem) {
      return theme.colorScheme.onSurface;
    }
    return fontColor;
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _deleteSelected() {
    final provider = context.read<SharedMoodProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedIds.length} 条分享吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              for (final id in _selectedIds.toList()) {
                provider.deleteShare(id);
              }
              _exitSelectionMode();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sharedMoodProvider = Provider.of<SharedMoodProvider>(context);
    final appBarColor =
        theme.colorScheme.inversePrimary ?? theme.colorScheme.primary;
    final appBarTextColor =
        theme.colorScheme.onPrimaryContainer ?? Colors.white;

    return Selector<ThemeProvider, (bool, Color)>(
      selector: (_, tp) => (tp.followSystem, tp.fontColor),
      builder: (context, tp, child) {
        return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              ),
              title: Text('已选择 ${_selectedIds.length} 项'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _selectedIds.isNotEmpty
                      ? _deleteSelected
                      : null,
                ),
              ],
            )
          : AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('好友分享'),
                  if (sharedMoodProvider.unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Badge(
                      label: Text('${sharedMoodProvider.unreadCount}'),
                      child: const Icon(Icons.mail_outlined),
                    ),
                  ],
                ],
              ),
              backgroundColor: appBarColor,
              foregroundColor: appBarTextColor,
              actions: [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  onPressed: _enterSelectionMode,
                  tooltip: '批量选择',
                ),
              ],
              bottom: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('收到的'),
                        if (sharedMoodProvider.unreadCount > 0) ...[
                          const SizedBox(width: 4),
                          Badge(
                            label:
                                Text('${sharedMoodProvider.unreadCount}'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: '发出的'),
                ],
              ),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceivedList(theme, tp.$1, tp.$2, sharedMoodProvider),
          _buildSentList(theme, tp.$1, tp.$2, sharedMoodProvider),
        ],
      ),
    );
    },
  );
  }

  Widget _buildReceivedList(ThemeData theme, bool followSystem, Color fontColor,
      SharedMoodProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.receivedShares.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64,
                color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '暂无收到的心情分享',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadReceived(),
      child: ListView.builder(
        itemCount: provider.receivedShares.length,
        itemBuilder: (context, index) {
          final share = provider.receivedShares[index];
          final unread = share.readAt == null;
          final moodType = share.mood != null
              ? MoodType.values.firstWhere(
                  (e) => e.name == share.mood!.moodType,
                  orElse: () => MoodType.calm,
                )
              : MoodType.calm;

          final hasImage = share.mood != null &&
              share.mood!.imageUrls.isNotEmpty;

          return Card(
            color: unread
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isSelectionMode
                  ? () => _toggleSelection(share.id)
                  : () async {
                      if (unread) {
                        provider.markAsRead(share.id);
                      }
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              SharedMoodDetailPage(sharedMood: share),
                        ),
                      );
                    },
              onLongPress: () {
                if (!_isSelectionMode) {
                  _enterSelectionMode();
                  _toggleSelection(share.id);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (_isSelectionMode)
                      Checkbox(
                        value: _selectedIds.contains(share.id),
                        onChanged: (_) => _toggleSelection(share.id),
                      )
                    else
                      CircleAvatar(
                        backgroundColor: moodType.color,
                        child: Icon(
                          moodType.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            share.fromUserNickname,
                            style: TextStyle(
                              color: _getCorrectColor(followSystem, fontColor, theme),
                              fontWeight:
                                  unread ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if ((share.mood?.note ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              share.mood!.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _getCorrectColor(followSystem, fontColor, theme)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(share.sharedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getCorrectColor(followSystem, fontColor, theme)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        if (hasImage) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: share.mood!.imageUrls.first,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 48,
                                height: 48,
                                color: theme
                                    .colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                color: theme
                                    .colorScheme.surfaceContainerHighest,
                                child:
                                    const Icon(Icons.image, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSentList(ThemeData theme, bool followSystem, Color fontColor,
      SharedMoodProvider provider) {
    if (provider.sentShares.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.send_outlined,
                size: 64,
                color: theme.colorScheme.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              '暂无发出的心情分享',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.loadSent(),
      child: ListView.builder(
        itemCount: provider.sentShares.length,
        itemBuilder: (context, index) {
          final share = provider.sentShares[index];
          final moodType = share.mood != null
              ? MoodType.values.firstWhere(
                  (e) => e.name == share.mood!.moodType,
                  orElse: () => MoodType.calm,
                )
              : MoodType.calm;

          final hasImage = share.mood != null &&
              share.mood!.imageUrls.isNotEmpty;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _isSelectionMode
                  ? () => _toggleSelection(share.id)
                  : () {
                      if (share.mood != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SharedMoodDetailPage(sharedMood: share),
                          ),
                        );
                      }
                    },
              onLongPress: () {
                if (!_isSelectionMode) {
                  _enterSelectionMode();
                  _toggleSelection(share.id);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (_isSelectionMode)
                      Checkbox(
                        value: _selectedIds.contains(share.id),
                        onChanged: (_) => _toggleSelection(share.id),
                      )
                    else
                      CircleAvatar(
                        backgroundColor: moodType.color,
                        child: Icon(
                          moodType.icon,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '分享给 ${share.fromUserNickname}',
                            style: TextStyle(
                                color: _getCorrectColor(followSystem, fontColor, theme)),
                          ),
                          if ((share.mood?.note ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              share.mood!.note,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _getCorrectColor(followSystem, fontColor, theme)
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(share.sharedAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getCorrectColor(followSystem, fontColor, theme)
                                .withValues(alpha: 0.5),
                          ),
                        ),
                        if (hasImage) ...[
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: share.mood!.imageUrls.first,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 48,
                                height: 48,
                                color: theme
                                    .colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                color: theme
                                    .colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.image, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}
