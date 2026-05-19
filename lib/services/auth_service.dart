import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import 'supabase_service.dart';

class AuthService {
  AuthService._();

  static Future<AuthResponse> register(
      String email, String password, String nickname) async {
    final response = await SupabaseService.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      await SupabaseService.profiles.insert({
        'id': response.user!.id,
        'nickname': nickname,
      });
    }

    return response;
  }

  static Future<AuthResponse> login(String email, String password) async {
    return await SupabaseService.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> logout() async {
    await SupabaseService.auth.signOut();
  }

  static User? get currentUser => SupabaseService.auth.currentUser;
  static Session? get currentSession => SupabaseService.auth.currentSession;
  static bool get isLoggedIn => currentUser != null;

  static Future<UserProfile?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await SupabaseService.profiles
          .select()
          .eq('id', user.id)
          .single();
      return UserProfile.fromMap(response as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  static Future<void> updateProfile({
    String? nickname,
    String? avatarUrl,
    bool? showMoodToFriends,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (nickname != null) updates['nickname'] = nickname;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (showMoodToFriends != null) updates['show_mood_to_friends'] = showMoodToFriends;

    await SupabaseService.profiles.update(updates).eq('id', user.id);
  }

  static Future<String> uploadAvatar(File file) async {
    final userId = currentUser!.id;
    final ext = file.path.split('.').last;
    final remotePath = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await SupabaseService.storage.upload(remotePath, file);
    return SupabaseService.storage.getPublicUrl(remotePath);
  }

  static Stream<AuthState> get onAuthChange =>
      SupabaseService.auth.onAuthStateChange;
}
