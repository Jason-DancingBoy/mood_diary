# 心情日记 (Mood Diary) — Android 产品手册

> 版本 1.0.0 | 构建日期 2026-05-20

---

## 一、应用概览

| 项目 | 值 |
|---|---|
| 包名 / Application ID | `com.example.mood_diary` |
| 应用名 | 心情日记 |
| 版本 | `1.0.0+1` |
| Flutter SDK | `^3.12.0-98.0.dev` |
| Material 版本 | Material 3 |

---

## 二、构建与 Gradle 配置

### Gradle 属性 (`android/gradle.properties`)

| 配置项 | 值 |
|---|---|
| JVM 堆 | `-Xmx2G` |
| Metaspace | `-XX:MaxMetaspaceSize=512M` |
| Code Cache | `-XX:ReservedCodeCacheSize=256m` |
| Kotlin Daemon | `-Xmx1G -XX:MaxMetaspaceSize=384M` |
| AndroidX | 已启用 |
| Lint | 已禁用 |
| 并行构建 | `org.gradle.parallel=true` |
| 构建缓存 | `org.gradle.caching=true` |
| Java | 17 (`/usr/lib/jvm/java-17-openjdk-amd64`) |

### Android 构建 (`android/app/build.gradle.kts`)

| 配置项 | 值 |
|---|---|
| compileSdk | Flutter 引擎决定 |
| minSdk | Flutter 引擎决定 |
| targetSdk | Flutter 引擎决定 |
| Java/Kotlin | Java 17 |
| 签名 | debug 签名（未配置正式发布签名） |

### 构建性能预估

| 场景 | 耗时 |
|---|---|
| `flutter build apk --release` (arm64 单 ABI) | 2~5 分钟（增量）/ 5~10 分钟（全量） |
| `flutter build apk --release --split-per-abi` (3 ABI) | 5~10 分钟（增量）/ 10~18 分钟（全量） |
| 热重载 (`r`) | ~1 秒 |
| 热重启 (`Shift+R`) | ~3 秒 |

---

## 三、应用权限

| 权限 | 用途 | 声明方式 |
|---|---|---|
| `INTERNET` | 网络通信（Supabase、AI API、图片） | AndroidManifest.xml |
| `RECORD_AUDIO` | 好友聊天语音消息 | AndroidManifest.xml |
| `REQUEST_INSTALL_PACKAGES` | 应用内版本更新 APK 安装 | AndroidManifest.xml |
| 相机 / 相册 | 拍照、选择图片 | Flutter 插件运行时请求 |
| 存储读写 | 保存图片到本地 | Flutter 插件自动处理 |

---

## 四、性能配置

### 图片缓存

| 参数 | 值 |
|---|---|
| 内存缓存数量上限 | 200 张 |
| 内存缓存大小上限 | 50 MB |
| 上传压缩目标 | ≤400KB/张 |
| 压缩管线 | 第 1 轮: quality=75, 1280px → 第 2 轮: quality=55, 1024px |

### AI API 参数

| 场景 | temperature | max_tokens | 超时 | 重试 |
|---|---|---|---|---|
| 聊天对话 | 0.8 | 800 | 30s | 3 次 (1s→2s→4s) |
| 安慰生成 | 0.7 | 400 | 30s | 3 次 |
| 胡萝卜介入 | 0.9 | 100 | 30s | 3 次 |
| 邮件生成 | 0.7 | 500 | 30s | 3 次 |

### 录音参数

| 参数 | 值 |
|---|---|
| 编码 | AAC-LC |
| 码率 | 64 kbps |
| 采样率 | 22050 Hz |
| 最长时长 | 60 秒 |

---

## 五、功能清单

### 5.1 心情记录
- 10 种心情类型：幸福(10)、开心(8)、平静(7)、惊讶(6)、焦虑(4)、难过(3)、内疚(2)、生气(2)、恐惧(2)、厌恶(1)
- 每条支持最多 9 张图片（JPEG/PNG/GIF/WebP/BMP）
- 自定义表情（emoji + 颜色 + 标签）
- AI 安慰开关
- 隐私标记（设为隐私后内容模糊显示）
- 滑动删除、批量选择、全选
- 下拉刷新

### 5.2 日历与趋势
- 月历视图（心情颜色圆点）
- 心情曲线图（7 天 / 30 天 / 全部）
- 月度统计（饼图 / 柱状图）

### 5.3 AI 聊天
- **小暖**：心理咨询师角色，3 阶段咨询（共情→探索→赋能）
- **魔魔胡胡胡萝卜（阿信）**：五月天主唱角色扮演，含本地知识库
- 多轮对话历史管理
- AI 模型：DeepSeek Chat
- 支持自定义 API Key

### 5.4 邮件/消息系统
- 定时生成温暖邮件（6 种频率）
- 情感分析、主题检测、认知扭曲检测
- 46 条名言库 + 心理学洞见

### 5.5 好友系统
- 邮箱注册/登录（Supabase Auth）
- 个人资料（昵称、头像、好友码）
- 通过昵称或好友码添加好友
- 好友请求管理
- 好友列表（显示最近心情）

### 5.6 好友聊天
- 文字、图片、语音消息
- Realtime WebSocket 推送
- AI 介入（检测五月天关键词自动插话）
- 消息多选、编辑、删除

### 5.7 心情分享
- 向好友分享心情记录
- 接收/发送分类
- 批量管理
- 已读状态

### 5.8 主题与外观
- 浅色/深色模式（跟随系统或手动）
- 6 种字体颜色可选
- 聊天气泡自定义颜色
- 自定义聊天背景图

### 5.9 版本更新
- 启动时检查 Supabase `app_config` 表
- 应用内 APK 下载与安装
- 支持强制更新标志

---

