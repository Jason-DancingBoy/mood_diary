class UserProfile {
  final String id;
  final String nickname;
  final String friendCode;
  final String? avatarUrl;
  final String? bio;
  final bool showMoodToFriends;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.nickname,
    required this.friendCode,
    this.avatarUrl,
    this.bio,
    this.showMoodToFriends = true,
    required this.createdAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      nickname: map['nickname'] as String,
      friendCode: map['friend_code'] as String,
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
      showMoodToFriends: (map['show_mood_to_friends'] as bool?) ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'friend_code': friendCode,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'bio': bio ?? '',
    };
  }
}
