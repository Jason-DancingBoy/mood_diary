import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mood_log.dart';
import '../services/image_manager.dart';
import '../enums/mood_type.dart';
import '../enums/mood_quadrant.dart';
import '../providers/theme_provider.dart';

/// 静态图片路径缓存，避免 FutureBuilder 重复调用
final Map<String, String> _imagePathCache = {};

class MoodLogCard extends StatefulWidget {
  final MoodLog log;
  final VoidCallback onView;
  final ThemeData theme;
  final VoidCallback onTogglePrivacy;

  const MoodLogCard({
    super.key,
    required this.log,
    required this.onView,
    required this.theme,
    required this.onTogglePrivacy,
  });

  @override
  State<MoodLogCard> createState() => _MoodLogCardState();
}

class _MoodLogCardState extends State<MoodLogCard> {
  late bool _isPrivate;

  @override
  void initState() {
    super.initState();
    _isPrivate = widget.log.isPrivate;
  }

  @override
  void didUpdateWidget(covariant MoodLogCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log.id != widget.log.id ||
        oldWidget.log.isPrivate != widget.log.isPrivate) {
      _isPrivate = widget.log.isPrivate;
    }
  }

  void _togglePrivacy() {
    setState(() => _isPrivate = !_isPrivate);
    widget.onTogglePrivacy();
  }

  bool get _isToday {
    final now = DateTime.now();
    return widget.log.createdAt.year == now.year &&
        widget.log.createdAt.month == now.month &&
        widget.log.createdAt.day == now.day;
  }

  String get _timeString {
    if (_isToday) {
      return '今天 ${widget.log.createdAt.hour.toString().padLeft(2, '0')}:${widget.log.createdAt.minute.toString().padLeft(2, '0')}';
    }
    return '${widget.log.createdAt.month}/${widget.log.createdAt.day} ${widget.log.createdAt.hour.toString().padLeft(2, '0')}:${widget.log.createdAt.minute.toString().padLeft(2, '0')}';
  }

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
    final textColor = _getCorrectColor(themeProvider, theme);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: widget.log.mood.bgColor,
      child: InkWell(
        onTap: widget.onView,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: widget.log.customColor ?? widget.log.mood.color,
            child: widget.log.customEmoji != null
                ? Text(widget.log.customEmoji ?? '',
                    style: const TextStyle(fontSize: 20))
                : Icon(widget.log.mood.icon, color: Colors.white),
          ),
          title: _PrivateText(
            private: _isPrivate,
            child: Text(
              widget.log.note,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          subtitle: _PrivateText(
            private: _isPrivate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Chip(
                        label: Text(
                          widget.log.displayLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor:
                            widget.log.customColor ?? widget.log.mood.color,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      if (widget.log.energy != null && widget.log.pleasantness != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: MoodQuadrant.fromEnergyPleasantness(
                              widget.log.energy!, widget.log.pleasantness!,
                            ).color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(
                        _timeString,
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.log.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '批注: ${widget.log.comment.length > 30 ? '${widget.log.comment.substring(0, 30)}...' : widget.log.comment}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: IconButton(
            icon: Icon(
              _isPrivate
                  ? Icons.visibility_off
                  : Icons.visibility_outlined,
            ),
            color: _isPrivate
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            onPressed: _togglePrivacy,
            tooltip: _isPrivate ? '取消隐私' : '设为隐私',
          ),
        ),
      ),
    );
  }
}

/// 隐私模式下对文字做模糊处理
class _PrivateText extends StatelessWidget {
  final bool private;
  final Widget child;

  const _PrivateText({required this.private, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!private) return child;
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: child,
    );
  }
}
