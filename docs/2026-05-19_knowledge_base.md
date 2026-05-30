# 2026-05-19 工作记录

## 一、知识库（提升萝卜 AI 歌词回答准确性）

### 背景

萝卜 AI 助手（五月天阿信 persona）在歌词方面的回答不准确，`qwen-turbo-latest` 模型缺乏五月天歌词的训练数据，经常编造或错误引用歌词。

### 方案

采用 **本地知识库 + 关键词/主题标签检索**，在发送 AI 请求前将匹配到的真实歌词和资料注入 system prompt。

### 变更

| 文件 | 操作 | 说明 |
|---|---|---|
| `assets/mayday_knowledge.json` | 新建 | 知识库：78 首歌曲、12 张专辑、5 位成员（含生日）、24 条乐队事实，每条带主题标签 |
| `lib/services/knowledge_base_service.dart` | 新建 | 检索引擎：中文分词(n-gram) + 多维评分（标题/标签/关键词/歌词）+ 概念匹配 |
| `lib/pages/ai_chat_page.dart` | 修改 | `_sendMessage()` 中为 luobo 助手注入检索结果到 system prompt |
| `lib/models/ai_assistant.dart` | 修改 | 更新 system prompt，要求 AI 基于资料回答、不编造歌词 |
| `pubspec.yaml` | 修改 | 添加 `assets/mayday_knowledge.json` 到 assets |

### 修复的 bug

1. **生日查询失败** — `_formatContext` 成员部分漏输出 `birthday` 字段；`birthday.contains("生日")` 永远为 false（日期字符串里没有"生日"两字）→ 改为概念匹配 `_matchesConcept(token, ['生日', '出生'])`
2. **"队伍"查询无命中** — 成员缺少 `"队伍"`、`"成员"`、`"五月天"` 标签 → JSON 补全
3. **5 人只返回 3 人** — `maxResults` 截断同分条目 → 改为同分不截断
4. **song year 不参与 scoring** — 问"2004 年的歌"搜不到 → year 加入评分
5. **song description 未格式化输出** — 歌词背后的故事没送给 AI → 格式化时追加 description
6. **album year 不参与 scoring** — 同上

### 流程

```
用户消息 → 中文分词 + 多维度评分 → 命中 → 注入 system prompt → AI 基于真实歌词回答
```

---

## 二、好友聊天语音消息

### 变更

| 文件 | 操作 | 说明 |
|---|---|---|
| `pubspec.yaml` | 修改 | 新增 `record`、`audioplayers`、`path` 依赖 |
| `lib/models/chat_message.dart` | 修改 | 新增 `audioUrl`、`audioDuration` 字段，新增 `isVoiceMessage` getter |
| `lib/services/voice_service.dart` | 新建 | 录音(AAC 64kbps)、上传 Supabase Storage、释放资源 |
| `lib/services/friend_chat_service.dart` | 修改 | `sendMessage`/`getMessages` 支持 `audio_url` + `audio_duration` |
| `lib/widgets/chat_message_bubble.dart` | 修改 | 语音气泡：播放/暂停按钮 + 时长 + 简易波形条 |
| `lib/pages/friend_chat_page.dart` | 修改 | 麦克风按钮、录音状态栏(闪烁红点+秒数+取消/发送)、播放控制 |
| `supabase_schema.sql` | 修改 | `friend_messages` 表新增 `image_url`、`audio_url`、`audio_duration` 列 |

### 使用方式

点麦克风 → 录音（红点闪烁 + 秒数） → 点发送 → 上传 Supabase → 对方看到语音气泡 → 点击播放

### 部署注意

需在 Supabase SQL Editor 执行：
```sql
ALTER TABLE friend_messages ADD COLUMN IF NOT EXISTS audio_url TEXT;
ALTER TABLE friend_messages ADD COLUMN IF NOT EXISTS audio_duration INTEGER;
```

---

## 三、其他修复

1. **对话内容复制** — `ai_chat_page.dart` 选择模式新增复制按钮（`Clipboard.setData`）
2. **Android 构建失败** — Java 21 仅有 JRE 无 javac → `android/gradle.properties` 强制指定 JDK 17

---

## 四、AI 模型迁移到 DeepSeek

### 背景

