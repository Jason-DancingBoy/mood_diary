import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

enum TraceNode {
  appColdStart('cold_start'),
  appFirstFrame('first_frame'),
  loginStart('login_start'),
  loginTokenRefresh('login_token_refresh'),
  loginHomePage('login_home_page'),
  moodCreateLocalSave('mood_create_local_save'),
  moodCreateRemoteSync('mood_create_remote_sync'),
  aiChatApiRequest('ai_chat_api_request'),
  aiChatResponse('ai_chat_response'),
  aiChatDisplay('ai_chat_display'),
  ;

  final String key;
  const TraceNode(this.key);
}

class AppTrace {
  AppTrace._();

  static final Map<String, _Span> _active = {};

  static void start(TraceNode node, {Map<String, dynamic>? data}) {
    final span = _Span(node.key, DateTime.now(), data: data);
    _active[node.key] = span;
    if (kDebugMode) {
      log('[Trace] ${node.key} started');
    }
  }

  static void end(TraceNode node, {bool success = true, String? error}) {
    final span = _active.remove(node.key);
    final now = DateTime.now();
    final durationMs = span != null
        ? now.difference(span.start).inMilliseconds
        : -1;

    if (kDebugMode) {
      final status = success ? 'OK' : 'FAIL';
      final dur = durationMs >= 0 ? '${durationMs}ms' : '?';
      log('[Trace] ${node.key} → $status ($dur)${error != null ? " err=$error" : ""}');
    }

    if (!success || error != null) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'Trace node failed: ${node.key}',
        category: 'trace',
        level: SentryLevel.error,
        data: {
          'node': node.key,
          'duration_ms': durationMs,
          'success': success,
          if (error != null) 'error': error,
        },
      ));
      Sentry.captureException(
        Exception('Trace node failed: ${node.key}'),
        stackTrace: StackTrace.current,
        withScope: (scope) {
          scope.setTag('source', '${node.key}');
          if (error != null) scope.setContexts('error_info', {'error': error});
        },
      );
    } else if (durationMs >= 0) {
      Sentry.addBreadcrumb(Breadcrumb(
        message: 'Trace: ${node.key}',
        category: 'trace',
        level: SentryLevel.info,
        data: {
          'node': node.key,
          'duration_ms': durationMs,
          'success': success,
        },
      ));
    }
  }

  /// Wrap an async function with start/end tracing + error reporting.
  static Future<T> wrap<T>(
    TraceNode node,
    Future<T> Function() fn, {
    Map<String, dynamic>? data,
  }) async {
    start(node, data: data);
    try {
      final result = await fn();
      end(node, success: true);
      return result;
    } catch (e, st) {
      end(node, success: false, error: e.toString());
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'trace:${node.key}'); });
      rethrow;
    }
  }
}

class _Span {
  final String key;
  final DateTime start;
  final Map<String, dynamic>? data;

  _Span(this.key, this.start, {this.data});
}
