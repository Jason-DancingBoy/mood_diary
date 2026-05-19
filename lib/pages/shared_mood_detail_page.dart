import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import '../models/shared_mood.dart';
import '../enums/mood_type.dart';
import '../providers/theme_provider.dart';
import 'full_screen_image_view.dart';
import '../utils/page_transitions.dart';

class SharedMoodDetailPage extends StatefulWidget {
  final SharedMood sharedMood;

  const SharedMoodDetailPage({super.key, required this.sharedMood});

  @override
  State<SharedMoodDetailPage> createState() => _SharedMoodDetailPageState();
}

class _SharedMoodDetailPageState extends State<SharedMoodDetailPage> {
  bool _preloaded = false;

  @override
  void initState() {
    super.initState();
    _preloadImages();
  }

  /// 预加载所有图片到缓存，确保打开详情页时图片立即可见
  void _preloadImages() {
    final urls = widget.sharedMood.mood?.imageUrls ?? [];
    if (urls.isEmpty) {
      _preloaded = true;
      return;
    }
    Future.wait(urls.map((url) {
      return DefaultCacheManager().downloadFile(url).then((_) {}).catchError((_) {});
    })).then((_) {
      if (mounted) setState(() => _preloaded = true);
    });
  }

  Color _getCorrectColor(bool followSystem, Color fontColor, ThemeData theme) {
    if (followSystem) {
      return theme.colorScheme.onSurface;
    }
    return fontColor;
  }

  MoodType get _moodType {
    if (widget.sharedMood.mood == null) return MoodType.calm;
    return MoodType.values.firstWhere(
      (e) => e.name == widget.sharedMood.mood!.moodType,
      orElse: () => MoodType.calm,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarColor =
        theme.colorScheme.inversePrimary ?? theme.colorScheme.primary;
    final appBarTextColor =
        theme.colorScheme.onPrimaryContainer ?? Colors.white;
    final mood = widget.sharedMood.mood;

    return Selector<ThemeProvider, (bool, Color)>(
      selector: (_, tp) => (tp.followSystem, tp.fontColor),
      builder: (context, tp, child) {
        return Scaffold(
      appBar: AppBar(
        title: Text('来自 ${widget.sharedMood.fromUserNickname} 的分享'),
        backgroundColor: appBarColor,
        foregroundColor: appBarTextColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sender info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                      child: Text(
                        widget.sharedMood.fromUserNickname.isNotEmpty
                            ? widget.sharedMood.fromUserNickname[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color:
                              theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sharedMood.fromUserNickname,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color:
                                _getCorrectColor(tp.$1, tp.$2, theme),
                          ),
                        ),
                        Text(
                          '${widget.sharedMood.sharedAt.year}/${widget.sharedMood.sharedAt.month}/${widget.sharedMood.sharedAt.day} ${widget.sharedMood.sharedAt.hour}:${widget.sharedMood.sharedAt.minute.toString().padLeft(2, '0')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Mood card
            if (mood != null) ...[
              Card(
                color: _moodType.bgColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: mood.customColorValue != null
                                ? Color(mood.customColorValue!)
                                : _moodType.color,
                            child: mood.customEmoji != null
                                ? Text(mood.customEmoji!,
                                    style: const TextStyle(fontSize: 24))
                                : Icon(_moodType.icon,
                                    color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            mood.customEmojiLabel ??
                                _moodType.label,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getCorrectColor(
                                  tp.$1, tp.$2, theme),
                            ),
                          ),
                        ],
                      ),
                      if (mood.note.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          '笔记:',
                          style:
                              theme.textTheme.titleMedium?.copyWith(
                            color: _getCorrectColor(
                                tp.$1, tp.$2, theme),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          mood.note,
                          style: TextStyle(
                            fontSize: 16,
                            color: _getCorrectColor(
                                tp.$1, tp.$2, theme),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text(
                        '日期: ${mood.createdAt.toString()}',
                        style: TextStyle(
                          color: _getCorrectColor(tp.$1, tp.$2, theme)
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Images
              if (mood.imageUrls.isNotEmpty) ...[
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 16) / 3;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(
                        mood.imageUrls.length,
                        (index) => SizedBox(
                          width: itemWidth,
                          height: itemWidth,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                FadeScalePageRoute(
                                  builder: (_) => FullScreenImageView(
                                    imagePath: mood.imageUrls[index],
                                    imageUrls: mood.imageUrls,
                                    initialIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: mood.imageUrls[index],
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) =>
                                    Container(
                                  color: theme
                                      .colorScheme.surfaceContainerHighest,
                                  child:
                                      const Icon(Icons.broken_image),
                                ),
                                placeholder: _preloaded
                                    ? (context, url) =>
                                        const SizedBox.shrink()
                                    : (context, url) => Container(
                                          color: theme
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          child: const Center(
                                            child:
                                                CircularProgressIndicator(),
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],

              // AI comfort
              if (mood.aiComfort != null &&
                  mood.aiComfort!.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.purple.shade700
                            .withValues(alpha: 0.3)
                        : Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color:
                                theme.brightness == Brightness.dark
                                    ? Colors.purple.shade200
                                    : Colors.purple.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '小暖对你说',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color:
                                  theme.brightness == Brightness.dark
                                      ? Colors.purple.shade200
                                      : Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        mood.aiComfort!,
                        style: TextStyle(
                          fontSize: 14,
                          color: _getCorrectColor(
                              tp.$1, tp.$2, theme),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
    },
  );
  }
}
