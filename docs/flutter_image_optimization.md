# Flutter 图片上传与显示优化

## 一、头像编辑功能实现

### 需求
- 点击头像从相册选图更换
- 点击昵称弹出编辑框修改
- 点击复制按钮复制好友码

### 架构分层

```
UI (ProfilePage) → Provider (AuthProvider) → Service (AuthService) → Supabase
```

### 关键代码路径

**AuthService** 负责与 Supabase 直接通信：
```dart
// 更新 profiles 表中的昵称/头像URL
static Future<void> updateProfile({String? nickname, String? avatarUrl})

// 上传图片到 storage bucket，返回公开URL
static Future<String> uploadAvatar(File file)
```

**AuthProvider** 负责状态管理，更新本地状态并通知 UI：
```dart
// 更新昵称：先调 API，成功后更新本地 _profile
Future<void> updateNickname(String nickname)

// 更新头像：先设本地路径(UI立即显示) → 上传 → 更新URL → 清除本地路径
Future<void> updateAvatar(File file)
```

**ProfilePage** UI 交互：
- `CircleAvatar` 的 `backgroundImage` 优先级：本地临时文件 > 缓存网络图 > 默认首字母
- 昵称旁加 `Icons.edit` 图标，点击弹出 `AlertDialog`
- 好友码旁加 `Icons.copy` 图标，点击调用 `Clipboard.setData()`

---

## 二、图片速度优化的三个维度

### 问题
图片上传和加载偏慢，用户体验差。

### 优化 1：上传前压缩

**原理**：手机摄像头拍的照片通常是 4000×3000 像素、JPEG quality 95+，文件大小 3-8MB。直接上传浪费带宽和时间。

**做法**：在 `ImagePicker.pickImage/pickMultiImage` 时直接指定压缩参数，让系统在选图阶段就完成压缩：

| 场景 | maxWidth/maxHeight | imageQuality | 文件大小 |
|------|-------------------|-------------|---------|
| 头像 | 256×256 | 75 | ~15-30KB |
| 心情图片 | 1920×1920 | 80 | ~200-500KB |

```dart
// 头像 - 小尺寸、低质量
picker.pickImage(maxWidth: 256, maxHeight: 256, imageQuality: 75)

// 心情图片 - 保留全屏查看所需清晰度
picker.pickMultiImage(maxWidth: 1920, maxHeight: 1920, imageQuality: 80)
```

### 优化 2：选图后立即显示本地预览

**原理**：用户选完图后，传统做法是弹 loading 遮罩等上传完成。改为立即用本地文件渲染，消除等待感。

**做法**：在 Provider 中增加 `_localAvatarPath` 字段：
```dart
Future<void> updateAvatar(File file) async {
  _localAvatarPath = file.path;  // 1. 立即设本地路径
  notifyListeners();              // 2. UI 马上用 FileImage 渲染
  final url = await upload...     // 3. 后台上传
  _profile = ...avatarUrl: url;  // 4. 更新远程 URL
  _localAvatarPath = null;        // 5. 清除本地路径，UI 自动切到网络图
  notifyListeners();
}
```

UI 侧判断优先级：
```dart
backgroundImage: localAvatarPath != null
    ? FileImage(File(localAvatarPath!))    // 临时本地文件
    : avatarUrl != null
        ? CachedNetworkImageProvider(url)   // 缓存的网络图
        : null                              // 默认文字头像
```

### 优化 3：网络图片本地缓存

**原理**：`Image.network` 每次显示都重新请求，不做磁盘缓存。`CachedNetworkImage` 首次加载后存入本地磁盘，后续访问瞬间完成。

**依赖**：`cached_network_image` 包（底层使用 `flutter_cache_manager`）

```dart
// 之前
Image.network(url)

// 之后
CachedNetworkImage(
  imageUrl: url,
  placeholder: (_, __) => CircularProgressIndicator(),
  errorWidget: (_, __, ___) => Icon(Icons.broken_image),
)
```

对于 `CircleAvatar`，使用 `CachedNetworkImageProvider`（纯 ImageProvider，不需要 widget）：
```dart
CircleAvatar(
  backgroundImage: CachedNetworkImageProvider(url),
)
```

### 优化 4：并行上传

**原理**：多张图片逐张上传时，总耗时 = 单张耗时 × 数量。改为并行上传，总耗时 ≈ 单张耗时。

```dart
// 之前：顺序上传
for (final fileName in fileNames) {
  urls.add(await uploadImage(fileName));
}

// 之后：并行上传
final futures = fileNames.map(uploadImage);
return Future.wait(futures);
```

---

## 三、涉及文件总览

| 文件 | 改动 |
|------|------|
| `lib/services/auth_service.dart` | 新增 `updateProfile()`、`uploadAvatar()` |
| `lib/providers/auth_provider.dart` | 新增 `updateNickname()`、`updateAvatar()`、`localAvatarPath` |
| `lib/pages/profile_page.dart` | 头像/昵称/好友码的交互 UI，`CachedNetworkImageProvider`，本地预览 |
| `lib/services/image_upload_service.dart` | `Future.wait` 并行上传 |
| `lib/widgets/log_editor_dialog.dart` | `pickMultiImage` 加压缩参数 |
| `lib/pages/mood_details_page.dart` | `pickMultiImage` 加压缩参数 |
| `lib/pages/full_screen_image_view.dart` | `Image.network` → `CachedNetworkImage` |
| `lib/pages/shared_mood_detail_page.dart` | `Image.network` → `CachedNetworkImage` |
| `pubspec.yaml` | 新增 `cached_network_image` 依赖 |

---

## 四、整体架构要点

1. **分层职责**：Service 层只做网络/存储 I/O，Provider 层管理状态和通知 UI，Page 层只做渲染和交互
2. **乐观更新**：先更新本地状态让 UI 立即响应，后台同步到远端，失败时回滚
3. **压缩前置**：在数据进入系统的最早阶段（选图时）就做压缩，而非上传前临时处理
4. **缓存策略**：优先显示本地临时文件 > 磁盘缓存 > 网络请求
