import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/friend.dart';
import '../models/user_profile.dart';
import '../services/friend_service.dart';
import '../services/supabase_service.dart';

class FriendProvider extends ChangeNotifier {
  List<Friend> _friends = [];
  List<Friend> _pendingRequests = [];
  List<Friend> _sentRequests = [];
  List<UserProfile> _searchResults = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _friendsChannel;

  List<Friend> get friends => _friends;
  List<Friend> get pendingRequests => _pendingRequests;
  List<Friend> get sentRequests => _sentRequests;
  List<UserProfile> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFriends() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _friends = await FriendService.getFriendList();
    } catch (e) {
      _error = '加载好友列表失败';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadPendingRequests() async {
    try {
      _pendingRequests = await FriendService.getPendingRequests();
      _sentRequests = await FriendService.getSentRequests();
    } catch (e) {
      _error = '加载好友请求失败';
    }
    notifyListeners();
  }

  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    try {
      _searchResults = await FriendService.searchUsers(query.trim());

      // Also try searching by friend code (uppercase alphanumeric)
      final codeResult = await FriendService.searchByFriendCode(query.trim());
      if (codeResult != null &&
          !_searchResults.any((u) => u.id == codeResult.id)) {
        _searchResults.insert(0, codeResult);
      }
    } catch (e) {
      _searchResults = [];
      _error = '搜索失败';
    }
    notifyListeners();
  }

  void clearSearch() {
    _searchResults = [];
    notifyListeners();
  }

  Future<bool> sendRequest(String userId) async {
    _error = null;
    try {
      await FriendService.sendRequest(userId);
      await loadPendingRequests();
      return true;
    } catch (e) {
      _error = '发送好友请求失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptRequest(String friendshipId) async {
    _error = null;
    try {
      await FriendService.acceptRequest(friendshipId);
      await loadFriends();
      await loadPendingRequests();
      return true;
    } catch (e) {
      _error = '接受请求失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectRequest(String friendshipId) async {
    _error = null;
    try {
      await FriendService.rejectRequest(friendshipId);
      await loadPendingRequests();
      return true;
    } catch (e) {
      _error = '拒绝请求失败';
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFriend(String friendshipId) async {
    _error = null;
    try {
      await FriendService.removeFriend(friendshipId);
      await loadFriends();
      return true;
    } catch (e) {
      _error = '删除好友失败';
      notifyListeners();
      return false;
    }
  }

  void startFriendListRealtime() {
    stopFriendListRealtime();
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return;

    _friendsChannel = SupabaseService.client
        .channel('friends_list_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'friends',
          callback: (payload) => _onFriendsChanged(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'friends',
          callback: (payload) => _onFriendsChanged(payload.newRecord),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'friends',
          callback: (payload) => _onFriendsChanged(payload.oldRecord),
        )
        .subscribe();
  }

  void _onFriendsChanged(Map<String, dynamic>? record) {
    if (record == null) return;
    final uid = SupabaseService.auth.currentUser?.id;
    if (uid == null) return;
    final requester = record['requester_id'] as String?;
    final addressee = record['addressee_id'] as String?;
    if (requester != uid && addressee != uid) return;
    loadFriends();
    loadPendingRequests();
  }

  void stopFriendListRealtime() {
    _friendsChannel?.unsubscribe();
    _friendsChannel = null;
  }

  @override
  void dispose() {
    stopFriendListRealtime();
    super.dispose();
  }
}
