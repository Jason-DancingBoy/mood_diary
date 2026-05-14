# 心情日记 - 模块功能说明

## 项目概述

**心情日记**是一款帮助用户记录每日心情的 Flutter 应用，配合 AI 伴侣"小暖"提供温暖的心理陪伴服务。支持心情记录、AI 对话、自动邮件关怀等功能。

---

## 目录结构

```
lib/
├── main.dart                      # 应用入口
├── constant/
│   └── app_constants.dart         # 应用常量
├── enums/
│   ├── mood_type.dart             # 心情类型枚举（9种心情）
│   ├── message_frequency.dart     # 消息频率枚举
│   └── message_log_range.dart     # 记录范围枚举
├── models/
│   └── mood_log.dart              # 心情日志数据模型
├── pages/
│   ├── home_page.dart             # 首页（底部导航栏）
│   ├── mood_list_page.dart        # 心情记录列表
│   ├── mood_details_page.dart    # 心情详情页
│   ├── mood_calendar_page.dart    # 日历视图 + 曲线图
│   ├── ai_chat_page.dart         # 小暖对话页
│   ├── message_page.dart          # 收件箱页
│   ├── profile_page.dart          # 个人设置页
│   └── full_screen_image_view.dart # 全屏图片查看
├── providers/
│   └── theme_provider.dart        # 主题与设置状态管理
├── services/
│   ├── ai_service.dart            # AI 对话服务（阿里云 API）
│   ├── message_service.dart       # 小暖邮件消息生成
│   ├── message_scheduler.dart     # 消息调度器
│   └── image_manager.dart         # 图片管理服务
└── widgets/
    ├── mood_log_card.dart         # 心情日志卡片组件
    └── log_editor_dialog.dart     # 日志编辑对话框
```

---

## 功能模块详解

---

### 1. 首页导航 (`home_page.dart`)

底部导航栏包含 **4 个标签页**，实现页面切换：

| 标签 | 图标 | 页面 | 功能 |
|------|------|------|------|
| 记录 | edit_note | MoodListPage | 心情记录列表 |
| 对话 | psychology | AIChatPage | 与小暖 AI 对话 |
| 收件箱 | mail | MessagePage | 小暖发来的邮件 |
| 我的 | person | ProfilePage | 个人设置 |

**实现方式**：使用 Flutter `NavigationBar` 组件，通过 `_selectedIndex` 切换 `_pages` 列表中的页面。

---

### 2. 心情记录模块

#### 2.1 心情列表页 (`mood_list_page.dart`)

**核心功能：**

1. **今日概览卡片**
   - 顶部显示"今日概览"
   - 统计当天各心情类型的记录数量
   - 显示格式：`今天心情：开心(2)、难过(1) (共记录 3 条)`

2. **记录列表**
   - 按时间倒序显示所有心情记录
   - 每条记录显示：心情图标、笔记内容、时间
   - 点击卡片进入详情页

3. **滑动删除**
   - 向左滑动记录卡片，显示删除按钮
   - 需二次确认后删除（避免误删）
   - 删除记录时同步删除关联图片

4. **批量选择模式**
   - 点击右上角"批量选择"按钮进入
   - 可全选、反选多条记录
   - 支持批量删除、批量分享
   - 底部显示删除按钮

5. **分享功能**
   - 分享格式：
     ```
     📔 我的心情日记
     ═══════════════════
     
     ⏰ 2026/4/6 19:15
     💭 开心
     
     今天心情很好！
     
     ───────────────────
     
     ═══════════════════
     来自：心情日记 App
     ```

6. **跳转日历**
   - 点击右上角日历图标
   - 进入心情日历视图

7. **新建记录**
   - 右下角 FAB 按钮"记录心情"
   - 弹出 `LogEditorDialog` 编辑器

---

#### 2.2 日志编辑器 (`log_editor_dialog.dart`)

**功能特点：**

1. **心情选择**
   - 9 种预设心情类型（见下方枚举）
   - 点击选中，高亮显示

2. **笔记输入**
   - 多行文本输入框
   - 最多 3 行可见

3. **图片功能**
   - 点击添加图片按钮
   - 支持多选（最多 9 张）
   - 图片预览，支持删除
   - 图片保存到应用文档目录

4. **自定义表情**
   - 可输入自定义 emoji
   - 可选择颜色
   - 可输入自定义标签（如"工作压力"）
   - 自定义表情会覆盖默认心情图标

5. **AI 安慰开关**
   - 开关控制是否启用 AI 安慰
   - 开启后，详情页会自动请求 AI 安慰

