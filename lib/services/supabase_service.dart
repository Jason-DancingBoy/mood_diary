import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get client => Supabase.instance.client;

  static GoTrueClient get auth => Supabase.instance.client.auth;

  static PostgrestQueryBuilder get profiles =>
      Supabase.instance.client.from('profiles');

  static PostgrestQueryBuilder get friends =>
      Supabase.instance.client.from('friends');

  static PostgrestQueryBuilder get remoteMoods =>
      Supabase.instance.client.from('remote_moods');

  static PostgrestQueryBuilder get sharedMoods =>
      Supabase.instance.client.from('shared_moods');

  static PostgrestQueryBuilder get friendMessages =>
      Supabase.instance.client.from('friend_messages');

  static StorageFileApi get storage =>
      Supabase.instance.client.storage.from('mood_images');
}
