class ChatMessage {
  final bool isUser;
  final String? id;
  final String content;
  final String? imageUrl;
  final String? audioUrl;
  final int? audioDuration; // 语音时长（秒）
  final DateTime timestamp;
  final String? senderName;
  final bool showSenderHeader;
  final String? senderEmoji;
  final String? senderAvatarAssetPath;
  final bool isAiMessage;

  ChatMessage({
    required this.isUser,
    this.id,
    required this.content,
    this.imageUrl,
    this.audioUrl,
    this.audioDuration,
    required this.timestamp,
    this.senderName,
    this.showSenderHeader = false,
    this.senderEmoji,
    this.senderAvatarAssetPath,
    this.isAiMessage = false,
  });

  bool get isVoiceMessage => audioUrl != null;

  factory ChatMessage.fromList(List list) {
    final isNewFormat = list.length >= 8;
    final isV2Format = list.length >= 9;
    final isV3Format = list.length >= 11;
    final isV4Format = list.length >= 12;
    return ChatMessage(
      isUser: list[0] as bool,
      content: list[1] as String,
      timestamp: DateTime.parse(list[2] as String),
      id: isNewFormat
          ? ((list[3] as String).isEmpty ? null : list[3] as String)
          : null,
      senderName: isNewFormat
          ? ((list[4] as String).isEmpty ? null : list[4] as String)
          : (list.length > 3 ? list[3] as String? : null),
      imageUrl: isNewFormat
          ? ((list[5] as String).isEmpty ? null : list[5] as String)
          : (list.length > 4 ? list[4] as String? : null),
      audioUrl: isNewFormat
          ? ((list[6] as String).isEmpty ? null : list[6] as String)
          : (list.length > 5 ? list[5] as String? : null),
      audioDuration: isNewFormat
          ? ((list[7] as int) == 0 ? null : list[7] as int)
          : (list.length > 6 ? list[6] as int? : null),
      showSenderHeader: isV2Format ? (list[8] as bool) : false,
      senderEmoji: isV3Format
          ? ((list[9] as String).isEmpty ? null : list[9] as String)
          : null,
      senderAvatarAssetPath: isV3Format
          ? ((list[10] as String).isEmpty ? null : list[10] as String)
          : null,
      isAiMessage: isV4Format ? (list[11] as bool) : false,
    );
  }

  List<dynamic> toList() {
    return [
      isUser,
      content,
      timestamp.toIso8601String(),
      id ?? '',
      senderName ?? '',
      imageUrl ?? '',
      audioUrl ?? '',
      audioDuration ?? 0,
      showSenderHeader,
      senderEmoji ?? '',
      senderAvatarAssetPath ?? '',
      isAiMessage,
    ];
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String currentUserId) {
    final isAi = map['is_ai_message'] as bool? ?? false;
    final isUser = isAi ? false : map['sender_id'] == currentUserId;
    return ChatMessage(
      isUser: isUser,
      id: map['id'] as String?,
      content: map['content'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
      audioUrl: map['audio_url'] as String?,
      audioDuration: map['audio_duration'] as int?,
      timestamp: DateTime.parse(map['created_at'] as String),
      senderName: isUser ? null : (map['sender_nickname'] as String?),
      isAiMessage: map['is_ai_message'] as bool? ?? false,
    );
  }
}
