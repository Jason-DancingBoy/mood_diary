import 'dart:async';
import './ai_service.dart';

/// AI聊天管理器 - 用于管理AI请求，确保在页面切换时请求不被取消
class AIChatManager {
  static final AIChatManager _instance = AIChatManager._internal();
  factory AIChatManager() => _instance;
  AIChatManager._internal();

  /// 当前活跃的AI请求
  Future<String>? _currentRequest;
  Completer<String>? _currentCompleter;

  /// 监听器列表
  final List<void Function(String)> _responseListeners = [];
  final List<void Function(Exception)> _errorListeners = [];
  final List<void Function(bool)> _loadingListeners = [];

  /// 发送消息并等待AI响应
  /// 这个方法会返回一个Future，即使页面切换，这个Future也会继续执行
  Future<String> sendMessage(
    List<dynamic> history,
    String newMessage, {
    bool offlineMode = false,
  }) async {
    // 如果有正在进行的请求，先取消它
    if (_currentRequest != null) {
      _currentCompleter?.completeError(Exception('请求被取消'));
      _currentCompleter = null;
      _currentRequest = null;
    }

    // 通知开始加载
    _notifyLoading(true);

    final completer = Completer<String>();
    _currentCompleter = completer;

    _currentRequest = _executeAIRequest(history, newMessage, offlineMode)
        .then((response) {
          completer.complete(response);
          _currentRequest = null;
          _currentCompleter = null;
          _notifyLoading(false);
          return response;
        })
        .catchError((error) {
          completer.completeError(error);
          _currentRequest = null;
          _currentCompleter = null;
          _notifyLoading(false);
          _notifyError(error);
          throw error;
        });

    return completer.future;
  }

  /// 执行AI请求的核心方法
  Future<String> _executeAIRequest(
    List<dynamic> history,
    String newMessage,
    bool offlineMode,
  ) async {
    if (offlineMode) {
      return '当前处于离线模式，无法与小暖对话。请检查网络设置。';
    }

    try {
      final response = await AIService.chat(history, newMessage);
      _notifyResponse(response);
      return response;
    } catch (e) {
      if (e is Exception) {
        _notifyError(e);
      }
      rethrow;
    }
  }

  /// 取消当前请求
  void cancelCurrentRequest() {
    if (_currentCompleter != null && !_currentCompleter!.isCompleted) {
      _currentCompleter?.completeError(Exception('用户取消了请求'));
    }
    _currentRequest = null;
    _currentCompleter = null;
    _notifyLoading(false);
  }

  /// 添加响应监听器
  void addResponseListener(void Function(String) listener) {
    _responseListeners.add(listener);
  }

  /// 移除响应监听器
  void removeResponseListener(void Function(String) listener) {
    _responseListeners.remove(listener);
  }

  /// 添加错误监听器
  void addErrorListener(void Function(Exception) listener) {
    _errorListeners.add(listener);
  }

  /// 移除错误监听器
  void removeErrorListener(void Function(Exception) listener) {
    _errorListeners.remove(listener);
  }

  /// 添加加载状态监听器
  void addLoadingListener(void Function(bool) listener) {
    _loadingListeners.add(listener);
  }

  /// 移除加载状态监听器
  void removeLoadingListener(void Function(bool) listener) {
    _loadingListeners.remove(listener);
  }

  /// 通知响应
  void _notifyResponse(String response) {
    for (final listener in _responseListeners) {
      try {
        listener(response);
      } catch (e) {
        // 忽略监听器错误
      }
    }
  }

  /// 通知错误
  void _notifyError(Exception error) {
    for (final listener in _errorListeners) {
      try {
        listener(error);
      } catch (e) {
        // 忽略监听器错误
      }
    }
  }

  /// 通知加载状态
  void _notifyLoading(bool isLoading) {
    for (final listener in _loadingListeners) {
      try {
        listener(isLoading);
      } catch (e) {
        // 忽略监听器错误
      }
    }
  }

  /// 清理资源
  void dispose() {
    cancelCurrentRequest();
    _responseListeners.clear();
    _errorListeners.clear();
    _loadingListeners.clear();
  }
}