6. **保存逻辑**
   - 生成唯一 ID（时间戳）
   - 保存到 Hive 数据库
   - 保存后刷新列表

---

#### 2.3 心情类型枚举 (`mood_type.dart`)

| 枚举值 | 中文标签 | 心情分数 | 图标颜色 | 背景色 |
|--------|----------|----------|----------|--------|
| happy | 开心 | 8 | 粉色 | 粉色15% |
| calm | 平静 | 7 | 青色 | 青色15% |
| sad | 难过 | 3 | 蓝色 | 蓝色15% |
| anxious | 焦虑 | 4 | 紫色 | 紫色15% |
| angry | 生气 | 2 | 红色 | 红色15% |
| blissful | 幸福 | 10 | 深橙 | 深橙15% |
| fear | 恐惧 | 2 | 靛蓝 | 靛蓝15% |
| surprise | 惊讶 | 6 | 琥珀 | 琥珀15% |
| disgust | 厌恶 | 1 | 黄绿 | 黄绿15% |

**心情分数**：1-10 分，用于曲线图统计和心情趋势分析。

---

#### 2.4 心情详情页 (`mood_details_page.dart`)

**功能特点：**

1. **心情卡片展示**
   - 显示心情类型（图标+标签）
   - 显示记录时间
   - 显示笔记内容

2. **图片画廊**
   - 网格布局展示多张图片
   - 点击图片进入全屏查看
   - 支持缩放、滑动浏览

3. **AI 安慰功能**
   - 进入页面自动请求 AI 安慰（需开启）
   - 显示加载状态
   - 展示 AI 生成的温暖回复
   - 保存到数据库

4. **编辑功能**
   - 点击编辑按钮
   - 弹出 `LogEditorDialog` 编辑器
   - 修改后保存更新

5. **分享功能**
   - 分享当前记录
   - 格式与列表页分享相同

---

#### 2.5 心情日历页 (`mood_calendar_page.dart`)

**功能特点：**

1. **月历视图**
   - 显示当前月份的日历
   - 左右滑动切换月份
   - 每天根据心情显示不同颜色圆点
   - 点击日期查看当天记录

2. **当月心情统计**
   - 显示本月各心情类型的数量
   - 饼图/柱状图可视化

3. **心情曲线图**
   - 使用 `fl_chart` 库绘制
   - 三种时间范围：7天、30天、全部
   - "全部"模式按月统计平均分
   - Y 轴为心情分数（1-10）
   - 点击数据点可查看详情

4. **点击日期查看记录**
   - 底部弹出当天记录列表
   - 点击记录进入详情页

---

### 3. AI 对话模块 (`ai_chat_page.dart`)

**功能特点：**

1. **心理咨询师角色**
   - 角色名：小暖 🌻
   - 三阶段咨询流程：
     - **共情与倾听**：真诚接纳，表达理解
     - **探索与深挖**：引导探索原生家庭、过往经历
     - **赋能与解决**：指出正常性，提供建议，给予鼓励

2. **多轮对话**
   - 每次发送消息都携带完整历史上下文
   - AI 能记住之前的对话内容
   - 支持连续的深度对话

3. **消息气泡 UI**
   - 用户消息：右侧蓝色气泡
   - AI 消息：左侧灰色气泡，带小暖头像
   - 显示时间戳

4. **历史记录管理**
   - 点击右上角"历史"图标
   - 显示所有历史对话列表
   - 每条显示：预览、时间、消息数
   - 支持加载、删除历史对话

5. **开启新对话**
   - 点击右上角"+"图标
   - 当前对话自动保存到历史
   - 清空界面，开始新对话

6. **批量选择与操作**
   - 长按消息进入选择模式
   - 可批量删除、分享消息
   - 分享格式带时间戳

7. **离线模式**
   - 断网模式下提示无法对话

---

### 4. 收件箱模块 (`message_page.dart`)

**功能特点：**

1. **邮件列表**
   - 显示小暖发来的所有邮件
   - 按时间倒序排列
   - 未读邮件显示红点标记
   - 未读邮件背景高亮

2. **邮件卡片**
   - 发件人：小暖 🌻
   - 显示主题、内容预览（2行）
   - 显示收到时间

3. **邮件详情**
   - 完整邮件内容
   - 发件人信息（头像、邮箱）
   - 收件人信息
   - 时间戳
   - 小暖签名

