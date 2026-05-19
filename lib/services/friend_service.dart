import '../models/user_profile.dart';
import '../models/friend.dart';
import 'supabase_service.dart';

class FriendService {
  FriendService._();

  static Future<List<UserProfile>> searchUsers(String query) async {
    final response = await SupabaseService.profiles
        .select()
        .ilike('nickname', '%$query%')
        .limit(20);
    return (response as List)
        .map((e) => UserProfile.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<UserProfile?> searchByFriendCode(String code) async {
    final response = await SupabaseService.profiles
        .select()
        .eq('friend_code', code.toUpperCase())
        .maybeSingle();
    if (response == null) return null;
    return UserProfile.fromMap(response as Map<String, dynamic>);
  }

  static Future<void> sendRequest(String addresseeId) async {
    final requesterId = SupabaseService.auth.currentUser!.id;
    await SupabaseService.friends.insert({
      'requester_id': requesterId,
      'addressee_id': addresseeId,
      'status': 'pending',
    });
  }

  static Future<void> acceptRequest(String friendshipId) async {
    await SupabaseService.friends
        .update({'status': 'accepted', 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', friendshipId);
  }

  static Future<void> rejectRequest(String friendshipId) async {
    await SupabaseService.friends
        .update({'status': 'rejected', 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', friendshipId);
  }

  static Future<void> removeFriend(String friendshipId) async {
    await SupabaseService.friends.delete().eq('id', friendshipId);
  }

  static Future<List<Friend>> getFriendList() async {
    final currentUid = SupabaseService.auth.currentUser!.id;
    return _fetchFriends(currentUid, 'accepted');
  }

  static Future<List<Friend>> getPendingRequests() async {
    final currentUid = SupabaseService.auth.currentUser!.id;
    return _fetchFriendRequests(currentUid, 'pending');
  }

  static Future<List<Friend>> getSentRequests() async {
    final currentUid = SupabaseService.auth.currentUser!.id;
    return _fetchSentRequests(currentUid, 'pending');
  }

  static Future<List<Friend>> _fetchFriends(String userId, String status) async {
    final response = await SupabaseService.friends
        .select('''
          id,
          status,
          created_at,
          requester_id,
          addressee_id,
          requester:profiles!friends_requester_id_fkey(id, nickname, avatar_url),
          addressee:profiles!friends_addressee_id_fkey(id, nickname, avatar_url)
        ''')
        .or('requester_id.eq.$userId,addressee_id.eq.$userId')
        .eq('status', status);

    final results = (response as List).map((row) {
      final map = row as Map<String, dynamic>;
      final isRequester = map['requester_id'] == userId;
      final otherUser = isRequester
          ? (map['addressee'] as Map<String, dynamic>)
          : (map['requester'] as Map<String, dynamic>);

      return Friend(
        id: map['id'] as String,
        userId: (otherUser['id'] as String?) ?? '',
        nickname: (otherUser['nickname'] as String?) ?? '',
        avatarUrl: otherUser['avatar_url'] as String?,
        status: FriendStatus.values.firstWhere(
          (e) => e.name == status,
          orElse: () => FriendStatus.pending,
        ),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    }).toList();

    return results;
  }

  static Future<List<Friend>> _fetchFriendRequests(
      String userId, String status) async {
    final response = await SupabaseService.friends
        .select('''
          id,
          status,
          created_at,
          requester_id,
          addressee_id,
          requester:profiles!friends_requester_id_fkey(id, nickname, avatar_url)
        ''')
        .eq('addressee_id', userId)
        .eq('status', status);

    return (response as List).map((row) {
      final map = row as Map<String, dynamic>;
      final requester = map['requester'] as Map<String, dynamic>;

      return Friend(
        id: map['id'] as String,
        userId: (requester['id'] as String?) ?? '',
        nickname: (requester['nickname'] as String?) ?? '',
        avatarUrl: requester['avatar_url'] as String?,
        status: FriendStatus.pending,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    }).toList();
  }

  static Future<List<Friend>> _fetchSentRequests(
      String userId, String status) async {
    final response = await SupabaseService.friends
        .select('''
          id,
          status,
          created_at,
          requester_id,
          addressee_id,
          addressee:profiles!friends_addressee_id_fkey(id, nickname, avatar_url)
        ''')
        .eq('requester_id', userId)
        .eq('status', status);

    return (response as List).map((row) {
      final map = row as Map<String, dynamic>;
      final addressee = map['addressee'] as Map<String, dynamic>;

      return Friend(
        id: map['id'] as String,
        userId: (addressee['id'] as String?) ?? '',
        nickname: (addressee['nickname'] as String?) ?? '',
        avatarUrl: addressee['avatar_url'] as String?,
        status: FriendStatus.pending,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    }).toList();
  }
}
