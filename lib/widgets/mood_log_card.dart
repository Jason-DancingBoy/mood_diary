import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood_log.dart';
import '../services/image_manager.dart';
import '../enums/mood_type.dart';
import '../providers/theme_provider.dart';

/// 静态图片路径缓存，避免 FutureBuilder 重复调用
final Map<String, String> _imagePathCache = {};

class MoodLogCard extends StatelessWidget {
  final MoodLog log;
  final VoidCallback onView;
  final ThemeData theme;

  const MoodLogCard({
    super.key,
    required this.log,
    required this.onView,
    required this.theme,
  });

  bool get _isToday {
    final now = DateTime.now();
    return log.createdAt.year == now.year &&
        log.createdAt.month == now.month &&
        log.createdAt.day == now.day;
  }

  String get _timeString {
    if (_isToday) {
      return '今天 ${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';
    }
    return '${log.createdAt.month}/${log.createdAt.day} ${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);

    // 获取正确的文字颜色（本地函数）
    Color getCorrectColor() {
      if (themeProvider.followSystem) {
        // 使用系统主题的文字颜色
        return theme.colorScheme.onSurface;
      } else {
        // 使用自定义的字体颜色
        return themeProvider.fontColor;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: log.mood.bgColor,
      child: InkWell(
        onDoubleTap: onView,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: log.customColor ?? log.mood.color,
            child: log.customEmoji != null
                ? Text(log.customEmoji!, style: const TextStyle(fontSize: 20))
                : Icon(log.mood.icon, color: Colors.white),
          ),
          title: Text(
            log.note,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: getCorrectColor(),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Chip(
                      label: Text(
                        log.displayLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: log.customColor ?? log.mood.color,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeString,
                      style: TextStyle(
                        fontSize: 12,
                        color: getCorrectColor().withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (log.comment.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '批注: ${log.comment.length > 30 ? '${log.comment.substring(0, 30)}...' : log.comment}',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: getCorrectColor().withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
          trailing: log.imageFileNames != null && log.imageFileNames!.isNotEmpty
              ? _buildImagePreview(log.imageFileName!, log.imageCount, theme)
              : IconButton(
                  icon: const Icon(Icons.visibility_outlined),
                  color: theme.colorScheme.primary,
                  onPressed: onView,
                  tooltip: '查看详情/批注',
                ),
        ),
      ),
    );
  }

  /// 构建图片预览，使用缓存路径
  Widget _buildImagePreview(String fileName, int imageCount, ThemeData theme) {
    String cachedPath = _imagePathCache[fileName] ?? ImageManager.getImagePath(fileName);

    // 缓存路径
    _imagePathCache[fileName] = cachedPath;

    if (cachedPath.isNotEmpty && File(cachedPath).existsSync()) {
      return Stack(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(
                File(cachedPath),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 96, // 限制图片尺寸，减少内存占用
              ),
            ),
          ),
          if (imageCount > 1)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$imageCount',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (imageCount == 1)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.photo_size_select_actual_outlined,
                  size: 12,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
        ],
      );
    }
    return const Icon(Icons.visibility_outlined);
  }
}