4. **邮件生成逻辑**
   - 根据心情记录生成
   - 引用正能量名言
   - 根据心情倾向选择名言类型：
     - 正向心情：幸福、成长名言
     - 负向心情：接纳、勇气名言

5. **批量删除**
   - 长按邮件进入选择模式
   - 显示复选框
   - 支持全选
   - 确认后批量删除

6. **未读计数**
   - 导航栏标题旁显示红点数字
   - 实时更新

---

### 5. 个人设置模块 (`profile_page.dart`)

#### 5.1 字体颜色设置
- 6 种颜色可选：黑、蓝、绿、红、紫、橙
- 实时预览效果
- 保存到 SharedPreferences

#### 5.2 断网模式
- 开关控制
- 开启后禁用所有 AI 功能
- 适用于无网络环境或隐私场景

#### 5.3 小暖消息设置

**消息发送频率**：
| 选项 | 说明 |
|------|------|
| 一小时一次 | 每隔1小时检查并发送 |
| 一天两次 | 每天最多2封邮件 |
| 一天一次 | 每天最多1封邮件 |
| 两天一次 | 每隔2天发送 |
| 三天一次 | 每隔3天发送 |
| 不回复 | 禁用自动消息 |

**消息读取记录范围**：
| 选项 | 说明 |
|------|------|
| 3天 | 读取最近3天的心情记录生成邮件 |
| 1周 | 读取最近7天 |
| 2周 | 读取最近14天 |
| 1个月 | 读取最近30天 |

---

### 6. AI 服务层 (`ai_service.dart`)

#### 6.1 对话功能 `chat()`
- **API**：阿里云通义千问 (qwen-turbo)
- **调用方式**：`AIService.chat(history, newMessage)`
- **历史格式**：`List<List<String>>` = `[[role, content], ...]`
- **角色**：`roleUser=0`（用户）、`roleAssistant=1`（AI）
- **参数**：
  - `max_tokens: 800`
  - `temperature: 0.8`（较高创意性）
- **离线返回**：固定提示语

#### 6.2 安慰功能 `getComfort()`
- **用途**：为心情记录生成安慰回复
- **输入**：心情类型 + 笔记内容
- **输出**：温暖、简短的安慰语（200字内）
- **参数**：
  - `max_tokens: 400`
  - `temperature: 0.7`
- **离线返回**：固定安慰语"虽然不知道发生了什么，但我陪着你。"

---

### 7. 消息生成服务 (`message_service.dart`)

**功能**：
- 根据用户心情记录生成邮件内容
- 包含名人名言引用
- 自动生成邮件主题

**名言库**：
- 正向名言（20条）：关于幸福、成长、自我实现
- 支持名言（26条）：关于接纳、勇气、韧性

**邮件主题自动生成规则**：
- 包含"提醒"→ "一条温暖的提醒"
- 包含"鼓励"→ "给你的鼓励信"
- 包含"感谢"→ "感谢你的记录"
- 默认 → "来自小暖的问候"

---

### 8. 消息调度器 (`message_scheduler.dart`)

**功能**：
- 定时检查是否需要发送邮件
- 支持多种频率配置
- 后台 Timer 实现

**实现逻辑**：
1. 每小时检查一次
2. 根据频率判断是否应该发送
3. 读取心情记录
4. 调用 MessageService 生成内容
5. 保存到邮件数据库
6. 更新发送状态

---

### 9. 主题与状态管理 (`theme_provider.dart`)

**状态**：
| 状态 | 类型 | 默认值 | 持久化 |
|------|------|--------|--------|
| 字体颜色 | Color | 黑色 | SharedPreferences |
| 离线模式 | bool | false | SharedPreferences |
| 消息频率 | MessageFrequency | 一天一次 | SharedPreferences |
| 记录范围 | MessageLogRange | 3天 | SharedPreferences |

**Provider 模式**：使用 Flutter Provider 管理全局状态，UI 自动响应变化。

---

### 10. 数据存储

#### 10.1 Hive 数据库

| Box 名称 | 用途 | 数据结构 |
|----------|------|----------|
| `mood_logs_box` | 心情记录 | `Map<dynamic, dynamic>` |
| `mail_messages_box` | 邮件消息 | `Map<dynamic, dynamic>` |
| `ai_chat_history` | AI 对话历史 | `List<dynamic>` |

#### 10.2 SharedPreferences

持久化存储用户设置：
- `fontColor`: int（颜色值）
- `offlineMode`: bool
- `messageFrequency`: int（枚举索引）
- `messageLogRange`: int（枚举索引）

