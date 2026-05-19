import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../enums/message_frequency.dart';
import '../enums/message_log_range.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../providers/friend_provider.dart';
import '../providers/shared_mood_provider.dart';
import 'login_page.dart';
import 'friend_list_page.dart';
import 'friend_request_page.dart';
import 'shared_moods_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  /// 获取正确的文字颜色
  /// 当跟随系统开启时使用系统主题的颜色
  /// 当跟随系统关闭时使用自定义的字体颜色
  Color _getCorrectColor(ThemeProvider themeProvider, ThemeData theme) {
    if (themeProvider.followSystem) {
      // 使用系统主题的文字颜色
      return theme.colorScheme.onSurface;
    } else {
      // 使用自定义的字体颜色
      return themeProvider.fontColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        backgroundColor:
            theme.colorScheme.inversePrimary ?? theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimaryContainer ?? Colors.white,
      ),
      body: ListView(
        children: [
          // User auth / social section
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isLoggedIn && authProvider.profile != null) {
                return Column(
                  children: [
                    // User info card
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    _pickAndUploadAvatar(context),
                                child: Stack(
                                  children: [
                                    SizedBox(
                                      width: 56,
                                      height: 56,
                                      child: ClipOval(
                                        child: (() {
                                          final fallback = Container(
                                            color: theme.colorScheme
                                                .primaryContainer,
                                            alignment: Alignment.center,
                                            child: Text(
                                              authProvider.profile!.nickname
                                                      .isNotEmpty
                                                  ? authProvider
                                                      .profile!.nickname[0]
                                                      .toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: theme
                                                    .colorScheme
                                                    .onPrimaryContainer,
                                              ),
                                            ),
                                          );
                                          // During upload, show the picked file
                                          if (authProvider.localAvatarPath !=
                                              null) {
                                            return Image.file(
                                              File(authProvider
                                                  .localAvatarPath!),
                                              fit: BoxFit.cover,
                                            );
                                          }
                                          // Show locally cached copy (avoids network on rebuild)
                                          if (authProvider.cachedAvatarPath !=
                                              null) {
                                            return Image.file(
                                              File(authProvider
                                                  .cachedAvatarPath!),
                                              fit: BoxFit.cover,
                                            );
                                          }
                                          if (authProvider.profile!.avatarUrl !=
                                              null) {
                                            return CachedNetworkImage(
                                              imageUrl: authProvider
                                                  .profile!.avatarUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (c, u) => fallback,
                                              errorWidget: (c, u, e) =>
                                                  fallback,
                                            );
                                          }
                                          return fallback;
                                        })(),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color:
                                              theme.colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () =>
                                          _showEditNicknameDialog(
                                        context,
                                        authProvider.profile!.nickname,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                            child: Text(
                                              authProvider.profile!.nickname,
                                              style: theme
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                color: _getCorrectColor(
                                                    themeProvider, theme),
                                              ),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.edit,
                                            size: 16,
                                            color: _getCorrectColor(
                                                    themeProvider, theme)
                                                .withValues(alpha: 0.4),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '好友码: ${authProvider.profile!.friendCode}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: _getCorrectColor(
                                                      themeProvider, theme)
                                                  .withValues(alpha: 0.6),
                                              fontFamily: 'monospace',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: () => _copyFriendCode(
                                            context,
                                            authProvider.profile!.friendCode,
                                          ),
                                          child: Icon(
                                            Icons.copy,
                                            size: 14,
                                            color: _getCorrectColor(
                                                    themeProvider, theme)
                                                .withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.people),
                      title: Text(
                        '好友',
                        style: TextStyle(
                          color: _getCorrectColor(themeProvider, theme),
                        ),
                      ),
                      subtitle: Text(
                        '管理你的好友列表',
                        style: TextStyle(
                          color: _getCorrectColor(themeProvider, theme)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        context.read<FriendProvider>().loadFriends();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FriendListPage()),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_add_alt),
                      title: Text(
                        '好友请求',
                        style: TextStyle(
                          color: _getCorrectColor(themeProvider, theme),
                        ),
                      ),
                      subtitle: Text(
                        '查看待处理的好友请求',
                        style: TextStyle(
                          color: _getCorrectColor(themeProvider, theme)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      trailing: Consumer<FriendProvider>(
                        builder: (context, friendProvider, _) {
                          if (friendProvider.pendingRequests.isNotEmpty) {
                            return Badge(
                              label: Text(
                                  '${friendProvider.pendingRequests.length}'),
                              child: const Icon(Icons.chevron_right),
                            );
                          }
                          return const Icon(Icons.chevron_right);
                        },
                      ),
                      onTap: () {
                        context
                            .read<FriendProvider>()
                            .loadPendingRequests();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const FriendRequestPage()),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.share),
                      title: Text(
                        '好友分享',
                        style: TextStyle(
                          color: _getCorrectColor(themeProvider, theme),
                        ),
                      ),
                      subtitle: Text(
                        '查看好友分享的心情',
                        style: TextStyle(
                          color: _getCorrectColor(themeProvider, theme)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                      trailing: Consumer<SharedMoodProvider>(
                        builder: (context, sharedMoodProvider, _) {
                          if (sharedMoodProvider.unreadCount > 0) {
                            return Badge(
                              label: Text(
                                  '${sharedMoodProvider.unreadCount}'),
                              child: const Icon(Icons.chevron_right),
                            );
                          }
                          return const Icon(Icons.chevron_right);
                        },
                      ),
                      onTap: () {
                        final sp = context.read<SharedMoodProvider>();
                        sp.loadReceived();
                        sp.loadSent();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const SharedMoodsPage()),
                        );
                      },
                    ),
                    ListTile(
                      leading:
                          Icon(Icons.logout, color: theme.colorScheme.error),
                      title: Text(
                        '退出登录',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('退出登录'),
                            content: const Text('确定要退出登录吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  context
                                      .read<AuthProvider>()
                                      .logout();
                                },
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('退出'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.psychology,
                                size: 48,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '登录后可以使用好友分享功能',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: _getCorrectColor(
                                      themeProvider, theme),
                                ),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const LoginPage()),
                                  );
                                },
                                icon: const Icon(Icons.login),
                                label: const Text('登录 / 注册'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(),
                  ],
                );
              }
            },
          ),
          // Original settings tiles...
          ListTile(leading: const Icon(Icons.palette),
            title: Text(
              '字体颜色设置',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              themeProvider.followSystem
                  ? '跟随系统已开启，使用系统默认颜色'
                  : '设置整个应用的字体颜色',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            onTap: themeProvider.followSystem
                ? null  // 跟随系统开启时禁用字体颜色设置
                : () => _showColorPicker(context, themeProvider),
          ),
          ListTile(
            leading: Icon(Icons.wallpaper,
                color: themeProvider.chatBgPath != null
                    ? theme.colorScheme.primary
                    : null),
            title: Text(
              '聊天背景图',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              themeProvider.chatBgPath != null
                  ? '已设置自定义背景'
                  : '使用本地图片作为聊天背景',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme)
                    .withValues(alpha: 0.7),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (themeProvider.chatBgPath != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 20),
                    onPressed: () async {
                      final file = File(themeProvider.chatBgPath!);
                      if (await file.exists()) await file.delete();
                      themeProvider.setChatBgPath(null);
                    },
                    tooltip: '清除背景',
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _pickChatBackground(context, themeProvider),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.wifi_off),
            title: Text(
              '断网模式',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              '开启后小暖回复默认关闭，且应用不再联网请求 AI 内容',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            value: themeProvider.offlineMode,
            onChanged: (value) => themeProvider.setOfflineMode(value),
          ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: Text(
              'AI API Key',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              themeProvider.apiKey.isEmpty
                  ? '未设置 API Key，AI 功能需要输入'
                  : '已设置 API Key，点击修改',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showApiKeyDialog(context, themeProvider),
          ),
          SwitchListTile(
            secondary: Icon(
              themeProvider.nightMode ? Icons.nightlight_round : Icons.light_mode,
              color: themeProvider.followSystem 
                  ? themeProvider.fontColor.withValues(alpha: 0.3)
                  : null,
            ),
            title: Text(
              '夜间模式',
              style: TextStyle(
                color: themeProvider.followSystem
                    ? _getCorrectColor(themeProvider, theme).withValues(alpha: 0.3)
                    : _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              themeProvider.followSystem
                  ? '跟随系统已开启，夜间模式设置无效'
                  : '开启后界面变暗，文字自动变白，保护眼睛',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(
                  alpha: themeProvider.followSystem ? 0.5 : 0.7,
                ),
              ),
            ),
            value: themeProvider.nightMode,
            onChanged: themeProvider.followSystem 
                ? null  // 跟随系统开启时禁用夜间模式开关
                : (value) => themeProvider.setNightMode(value),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.settings_system_daydream),
            title: Text(
              '跟随系统',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              '开启后应用主题跟随系统日间/夜间模式自动切换',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            value: themeProvider.followSystem,
            onChanged: (value) => themeProvider.setFollowSystem(value),
          ),
          SwitchListTile(
            secondary: Icon(
              themeProvider.showMoodToFriends
                  ? Icons.visibility
                  : Icons.visibility_off,
            ),
            title: Text(
              '向好友展示心情',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              '关闭后好友将无法看到你的最新心情状态',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme)
                    .withValues(alpha: 0.7),
              ),
            ),
            value: themeProvider.showMoodToFriends,
            onChanged: (value) {
              themeProvider.setShowMoodToFriends(value);
              try {
                AuthService.updateProfile(showMoodToFriends: value);
              } catch (_) {}
            },
          ),
          const Divider(),
          // 小暖消息设置区域
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '小暖消息设置',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(
              '消息发送频率',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              themeProvider.messageFrequency.label,
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFrequencyPicker(context, themeProvider),
          ),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: Text(
              '消息读取记录范围',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              themeProvider.messageLogRange.label,
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLogRangePicker(context, themeProvider),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text('关于', style: TextStyle(
              color: _getCorrectColor(themeProvider, theme),
            )),
            subtitle: Text(
              '版本 1.0.0',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            onTap: () {
              // 可以添加关于页面的逻辑
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 75,
    );
    if (picked == null) return;

    if (!context.mounted) return;

    try {
      await context.read<AuthProvider>().updateAvatar(File(picked.path));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('头像已更新')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像更新失败: $e')),
        );
      }
    }
  }

  Future<void> _pickChatBackground(
      BuildContext context, ThemeProvider themeProvider) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
    );
    if (picked == null) return;

    if (!context.mounted) return;

    // Copy to app directory so it persists
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.substring(picked.name.lastIndexOf('.'))
          : '.jpg';
      final appDir = await getApplicationDocumentsDirectory();
      final bgDir = Directory('${appDir.path}/mood_images');
      if (!await bgDir.exists()) await bgDir.create(recursive: true);
      final filePath = '${bgDir.path}/chat_bg$ext';
      final file = File(filePath);
      await file.writeAsBytes(bytes);
      await themeProvider.setChatBgPath(filePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('聊天背景已设置')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('设置背景失败: $e')),
        );
      }
    }
  }

  void _showEditNicknameDialog(
      BuildContext context, String currentNickname) {
    final controller = TextEditingController(text: currentNickname);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(
            labelText: '昵称',
            hintText: '请输入新昵称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final newNickname = controller.text.trim();
              if (newNickname.isEmpty) return;
              context.read<AuthProvider>().updateNickname(newNickname);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _copyFriendCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('好友码已复制到剪贴板')),
    );
  }

  void _showApiKeyDialog(BuildContext context, ThemeProvider themeProvider) {
    final controller = TextEditingController(text: themeProvider.apiKey);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI API Key'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: '请输入 API Key',
            hintText: 'sk-...',
          ),
        ),
        actions: [
          if (themeProvider.apiKey.isNotEmpty)
            TextButton(
              onPressed: () {
                themeProvider.clearApiKey();
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key 已清除')),
                );
              },
              child: const Text('清除', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              themeProvider.setApiKey(controller.text.trim());
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('API Key 已保存')),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, ThemeProvider themeProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择字体颜色'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _colorOption(context, themeProvider, Colors.black, '黑色'),
            _colorOption(context, themeProvider, Colors.blue, '蓝色'),
            _colorOption(context, themeProvider, Colors.green, '绿色'),
            _colorOption(context, themeProvider, Colors.red, '红色'),
            _colorOption(context, themeProvider, Colors.purple, '紫色'),
            _colorOption(context, themeProvider, Colors.orange, '橙色'),
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

  Widget _colorOption(
    BuildContext context,
    ThemeProvider themeProvider,
    Color color,
    String label,
  ) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, radius: 12),
      title: Text(label),
      onTap: () {
        themeProvider.setFontColor(color);
        Navigator.of(context).pop();
      },
    );
  }

  void _showFrequencyPicker(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择小暖消息频率',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ...MessageFrequency.values.map((frequency) {
                final selected = themeProvider.messageFrequency == frequency;
                return ListTile(
                  title: Text(frequency.label),
                  trailing: selected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    themeProvider.setMessageFrequency(frequency);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showLogRangePicker(BuildContext context, ThemeProvider themeProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '小暖读取心情记录的时间范围',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '小暖会根据这个范围内的记录生成消息',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 16),
              ...MessageLogRange.values.map((range) {
                final selected = themeProvider.messageLogRange == range;
                return ListTile(
                  title: Text(range.label),
                  trailing: selected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () {
                    themeProvider.setMessageLogRange(range);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
