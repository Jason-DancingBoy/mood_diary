import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/remote_mood_service.dart';
import '../services/app_trace.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  UserProfile? _profile;
  bool _isLoading = false;
  String? _error;

  String? _uploadingAvatarPath;
  String? _cachedAvatarPath;

  User? get user => _user;
  UserProfile? get profile => _profile;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get localAvatarPath => _uploadingAvatarPath;
  String? get cachedAvatarPath => _cachedAvatarPath;

  AuthProvider() {
    _user = AuthService.currentUser;
    AuthService.onAuthChange.listen(_onAuthStateChanged);
    if (_user != null) {
      _loadProfile();
      _restoreCachedAvatar();
      RemoteMoodService.restoreMoodsIfNeeded();
    }
  }

  void _restoreCachedAvatar() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/avatar_cache');
      if (await file.exists()) {
        _cachedAvatarPath = file.path;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _onAuthStateChanged(AuthState authState) {
    _user = authState.session?.user;
    if (_user != null && authState.event != AuthChangeEvent.tokenRefreshed) {
      _loadProfile();
    } else if (_user == null) {
      _profile = null;
      _cachedAvatarPath = null;
    }
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    try {
      _profile = await AuthService.getProfile();
      if (_profile?.avatarUrl != null) {
        _cacheAvatarFromUrl(_profile!.avatarUrl!);
      }
    } catch (e) {
      _profile = null;
    }
    notifyListeners();
  }

  Future<void> _cacheAvatarFromUrl(String url) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/avatar_cache');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(url));
      final response = await request.close();
      await response.pipe(dest.openWrite());
      httpClient.close();
      _cachedAvatarPath = dest.path;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    AppTrace.start(TraceNode.loginStart);

    try {
      await AuthService.login(email, password);
      AppTrace.end(TraceNode.loginTokenRefresh, success: true);
      _user = AuthService.currentUser;
      await _loadProfile();
      RemoteMoodService.restoreMoodsIfNeeded();
      AppTrace.end(TraceNode.loginHomePage, success: true);
    } on AuthException catch (e) {
      AppTrace.end(TraceNode.loginStart, success: false, error: e.message);
      _error = e.message;
    } catch (e, st) {
      AppTrace.end(TraceNode.loginStart, success: false, error: e.toString());
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'AuthProvider.login'); });
      _error = '登录失败: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> register(String email, String password, String nickname) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await AuthService.register(email, password, nickname);
      _user = AuthService.currentUser;
      await _loadProfile();
      RemoteMoodService.restoreMoodsIfNeeded();
    } on AuthException catch (e) {
      _error = e.message;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'AuthProvider.register'); });
      _error = '注册失败: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateNickname(String nickname) async {
    await AuthService.updateProfile(nickname: nickname);
    _profile = UserProfile(
      id: _profile!.id,
      nickname: nickname,
      friendCode: _profile!.friendCode,
      avatarUrl: _profile!.avatarUrl,
      bio: _profile!.bio,
      showMoodToFriends: _profile!.showMoodToFriends,
      createdAt: _profile!.createdAt,
    );
    notifyListeners();
  }

  Future<void> updateAvatar(File file) async {
    _uploadingAvatarPath = file.path;
    notifyListeners();

    try {
      final url = await AuthService.uploadAvatar(file);
      await AuthService.updateProfile(avatarUrl: url);
      _profile = UserProfile(
        id: _profile!.id,
        nickname: _profile!.nickname,
        friendCode: _profile!.friendCode,
        avatarUrl: url,
        bio: _profile!.bio,
        showMoodToFriends: _profile!.showMoodToFriends,
        createdAt: _profile!.createdAt,
      );
      // Cache the local file so rebuilds don't need network
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/avatar_cache');
      await file.copy(dest.path);
      _cachedAvatarPath = dest.path;
    } finally {
      _uploadingAvatarPath = null;
      notifyListeners();
    }
  }

  Future<void> updateShowMoodToFriends(bool value) async {
    await AuthService.updateProfile(showMoodToFriends: value);
    _profile = UserProfile(
      id: _profile!.id,
      nickname: _profile!.nickname,
      friendCode: _profile!.friendCode,
      avatarUrl: _profile!.avatarUrl,
      bio: _profile!.bio,
      showMoodToFriends: value,
      createdAt: _profile!.createdAt,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.logout();
    _user = null;
    _profile = null;
    _error = null;
    _cachedAvatarPath = null;
    notifyListeners();
  }
}