#### 10.3 图片存储

- 存储位置：应用文档目录 `/mood_images/`
- 文件命名：UUID 或时间戳
- 缓存机制：`ImageManager` 提供路径缓存

---

### 11. 图片管理 (`image_manager.dart`)

**功能**：
- `saveImageToFile()`: 保存图片到文档目录
- `getImagePathAsync()`: 获取图片路径
- `deleteImage()`: 删除图片
- `warmupCache()`: 预热缓存

---

## 技术栈

| 技术 | 版本/说明 | 用途 |
|------|----------|------|
| Flutter | 3.x | 跨平台框架 |
| Provider | 最新 | 状态管理 |
| Hive | hive_flutter | 本地数据库 |
| http | 最新 | 网络请求 |
| image_picker | 最新 | 图片选择 |
| share_plus | 最新 | 内容分享 |
| fl_chart | 最新 | 图表绘制 |
| intl | 最新 | 日期格式化 |

---

## API 集成

### 配置信息

- **服务商**：阿里云通义千问
- **模型**：qwen-turbo
- **端点**：`https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`
- **认证方式**：Bearer Token

### API Key 配置

API Key 存储在项目根目录 `ali_apikey.env` 文件中：
```
DASHSCOPE_API_KEY=sk-a29fe46ce1af4a6e9d921fe5636cad7a
```

**使用场景**：
1. AI 对话（多轮聊天）
2. 心情记录安慰（单次生成）
3. 邮件内容生成（定时任务）

> ⚠️ **注意**：请勿将 API Key 上传到公开仓库，建议将 `ali_apikey.env` 加入 `.gitignore`。

---

## 数据模型

### MoodLog（心情日志）

```dart
class MoodLog {
  String id;              // 唯一标识
  MoodType mood;          // 心情类型
  String note;            // 笔记内容
  String? comment;         // 批注（暂未启用）
  List<String>? imageFileNames;  // 图片文件名列表
  DateTime createdAt;      // 创建时间
  String? aiComfort;      // AI 安慰内容
  bool aiEnabled;         // 是否启用 AI
  // 自定义表情（可选）
  String? customEmoji;
  String? customEmojiLabel;
  int? customColorValue;
}
```

---

## 12. 跨设备后端心情分享方案

### 12.1 目标
- 实现跨设备、跨用户的“好友心情分享”功能
- 通过后端服务器传输分享数据
- 兼顾本地缓存与离线体验
- 保持现有心情记录模型和分享入口

### 12.2 总体架构

本方案由三部分组成：
1. **客户端（Flutter）**
   - 本地心情记录仍保存在 Hive
   - 好友关系、分享历史在本地缓存
   - 通过 HTTP / REST 与后端交互
2. **后端服务**
   - 负责账户、好友、心情分享、图片等数据存储
   - 提供标准 API 接口
   - 支持跨设备同步和消息推送（可选）
3. **后端数据库**
   - 用户表
   - 好友表
   - 心情记录表
   - 分享记录表
   - 图片存储或对象存储引用

### 12.3 推荐数据模型

#### UserProfile
- `userId`：唯一用户 ID
- `nickname`：昵称
- `avatarUrl`：头像 URL
- `signature`：签名
- `inviteCode`：邀请码
- `createdAt`：创建时间

#### Friend
- `id`：关系记录 ID
- `userId`：当前用户 ID
- `friendUserId`：好友用户 ID
- `status`：`pending` / `accepted` / `rejected`
- `createdAt`：创建时间
- `remark`：备注

#### MoodRecord（远端心情记录）
- `moodId`：唯一 ID
- `ownerId`：记录所属用户
- `mood`：心情类型
- `note`：心情内容
- `comment`：备注
- `imageUrls`：图片 URL 列表
- `customEmoji`：自定义表情
- `customEmojiLabel`：自定义标签
- `customColorValue`：自定义颜色值
- `createdAt`：创建时间
- `aiComfort`：AI 安慰内容
- `aiEnabled`：AI 开启状态

#### SharedMood
- `sharedId`：分享记录 ID
- `fromUserId`：分享人
- `toUserId`：接收人
- `moodId`：远端心情记录 ID
- `sharedAt`：分享时间
- `readAt`：已读时间
- `permission`：`view` / `comment`
- `status`：`sent` / `received` / `deleted`

### 12.4 后端 API 设计

