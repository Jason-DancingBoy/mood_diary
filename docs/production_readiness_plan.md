# 生产环境就绪方案

## 一、Flutter Stable 迁移

### 1.1 现状

| 项目 | 当前值 | 问题 |
|------|--------|------|
| Flutter | 3.44.0 stable | 已就绪 |
| Dart | 3.12.0 stable | 已就绪 |
| pubspec SDK 约束 | `^3.12.0-98.0.dev` | 指向 dev 预发布版，App Store 审核会拒绝 |

### 1.2 操作步骤

**Step 1 — 修改 SDK 约束**

`pubspec.yaml` 第 22 行：

```yaml
# 改前
environment:
  sdk: ^3.12.0-98.0.dev

# 改后
environment:
  sdk: ^3.12.0
```

**Step 2 — 重新解析依赖并验证**

```bash
rm -rf .dart_tool build
flutter pub get
flutter analyze
flutter test
```

如果 `flutter analyze` 通过且测试全绿，说明没有任何 API 变动影响你的代码（当前环境实际上就是 stable Dart 3.12.0，所以这一步大概率直接过）。

**Step 3 — 可选：升级主要依赖**

以下包有大版本更新，建议在迁移时一并处理，避免未来积压：

| 包 | 当前 | 最新 | 说明 |
|---|---|---|---|
| `fl_chart` | 0.69.2 | 1.2.0 | 图表 API 有破坏性变更，需检查 `MoodCalendarPage` |
| `package_info_plus` | 8.3.1 | 10.1.0 | API 基本兼容 |
| `share_plus` | 10.1.4 | 13.1.0 | 可能需要调整 Android 配置 |

推荐策略：先只改 SDK 约束让项目能通过审核，大版本升级放到后续迭代单独处理。

**Step 4 — 验证构建**

```bash
flutter build apk --release
flutter build ios --release --no-codesign
```

---

## 二、推送通知方案

### 2.1 架构设计

```
┌─────────────────────────────────────────────────────┐
│                    Supabase                          │
│                                                      │
│  friend_messages  ──┬── INSERT 触发器                │
│  shared_moods      ──┤                               │
│  (AI mail 事件)    ──┘                               │
│                         │                            │
│                    Edge Function                      │
│                  (send_push_notification)             │
│                         │                            │
│                    Firebase Admin SDK                 │
│                         │                            │
│                    FCM / APNs                         │
│                         │                            │
│                    用户手机                           │
└─────────────────────────────────────────────────────┘
```

### 2.2 新增数据库表

在 `supabase_schema.sql` 中新增：

```sql
-- 设备推送令牌表
CREATE TABLE IF NOT EXISTS public.device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, fcm_token)
);

-- 推送通知日志（用于调试和统计）
CREATE TABLE IF NOT EXISTS public.push_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL,  -- 'new_message', 'shared_mood', 'ai_mail'
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    data JSONB DEFAULT '{}',
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own tokens"
    ON public.device_tokens FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Users read own notifications"
    ON public.push_notifications FOR SELECT
    USING (auth.uid() = user_id);

-- Realtime 启用（用于应用内通知横幅）
ALTER PUBLICATION supabase_realtime ADD TABLE public.push_notifications;
```

### 2.3 Flutter 端集成

**Step 1 — 添加依赖**

`pubspec.yaml` 新增：

```yaml
dependencies:
  firebase_core: ^3.0.0
  firebase_messaging: ^15.0.0
```

然后 `flutter pub get`。

**Step 2 — 创建推送服务 `lib/services/push_notification_service.dart`**

