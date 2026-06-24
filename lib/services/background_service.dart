import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class BackgroundService {
  BackgroundService._();

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  static Future<void> start() async {
    // 已运行则跳过
    if (await _service.isRunning()) return;

    try {
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onBackgroundStart,
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
    } catch (e) {
      debugPrint('BackgroundService start failed: $e');
    }
  }
}

@pragma('vm:entry-point')
Future<void> _onBackgroundStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 监听停止事件
  service.on('stopWithTask').listen((event) {
    service.stopSelf();
  });

  // 监听销毁事件，清理定时器
  Timer? keepAliveTimer;

  service.on('onDestroy').listen((event) {
    keepAliveTimer?.cancel();
  });

  // 保持 Dart event loop 不退出
  keepAliveTimer = Timer.periodic(const Duration(seconds: 30), (_) {});
}
