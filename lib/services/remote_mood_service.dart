import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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

  /// Add a single friend to the realtime watch list without replacing the
  /// entire list. Does nothing if the friend is already being watched.
  static Future<void> addFriendToRealtime(String friendUserId) async {
    if (_watchedFriendIds.contains(friendUserId)) return;

    _watchedFriendIds = List.from(_watchedFriendIds)..add(friendUserId);

    final mood = await getFriendLatestMood(friendUserId);
    if (mood != null) {
      final current =
          Map<String, Map<String, dynamic>>.from(friendMoodsNotifier.value);
      if (!current.containsKey(friendUserId)) {
        current[friendUserId] = mood;
        friendMoodsNotifier.value = current;
      }
    }

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
          table: 'user_mood_status',
          callback: _onMoodInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_mood_status',
          callback: _onMoodUpdate,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'user_mood_status',
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
    final existing = current[ownerId];
    if (existing == null || _isNewer(record, existing)) {
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
      'created_at': record['updated_at'],
    };
  }

  static bool _isNewer(Map<String, dynamic> a, Map<String, dynamic> b) {
    final tA = (a['updated_at'] ?? a['created_at']) as String?;
    final tB = (b['updated_at'] ?? b['created_at']) as String?;
    if (tA == null || tB == null) return false;
    return tA.compareTo(tB) > 0;
  }

  static void disposeFriendMoodRealtime() {
    _friendMoodChannel?.unsubscribe();
    _friendMoodChannel = null;
    _watchedFriendIds = [];
  }

  /// 将最新本地心情同步到 user_mood_status 表（持续同步）。
  /// 若 show_mood_to_friends 关闭，则清除远端状态。
  static Future<void> syncLatestMoodToStatus() async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final showMood = prefs.getBool('showMoodToFriends') ?? true;

    if (!showMood) {
      await clearMoodStatus();
      return;
    }

    final box = Hive.box<Map<dynamic, dynamic>>('mood_logs_box');
    if (box.isEmpty) {
      await clearMoodStatus();
      return;
    }

    // 找到最新一条记录
    final allKeys = box.keys.toList();
    final allValues = box.values.toList();
    DateTime? latest;
    Map<dynamic, dynamic>? latestEntry;
    for (int i = 0; i < allKeys.length; i++) {
      final v = allValues[i];
      final createdAt = v['createdAt'] as DateTime?;
      if (createdAt == null) continue;
      if (latest == null || createdAt.isAfter(latest)) {
        latest = createdAt;
        latestEntry = v;
      }
    }

    if (latestEntry == null) {
      await clearMoodStatus();
      return;
    }

    final upsertData = <String, dynamic>{
      'owner_id': userId,
      'mood_type': latestEntry['mood'] as String,
      'note': (latestEntry['note'] as String?) ?? '',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (latestEntry['energy'] != null) {
      upsertData['energy'] = (latestEntry['energy'] as num).toDouble();
    }
    if (latestEntry['pleasantness'] != null) {
      upsertData['pleasantness'] = (latestEntry['pleasantness'] as num).toDouble();
    }
    if (latestEntry['emotionWord'] != null) {
      upsertData['emotion_word'] = latestEntry['emotionWord'] as String;
    }
    if (latestEntry['quadrant'] != null) {
      upsertData['quadrant'] = latestEntry['quadrant'] as String;
    }
    await SupabaseService.userMoodStatus.upsert(upsertData, onConflict: 'owner_id');
  }

  /// 删除当前用户在 user_mood_status 表中的记录。
  static Future<void> clearMoodStatus() async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.userMoodStatus.delete().eq('owner_id', userId);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'RemoteMoodService.clearMoodStatus'); });
    }
  }

  static Future<MoodRecord> uploadMood(MoodLog log) async {
    final ownerId = SupabaseService.auth.currentUser!.id;
    final record = MoodRecord.fromLocalMoodLog(log, ownerId);
    final data = record.toMap();
    data.remove('id');

    try {
      final response = await SupabaseService.remoteMoods
          .insert(data)
          .select()
          .single();
      return MoodRecord.fromMap(response as Map<String, dynamic>);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'RemoteMoodService.uploadMood'); });
      rethrow;
    }
  }

  static Future<void> updateMoodUrls(String moodId, List<String> imageUrls) async {
    await SupabaseService.remoteMoods
        .update({'image_urls': imageUrls})
        .eq('id', moodId);
  }

  static Future<void> updateMoodAudio(String moodId, String audioUrl, int audioDuration) async {
    await SupabaseService.remoteMoods
        .update({'audio_url': audioUrl, 'audio_duration': audioDuration})
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
      final moods = await SupabaseService.userMoodStatus
          .select('owner_id, mood_type, note, updated_at')
          .inFilter('owner_id', friendUserIds)
          .order('updated_at', ascending: false);

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

  /// 从远端恢复心情记录到本地 Hive。已存在的记录自动跳过。
  /// 返回新恢复的记录数，失败返回 -1。
  static Future<int> restoreMoodsIfNeeded() async {
    try {
      final box = Hive.box<Map<dynamic, dynamic>>('mood_logs_box');

      final moods = await _fetchAllMyMoods();
      if (moods.isEmpty) return 0;

      int restored = 0;
      for (final record in moods) {
        final key = record.localId ?? record.id;
        if (box.containsKey(key)) continue;

        final moodType = record.moodType;
        await box.put(key, {
          'mood': moodType,
          'note': record.note,
          'comment': record.comment,
          'createdAt': record.createdAt.toLocal(),
          if (record.imageUrls.isNotEmpty) 'imageUrls': record.imageUrls,
          if (record.audioUrl != null) 'voiceUrl': record.audioUrl,
          if (record.audioDuration != null) 'voiceDuration': record.audioDuration,
          if (record.customEmoji != null) 'customEmoji': record.customEmoji,
          if (record.customEmojiLabel != null) 'customEmojiLabel': record.customEmojiLabel,
          if (record.customColorValue != null) 'customColorValue': record.customColorValue,
          if (record.aiComfort != null) 'aiComfort': record.aiComfort,
          'aiEnabled': record.aiEnabled,
          if (record.energy != null) 'energy': record.energy,
          if (record.pleasantness != null) 'pleasantness': record.pleasantness,
          if (record.emotionWord != null) 'emotionWord': record.emotionWord,
          if (record.quadrant != null) 'quadrant': record.quadrant,
        });
        restored++;
      }
      return restored;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'RemoteMoodService.restoreMoodsIfNeeded'); });
      return -1;
    }
  }

  static Future<List<MoodRecord>> _fetchAllMyMoods() async {
    final all = <MoodRecord>[];
    const pageSize = 100;
    int offset = 0;
    while (true) {
      final page = await getMyMoods(limit: pageSize, offset: offset);
      if (page.isEmpty) break;
      all.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return all;
  }
}
