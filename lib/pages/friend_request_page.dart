import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../providers/theme_provider.dart';

class FriendRequestPage extends StatefulWidget {
  const FriendRequestPage({super.key});

  @override
  State<FriendRequestPage> createState() => _FriendRequestPageState();
}

class _FriendRequestPageState extends State<FriendRequestPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendProvider>().loadPendingRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        title: const Text('好友请求'),
        backgroundColor: appBarColor,
        foregroundColor: appBarTextColor,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '收到的请求'),
            Tab(text: '已发送'),
          ],
        ),
      ),
      body: Consumer<FriendProvider>(
        builder: (context, friendProvider, child) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildPendingRequestsList(theme, themeProvider, friendProvider),
              _buildSentRequestsList(theme, themeProvider, friendProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingRequestsList(
      ThemeData theme, ThemeProvider themeProvider, FriendProvider friendProvider) {
    if (friendProvider.pendingRequests.isEmpty) {
      return _buildEmptyState(theme, '暂无收到的好友请求');
    }

    return RefreshIndicator(
      onRefresh: () => friendProvider.loadPendingRequests(),
      child: ListView.builder(
        itemCount: friendProvider.pendingRequests.length,
        itemBuilder: (context, index) {
          final friend = friendProvider.pendingRequests[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                friend.nickname.isNotEmpty
                    ? friend.nickname[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            title: Text(
              friend.nickname,
              style: TextStyle(
                  color: _getCorrectColor(themeProvider, theme)),
            ),
            subtitle: const Text('请求添加你为好友'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_outline,
                      color: Colors.green),
                  onPressed: () async {
                    final success = await friendProvider
                        .acceptRequest(friend.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                success ? '已接受好友请求' : '操作失败')),
                      );
                    }
                  },
                  tooltip: '接受',
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_outlined,
                      color: Colors.red),
                  onPressed: () async {
                    final success = await friendProvider
                        .rejectRequest(friend.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(
                                success ? '已拒绝好友请求' : '操作失败')),
                      );
                    }
                  },
                  tooltip: '拒绝',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSentRequestsList(
      ThemeData theme, ThemeProvider themeProvider, FriendProvider friendProvider) {
    if (friendProvider.sentRequests.isEmpty) {
      return _buildEmptyState(theme, '暂无已发送的好友请求');
    }

    return RefreshIndicator(
      onRefresh: () => friendProvider.loadPendingRequests(),
      child: ListView.builder(
        itemCount: friendProvider.sentRequests.length,
        itemBuilder: (context, index) {
          final request = friendProvider.sentRequests[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Text(
                request.nickname.isNotEmpty
                    ? request.nickname[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            title: Text(
              request.nickname,
              style: TextStyle(
                  color: _getCorrectColor(themeProvider, theme)),
            ),
            subtitle: const Text('等待对方回应'),
            trailing: const Chip(label: Text('等待中')),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
