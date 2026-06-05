# "我的"页面重组设计

## 问题

当前 ProfilePage 约 20 个选项堆在扁平 ListView 中，无分组、无视觉层次。社交、AI 配置、显示设置、消息设置全部混在一起，用户难以快速定位目标功能。

## 目标

将"我的"页面从「杂货铺」改造为「个人信息 + 快捷操作 + 设置入口」的清晰结构。

## 设计方案

### 1. 我的 主页 (`ProfilePage`)

仅保留 5 项，其余全部移走：

| 项目 | 类型 | 行为 |
|------|------|------|
| 个人信息卡片 | 头像 + 昵称 + 好友码 | 点击进入 PersonalInfoPage |
| 向好友展示心情 | SwitchListTile | 同现有逻辑 |
| 聊天背景 | ListTile（显示当前状态） | 点击选择本地图片 |
| 关于 | ListTile（显示版本号） | 点击检查更新 |
| 更多设置 | ListTile | push → SettingsPage |

### 2. 设置子页 (`SettingsPage`，新建)

分组展示，每组带 section header：

**显示**
- 夜间模式 (SwitchListTile)
- 跟随系统 (SwitchListTile)
- 字体颜色 (ListTile → 颜色选择 dialog)

**社交**
- 好友 (ListTile → FriendListPage)
- 好友请求 (ListTile，带 badge → FriendRequestPage)
- 好友分享 (ListTile，带 badge → SharedMoodsPage)

**AI & 服务**
- 断网模式 (SwitchListTile)
- API Key (ListTile → 输入 dialog)
- Token 用量 (ListTile → 详情 dialog)
- 导入配置 (ListTile → JSON 导入 dialog)
- 萝卜语音 (ListTile → VoiceSamplePage)

**数据**
- 从云端恢复数据 (ListTile)

底部：退出登录（红色文字，居中）

### 3. 收件箱页 (`MessagePage`)

顶部 AppBar 增加设置图标按钮，点击弹出底部 sheet，包含：
- 消息发送频率
- 消息读取范围

### 4. 对话页 (`ChatListPage`)

AppBar 增加切换按钮（图标或 toggle），控制"防 AI 小作文模式"开关，切换即时生效。

## 不变项

- 所有现有功能的业务逻辑不变，仅调整 UI 位置
- PersonalInfoPage 保持不动
- 各子页（FriendListPage, VoiceSamplePage 等）保持不动
- 未登录状态的登录引导卡片移到设置子页顶部（社交分组需要登录才能使用）

## 未登录态处理

- 主页：个人信息区显示登录引导卡片；"向好友展示心情"隐藏；聊天背景/关于/更多设置仍可见可操作
- 设置子页：登录引导卡片显示在页面顶部；社交分组项变灰或隐藏；退出登录隐藏
