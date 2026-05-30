# 2026-05-20 好友聊天 Bug 修复 & 构建优化

## 好友聊天 Bug 修复

### Bug 1: 消息无法发送

**根因**: `FriendChatService.sendMessage()` 每次 INSERT 都包含 `is_ai_message` 字段，但数据库 `friend_messages` 表中缺少此列。PostgREST 遇到不存在的列直接拒绝整条 INSERT，导致所有消息（普通 + AI 介入）全部发送失败。

**修复** (`supabase_schema.sql`):
```sql
ALTER TABLE friend_messages ADD COLUMN IF NOT EXISTS is_ai_message BOOLEAN DEFAULT FALSE;
```

### Bug 2: 麦克风无法打开

**根因**: `VoiceService.startRecording()` 用 try/catch 静默吞掉所有异常返回 `null`。`FriendChatPage._startRecording()` 收到 `null` 后无任何用户反馈——不弹提示、UI 不变。用户点击麦克风后什么都看不到。

**修复**:
- `lib/services/voice_service.dart`: 权限不足返回 `null`（可区分），启动失败抛异常（不再静默吞）；添加 fallback 编码器（AAC-LC 失败后尝试默认配置）
- `lib/pages/friend_chat_page.dart`: 区分「无权限」和「启动失败」，分别显示对应 SnackBar

### Bug 3: Supabase Realtime 频道反复断连

**根因**: `friend_messages` 表未加入 `supabase_realtime` publication，导致订阅后立即被服务端断开（subscribed → closed 循环）。

**修复** (`supabase_schema.sql`):
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE friend_messages;
ALTER TABLE public.friend_messages REPLICA IDENTITY FULL;
```

## 构建内存优化

### 问题: Release 构建 Metaspace 溢出

R8 代码混淆 + 多模块 lint 分析导致 JVM Metaspace（类元数据）不足。同时 Kotlin 编译器守护进程默认 `-Xmx3G` 在 5.1G 机器上过重。

### 修复 (`android/gradle.properties`)

| 配置 | 之前 | 之后 | 作用 |
|------|------|------|------|
| `MaxMetaspaceSize` | 256M | 512M | R8 混淆需要更多类元数据 |
| `android.enableLint` | true | false | 跳过 lintVitalAnalyzeRelease |
| `kotlin.daemon.jvmargs` | -Xmx3G (默认) | -Xmx1G | 省 2G 内存 |

## 待执行（Supabase SQL Editor）

```sql
ALTER TABLE friend_messages ADD COLUMN IF NOT EXISTS is_ai_message BOOLEAN DEFAULT FALSE;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public' AND tablename = 'friend_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE friend_messages;
  END IF;
END $$;

ALTER TABLE public.friend_messages REPLICA IDENTITY FULL;
```

## 变更文件

| 文件 | 变更 |
|------|------|
| `supabase_schema.sql` | 添加 is_ai_message 列 + friend_messages Realtime 配置 |
| `lib/services/voice_service.dart` | 错误抛异常 + 编码器 fallback |
| `lib/pages/friend_chat_page.dart` | 录音失败用户提示 |
| `android/gradle.properties` | Metaspace 512M + 禁用 lint + Kotlin daemon 1G |

---

## 发版流水线修复（下午）

### release.sh 从头重写

旧脚本存在多个问题，逐一修复后成功发布 `v1.0.1`。

| 问题 | 根因 | 修复 |
|------|------|------|
| git "不是仓库" | `PROJECT_DIR=$(dirname $SCRIPT_DIR)` 向上取了一层父目录 | 改为 `PROJECT_DIR=$SCRIPT_DIR`（脚本就在项目根目录） |
| Supabase 403 "Invalid Compact JWS" | 旧 key `sb_secret_6kWu...` 不是有效 JWT 格式 | 用 Dashboard → API → Legacy `service_role` 完整 JWT 替换 |
| Storage 上传 403 | curl 缺少 `apikey` header | 补充 `-H "apikey: $KEY"` |
| APK 上传 413 "Payload too large" | 单 APK 60MB 超 Supabase 免费版 50MB 限制 | `flutter build apk --release` → `--split-per-abi`（arm64/armeabi/x86_64） |
| 无法跳过构建 | 无相应参数 | 新增 `--skip-build` 参数 |
| Gradle daemon OOM | `-Xmx8G` 在 5.1GB 虚拟机上直接被杀 | 降为 `-Xmx1536m` |

### 发版产物

Supabase Storage `mood_images` bucket：

| 路径 | ABI | 大小 |
|------|-----|------|
| `releases/app-release.apk` | arm64-v8a（主下载包，App 默认 URL） | 21MB |
| `releases/app-armeabi-v7a-release.apk` | 32 位 ARM | 19MB |
| `releases/app-x86_64-release.apk` | 模拟器 | 23MB |

### 网络排障

- 宿主机 Windows + Clash Verge TUN 模式，Ubuntu 为 VMware 虚拟机（NAT 网络）
- Clash "允许局域网连接" 因 Windows 防火墙未放行端口，VM 无法直连 7897 代理端口
- **结论：TUN 模式在宿主机层面透明代理，VM 流量经 NAT 自动走 TUN，无需额外配 git proxy**

### Supabase Key 类型

| Key | 前缀 | 权限 | 用途 |
|-----|------|------|------|
| anon / publishable | `sb_publishable_` | 受 RLS 限制 | App 客户端 |
| service_role | `sb_secret_`（旧）/ 纯 JWT | 绕过 RLS，完全权限 | 管理脚本，**不可泄露** |

`release.sh` 需要 service_role 因为 Storage 写入和 `app_config` PATCH 超出 RLS 允许范围。

### 配置快照

`app_config` 表当前值：
- `latest_version`: `1.0.1`
- `force_update`: `false`
- `update_url_android`: `https://tjedmzbioaeualutpbxv.supabase.co/storage/v1/object/public/mood_images/releases/app-release.apk`
- `update_url_ios`: `""`
