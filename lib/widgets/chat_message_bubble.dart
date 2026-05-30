import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ThemeData theme;
  final int index;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onLongPress;
  final void Function(LongPressStartDetails)? onLongPressStart;
  final VoidCallback? onTap;
  final void Function(String imageUrl)? onImageTap;
  final VoidCallback? onVoiceTap;
  final bool isVoicePlaying;
  final String aiName;
  final String aiEmoji;
  final String? aiAvatarAssetPath;
  final bool showSenderHeader;
  final Color? userBubbleColor;
  final Color? otherBubbleColor;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.theme,
    required this.index,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onLongPress,
    this.onLongPressStart,
    this.onTap,
    this.onImageTap,
    this.onVoiceTap,
    this.isVoicePlaying = false,
    this.aiName = '小暖',
    this.aiEmoji = '🌻',
    this.aiAvatarAssetPath,
    this.showSenderHeader = true,
    this.userBubbleColor,
    this.otherBubbleColor,
  });

  Widget _buildImage(double maxWidth) {
    return GestureDetector(
      onTap: () => onImageTap?.call(message.imageUrl!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: message.imageUrl!,
          width: maxWidth * 0.8,
          height: 200,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: maxWidth * 0.8,
            height: 200,
            color: Colors.grey.withValues(alpha: 0.2),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (context, url, error) => Container(
            width: maxWidth * 0.8,
            height: 120,
            color: Colors.grey.withValues(alpha: 0.1),
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      ),
    );
  }

  /// 语音消息气泡
  Widget _buildVoiceBubble(Color textColor) {
    final duration = message.audioDuration ?? 0;
    final isMe = message.isUser;
    return GestureDetector(
      onTap: onVoiceTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isMe) ...[
            Text('${duration}s', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
            const SizedBox(width: 8),
            Icon(
              isVoicePlaying ? Icons.pause : Icons.play_arrow,
              color: textColor,
              size: 22,
            ),
          ] else ...[
            Icon(
              isVoicePlaying ? Icons.pause : Icons.play_arrow,
              color: textColor,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text('${duration}s', style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
          ],
          // 简易波形条
          ...List.generate(4, (i) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 3,
              height: 8.0 + (i % 3) * 4.0,
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: isVoicePlaying ? 0.9 : 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble(context);
    } else {
      return _buildOtherBubble(context);
    }
  }

  Widget _buildUserBubble(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    return GestureDetector(
      onLongPress: onLongPressStart != null ? null : onLongPress,
      onLongPressStart: onLongPressStart,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSelectionMode)
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap?.call(),
              activeColor: theme.colorScheme.primary,
            ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                color: userBubbleColor ?? theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(18)
                    .copyWith(bottomRight: const Radius.circular(4)),
                border: isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.imageUrl != null) ...[
                    _buildImage(maxWidth),
                    if (message.content.isNotEmpty || message.isVoiceMessage) const SizedBox(height: 8),
                  ],
                  if (message.isVoiceMessage)
                    _buildVoiceBubble(Colors.white)
                  else if (message.content.isNotEmpty)
                    Text(message.content, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherBubble(BuildContext context) {
    final name = message.isAiMessage
        ? '魔魔胡胡胡萝卜'
        : (message.senderName ?? aiName);
    final emoji = message.isAiMessage
        ? ''
        : (message.senderEmoji ?? aiEmoji);
    final avatarPath = message.isAiMessage
        ? 'assets/carrot.jpg'
        : (message.senderAvatarAssetPath ?? aiAvatarAssetPath);
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    return GestureDetector(
      onLongPress: onLongPressStart != null ? null : onLongPress,
      onLongPressStart: onLongPressStart,
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSelectionMode)
            Checkbox(
              value: isSelected,
              onChanged: (_) => onTap?.call(),
              activeColor: theme.colorScheme.primary,
            ),
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              constraints: BoxConstraints(maxWidth: maxWidth),
              decoration: BoxDecoration(
                color: otherBubbleColor ?? theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18)
                    .copyWith(bottomLeft: const Radius.circular(4)),
                border: isSelected
                    ? Border.all(color: theme.colorScheme.primary, width: 2)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSenderHeader || message.showSenderHeader || message.isAiMessage) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (avatarPath != null)
                          ClipOval(
                            child: Image.asset(
                              avatarPath,
                              width: 18,
                              height: 18,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Text(emoji, style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (message.imageUrl != null) ...[
                    _buildImage(maxWidth),
                    if (message.content.isNotEmpty || message.isVoiceMessage) const SizedBox(height: 8),
                  ],
                  if (message.isVoiceMessage)
                    _buildVoiceBubble(theme.colorScheme.onSurface)
                  else if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    final now = DateTime.now();
    final diff = now.difference(localTime);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${localTime.month}/${localTime.day} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