#### 用户与好友
- `POST /api/auth/login`：登录
- `POST /api/auth/register`：注册
- `GET /api/user/me`：获取当前用户信息
- `GET /api/user/search?keyword=`：搜索用户
- `POST /api/friends/request`：发送好友请求
- `POST /api/friends/accept`：接受好友请求
- `POST /api/friends/reject`：拒绝好友请求
- `GET /api/friends/list`：获取好友列表
- `GET /api/friends/requests`：获取待处理请求

#### 心情记录
- `POST /api/moods`：上传心情记录（可选是否同时保存到本地）
- `GET /api/moods/{moodId}`：获取指定心情记录
- `GET /api/moods?ownerId={userId}`：获取用户心情列表
- `POST /api/images/upload`：上传图片，返回 URL

#### 分享与接收
- `POST /api/shared-moods`：分享心情给好友（创建 SharedMood）
- `GET /api/shared-moods/received`：获取当前用户收到的分享列表
- `GET /api/shared-moods/sent`：获取当前用户发送的分享列表
- `POST /api/shared-moods/{sharedId}/read`：标记已读

### 12.5 客户端存储方案

#### 本地缓存
- `user_profile_box`：本地用户资料缓存
- `friend_box`：本地好友列表缓存
- `shared_mood_box`：本地分享记录缓存
- `remote_mood_box`：可选本地缓存远端心情数据

#### 同步策略
- 登录后拉取好友列表、收到的分享、已发送分享
- 发送分享时先写本地缓存，再异步同步到后端
- 如果离线，先缓存分享请求，网络恢复后自动重试
- 接收方打开分享列表时，优先展示本地缓存，后台刷新最新数据

### 12.6 关键流程

#### 1. 添加好友
1. 用户 A 输入好友 ID / 邀请码
2. APP 调用 `POST /api/friends/request`
3. 后端创建好友请求记录，通知 B（可选推送）
4. 用户 B 查询 `GET /api/friends/requests`
5. B 接受后，后端更新关系为 `accepted`

#### 2. 分享心情
1. 用户 A 在 `mood_details_page.dart` 选择“分享给好友”
2. APP 校验目标好友是否已接受
3. 如果该心情未上传到后端，APP 先调用 `POST /api/moods`
4. 如果有图片，调用 `POST /api/images/upload` 获取 URL
5. APP 调用 `POST /api/shared-moods`，传入 `fromUserId`、`toUserId`、`moodId`
6. 后端保存分享记录，并可推送通知给接收方

#### 3. 接收与展示
1. 用户 B 打开 `shared_mood_page.dart`
2. APP 调用 `GET /api/shared-moods/received`
3. 后端返回分享列表
4. B 点击某条分享，APP 调用 `GET /api/moods/{moodId}` 获取心情详情
5. APP 可将详情缓存在本地，以便切换页面和离线查看

### 12.7 主要页面与组件

- `friend_list_page.dart`：好友列表与好友状态
- `add_friend_page.dart`：输入好友 ID / 邀请码添加好友
- `friend_request_page.dart`：处理好友请求
- `shared_mood_page.dart`：展示收到的好友分享
- `shared_mood_detail_page.dart`：展示好友分享的心情详情
- `friend_tile.dart`：好友卡片组件

### 12.8 推荐服务与 Provider

推荐新增：
- `auth_service.dart`：登录/注册/Token 管理
- `friend_service.dart`：好友请求、列表、关系管理
- `remote_mood_service.dart`：远程心情记录上传与读取
- `shared_mood_service.dart`：分享记录创建与获取
- `friend_provider.dart`：管理好友与请求数据
- `shared_mood_provider.dart`：管理收到分享数据与本地缓存

### 12.9 图片处理方案

- 本地心情图片先保存到应用目录
- 上传分享前调用 `POST /api/images/upload`
- 后端返回图片 URL
- `MoodRecord.imageUrls` 存储远端 URL
- 若用户侧无需完整图片，可只上传首张图片或缩略图

### 12.10 方案实现建议

1. 优先实现账号与好友体系，再实现分享流程。
2. 先构建后端基础 API，然后在 Flutter 端接入。
3. 本地缓存与异步同步并行，提升跨设备体验。
4. 后端应支持单条分享的状态查询与已读标记。
5. 现有 `share_plus` 仍保留用于“导出/分享给手机其它应用”。

### 12.11 关键设计原则

- `MoodLog` 继续作为本地核心记录。跨设备分享时，将其同步为 `MoodRecord`。
- 分享关系由后端 `SharedMood` 管理，避免客户端直接复制业务逻辑。
- 好友关系由后端统一控制，客户端只做展示和同步。
- 上传图片与心情内容分离，降低接口耦合。
- 离线模式不影响本地记录，但分享需在网络恢复后重试。

