# OAM 视角的 App 质量保障方案

> OAM（Operations, Administration, Maintenance）源自通信行业网络管理框架，本文档将其核心理念——PM 指标、FM 告警、信令回溯——映射到移动 App 质量保障场景。

## 1. PM（Performance Management，性能管理）

### 1.1 关键性能指标（KPI）

| 指标 | 目标值 | 采集方式 |
|------|--------|----------|
| 冷启动首帧时间 | < 2s | AppTrace + Sentry Performance |
| AI 对话首 Token 延迟 | < 2s | AppTrace（aiChatApiRequest → aiChatResponse） |
| 心情创建保存耗时 | < 500ms | AppTrace（moodCreateLocalSave） |
| 远端同步耗时 | < 3s | AppTrace（moodCreateRemoteSync） |
| Crash-free rate | > 99.5% | Sentry Release Health |
| 列表滚动帧率 | ≥ 55fps | Flutter DevTools Performance |

### 1.2 数据采集架构

```
App 启动 → SentryFlutter.init (自动采集帧率/内存/ANR)
         → AppTrace (业务链路耗时埋点)
         → Sentry Performance (自动 span 上报)
```

### 1.3 看板建议

- Sentry Dashboard：Release Health + Performance 概览
- 自定义 Grafana Dashboard（如自建后端采集）：冷启动 P50/P95/P99

## 2. FM（Fault Management，故障管理）

### 2.1 告警分级

| 级别 | 定义 | 触发条件 | 通知方式 |
|------|------|----------|----------|
| Critical | 用户无法使用 | Crash 率 > 1%、登录成功率 < 95% | Sentry Alert → 邮件/飞书 |
| Warning | 功能降级 | AI API 超时率 > 10%、数据库写入失败 > 5% | Sentry Alert |
| Info | 需关注 | 版本更新检查失败、图片上传失败 | Sentry 面板 Review |

### 2.2 异常捕获覆盖

```
┌─────────────────────────────────────────────┐
│  SentryFlutter.init (全局兜底)               │
│  ├── FlutterError.onError (Widget 构建错误)   │
│  ├── PlatformDispatcher.instance.onError      │
│  └── runZonedGuarded (未捕获异常)             │
├─────────────────────────────────────────────┤
│  手动上报 (关键业务异常)                       │
│  ├── AIService (getComfort/chat/mail/介入)    │
│  ├── RemoteMoodService (upload/sync/restore)  │
│  ├── AuthProvider (login/register)            │
│  └── AppTrace (链路节点失败)                  │
└─────────────────────────────────────────────┘
```

### 2.3 告警规则建议（Sentry）

- **Critical**：`error` 级别事件 > 5 次/小时 → 通知
- **Warning**：`trace` 类别 breadcrumb 中 `success=false` 比例 > 20% → 通知

## 3. 信令回溯（Call Chain Tracing）

### 3.1 设计思路

借鉴通信网络中信令回溯的理念：每个关键业务操作分配一个 TraceNode，记录操作的起止时间、成功/失败状态。Debug 模式下输出完整链路日志，Release 模式下通过 Sentry Breadcrumb 仅记录异常节点。

### 3.2 链路节点定义

```
App 生命周期：
  cold_start ──→ first_frame

用户认证链路：
  login_start ──→ login_token_refresh ──→ login_home_page

心情创建链路：
  mood_create_local_save ──→ mood_create_remote_sync

AI 对话链路：
  ai_chat_api_request ──→ ai_chat_response ──→ ai_chat_display
```

### 3.3 数据格式

每个 Trace 节点记录：

```json
{
  "node": "cold_start",
  "start": "2026-05-26T10:00:00.000Z",
  "duration_ms": 1234,
  "success": true,
  "error": null
}
```

### 3.4 实现

- `lib/services/app_trace.dart`：轻量 Trace 工具类
- Debug 模式：`log()` 输出全链路
- Release 模式：仅异常节点通过 Sentry Breadcrumb + Exception 上报
- `AppTrace.wrap()` 便捷方法：自动 start/end + Sentry 异常上报

### 3.5 排查示例

用户反馈"心情保存很慢"：

1. 查看 Sentry Performance → 筛选 `mood_create_remote_sync` span
2. 发现 duration_ms 集中在 5s-8s，说明远端 Supabase 写入慢
3. 联动检查 Supabase Dashboard → 确认数据库连接池是否饱和

## 4. 工具链

| 工具 | 用途 | 接入状态 |
|------|------|----------|
| Sentry Flutter SDK | Crash/Error 采集 + Performance | 已完成 |
| AppTrace (自研) | 业务链路埋点 | 已完成 |
| Flutter DevTools | 本地性能分析 | 可用 |
| Supabase Dashboard | 数据库监控 | 可用 |

## 5. 后续优化方向

- [ ] 接入 Sentry Performance 自动采集（已配置 tracesSampleRate=1.0，后续可在 Dashboard 查看）
- [ ] 自建后端增加 /api/health 健康检查 + Prometheus metrics 端点
- [ ] 配置 Sentry Alert 规则（需创建 Sentry 项目并获取 DSN 后配置）
- [ ] 建立周报机制：每周 Review Sentry Dashboard 的 Crash 趋势和 P50/P95 延迟

---

*设计原则：不追求大而全，聚焦对用户体验有直接影响的 3-5 个核心指标。*
