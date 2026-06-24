# Background Message Notification — Design Spec

## Problem

好友发消息时，App 在前台能正常收到 WebSocket 推送并弹通知。App 切后台后，进程可能被系统杀死，WebSocket 断开，通知中断。

## Solution

Android 前台服务（Foreground Service）保活进程。进程活着 → WebSocket 连着 → 消息到达即弹通知。

iOS 不做额外处理（`flutter_background_service` 仅提供有限后台任务，iOS 平台本身不允许常驻后台）。

## Architecture

```
App 启动 → BackgroundService.start()
App 切后台 → 前台服务通知栏显示"心情日记正在后台运行"
消息到达 → WebSocket 回调 → NotificationService (已有逻辑，不改)
用户点击通知 → 跳转聊天页 (已有逻辑，不改)
用户手动杀 App → 服务随进程消亡
```

## Dependencies

新增 `flutter_background_service`，无其他新依赖。

## Changes

| 层 | 改动 |
|---|---|
| `pubspec.yaml` | 新增 `flutter_background_service` |
| `android/app/src/main/AndroidManifest.xml` | 新增 `FOREGROUND_SERVICE` 权限，声明 `BackgroundService`（`dataSync` 类型） |
| `lib/services/background_service.dart` | 新增，管理前台服务启停 |
| `lib/main.dart` | Supabase 初始化后调用 `BackgroundService.start()` |

## 不改动的文件

`NotificationService`、`FriendChatService`（含 `startGlobalSubscription`）、`ChatListPage`、所有聊天页面——行为完全不变。

## BackgroundService 设计

- 单一职责：保活进程，不做任何业务逻辑
- 前台通知栏内容："心情日记正在后台运行"，静默不打扰
- 幂等启动：已运行时跳过
- 未登录时不启动

## Edge Cases

| 场景 | 行为 |
|---|---|
| 通知权限关闭 | 现有逻辑已处理，静默跳过，不影响服务 |
| 系统强杀 App | 服务随进程消亡，下次启动恢复 |
| 国产 ROM 杀后台 | 前台服务存活率远高于普通进程；仍被杀可后续加 workmanager 轮询兜底 |
| 网络断连恢复 | Supabase Realtime 自带自动重连 |
| 退出登录 | 初始化时判断登录态，未登录不启动 |
| iOS | `flutter_background_service` 有限后台任务（30s~3min），不追求常驻，代码对 iOS 无害 |

## Power Consumption

- 前台服务：零额外 CPU 运算，仅静态通知栏图标
- WebSocket 心跳：Supabase Realtime 约 30s 一次心跳，几个字节
- 结论：正常使用下后台耗电可忽略不计
