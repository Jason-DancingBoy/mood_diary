import 'mood_record.dart';

class SharedMood {
  final String id;
  final String fromUserId;
  final String fromUserNickname;
  final String? fromUserAvatarUrl;
  final String toUserId;
  final String moodId;
  final String permission;
  final String status;
  final DateTime sharedAt;
  final DateTime? readAt;
  final MoodRecord? mood;

  SharedMood({
    required this.id,
    required this.fromUserId,
    required this.fromUserNickname,
    this.fromUserAvatarUrl,
    required this.toUserId,
    required this.moodId,
    this.permission = 'view',
    this.status = 'sent',
    required this.sharedAt,
    this.readAt,
    this.mood,
  });

  bool get isRead => readAt != null;

  factory SharedMood.fromMap(Map<String, dynamic> map) {
    MoodRecord? mood;
    if (map['mood'] != null) {
      mood = MoodRecord.fromMap(map['mood'] as Map<String, dynamic>);
    }

    String fromNickname = '';
    String? fromAvatar;
    if (map['from_user'] != null) {
      final fu = map['from_user'] as Map<String, dynamic>;
      fromNickname = (fu['nickname'] as String?) ?? '';
      fromAvatar = fu['avatar_url'] as String?;
    }

    return SharedMood(
      id: map['id'] as String,
      fromUserId: map['from_user_id'] as String,
      fromUserNickname: fromNickname,
      fromUserAvatarUrl: fromAvatar,
      toUserId: map['to_user_id'] as String,
      moodId: map['mood_id'] as String,
      permission: (map['permission'] as String?) ?? 'view',
      status: (map['status'] as String?) ?? 'sent',
      sharedAt: DateTime.parse(map['shared_at'] as String),
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      mood: mood,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'mood_id': moodId,
      'permission': permission,
      'status': status,
    };
  }
}