### 12.12 方案总结

这套方案适合你当前项目的升级方向：
- 现有 Flutter + Hive 架构继续保留
- 新增后端服务实现跨设备同步
- 通过 `user / friend / mood / sharedMood` 四类 API 实现心情分享
- 兼顾本地缓存与在线传输

后续可继续扩展：
- WebSocket / 推送通知
- 分享评论与鼓励回复
- 朋友圈式“好友动态”
- 多人共享和分组分享

---

## 13. 后端服务器选择与部署建议

### 13.1 选择原则

在跨设备分享方案中，后端服务器负责：
- 用户认证与账户管理
- 好友关系维护
- 心情记录与分享数据存储
- 图片上传与存储
- API 接口提供

选择服务器时应考虑：
- **易用性**：快速搭建，减少开发时间
- **成本**：免费额度充足，付费合理
- **集成度**：与 Flutter 兼容，提供 SDK
- **扩展性**：支持后续功能扩展
- **数据安全**：用户数据保护

### 13.2 推荐服务器选项

#### 选项 1：Supabase（推荐首选）
- **类型**：开源 BaaS（Backend as a Service）
- **优势**：
  - 基于 PostgreSQL，提供实时数据库
  - 内置认证、存储、API 生成
  - Flutter SDK 完善，支持实时订阅
  - 免费额度：每月 500MB 数据库、50GB 存储
  - 易于部署到 Vercel / Railway / 自托管
- **适用场景**：快速原型与中小型应用
- **集成方式**：`supabase_flutter` 包
- **官网**：https://supabase.com

#### 选项 2：Firebase
- **类型**：Google 云服务 BaaS
- **优势**：
  - Firestore 实时数据库
  - Firebase Auth 认证
  - Cloud Storage 图片存储
  - FlutterFire SDK 官方支持
  - 免费额度：每月 1GB 存储、100K 次读取
- **适用场景**：大型应用，Google 生态
- **集成方式**：`firebase_core` + `cloud_firestore`
- **官网**：https://firebase.google.com

#### 选项 3：Appwrite
- **类型**：开源 BaaS
- **优势**：
  - 自托管或云托管
  - 数据库、存储、认证、函数
  - Flutter SDK 支持
  - 免费自托管
- **适用场景**：注重隐私，自托管偏好
- **集成方式**：`appwrite` 包
- **官网**：https://appwrite.io

#### 选项 4：自建服务器（Node.js + Express）
- **类型**：自定义后端
- **优势**：
  - 完全控制，灵活定制
  - 可选数据库：MongoDB / PostgreSQL
  - 部署到 Vercel / Heroku / 自有服务器
- **适用场景**：有后端开发经验，需高度定制
- **技术栈**：Node.js + Express + MongoDB
- **部署建议**：Vercel（免费额度充足）

### 13.3 为什么推荐 Supabase

- **快速上手**：几分钟内创建项目，自动生成 API
- **Flutter 友好**：官方 SDK，文档完善
- **实时同步**：支持好友请求、分享通知的实时推送
- **成本控制**：免费额度足够个人项目使用
- **扩展性**：可从免费升级到付费，无缝迁移

### 13.4 部署与维护建议

1. **开发阶段**：
   - 使用 Supabase / Firebase 的免费计划
   - 本地开发时用模拟器或测试环境

2. **生产部署**：
   - 选择云托管服务（Vercel / Railway）
   - 配置环境变量存储 API Key
   - 启用 HTTPS 和数据加密

3. **数据备份**： 
   - 定期备份用户数据
   - 遵守隐私政策（GDPR 等）

4. **监控与扩展**：
   - 使用服务商的监控工具
   - 根据用户增长调整资源

### 13.5 实施步骤

1. 注册 Supabase 账户，创建项目
2. 在 Flutter 项目中添加 `supabase_flutter` 依赖
3. 配置数据库表：users、friends、moods、shared_moods
4. 实现认证流程（注册/登录）
5. 逐步接入好友、分享 API
6. 测试跨设备同步功能

### 13.6 注意事项

- **数据隐私**：确保用户数据不被滥用
- **API 安全**：使用 JWT 认证，限制 API 访问
- **离线支持**：客户端需处理网络异常
- **版本兼容**：选择稳定的 SDK 版本

这套后端方案可与现有 Flutter 项目无缝集成，实现跨设备心情分享功能。
