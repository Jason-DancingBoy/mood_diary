import 'package:flutter/foundation.dart';
import '../models/shared_mood.dart';
import '../services/shared_mood_service.dart';

class SharedMoodProvider extends ChangeNotifier {
  List<SharedMood> _receivedShares = [];
  List<SharedMood> _sentShares = [];
  bool _isLoading = false;
  String? _error;

  List<SharedMood> get receivedShares => _receivedShares;
  List<SharedMood> get sentShares => _sentShares;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount =>
      _receivedShares.where((s) => s.readAt == null).length;

  Future<void> loadReceived() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _receivedShares = await SharedMoodService.getReceivedShares();
    } catch (e) {
      _error = '加载收到的分享失败';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSent() async {
    try {
      _sentShares = await SharedMoodService.getSentShares();
    } catch (e) {
      _error = '加载发出的分享失败';
    }
    notifyListeners();
  }

  Future<bool> shareMood(String toUserId, String moodId) async {
    _error = null;
    try {
      await SharedMoodService.shareMood(toUserId, moodId);
      await loadSent();
      return true;
    } catch (e) {
      _error = '分享失败';
      notifyListeners();
      return false;
    }
  }

  Future<void> markAsRead(String sharedId) async {
    try {
      await SharedMoodService.markAsRead(sharedId);
      final index =
          _receivedShares.indexWhere((s) => s.id == sharedId);
      if (index != -1) {
        _receivedShares[index] = SharedMood.fromMap({
          ..._receivedShares[index].toMap(),
          'read_at': DateTime.now().toUtc().toIso8601String(),
          'status': 'received',
        });
        notifyListeners();
      }
    } catch (e) {
      // silent fail for mark as read
    }
  }

  Future<void> deleteShare(String sharedId) async {
    try {
      await SharedMoodService.deleteShare(sharedId);
      _receivedShares.removeWhere((s) => s.id == sharedId);
      _sentShares.removeWhere((s) => s.id == sharedId);
      notifyListeners();
    } catch (e) {
      _error = '删除失败';
      notifyListeners();
    }
  }
}
