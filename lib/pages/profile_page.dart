import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../enums/message_frequency.dart';
import '../enums/message_log_range.dart';
import '../providers/theme_provider.dart';

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
            onTap: themeProvider.followSystem 
                ? null  // 跟随系统开启时禁用字体颜色设置
                : () => _showColorPicker(context, themeProvider),
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
