import '../models/shared_mood.dart';
import 'supabase_service.dart';

class SharedMoodService {
  SharedMoodService._();

  static Future<SharedMood> shareMood(
    String toUserId,
    String moodId, {
    String permission = 'view',
  }) async {
    final fromUserId = SupabaseService.auth.currentUser!.id;
    final response = await SupabaseService.sharedMoods
        .insert({
          'from_user_id': fromUserId,
          'to_user_id': toUserId,
          'mood_id': moodId,
          'permission': permission,
        })
        .select()
        .single();
    return SharedMood.fromMap(response as Map<String, dynamic>);
  }

  static Future<List<SharedMood>> getReceivedShares() async {
    final toUserId = SupabaseService.auth.currentUser!.id;
    final response = await SupabaseService.sharedMoods
        .select('''
          *,
          mood:remote_moods(*),
          from_user:profiles!shared_moods_from_user_id_fkey(nickname, avatar_url)
        ''')
        .eq('to_user_id', toUserId)
        .neq('status', 'deleted')
        .order('shared_at', ascending: false);

    return (response as List)
        .map((e) => SharedMood.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<SharedMood>> getSentShares() async {
    final fromUserId = SupabaseService.auth.currentUser!.id;
    final response = await SupabaseService.sharedMoods
        .select('''
          *,
          mood:remote_moods(*),
          to_user:profiles!shared_moods_to_user_id_fkey(nickname, avatar_url)
        ''')
        .eq('from_user_id', fromUserId)
        .neq('status', 'deleted')
        .order('shared_at', ascending: false);

    return (response as List).map((row) {
      final map = row as Map<String, dynamic>;
      // Swap to_user into from_user for display consistency
      if (map['to_user'] != null) {
        map['from_user'] = map['to_user'];
      }
      return SharedMood.fromMap(map);
    }).toList();
  }

  static Future<void> markAsRead(String sharedId) async {
    await SupabaseService.sharedMoods.update({
      'read_at': DateTime.now().toUtc().toIso8601String(),
      'status': 'received',
    }).eq('id', sharedId);
  }

  static Future<void> deleteShare(String sharedId) async {
    await SupabaseService.sharedMoods.update({
      'status': 'deleted',
    }).eq('id', sharedId);
  }
}
