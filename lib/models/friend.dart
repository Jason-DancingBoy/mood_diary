enum FriendStatus { pending, accepted, rejected }

class Friend {
  final String id;
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final FriendStatus status;
  final DateTime createdAt;

  Friend({
    required this.id,
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.status,
    required this.createdAt,
  });

  factory Friend.fromMap(Map<String, dynamic> map) {
    return Friend(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      nickname: map['nickname'] as String,
      avatarUrl: map['avatar_url'] as String?,
      status: FriendStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => FriendStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'nickname': nickname,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