## 六、数据库架构 (Supabase)

### 数据表

| 表名 | 用途 | 行级安全 |
|---|---|---|
| `profiles` | 用户资料 | 本人可写，所有人可读 |
| `friends` | 好友关系 | 参与者可见，发起方可写 |
| `remote_moods` | 同步心情记录 | 所有者 + 授权好友可见 |
| `shared_moods` | 跨用户分享 | 发送方/接收方可访问 |
| `friend_messages` | 聊天消息 | 发送方/接收方可读，发送方可写 |
| `app_config` | 应用配置键值对 | 所有人可读（无需认证） |

### Realtime 推送
- `remote_moods` — INSERT/UPDATE/DELETE（好友心情实时更新）
- `friend_messages` — INSERT（聊天消息推送）

### Storage 桶
- `mood_images`：公开可读，已认证用户可上传
- 用途：头像、心情图片、语音消息、APK 更新文件

---

## 七、本地存储

### Hive Box

| Box 名称 | 内容 |
|---|---|
| `mood_logs_box` | 心情记录 |
| `mail_messages_box` | 系统邮件 |
| `ai_chat_history_*` | 每个 AI 助手的对话历史 |
| `friend_chat` | 缓存的好友聊天消息 |
| `message_cache_box` | 消息调度器状态 |

### SharedPreferences

| Key | 内容 |
|---|---|
| `nightMode` / `followSystem` | 主题设置 |
| `fontColor` | 字体颜色 |
| `userBubbleColor` / `otherBubbleColor` | 聊天气泡颜色 |
| `chatBgPath` | 聊天背景图片路径 |
| `offlineMode` | 离线模式 |
| `apiKey` | 自定义 AI API Key |
| `messageFrequency` / `messageLogRange` | 邮件频率/范围 |
| `luoBoInterventionEnabled` | AI 介入开关 |
| `saved_email` / `saved_password` / `remember_me` | 登录凭据保存 |

---

## 八、环境变量 (.env)

```
SUPABASE_URL=https://tjedmzbioaeualutpbxv.supabase.co
SUPABASE_ANON_KEY=sb_publishable_Oe2V7fILYeRluJapoEbYsQ_Uk0Xobuh
```

通过 `flutter_dotenv` 加载。

---

## 九、发布流程

```bash
# 默认：arm64-v8a 单 ABI
./release.sh 1.0.1

# 全架构
./release.sh 1.0.1 --all-abis

# 强制更新
./release.sh 1.0.1 --force

# 仅更新版本号（已有 APK）
./release.sh 1.0.1 --skip-build
```

脚本流程：`git pull` → `flutter build apk` → 上传 Supabase Storage → 更新 `app_config` 版本号 → 推送 Git tag

---

## 十、依赖库一览

| 类别 | 库 | 版本 |
|---|---|---|
| 状态管理 | provider | ^6.1.2 |
| 本地数据库 | hive_flutter | ^1.1.0 |
| 键值存储 | shared_preferences | ^2.2.3 |
| 后端 | supabase_flutter | ^2.5.0 |
| AI API | http | ^1.2.1 |
| 网络下载 | dio | ^5.4.0 |
| 图片选择 | image_picker | ^1.1.2 |
| 图片缓存 | cached_network_image | ^3.4.1 |
| 图片压缩 | flutter_image_compress | ^2.3.0 |
| 录音 | record | ^6.0.0 |
| 音频播放 | audioplayers | ^6.1.0 |
| 分享 | share_plus | ^10.0.0 |
| URL 启动 | url_launcher | ^6.3.1 |
| 文件打开 | open_filex | ^4.5.0 |
| 图表 | fl_chart | ^0.69.0 |
| 国际化 | intl | ^0.20.2 |
| 环境变量 | flutter_dotenv | ^6.0.0 |
| 版本信息 | package_info_plus | ^8.0.0 |
| 路径管理 | path_provider | ^2.1.3 |

---

## 十一、远程开发环境搭建

通过手机 SSH 远程连接开发机，在 Termux 中运行 `claude` 实现远程 vibe coding。

### 网络架构

```
手机 (Termux + Tailscale) → Tailscale 内网 → Ubuntu 开发机 (Tailscale + SSH + Claude Code)
```

前提：手机和电脑均安装 Tailscale，用**同一个 Google 账号**登录。

### 11.1 Ubuntu 开发机

```bash
# 安装 Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# 登录（用浏览器打开输出的链接，Google 账号登录）
sudo tailscale up

# 查看 Tailscale IP（100.x.x.x）
tailscale ip -4

# 确认 SSH 运行
sudo systemctl enable ssh --now
```

### 11.2 Windows 宿主机

https://tailscale.com/download 下载安装，**同一 Google 账号**登录。

### 11.3 手机端

**装 Tailscale**（Google Play / APK），**同一 Google 账号**登录。

**装 Termux**（Google Play / F-Droid）：

```bash
# 安装 SSH 客户端
pkg update && pkg install openssh -y

# 推荐装 tmux，断网后任务不丢
pkg install tmux -y

# SSH 连接（用 Ubuntu 的 Tailscale IP）
ssh jason@100.x.x.x

# 进入项目
cd ~/mood_diary

# 开始 vibe coding
claude
```

### 11.4 故障排查

| 症状 | 解决 |
|---|---|
| Tailscale App 看不见设备 | 三端确认是同一 Google 账号；Ubuntu 端 `sudo tailscale logout && sudo tailscale up` 重新认证 |
| 手机 DNS 解析出错 | WiFi 设置中关掉代理（Clash），登录完再恢复 |
| SSH 连不上 | `tailscale ip -4` 确认 IP；`systemctl is-active ssh` 确认 SSH 运行 |
| 连接断开 | `tmux attach` 恢复之前的会话 |
