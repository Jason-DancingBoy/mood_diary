# Profile Page Reorganization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reorganize the cluttered "我的" ProfilePage from ~20 flat items into a clean 5-item main page with a grouped SettingsPage, and relocate message/AI settings closer to their usage context.

**Architecture:** Main-sub navigation pattern. ProfilePage keeps only personal card + 3 commonly-used items + "更多设置" entry. A new SettingsPage hosts all other settings in 4 card-based groups (显示/社交/AI服务/数据). Message frequency/log range move to MessagePage's existing AppBar gear. Anti-essay mode toggle moves to ChatListPage's existing PopupMenu.

**Tech Stack:** Flutter, Provider, Hive

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/pages/settings_page.dart` | **Create** | New grouped settings page with all secondary settings |
| `lib/pages/profile_page.dart` | **Modify** | Strip down to 5 items, remove all moved code |
| `lib/pages/message_page.dart` | **Modify** | Expand bottom sheet to include log range alongside frequency |
| `lib/pages/chat_list_page.dart` | **Modify** | Add noEssayMode toggle to PopupMenuButton |

---

### Task 1: Create SettingsPage — 显示 section

**Files:**
- Create: `lib/pages/settings_page.dart`

- [ ] **Step 1: Create the file with imports and scaffold**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../enums/message_frequency.dart';
import '../enums/message_log_range.dart';
import 'login_page.dart';

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
        backgroundColor:
            theme.colorScheme.inversePrimary ?? theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimaryContainer ?? Colors.white,
      ),
      body: ListView(
        children: [
          // Placeholder for login card (Task 2)
          // Placeholder for 显示 section (this task)
          // Placeholder for 社交 section (Task 3)
          // Placeholder for AI & 服务 section (Task 4)
          // Placeholder for 数据 section (Task 5)
          // Placeholder for logout (Task 6)
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add the 显示 section to the body**

Add right after the opening `children: [` of the ListView body:

```dart
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
          const Divider(),
```

- [ ] **Step 3: Add _showColorPicker and _colorOption methods to SettingsPage**

```dart
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
```

- [ ] **Step 4: Commit**

```bash
git add lib/pages/settings_page.dart
git commit -m "feat: create SettingsPage with 显示 section"
```

---

### Task 2: SettingsPage — login card at top

**Files:**
- Modify: `lib/pages/settings_page.dart`

- [ ] **Step 1: Add login card rendering at top of ListView body**

Insert BEFORE the 显示 section added in Task 1, at the top of `children: [`:

```dart
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (authProvider.isLoggedIn && authProvider.profile != null) {
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
```

- [ ] **Step 2: Commit**

```bash
git add lib/pages/settings_page.dart
git commit -m "feat: add login card to SettingsPage"
```

---

### Task 3: SettingsPage — 社交 section

**Files:**
- Modify: `lib/pages/settings_page.dart`

- [ ] **Step 1: Add imports for social pages at top**

```dart
import '../providers/friend_provider.dart';
import '../providers/shared_mood_provider.dart';
import 'friend_list_page.dart';
import 'friend_request_page.dart';
import 'shared_moods_page.dart';
```

- [ ] **Step 2: Add 社交 section after the 显示 section's Divider**

```dart
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/settings_page.dart
git commit -m "feat: add 社交 section to SettingsPage"
```

---

### Task 4: SettingsPage — AI & 服务 section

**Files:**
- Modify: `lib/pages/settings_page.dart`

- [ ] **Step 1: Add imports for voice and token services**

```dart
import '../services/supabase_service.dart';
import '../services/token_usage_tracker.dart';
import 'voice_sample_page.dart';
```

- [ ] **Step 2: Add AI & 服务 section after 社交 section's Divider**

```dart
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
```

- [ ] **Step 3: Add _showApiKeyDialog method**

```dart
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
```

- [ ] **Step 4: Add _showImportConfigDialog method**

```dart
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
```

- [ ] **Step 5: Add _TokenUsageTile class at bottom of file**

```dart
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
```

- [ ] **Step 6: Add required type imports at top of file**

```dart
import '../services/supabase_service.dart';
import '../services/token_usage_tracker.dart';
```

(Note: `supabase_service.dart` already imported from step 1; `token_usage_tracker.dart` already imported from step 1. Verify both are present.)

- [ ] **Step 7: Commit**

```bash
git add lib/pages/settings_page.dart
git commit -m "feat: add AI & 服务 section to SettingsPage with TokenUsageTile"
```

---

### Task 5: SettingsPage — 数据 section + 退出登录

**Files:**
- Modify: `lib/pages/settings_page.dart`

- [ ] **Step 1: Add imports**

```dart
import '../services/auth_service.dart';
import '../services/remote_mood_service.dart';
```

- [ ] **Step 2: Add 数据 section and logout after AI & 服务 section's Divider**

```dart
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
```

- [ ] **Step 3: Commit**

```bash
git add lib/pages/settings_page.dart
git commit -m "feat: add 数据 section and logout to SettingsPage"
```

---

### Task 6: Simplify ProfilePage — remove moved content

**Files:**
- Modify: `lib/pages/profile_page.dart`

- [ ] **Step 1: Remove unused imports**

Remove these lines from the top of the file:
- `import 'dart:io';`
- `import 'package:cached_network_image/cached_network_image.dart';`
- `import '../enums/message_frequency.dart';`
- `import '../enums/message_log_range.dart';`
- `import '../services/auth_service.dart';`
- `import '../services/remote_mood_service.dart';`
- `import '../providers/friend_provider.dart';`
- `import '../providers/shared_mood_provider.dart';`
- `import 'login_page.dart';`
- `import 'friend_list_page.dart';`
- `import 'friend_request_page.dart';`
- `import 'shared_moods_page.dart';`
- `import '../services/supabase_service.dart';`
- `import '../services/token_usage_tracker.dart';`
- `import 'voice_sample_page.dart';`

Keep:
- `import 'dart:io';` — needed for `File` in _pickChatBackground
- `import 'package:image_picker/image_picker.dart';`
- `import 'package:path_provider/path_provider.dart';`
- `import 'package:provider/provider.dart';`
- `import '../providers/theme_provider.dart';`
- `import '../providers/auth_provider.dart';`
- `import 'personal_info_page.dart';`
- `import '../services/version_service.dart';`
- `import '../widgets/update_dialog.dart';`

Add:
- `import 'settings_page.dart';`

- [ ] **Step 2: Replace the entire build method body**

Replace the current `body: ListView(children: [...])` with:

```dart
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
```

- [ ] **Step 3: Add back needed imports (removed in Step 1 but still needed)**

Ensure these imports are present at top:
```dart
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/remote_mood_service.dart';
import 'login_page.dart';
```

- [ ] **Step 4: Remove all old methods from ProfilePage**

Delete these methods from the class:
- `_showColorPicker`
- `_colorOption`
- `_showApiKeyDialog`
- `_showImportConfigDialog`
- `_showFrequencyPicker`
- `_showLogRangePicker`
- Delete the entire `_TokenUsageTile` class at the bottom of the file

Keep:
- `_getCorrectColor`
- `_checkUpdate`
- `_pickChatBackground`

- [ ] **Step 5: Verify the file compiles**

```bash
cd /home/jason/mood_diary && flutter analyze lib/pages/profile_page.dart lib/pages/settings_page.dart 2>&1 | head -40
```

Fix any compilation errors.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/profile_page.dart lib/pages/settings_page.dart
git commit -m "refactor: simplify ProfilePage to 5 items, extract SettingsPage"
```

---

### Task 7: Expand MessagePage bottom sheet to include log range

**Files:**
- Modify: `lib/pages/message_page.dart`

- [ ] **Step 1: Verify import for MessageLogRange exists**

Check that `import '../enums/message_log_range.dart';` is at the top of the file (line 5). If not, add it.

- [ ] **Step 2: Replace _showFrequencyPicker method with _showMessageSettings**

Replace the method at line 441-477:

```dart
  void _showMessageSettings(BuildContext context, ThemeProvider themeProvider) {
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
              Text('小暖消息设置', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                '小暖会根据这些设置生成和发送消息',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 16),
              Text('消息发送频率',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...MessageFrequency.values.map((frequency) {
                final selected = themeProvider.messageFrequency == frequency;
                return ListTile(
                  title: Text(frequency.label),
                  trailing: selected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () async {
                    await themeProvider.setMessageFrequency(frequency);
                    MessageScheduler.updateFrequency(frequency);
                    await MessageScheduler.triggerCheck(frequency);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const Divider(height: 24),
              Text('消息读取记录范围',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Text(
                '小暖会根据这个范围内的记录生成消息',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
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
```

- [ ] **Step 3: Update the AppBar onPressed to call _showMessageSettings**

Change line ~861 from:
```dart
onPressed: () => _showFrequencyPicker(context, tp),
```
to:
```dart
onPressed: () => _showMessageSettings(context, tp),
```

- [ ] **Step 4: Update the tooltip on the settings icon**

Change line ~860 from:
```dart
tooltip: '设置消息频率',
```
to:
```dart
tooltip: '小暖消息设置',
```

- [ ] **Step 5: Commit**

```bash
git add lib/pages/message_page.dart
git commit -m "feat: add log range to MessagePage settings bottom sheet"
```

---

### Task 8: Add noEssayMode toggle to ChatListPage AppBar

**Files:**
- Modify: `lib/pages/chat_list_page.dart`

- [ ] **Step 1: Update the Selector to include noEssayMode**

Change the Selector at line 205 from:
```dart
          Selector<ThemeProvider, (Color?, Color?, bool)>(
            selector: (_, tp) => (tp.userBubbleColor, tp.otherBubbleColor, tp.luoBoInterventionEnabled),
```
to:
```dart
          Selector<ThemeProvider, (Color?, Color?, bool, bool)>(
            selector: (_, tp) => (tp.userBubbleColor, tp.otherBubbleColor, tp.luoBoInterventionEnabled, tp.noEssayMode),
```

- [ ] **Step 2: Add noEssayMode menu item**

Insert BEFORE the line `const PopupMenuDivider(),` (around line 240):

```dart
                  PopupMenuItem(
                    value: 'no_essay',
                    child: ListTile(
                      leading: Icon(data.$4 ? Icons.chat_bubble : Icons.chat_bubble_outline),
                      title: const Text('防 AI 小作文'),
                      subtitle: const Text('短句口语化回复',
                          style: TextStyle(fontSize: 12)),
                      trailing: Switch(
                        value: data.$4,
                        onChanged: (v) {
                          themeProvider.setNoEssayMode(v);
                          Navigator.pop(context);
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
```

- [ ] **Step 3: Add 'no_essay' case to onSelected switch**

Add to the `onSelected` switch at line 211:
```dart
                    case 'no_essay':
                      themeProvider.setNoEssayMode(!data.$4);
```

Wait — the switch in the PopupMenuItem already handles the toggle inline via its own `onChanged`. So the menu item's `onTap` will fire first (closing the popup), and the Switch's `onChanged` handles the state change. Actually, PopupMenuItem will auto-close when tapped. The Switch inside it has its own onChanged. So the `value: 'no_essay'` and the case in onSelected are actually the way to go for consistency with the existing pattern in this menu.

Actually, looking at the existing code more carefully: the 'luobo_intervention' item has its own inline Switch.onChanged that does the state change AND pops the navigator. The onSelected switch case also handles 'luobo_intervention'. This is a double-handling pattern. Let me follow the same pattern for consistency.

Actually, the cleanest approach: just add the menu item with the Switch inline (like luobo_intervention does), and add the case in onSelected as a fallback.

- [ ] **Step 3 (revised): Add case to onSelected switch**

Add after the `'luobo_intervention'` case:
```dart
                    case 'no_essay':
                      themeProvider.setNoEssayMode(!data.$4);
```

- [ ] **Step 4: Verify the file compiles**

```bash
cd /home/jason/mood_diary && flutter analyze lib/pages/chat_list_page.dart 2>&1 | head -20
```

- [ ] **Step 5: Commit**

```bash
git add lib/pages/chat_list_page.dart
git commit -m "feat: add noEssayMode toggle to ChatListPage popup menu"
```

---

### Task 9: Final verification — full build check

**Files:**
- All modified files

- [ ] **Step 1: Run flutter analyze on all changed files**

```bash
cd /home/jason/mood_diary && flutter analyze lib/pages/profile_page.dart lib/pages/settings_page.dart lib/pages/message_page.dart lib/pages/chat_list_page.dart 2>&1
```

Fix any errors or warnings.

- [ ] **Step 2: Verify profile_page.dart no longer imports unused items**

Ensure no unused import warnings for removed dependencies (friend_provider, shared_mood_provider, supabase_service, token_usage_tracker, voice_sample_page, etc.)

- [ ] **Step 3: Commit any final fixes**

```bash
git add lib/pages/profile_page.dart lib/pages/settings_page.dart lib/pages/message_page.dart lib/pages/chat_list_page.dart
git commit -m "chore: final cleanup after profile page reorganization"
```