```dart
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

class PushNotificationService {
  PushNotificationService._();

  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();
  static String? _fcmToken;

  /// 初始化（在 main.dart 中 Firebase.initializeApp() 之后调用）
  static Future<void> init() async {
    // 1. 请求权限
    if (Platform.isIOS) {
      await _messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
    }

    // 2. 获取 FCM Token
    _fcmToken = await _messaging.getToken();
    if (_fcmToken != null) {
      await _uploadToken(_fcmToken!);
    }

    // 3. 监听 Token 刷新
    _messaging.onTokenRefresh.listen(_uploadToken);

    // 4. 前台消息处理
    await _setupLocalNotifications();
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. 后台消息点击处理
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 6. 冷启动点击处理
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// 上传 FCM Token 到 Supabase
  static Future<void> _uploadToken(String token) async {
    final userId = SupabaseService.auth.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client.from('device_tokens').upsert({
      'user_id': userId,
      'fcm_token': token,
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// 用户登出时删除 Token
  static Future<void> removeToken() async {
    if (_fcmToken == null) return;
    await SupabaseService.client
        .from('device_tokens')
        .delete()
        .eq('fcm_token', _fcmToken!);
  }

  /// 本地通知设置（用于前台消息展示）
  static Future<void> _setupLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  /// 前台消息：显示本地通知横幅
  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      message.messageId.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mood_diary_channel',
          '心情日记消息',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data.toString(),
    );
  }

  /// 通知点击 → 跳转到对应页面
  static void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'] as String?;
    // 通过全局 NavigatorKey 跳转
    // type == 'new_message'  → 跳转到对应好友聊天页
    // type == 'shared_mood'  → 跳转到分享详情页
    // type == 'ai_mail'      → 跳转到 AI 邮件列表
    _navigateByType(type, message.data);
  }

  static void _onNotificationResponse(NotificationResponse response) {
    // 处理本地通知点击
  }

  static void _navigateByType(String? type, Map<String, dynamic> data) {
    // TODO: 使用全局 navigatorKey 跳转到对应页面
    // 示例：
    // if (type == 'new_message') {
    //   final friendId = data['friend_id'];
    //   navigatorKey.currentState?.pushNamed('/friend_chat', arguments: friendId);
    // }
  }
}
```

**Step 3 — 在 `main.dart` 中初始化**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Firebase（新增）
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // 需要 firebase_cli 生成
  );

  // 原有初始化...
  await Hive.initFlutter();
  // ...

  // 初始化推送（新增）
  await PushNotificationService.init();

  runApp(const MyApp());
}
```

**Step 4 — 登出时清理 Token**

在 `AuthService.logout()` 中新增：

```dart
await PushNotificationService.removeToken();
```

### 2.4 Firebase 项目配置

**Android (`android/app/google-services.json`)：**

1. 前往 [Firebase Console](https://console.firebase.google.com/) 创建项目
2. 添加 Android 应用，包名 `com.example.mood_diary`（替换为实际包名）
3. 下载 `google-services.json` 放到 `android/app/` 目录
4. 在 `android/build.gradle.kts` 中确认有 `classpath 'com.google.gms:google-services:4.4.0'`
5. 在 `android/app/build.gradle.kts` 中确认有 `apply plugin: 'com.google.gms.google-services'`

**iOS (`ios/Runner/GoogleService-Info.plist`)：**

1. 在 Firebase Console 中添加 iOS 应用，Bundle ID 与 Xcode 中一致
2. 下载 `GoogleService-Info.plist` 放到 `ios/Runner/` 目录
3. 在 Xcode 中启用 Push Notifications capability
4. 在 Apple Developer Console 生成 APNs Key，上传到 Firebase Console

**生成 `firebase_options.dart`：**

```bash
flutterfire configure
```

### 2.5 Supabase Edge Function（服务端推送触发）

在 Supabase 项目中创建 Edge Function `send_push`：

```typescript
// supabase/functions/send_push/index.ts
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import admin from "npm:firebase-admin@12";

// Firebase Admin 初始化（使用环境变量中的 Service Account JSON）
const serviceAccount = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

