import 'dart:io' if (dart.library.html) 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../services/remote_mood_service.dart';
import 'login_page.dart';
import 'personal_info_page.dart';
import '../services/version_service.dart';
import '../widgets/update_dialog.dart';
import 'settings_page.dart';

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
          // User info card or login prompt
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isLoggedIn && authProvider.profile != null) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PersonalInfoPage()),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 56,
                              height: 56,
                              child: ClipOval(
                                child: (() {
                                  final fallback = Container(
                                    color: theme.colorScheme.primaryContainer,
                                    alignment: Alignment.center,
                                    child: Text(
                                      authProvider.profile!.nickname.isNotEmpty
                                          ? authProvider.profile!.nickname[0]
                                              .toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: theme
                                            .colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  );
                                  if (authProvider.localAvatarPath != null) {
                                    return Image.file(
                                      File(authProvider.localAvatarPath!),
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  if (authProvider.cachedAvatarPath != null) {
                                    return Image.file(
                                      File(authProvider.cachedAvatarPath!),
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  if (authProvider.profile!.avatarUrl != null) {
                                    return CachedNetworkImage(
                                      imageUrl:
                                          authProvider.profile!.avatarUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (c, u) => fallback,
                                      errorWidget: (c, u, e) => fallback,
                                    );
                                  }
                                  return fallback;
                                })(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    authProvider.profile!.nickname,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: _getCorrectColor(
                                          themeProvider, theme),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
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
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: _getCorrectColor(themeProvider, theme)
                                  .withValues(alpha: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              } else {
                return Padding(
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
                                    builder: (_) => const LoginPage()),
                              );
                            },
                            icon: const Icon(Icons.login),
                            label: const Text('登录 / 注册'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          // Quick access items
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (!authProvider.isLoggedIn) return const SizedBox.shrink();
              return SwitchListTile(
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
                  if (value) {
                    RemoteMoodService.syncLatestMoodToStatus();
                  } else {
                    RemoteMoodService.clearMoodStatus();
                  }
                },
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.wallpaper,
                color: themeProvider.chatBgPath != null
                    ? theme.colorScheme.primary
                    : null),
            title: Text(
              '聊天背景',
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
          ListTile(
            leading: const Icon(Icons.info),
            title: Text('关于', style: TextStyle(
              color: _getCorrectColor(themeProvider, theme),
            )),
            subtitle: FutureBuilder<String>(
              future: VersionService.currentVersion,
              builder: (context, snapshot) {
                final version = snapshot.data ?? '';
                return Text(
                  '版本 $version',
                  style: TextStyle(
                    color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
                  ),
                );
              },
            ),
            onTap: () => _checkUpdate(context),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.settings, color: theme.colorScheme.primary),
            title: Text(
              '更多设置',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              '显示、社交、AI 等更多设置',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('正在检查更新...'), duration: Duration(seconds: 1)),
    );

    final currentVersion = await VersionService.currentVersion;
    final latest = await VersionService.getLatestVersion();

    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();

    if (latest == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('检查更新失败，请稍后重试')),
      );
      return;
    }

    if (VersionService.isNewer(currentVersion, latest.latestVersion)) {
      showDialog(
        context: context,
        builder: (_) => UpdateDialog(versionInfo: latest),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('已是最新版本')),
      );
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

}
