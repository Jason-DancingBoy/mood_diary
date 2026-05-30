import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 当前打开的好友聊天 ID，用于去重
  static String? activeChatFriendId;

  /// 通知点击回调，由 main.dart 注入
  static void Function(String friendId)? onNotificationNavigate;

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    final friendId = response.payload;
    if (friendId == null) return;
    onNotificationNavigate?.call(friendId);
  }

  static Future<void> showMessageNotification({
    required String friendName,
    required String message,
    required String friendId,
    String? avatarUrl,
  }) async {
    final body = message.length > 100 ? '${message.substring(0, 100)}...' : message;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'friend_messages',
        '好友消息',
        channelDescription: '收到好友消息时通知',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(
      friendId.hashCode,
      friendName,
      body,
      details,
      payload: friendId,
    );
  }
}