Deno.serve(async (req) => {
  const { user_id, title, body, type, data } = await req.json();

  // 查询用户的所有设备 Token
  const { data: tokens, error } = await supabase
    .from("device_tokens")
    .select("fcm_token, platform")
    .eq("user_id", user_id);

  if (error || !tokens || tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0, reason: "no tokens" }), {
      status: 200,
    });
  }

  const fcmTokens = tokens.map((t: any) => t.fcm_token);

  // 通过 FCM 发送推送
  const message: admin.messaging.MulticastMessage = {
    tokens: fcmTokens,
    notification: { title, body },
    data: { type, ...data, click_action: "FLUTTER_NOTIFICATION_CLICK" },
    apns: {
      payload: {
        aps: { sound: "default", badge: 1 },
      },
    },
  };

  const result = await admin.messaging().sendEachForMulticast(message);

  // 记录推送日志
  await supabase.from("push_notifications").insert({
    user_id,
    type,
    title,
    body,
    data,
  });

  return new Response(
    JSON.stringify({ sent: result.successCount, failed: result.failureCount }),
    { status: 200 }
  );
});
```

**数据库触发器（在 Supabase SQL Editor 中执行）：**

```sql
-- 好友新消息 → 推送通知
CREATE OR REPLACE FUNCTION notify_new_friend_message()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    url := CONCAT(current_setting('app.settings.supabase_url'), '/functions/v1/send_push'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', CONCAT('Bearer ', current_setting('app.settings.service_role_key'))
    ),
    body := jsonb_build_object(
      'user_id', NEW.receiver_id,
      'title', (SELECT nickname FROM public.profiles WHERE id = NEW.sender_id),
      'body', NEW.content,
      'type', 'new_message',
      'data', jsonb_build_object('friend_id', NEW.sender_id)
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_friend_message
  AFTER INSERT ON public.friend_messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_friend_message();

-- 好友分享心情 → 推送通知
CREATE OR REPLACE FUNCTION notify_new_shared_mood()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM net.http_post(
    url := CONCAT(current_setting('app.settings.supabase_url'), '/functions/v1/send_push'),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', CONCAT('Bearer ', current_setting('app.settings.service_role_key'))
    ),
    body := jsonb_build_object(
      'user_id', NEW.to_user_id,
      'title', (SELECT nickname FROM public.profiles WHERE id = NEW.from_user_id),
      'body', '分享了一条心情给你',
      'type', 'shared_mood',
      'data', jsonb_build_object('shared_mood_id', NEW.id)
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_shared_mood
  AFTER INSERT ON public.shared_moods
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_shared_mood();
```

> **注意：** 以上触发器使用了 `pg_net` 扩展（`net.http_post`）。需要在 Supabase Dashboard → Database → Extensions 中启用 `pg_net`。

### 2.6 替代方案：OneSignal（更简单但增加外部依赖）

如果觉得 Firebase + Edge Function 太重，可以用 OneSignal 替代：

- **优点：** 无需维护 Edge Function，可视化推送后台，支持定时推送、A/B 测试、用户分群
- **缺点：** 免费额度有限（10,000 subscribers），超量需付费；多一个第三方依赖
- **集成：** 使用 `onesignal_flutter` 包，在 main.dart 中初始化，数据库触发器直接调用 OneSignal API

---

## 三、执行清单

### 第一阶段：Stable 迁移（预计 0.5 天）

- [ ] `pubspec.yaml`: `sdk: ^3.12.0-98.0.dev` → `sdk: ^3.12.0`
- [ ] `flutter clean && flutter pub get && flutter analyze`
- [ ] Release 构建验证：`flutter build apk --release`
- [ ] 真机安装测试 10 分钟

### 第二阶段：推送通知（预计 2-3 天）

- [ ] Firebase 项目创建 + `google-services.json` / `GoogleService-Info.plist` 配置
- [ ] `firebase_core` + `firebase_messaging` + `flutter_local_notifications` 集成
- [ ] `PushNotificationService` 实现 + `main.dart` 初始化
- [ ] `device_tokens` + `push_notifications` 表创建
- [ ] Supabase Edge Function `send_push` 部署
- [ ] 数据库触发器创建
- [ ] 前台/后台/冷启动三种场景的推送测试
- [ ] 通知点击跳转逻辑实现
- [ ] iOS APNs 证书配置（需 Apple Developer 账号）

### 第三阶段：App Store 准备（预计 1-2 天）

- [ ] Android: 签名配置、ProGuard 规则、隐私政策页面
- [ ] iOS: Xcode 签名、Info.plist 隐私描述、App Store 截图
- [ ] 应用内隐私政策 + 用户协议链接
- [ ] GDPR/个人信息保护法合规检查
