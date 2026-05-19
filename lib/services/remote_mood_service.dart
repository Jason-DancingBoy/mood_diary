import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/mood_log.dart';
import '../models/mood_record.dart';
import 'supabase_service.dart';

class RemoteMoodService {
  RemoteMoodService._();

  // --- Friend Mood Realtime ---

  static final ValueNotifier<Map<String, Map<String, dynamic>>>
      friendMoodsNotifier = ValueNotifier({});

  static RealtimeChannel? _friendMoodChannel;
  static List<String> _watchedFriendIds = [];

  /// Start (or restart) the realtime subscription for the given friend IDs.
  /// Safe to call multiple times — updates the watched ID list and restarts.
  static Future<void> ensureFriendMoodRealtime(
      List<String> friendUserIds) async {
    _watchedFriendIds = List.from(friendUserIds);

    final moods = await getFriendsLatestMoods(friendUserIds);
    friendMoodsNotifier.value = moods;

    _startChannel();
  }

  static void _startChannel() {
    _friendMoodChannel?.unsubscribe();
    if (_watchedFriendIds.isEmpty) return;

    _friendMoodChannel = SupabaseService.client
        .channel('friend_moods_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'remote_moods',
          callback: _onMoodInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'remote_moods',
          callback: _onMoodUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'remote_moods',
          callback: _onMoodDelete,
        )
        .subscribe((status, error) {
      debugPrint(
          '[Realtime] friend_moods_rt status=$status${error != null ? " error=$error" : ""}');
    });
  }

  static void _onMoodInsert(PostgresChangePayload payload) {
    final record = payload.newRecord;
    final ownerId = record['owner_id'] as String?;
    debugPrint('[Realtime] INSERT owner_id=$ownerId');
    if (ownerId == null || !_watchedFriendIds.contains(ownerId)) return;

    final current =
        Map<String, Map<String, dynamic>>.from(friendMoodsNotifier.value);
    final existing = current[ownerId];
    if (existing == null || _isNewer(record, existing)) {
      current[ownerId] = _extractMoodData(record);
      friendMoodsNotifier.value = current;
    }
  }

  static void _onMoodUpdate(PostgresChangePayload payload) {
    final record = payload.newRecord;
    final ownerId = record['owner_id'] as String?;
    debugPrint('[Realtime] UPDATE owner_id=$ownerId');
    if (ownerId == null || !_watchedFriendIds.contains(ownerId)) return;

    final current =
        Map<String, Map<String, dynamic>>.from(friendMoodsNotifier.value);
    if (current.containsKey(ownerId)) {
      current[ownerId] = _extractMoodData(record);
      friendMoodsNotifier.value = current;
    }
  }

  static void _onMoodDelete(PostgresChangePayload payload) {
    debugPrint('[Realtime] DELETE id=${payload.oldRecord['id']}');
    // oldRecord may only contain the primary key (without REPLICA IDENTITY FULL),
    // so re-fetch all moods unconditionally
    getFriendsLatestMoods(_watchedFriendIds).then((moods) {
      friendMoodsNotifier.value = moods;
    });
  }

  static Map<String, dynamic> _extractMoodData(Map<String, dynamic> record) {
    return {
      'owner_id': record['owner_id'],
      'mood_type': record['mood_type'],
      'note': record['note'],
      'created_at': record['created_at'],
    };
  }

  static bool _isNewer(Map<String, dynamic> a, Map<String, dynamic> b) {
    final tA = a['created_at'] as String?;
    final tB = b['created_at'] as String?;
    if (tA == null || tB == null) return false;
    return tA.compareTo(tB) > 0;
  }

  static void disposeFriendMoodRealtime() {
    _friendMoodChannel?.unsubscribe();
    _friendMoodChannel = null;
    _watchedFriendIds = [];
  }

  static Future<MoodRecord> uploadMood(MoodLog log) async {
    final ownerId = SupabaseService.auth.currentUser!.id;
    final record = MoodRecord.fromLocalMoodLog(log, ownerId);
    final data = record.toMap();
    // Don't include 'id' on insert — Supabase generates it
    data.remove('id');

    final response = await SupabaseService.remoteMoods
        .insert(data)
        .select()
        .single();
    return MoodRecord.fromMap(response as Map<String, dynamic>);
  }

  static Future<void> updateMoodUrls(String moodId, List<String> imageUrls) async {
    await SupabaseService.remoteMoods
        .update({'image_urls': imageUrls})
        .eq('id', moodId);
  }

  static Future<List<MoodRecord>> getMyMoods({int limit = 50, int offset = 0}) async {
    final ownerId = SupabaseService.auth.currentUser!.id;
    final response = await SupabaseService.remoteMoods
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (response as List)
        .map((e) => MoodRecord.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<MoodRecord?> getMood(String moodId) async {
    try {
      final response = await SupabaseService.remoteMoods
          .select()
          .eq('id', moodId)
          .single();
      return MoodRecord.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteMood(String moodId) async {
    await SupabaseService.remoteMoods.delete().eq('id', moodId);
  }

  static Future<Map<String, Map<String, dynamic>>> getFriendsLatestMoods(
      List<String> friendUserIds) async {
    if (friendUserIds.isEmpty) return {};

    try {
      final profiles = await SupabaseService.profiles
          .select('id, show_mood_to_friends')
          .inFilter('id', friendUserIds);

      final visibleIds = <String>[];
      for (final p in profiles) {
        if (p['show_mood_to_friends'] == true) {
          visibleIds.add(p['id'] as String);
        }
      }

      if (visibleIds.isEmpty) return {};

      final moods = await SupabaseService.remoteMoods
          .select('owner_id, mood_type, note, created_at')
          .inFilter('owner_id', visibleIds)
          .order('created_at', ascending: false)
          .limit(visibleIds.length * 5);

      final result = <String, Map<String, dynamic>>{};
      for (final mood in moods) {
        final ownerId = mood['owner_id'] as String;
        result.putIfAbsent(ownerId, () => mood as Map<String, dynamic>);
      }

      return result;
    } catch (e) {
      return {};
    }
  }

  static Future<Map<String, dynamic>?> getFriendLatestMood(
      String friendUserId) async {
    final moods = await getFriendsLatestMoods([friendUserId]);
    return moods[friendUserId];
  }
}
