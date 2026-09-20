import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';
import '../providers/friend_provider.dart';
import '../providers/shared_mood_provider.dart';
import 'friend_list_page.dart';
import 'friend_request_page.dart';
import 'shared_moods_page.dart';
import '../services/supabase_service.dart';
import '../services/token_usage_tracker.dart';
import '../services/remote_mood_service.dart';
import 'voice_sample_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Color _getCorrectColor(ThemeProvider themeProvider, ThemeData theme) {
    if (themeProvider.followSystem) {
      return theme.colorScheme.onSurface;
    }
    return themeProvider.fontColor;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: theme.colorScheme.inversePrimary,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: ListView(
        children: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isLoggedIn) {
                return const SizedBox.shrink();
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
                              color: _getCorrectColor(themeProvider, theme),
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
          // 显示
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '显示',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          SwitchListTile(
            secondary: Icon(
              themeProvider.nightMode ? Icons.nightlight_round : Icons.light_mode,
              color: themeProvider.followSystem
                  ? _getCorrectColor(themeProvider, theme).withValues(alpha: 0.3)
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
                ? null
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
          ListTile(
            leading: const Icon(Icons.palette),
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
            trailing: const Icon(Icons.chevron_right),
            onTap: themeProvider.followSystem
                ? null
                : () => _showColorPicker(context, themeProvider),
          ),
          ListTile(
            leading: Icon(Icons.format_paint, color: Colors.orange),
            title: Text(
              '温馨底色',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              themeProvider.warmThemeIndex > 0
                  ? ThemeProvider.warmPalettes[themeProvider.warmThemeIndex - 1].label
                  : '默认',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showWarmPaletteSheet(context, themeProvider),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '社交',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final loggedIn = authProvider.isLoggedIn;
              return Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.people),
                    title: Text(
                      '好友',
                      style: TextStyle(
                        color: loggedIn
                            ? _getCorrectColor(themeProvider, theme)
                            : _getCorrectColor(themeProvider, theme).withValues(alpha: 0.4),
                      ),
                    ),
                    subtitle: Text(
                      '管理你的好友列表',
                      style: TextStyle(
                        color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: loggedIn
                        ? () {
                            context.read<FriendProvider>().loadFriends();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FriendListPage()),
                            );
                          }
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt),
                    title: Text(
                      '好友请求',
                      style: TextStyle(
                        color: loggedIn
                            ? _getCorrectColor(themeProvider, theme)
                            : _getCorrectColor(themeProvider, theme).withValues(alpha: 0.4),
                      ),
                    ),
                    subtitle: Text(
                      '查看待处理的好友请求',
                      style: TextStyle(
                        color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
                      ),
                    ),
                    trailing: Consumer<FriendProvider>(
                      builder: (context, friendProvider, _) {
                        if (!loggedIn) return const Icon(Icons.chevron_right);
                        if (friendProvider.pendingRequests.isNotEmpty) {
                          return Badge(
                            label: Text('${friendProvider.pendingRequests.length}'),
                            child: const Icon(Icons.chevron_right),
                          );
                        }
                        return const Icon(Icons.chevron_right);
                      },
                    ),
                    onTap: loggedIn
                        ? () {
                            context.read<FriendProvider>().loadPendingRequests();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const FriendRequestPage()),
                            );
                          }
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.share),
                    title: Text(
                      '好友分享',
                      style: TextStyle(
                        color: loggedIn
                            ? _getCorrectColor(themeProvider, theme)
                            : _getCorrectColor(themeProvider, theme).withValues(alpha: 0.4),
                      ),
                    ),
                    subtitle: Text(
                      '查看好友分享的心情',
                      style: TextStyle(
                        color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
                      ),
                    ),
                    trailing: Consumer<SharedMoodProvider>(
                      builder: (context, sharedMoodProvider, _) {
                        if (!loggedIn) return const Icon(Icons.chevron_right);
                        if (sharedMoodProvider.unreadCount > 0) {
                          return Badge(
                            label: Text('${sharedMoodProvider.unreadCount}'),
                            child: const Icon(Icons.chevron_right),
                          );
                        }
                        return const Icon(Icons.chevron_right);
                      },
                    ),
                    onTap: loggedIn
                        ? () {
                            final sp = context.read<SharedMoodProvider>();
                            sp.loadReceived();
                            sp.loadSent();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SharedMoodsPage()),
                            );
                          }
                        : null,
                  ),
                ],
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'AI & 服务',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
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
          _TokenUsageTile(themeProvider: themeProvider, theme: theme),
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: Text(
              '导入配置',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              '粘贴 JSON 文本，一键设置所有 API 密钥',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showImportConfigDialog(context, themeProvider),
          ),
          ListTile(
            leading: const Text('🥕', style: TextStyle(fontSize: 22)),
            title: Text(
              '萝卜语音设置',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme),
              ),
            ),
            subtitle: Text(
              themeProvider.ttsVoiceId.isNotEmpty
                  ? themeProvider.ttsEnabled
                      ? '已开启 · 萝卜会用你的音色说话'
                      : '已录制音色 · 当前未开启'
                  : '录制你的声音，让萝卜用你的音色发语音',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VoiceSamplePage()),
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              '数据',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: Text('从云端恢复数据', style: TextStyle(
              color: _getCorrectColor(themeProvider, theme),
            )),
            subtitle: Text(
              '将之前上传到云端的心情记录恢复到本地',
              style: TextStyle(
                color: _getCorrectColor(themeProvider, theme).withValues(alpha: 0.7),
              ),
            ),
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('正在恢复数据...')),
              );
              final count = await RemoteMoodService.restoreMoodsIfNeeded();
              messenger.hideCurrentSnackBar();
              if (count > 0) {
                messenger.showSnackBar(
                  SnackBar(content: Text('已恢复 $count 条心情记录')),
                );
              } else if (count == 0) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('没有需要恢复的数据')),
                );
              } else {
                messenger.showSnackBar(
                  const SnackBar(content: Text('恢复失败，请检查网络')),
                );
              }
            },
          ),
          const Divider(),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (!authProvider.isLoggedIn) return const SizedBox.shrink();
              return ListTile(
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text(
                  '退出登录',
                  style: TextStyle(color: theme.colorScheme.error),
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
                            context.read<AuthProvider>().logout();
                          },
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('退出'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
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

  void _showWarmPaletteSheet(BuildContext context, ThemeProvider themeProvider) {
    final currentIndex = themeProvider.warmThemeIndex;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '选择温馨底色',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _warmPaletteOption(
                  context: context,
                  themeProvider: themeProvider,
                  index: 0,
                  label: '默认',
                  swatchColor: Colors.grey.shade200,
                  isSelected: currentIndex == 0,
                ),
                const Divider(height: 1),
                ...List.generate(ThemeProvider.warmPalettes.length, (i) {
                  final palette = ThemeProvider.warmPalettes[i];
                  final paletteIndex = i + 1;
                  return _warmPaletteOption(
                    context: context,
                    themeProvider: themeProvider,
                    index: paletteIndex,
                    label: palette.label,
                    swatchColor: palette.light,
                    isSelected: currentIndex == paletteIndex,
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _warmPaletteOption({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required int index,
    required String label,
    required Color swatchColor,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: swatchColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      title: Text(label),
      trailing: isSelected
          ? const Icon(Icons.check, color: Colors.orange)
          : null,
      onTap: () {
        themeProvider.setWarmThemeIndex(index);
        Navigator.pop(context);
      },
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

  void _showImportConfigDialog(BuildContext context, ThemeProvider themeProvider) {
    final controller = TextEditingController();
    const template = '''{
  "apiKey": "sk-...",
  "ttsApiKey": "...",
  "ttsVoiceId": "...",
  "realtimeAppId": "...",
  "realtimeAccessToken": "..."
}''';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_alt, size: 20),
            SizedBox(width: 8),
            Text('导入 API 配置'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '粘贴包含 API 密钥的 JSON 文本，一键配置所有服务。'
                  '所有字段均可选，只更新你提供的字段。',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 10,
                  minLines: 5,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: template,
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.all(12),
                    hintStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    hintMaxLines: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          if (themeProvider.apiKey.isNotEmpty ||
              themeProvider.ttsApiKey.isNotEmpty ||
              themeProvider.ttsVoiceId.isNotEmpty)
            TextButton(
              onPressed: () {
                showDialog(
                  context: ctx,
                  builder: (c2) => AlertDialog(
                    title: const Text('清除全部配置'),
                    content: const Text('确定要清除所有 API 配置吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c2),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          themeProvider.clearApiKey();
                          themeProvider.setTtsApiKey('');
                          themeProvider.setTtsVoiceId('');
                          themeProvider.setRealtimeAppId('');
                          themeProvider.setRealtimeAccessToken('');
                          Navigator.pop(c2);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已清除全部 API 配置')),
                          );
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('清除全部'),
            ),
          FilledButton(
            onPressed: () async {
              final error = await themeProvider.importApiConfig(controller.text);
              if (!ctx.mounted) return;
              if (error == null) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('配置导入成功')),
                );
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(error)),
                );
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }
}

class _TokenUsageTile extends StatelessWidget {
  final ThemeProvider themeProvider;
  final ThemeData theme;

  const _TokenUsageTile({required this.themeProvider, required this.theme});

  Color _getColor() {
    if (themeProvider.followSystem) {
      return theme.colorScheme.onSurface;
    }
    return themeProvider.fontColor;
  }

  Future<MonthlyStats> _fetchMonthlyStats() async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId != null) {
      try {
        final now = DateTime.now();
        final monthStart = DateTime.utc(now.year, now.month, 1).toIso8601String();
        final result = await SupabaseService.tokenUsageLogs
            .select('prompt_tokens, completion_tokens, total_tokens')
            .eq('user_id', userId)
            .gte('created_at', monthStart);

        final rows = result as List<dynamic>;
        int prompt = 0, completion = 0, total = 0;
        for (final row in rows) {
          prompt += (row['prompt_tokens'] as int?) ?? 0;
          completion += (row['completion_tokens'] as int?) ?? 0;
          total += (row['total_tokens'] as int?) ?? 0;
        }
        return MonthlyStats(
          promptTokens: prompt,
          completionTokens: completion,
          totalTokens: total,
          callCount: rows.length,
        );
      } catch (_) {}
    }
    return TokenUsageTracker.instance.getMonthlyStats();
  }

  Future<Map<String, SourceStats>> _fetchSourceBreakdown() async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId != null) {
      try {
        final now = DateTime.now();
        final monthStart = DateTime.utc(now.year, now.month, 1).toIso8601String();
        final result = await SupabaseService.tokenUsageLogs
            .select('source, prompt_tokens, completion_tokens')
            .eq('user_id', userId)
            .gte('created_at', monthStart);

        final rows = result as List<dynamic>;
        final map = <String, SourceStats>{};
        for (final row in rows) {
          final src = row['source'] as String? ?? 'unknown';
          final stats = map.putIfAbsent(src, () => SourceStats(source: src));
          stats.promptTokens += (row['prompt_tokens'] as int?) ?? 0;
          stats.completionTokens += (row['completion_tokens'] as int?) ?? 0;
          stats.callCount++;
        }
        return map;
      } catch (_) {}
    }
    return TokenUsageTracker.instance.getSourceBreakdown();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MonthlyStats>(
      future: _fetchMonthlyStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final hasData = stats != null && stats.callCount > 0;

        return ListTile(
          leading: const Icon(Icons.data_usage),
          title: Text(
            '本月 Token 用量',
            style: TextStyle(color: _getColor()),
          ),
          subtitle: Text(
            hasData
                ? '${_formatTokens(stats.totalTokens)} · ${stats.callCount}次调用'
                : '暂无数据',
            style: TextStyle(
              color: _getColor().withValues(alpha: 0.7),
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: hasData
              ? () => _showUsageDialog(context, stats)
              : null,
        );
      },
    );
  }

  void _showUsageDialog(BuildContext context, MonthlyStats stats) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('本月 Token 用量'),
          content: FutureBuilder<Map<String, SourceStats>>(
            future: _fetchSourceBreakdown(),
            builder: (context, snapshot) {
              final breakdown = snapshot.data ?? {};
              final isOnline = SupabaseService.auth.currentUser != null;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statRow('Prompt', _formatTokens(stats.promptTokens)),
                  const SizedBox(height: 4),
                  _statRow('Completion', _formatTokens(stats.completionTokens)),
                  const SizedBox(height: 4),
                  _statRow('总计', _formatTokens(stats.totalTokens)),
                  const SizedBox(height: 4),
                  _statRow('调用次数', '${stats.callCount}次'),
                  if (isOnline)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '数据来源：联网同步',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ),
                  if (breakdown.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text('按来源分类', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...breakdown.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _statRow(
                        _sourceLabel(e.key),
                        _formatTokens(e.value.totalTokens),
                        extra: '${e.value.callCount}次',
                      ),
                    )),
                  ],
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  String _sourceLabel(String key) {
    switch (key) {
      case 'comfort':
        return '日记安慰';
      case 'chat':
        return 'AI 对话';
      case 'mail':
        return '邮件生成';
      case 'emotion_analysis':
        return '情绪分析';
      case 'intervene':
        return '阿信介入';
      default:
        return key;
    }
  }

  static String _formatTokens(int tokens) {
    if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }

  static Widget _statRow(String label, String value, {String? extra}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (extra != null) ...[
              const SizedBox(width: 8),
              Text(extra, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ],
        ),
      ],
    );
  }
}
