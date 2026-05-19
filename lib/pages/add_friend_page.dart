import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../providers/theme_provider.dart';
import '../models/user_profile.dart';

class AddFriendPage extends StatefulWidget {
  const AddFriendPage({super.key});

  @override
  State<AddFriendPage> createState() => _AddFriendPageState();
}

class _AddFriendPageState extends State<AddFriendPage> {
  final _searchController = TextEditingController();
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getCorrectColor(ThemeProvider themeProvider, ThemeData theme) {
    if (themeProvider.followSystem) {
      return theme.colorScheme.onSurface;
    }
    return themeProvider.fontColor;
  }

  void _onSearchChanged(String query) {
    _hasSearched = true;
    context.read<FriendProvider>().searchUsers(query);
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
        title: const Text('添加好友'),
        backgroundColor: appBarColor,
        foregroundColor: appBarTextColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchChanged,
              decoration: InputDecoration(
                hintText: '输入昵称或好友码搜索',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<FriendProvider>().clearSearch();
                          setState(() => _hasSearched = false);
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Consumer<FriendProvider>(
              builder: (context, friendProvider, child) {
                if (!_hasSearched) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search,
                            size: 64,
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          '输入昵称或好友码搜索用户',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (friendProvider.searchResults.isEmpty) {
                  return Center(
                    child: Text(
                      '未找到匹配的用户',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: friendProvider.searchResults.length,
                  itemBuilder: (context, index) {
                    final user = friendProvider.searchResults[index];
                    return _buildUserTile(
                        theme, themeProvider, user, friendProvider);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(ThemeData theme, ThemeProvider themeProvider,
      UserProfile user, FriendProvider friendProvider) {
    final isAlreadyFriend = friendProvider.friends
        .any((f) => f.userId == user.id);
    final isRequestSent = friendProvider.sentRequests
        .any((f) => f.userId == user.id);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Text(
          user.nickname.isNotEmpty
              ? user.nickname[0].toUpperCase()
              : '?',
          style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
        ),
      ),
      title: Text(
        user.nickname,
        style: TextStyle(color: _getCorrectColor(themeProvider, theme)),
      ),
      subtitle: Text(
        '好友码: ${user.friendCode}',
        style: TextStyle(
          color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.6),
          fontFamily: 'monospace',
        ),
      ),
      trailing: isAlreadyFriend
          ? const Chip(label: Text('已是好友'))
          : isRequestSent
              ? const Chip(label: Text('已发送'))
              : FilledButton.tonal(
                  onPressed: () async {
                    final success = await friendProvider
                        .sendRequest(user.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success ? '好友请求已发送' : '发送失败'),
                        ),
                      );
                    }
                  },
                  child: const Text('添加好友'),
                ),
    );
  }
}
