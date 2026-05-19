class ChatMessage {
  final bool isUser;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;
  final String? senderName;

  ChatMessage({
    required this.isUser,
    required this.content,
    this.imageUrl,
    required this.timestamp,
    this.senderName,
  });

  factory ChatMessage.fromList(List list) {
    return ChatMessage(
      isUser: list[0] as bool,
      content: list[1] as String,
      timestamp: DateTime.parse(list[2] as String),
      senderName: list.length > 3 ? list[3] as String? : null,
      imageUrl: list.length > 4 ? list[4] as String? : null,
    );
  }

  List<dynamic> toList() {
    return [
      isUser,
      content,
      timestamp.toIso8601String(),
      if (senderName != null) senderName,
      if (imageUrl != null) imageUrl,
    ];
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String currentUserId) {
    final isUser = map['sender_id'] == currentUserId;
    return ChatMessage(
      isUser: isUser,
      content: map['content'] as String,
      imageUrl: map['image_url'] as String?,
      timestamp: DateTime.parse(map['created_at'] as String),
      senderName: isUser ? null : (map['sender_nickname'] as String?),
    );
  }
}
