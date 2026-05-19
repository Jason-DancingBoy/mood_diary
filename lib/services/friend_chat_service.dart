import '../models/chat_message.dart';
import 'supabase_service.dart';

class FriendChatService {
  FriendChatService._();

  static String get _currentUserId => SupabaseService.auth.currentUser!.id;

  static Future<void> sendMessage(String receiverId, String content,
      {String? imageUrl}) async {
    final data = <String, dynamic>{
      'sender_id': _currentUserId,
      'receiver_id': receiverId,
      'content': content,
    };
    if (imageUrl != null) data['image_url'] = imageUrl;
    await SupabaseService.friendMessages.insert(data);
  }

  static Future<List<ChatMessage>> getMessages(String friendId) async {
    final response = await SupabaseService.friendMessages
        .select('id, sender_id, receiver_id, content, image_url, created_at, sender:profiles!friend_messages_sender_id_fkey(nickname)')
        .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId')
        .order('created_at', ascending: true);

    final messages = <ChatMessage>[];
    for (final row in (response as List)) {
      final map = row as Map<String, dynamic>;
      final senderId = map['sender_id'] as String;
      final receiverId = map['receiver_id'] as String;
      if ((senderId == _currentUserId && receiverId == friendId) ||
          (senderId == friendId && receiverId == _currentUserId)) {
        final senderProfile = map['sender'] as Map<String, dynamic>?;
        messages.add(ChatMessage(
          isUser: senderId == _currentUserId,
          content: map['content'] as String,
          imageUrl: map['image_url'] as String?,
          timestamp: DateTime.parse(map['created_at'] as String),
          senderName: senderId == _currentUserId
              ? null
              : (senderProfile?['nickname'] as String?),
        ));
      }
    }
    return messages;
  }

  static Future<List<ChatMessage>> getNewMessages(
      String friendId, DateTime since) async {
    final response = await SupabaseService.friendMessages
        .select('id, sender_id, receiver_id, content, image_url, created_at, sender:profiles!friend_messages_sender_id_fkey(nickname)')
        .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId')
        .gt('created_at', since.toUtc().toIso8601String())
        .order('created_at', ascending: true);

    final messages = <ChatMessage>[];
    for (final row in (response as List)) {
      final map = row as Map<String, dynamic>;
      final senderId = map['sender_id'] as String;
      final receiverId = map['receiver_id'] as String;
      if ((senderId == _currentUserId && receiverId == friendId) ||
          (senderId == friendId && receiverId == _currentUserId)) {
        final senderProfile = map['sender'] as Map<String, dynamic>?;
        messages.add(ChatMessage(
          isUser: senderId == _currentUserId,
          content: map['content'] as String,
          imageUrl: map['image_url'] as String?,
          timestamp: DateTime.parse(map['created_at'] as String),
          senderName: senderId == _currentUserId
              ? null
              : (senderProfile?['nickname'] as String?),
        ));
      }
    }
    return messages;
  }
}
