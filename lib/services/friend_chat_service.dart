import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';
import 'supabase_service.dart';
import 'notification_service.dart';

class FriendChatService {
  FriendChatService._();

  static String get _currentUserId => SupabaseService.auth.currentUser!.id;

  /// 未读消息的好友 ID 集合
  static final unreadFriendIds = ValueNotifier<Set<String>>({});

  // --- 持久化 ---

  static const _metaBoxName = 'friend_chat_meta_box';
  static const _unreadKey = 'unread_friend_ids';
  static const _lastSeenKey = 'last_seen_timestamps';

  static Box<dynamic> get _metaBox => Hive.box<dynamic>(_metaBoxName);

  static Future<void> _saveUnreadState() async {
    await _metaBox.put(_unreadKey, unreadFriendIds.value.toList());
  }

  static void _loadUnreadState() {
    final list = _metaBox.get(_unreadKey) as List<dynamic>?;
    if (list != null && list.isNotEmpty) {
      unreadFriendIds.value = list.cast<String>().toSet();
    }
  }

  /// 供 ChatListPage 初始化时调用：恢复持久化的未读状态
  static void restoreUnreadState() {
    _loadUnreadState();
  }

  /// 合并离线检测到的未读消息
  static Future<void> mergeUnread(Set<String> friendIds) async {
    if (friendIds.isEmpty) return;
    unreadFriendIds.value = {...unreadFriendIds.value, ...friendIds};
    await _saveUnreadState();
  }

  /// 清除某好友的未读标记并持久化
  static Future<void> clearUnreadFor(String friendId) async {
    if (!unreadFriendIds.value.contains(friendId)) return;
    unreadFriendIds.value = {...unreadFriendIds.value}..remove(friendId);
    await _saveUnreadState();
  }

  /// 记录用户进入某好友聊天页的时间
  static Future<void> updateLastSeen(String friendId) async {
    final timestamps = _metaBox.get(_lastSeenKey) as Map<dynamic, dynamic>?;
    final map = Map<String, String>.from(
      timestamps?.map((k, v) => MapEntry(k.toString(), v.toString())) ?? {},
    );
    map[friendId] = DateTime.now().toUtc().toIso8601String();
    await _metaBox.put(_lastSeenKey, map);
  }

  /// 获取所有好友的最后查看时间
  static Map<String, DateTime> getLastSeenTimestamps() {
    final timestamps = _metaBox.get(_lastSeenKey) as Map<dynamic, dynamic>?;
    if (timestamps == null) return {};
    final result = <String, DateTime>{};
    for (final entry in timestamps.entries) {
      final key = entry.key.toString();
      final value = entry.value?.toString();
      if (value != null) {
        final dt = DateTime.tryParse(value);
        if (dt != null) result[key] = dt;
      }
    }
    return result;
  }

  /// 检查好友是否有新消息（自 last_seen 以来），用于启动时检测离线消息
  static Future<Set<String>> checkOfflineMessages(List<String> friendIds) async {
    final lastSeen = getLastSeenTimestamps();
    final unread = <String>{};
    for (final friendId in friendIds) {
      final since = lastSeen[friendId];
      if (since == null) continue; // 没有基准时间，跳过
      try {
        final response = await SupabaseService.friendMessages
            .select('id, sender_id, receiver_id, is_ai_message')
            .or('sender_id.eq.$_currentUserId,receiver_id.eq.$_currentUserId')
            .gt('created_at', since.toUtc().toIso8601String())
            .limit(1);
        if (response is! List) continue;
        for (final row in response) {
          final map = row as Map<String, dynamic>;
          final senderId = map['sender_id'] as String;
          final receiverId = map['receiver_id'] as String;
          final isAi = map['is_ai_message'] as bool? ?? false;
          if (isAi) continue;
          if ((senderId == _currentUserId && receiverId == friendId) ||
              (senderId == friendId && receiverId == _currentUserId)) {
            // 好友发来的消息才算未读
            if (senderId == friendId) {
              unread.add(friendId);
            }
          }
        }
      } catch (_) {
        // 查询失败静默跳过
      }
    }
    return unread;
  }

  // --- 全局持久订阅（用于通知） ---

  static RealtimeChannel? _globalChannel;

  /// 启动全局订阅：监听所有发给当前用户的好友消息，不在聊天页时弹通知
  static void startGlobalSubscription() {
    stopGlobalSubscription();
    _loadUnreadState();

    _globalChannel = SupabaseService.client
        .channel('global_friend_messages_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friend_messages',
          callback: (payload) {
            final record = payload.newRecord;
            final senderId = record['sender_id'] as String?;
            final receiverId = record['receiver_id'] as String?;
            if (senderId == null || receiverId == null) return;
            // 只处理发给当前用户的非 AI 消息
            if (receiverId != _currentUserId) return;
            final isAi = record['is_ai_message'] as bool? ?? false;
            if (isAi) return;

            // 当前正在看该好友的聊天页 → 不弹通知，不标未读
            if (NotificationService.activeChatFriendId == senderId) return;

            // 标记未读并持久化
            unreadFriendIds.value = {...unreadFriendIds.value, senderId};
            _saveUnreadState();

            _showNotificationForMessage(senderId, record['content'] as String? ?? '');
          },
        )
        .subscribe();
  }

