# 2026-05-21 工作归档

## 版本

`1.0.7+12`

## 主要变更

### 1. 语音消息（好友聊天）

- 新增 `VoiceService`（`lib/services/voice_service.dart`）和 `TtsService`（`lib/services/tts_service.dart`）
- 好友聊天页支持录音（长按录制，最长60秒自动发送）
- 新增语音消息气泡（`ChatMessageBubble`），包含播放/暂停、时长显示、简易波形条
- 使用 `audioplayers` 包处理语音播放，全局单例 `AudioPlayer` 避免多个同时播放
- 依赖 `cached_network_image` 进行图片缓存优化

### 2. AI 服务迁移

- 从阿里云 DashScope（qwen-turbo-latest）切换到 DeepSeek API（deepseek-chat）
- 新增 `enable_search` 参数支持联网搜索
- API 基点从 `dashscope.aliyuncs.com` 改为 `api.deepseek.com`

### 3. "魔魔胡胡胡萝卜" 自动插话

- 当好友聊天中出现五月天/阿信/陈信宏相关关键词时，AI 自动以阿信身份插入一条幽默短句
- 新增 `interveneSystemPrompt` 系统提示词，限定 50 字以内、幽默自嘲、自然引用五月天歌词
- 每次触发后冷却 30 分钟（`_lastInterventionTime`）

### 4. 聊天消息多选模式

- 好友聊天页支持多选模式：长按进入，可批量处理消息
- 新增 `_isSelectionMode` 和 `_selectedIndexes` 状态管理

### 5. UI / 组件增强

- `ChatMessageBubble` 新增：语音气泡、AI 头像（`aiAvatarAssetPath`）、长按详情回调（`onLongPressStart`）
- `LogEditorDialog`、`UpdateDialog` 等弹窗组件增强
- `ProfilePage`、`MoodDetailsPage` 等多页面增强

### 6. 通知与实时同步

- `NotificationService` 新增 `activeChatFriendId` 追踪当前活跃聊天
- 好友心情改为实时订阅（`addFriendToRealtime`）

### 7. 新增未跟踪文件

- `lib/services/voice_service.dart`
- `lib/services/tts_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/knowledge_base_service.dart`
- `lib/pages/friend_chat_by_id_page.dart`
- `lib/pages/voice_sample_page.dart`
- `assets/` 资源目录
- 测试目录 `test/enums/`、`test/models/`、`test/services/`

### 8. 新增依赖

- `audioplayers` — 音频播放
- `cached_network_image` — 网络图片缓存

## 涉及文件（已修改 35 个）

| 文件 | 变更量 |
|---|---|
| `lib/pages/friend_chat_page.dart` | +1096 |
| `lib/services/friend_chat_service.dart` | +196 |
| `lib/services/ai_service.dart` | +97 |
| `lib/widgets/chat_message_bubble.dart` | +93 |
| `lib/widgets/log_editor_dialog.dart` | +186 |
| `lib/providers/theme_provider.dart` | +85 |
| `lib/services/remote_mood_service.dart` | +81 |
| 其余 28 个文件 | 合计 +600 |

**总计：35 个文件，+2874 / -333 行**

## 待提交

所有变更尚未提交（worktree dirty），建议按功能拆分为多个 commit：

1. AI 服务迁移（DeepSeek + enable_search）
2. 语音消息功能
3. "魔魔胡胡胡萝卜"自动插话
4. 多选模式与 UI 增强
5. 版本号 bump