原模型 Aliyun DashScope `qwen-turbo-latest` 在某些场景回答质量不足，切换为 DeepSeek 的 `deepseek-chat` 模型。

### 变更

| 文件 | 操作 | 说明 |
|---|---|---|
| `lib/services/ai_service.dart` | 修改 | `baseUrl` → `https://api.deepseek.com/v1/chat/completions`，`model` → `deepseek-chat` |
| `lib/services/ai_chat_manager.dart` | 修改 | 跟进模型名变更 |

---

## 五、萝卜 AI 头像

### 变更

| 文件 | 操作 | 说明 |
|---|---|---|
| `assets/carrot.jpg` | 新建 | 萝卜头像图片 |
| `pubspec.yaml` | 修改 | 添加 `assets/carrot.jpg` 到 assets |
| `lib/models/ai_assistant.dart` | 修改 | 新增 `avatarAssetPath` 字段，luoBo 实例设为 `assets/carrot.jpg` |
| `lib/pages/ai_chat_page.dart` | 修改 | AppBar CircleAvatar 使用图片头像 |
| `lib/pages/chat_list_page.dart` | 修改 | 对话列表 CircleAvatar 使用图片头像 |
| `lib/widgets/chat_message_bubble.dart` | 修改 | 新增 `aiAvatarAssetPath` 参数，支持图片头像 vs emoji 文字 |

---

## 六、萝卜 AI 好友对话介入

### 需求

在好友对话中，打开介入开关后，萝卜 AI 检测到五月天/阿信相关关键词时自动插话，风格幽默风趣。

### 变更

| 文件 | 操作 | 说明 |
|---|---|---|
| `lib/providers/theme_provider.dart` | 修改 | 新增 `luoBoInterventionEnabled` 开关 + SharedPreferences 持久化 |
| `lib/pages/chat_list_page.dart` | 修改 | 右上角 ⋮ 菜单中集成介入开关（PopupMenuButton + Switch） |
| `lib/services/ai_service.dart` | 修改 | 新增 `containsMaydayKeywords()` 关键词检测 + `interveneInFriendChat()` 调用 DeepSeek |
| `lib/models/chat_message.dart` | 修改 | 新增 `showSenderHeader`、`senderEmoji`、`senderAvatarAssetPath` 字段，toList/fromList 升级到 v3 |
| `lib/pages/friend_chat_page.dart` | 修改 | 新增 `_checkAndTriggerIntervention()`，在消息轮询/加载/发送三条路径触发，30s 冷却 |
| `lib/widgets/chat_message_bubble.dart` | 修改 | 非用户气泡支持 per-message 头像 + 名字头，萝卜介入消息显示 carrot 图片 + "萝卜" 标签 |

### 触发流程

```
新消息到达 → 检查开关 & 30s 冷却 → AIService.containsMaydayKeywords()
→ 构建最近 5 条上下文 → AIService.interveneInFriendChat()
→ DeepSeek 返回 → 作为 ChatMessage(isUser:false, senderName:'萝卜', showSenderHeader:true) 插入
```

### 关键词列表

五月天、阿信、陈信宏、信宏、mayday、Mayday、MAYDAY、怪兽、石头、玛莎、冠佑、主唱、Ashin、ashin、ASHIN

---

## 七、知识库扩充

知识库从 59 首歌、10 张专辑、8 条事实扩充至 **78 首歌、12 张专辑、24 条事实**，成员信息大幅丰富。

### 新增歌曲（约 20 首）
离开地球表面、轧车、相信、DNA、玫瑰少年、兄弟、终于结束的起点、什么歌、一半人生、摩托车日记、米老鼠、宠上天、春天的呐喊、约翰蓝侬、T1213121、2012、心中无别人、透露、牙关

### 新增专辑（2 张）
离开地球表面 Jump! The World、作品 9号

### 成员扩充
每位成员新增 5-8 条事实（个性、乐器、创作、趣闻等）

### 新增事实（18 条）
阿信经典语录、歌曲创作故事、蓝色三部曲、20 周年纪念、阿信作词习惯、歌迷文化、诺亚方舟巡回、人生无限公司巡回、阿信副业、阿信合作、怪兽吉他、石头演艺、玛莎文艺、冠佑稳定、作品编号等