  static Future<void> _showNotificationForMessage(String friendId, String content) async {
    // 查找好友昵称
    try {
      final response = await SupabaseService.client
          .from('profiles')
          .select('nickname, avatar_url')
          .eq('id', friendId)
          .single();
      final profile = response as Map<String, dynamic>;
      final nickname = profile['nickname'] as String? ?? '好友';
      final avatarUrl = profile['avatar_url'] as String?;

      var displayContent = content;
      if (displayContent.isEmpty) {
        // 可能是图片或语音消息
        displayContent = '[图片/语音]';
      }

      await NotificationService.showMessageNotification(
        friendName: nickname,
        message: displayContent,
        friendId: friendId,
        avatarUrl: avatarUrl,
      );
    } catch (_) {
      // 查不到 profile 也弹通知
      await NotificationService.showMessageNotification(
        friendName: '好友',
        message: content.isNotEmpty ? content : '[新消息]',
        friendId: friendId,
      );
    }
  }

  static void stopGlobalSubscription() {
    _globalChannel?.unsubscribe();
    _globalChannel = null;
  }

  // --- Realtime 订阅（用于聊天页 UI 实时更新） ---

  static RealtimeChannel? _channel;
  static String? _subscribedFriendId;

  /// 订阅与指定好友的新消息（Realtime WebSocket 推送）
  static void subscribeToMessages(
    String friendId,
    void Function(ChatMessage) onNewMessage,
  ) {
    unsubscribe();
    _subscribedFriendId = friendId;

    _channel = SupabaseService.client
        .channel('friend_messages_${friendId}_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friend_messages',
          callback: (payload) {
            final record = payload.newRecord;
            final senderId = record['sender_id'] as String?;
            final receiverId = record['receiver_id'] as String?;
            // 只处理当前用户和该好友之间的消息
            if (senderId == null || receiverId == null) return;
            if (!((senderId == _currentUserId && receiverId == friendId) ||
                (senderId == friendId && receiverId == _currentUserId))) {
              return;
            }

            final isAi = record['is_ai_message'] as bool? ?? false;
            final msg = ChatMessage(
              isUser: isAi ? false : senderId == _currentUserId,
              id: record['id'] as String?,
              content: record['content'] as String? ?? '',
              imageUrl: record['image_url'] as String?,
              audioUrl: record['audio_url'] as String?,
              audioDuration: record['audio_duration'] as int?,
              timestamp: DateTime.parse(record['created_at'] as String),
              isAiMessage: isAi,
              senderName: isAi ? '魔魔胡胡胡萝卜' : null,
              showSenderHeader: isAi,
              senderAvatarAssetPath: isAi ? 'assets/carrot.jpg' : null,
            );
            onNewMessage(msg);
          },
        )
        .subscribe((status, _) {
          // debugPrint('[Realtime] friend_messages status=$status');
        });
  }

  /// 取消订阅
  static void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
    _subscribedFriendId = null;
  }

  static Future<void> sendMessage(String receiverId, String content,
      {String? imageUrl, String? audioUrl, int? audioDuration, bool isAiMessage = false}) async {
    final data = <String, dynamic>{
      'sender_id': _currentUserId,
      'receiver_id': receiverId,
      'content': content,
      'is_ai_message': isAiMessage,
    };
    if (imageUrl != null) data['image_url'] = imageUrl;
    if (audioUrl != null) {
      data['audio_url'] = audioUrl;
      if (audioDuration != null) data['audio_duration'] = audioDuration;
    }
    await SupabaseService.friendMessages.insert(data);
  }

  static Future<void> deleteMessage(String messageId) async {
    await SupabaseService.friendMessages
        .delete()
        .eq('id', messageId)
        .eq('sender_id', _currentUserId);
  }

  static Future<void> updateMessage(String messageId, String newContent) async {
    await SupabaseService.friendMessages
        .update({'content': newContent})
        .eq('id', messageId)
        .eq('sender_id', _currentUserId);
  }

  static Future<List<ChatMessage>> getMessages(String friendId) async {
    final response = await SupabaseService.friendMessages
        .select('id, sender_id, receiver_id, content, image_url, audio_url, audio_duration, is_ai_message, created_at, sender:profiles!friend_messages_sender_id_fkey(nickname)')
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
        final isAi = map['is_ai_message'] as bool? ?? false;
        messages.add(ChatMessage(
          isUser: isAi ? false : senderId == _currentUserId,
          id: map['id'] as String?,
          content: map['content'] as String? ?? '',
          imageUrl: map['image_url'] as String?,
          audioUrl: map['audio_url'] as String?,
          audioDuration: map['audio_duration'] as int?,
          timestamp: DateTime.parse(map['created_at'] as String),
          senderName: isAi
              ? '魔魔胡胡胡萝卜'
              : (senderId == _currentUserId
                  ? null
                  : (senderProfile?['nickname'] as String?)),
          showSenderHeader: isAi,
          senderAvatarAssetPath: isAi ? 'assets/carrot.jpg' : null,
          isAiMessage: isAi,
        ));
      }
    }
    return messages;
  }

  static Future<List<ChatMessage>> getNewMessages(
      String friendId, DateTime since) async {
    final response = await SupabaseService.friendMessages
        .select('id, sender_id, receiver_id, content, image_url, audio_url, audio_duration, is_ai_message, created_at, sender:profiles!friend_messages_sender_id_fkey(nickname)')
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
        final isAi = map['is_ai_message'] as bool? ?? false;
        messages.add(ChatMessage(
          isUser: isAi ? false : senderId == _currentUserId,
          id: map['id'] as String?,
          content: map['content'] as String? ?? '',
          imageUrl: map['image_url'] as String?,
          audioUrl: map['audio_url'] as String?,
          audioDuration: map['audio_duration'] as int?,
          timestamp: DateTime.parse(map['created_at'] as String),
          senderName: isAi
              ? '魔魔胡胡胡萝卜'
              : (senderId == _currentUserId
                  ? null
                  : (senderProfile?['nickname'] as String?)),
          showSenderHeader: isAi,
          senderAvatarAssetPath: isAi ? 'assets/carrot.jpg' : null,
          isAiMessage: isAi,
        ));
      }
    }
    return messages;
  }
}
