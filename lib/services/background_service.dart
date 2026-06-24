import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class BackgroundService {
  BackgroundService._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  static Future<void> start() async {
    // 已运行则跳过
    if (await _service.isRunning()) return;

    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: 'background_service',
        initialNotificationTitle: '心情日记',
        initialNotificationContent: '正在后台运行',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
      ),
    );

    await _service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> _onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();

    // 服务只做保活。
    // 所有消息通知逻辑由 FriendChatService.startGlobalSubscription() 的
    // WebSocket 回调 + NotificationService 处理，此处无需额外逻辑。

    return true;
  }
}
