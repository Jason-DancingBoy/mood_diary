# 版本更新操作手册

## 架构概览

```
App 启动
  → VersionService.currentVersion (本地 PackageInfo)
  → VersionService.getLatestVersion() (Supabase app_config 表)
  → 语义化版本比较
  → 有新版本 → UpdateDialog
      ├─ 稍后再说 → 关闭
      └─ 立即更新 → dio 下载 APK (进度条)
                   → OpenFilex 触发系统安装器
```

> `force_update = true` 时弹窗不可关闭，用户只能选择更新。

---

## 一、初始化（仅首次）

### 1. 创建 app_config 表

Supabase SQL Editor：

```sql
CREATE TABLE IF NOT EXISTS app_config (
  id   SERIAL PRIMARY KEY,
  key  TEXT   NOT NULL UNIQUE,
  value TEXT  NOT NULL DEFAULT ''
);
```

### 2. 上传 APK 到 Storage

1. Supabase Dashboard → Storage → `mood_images`
2. 新建文件夹 `releases`
3. 上传 `app-release.apk`
4. 复制 Public URL

### 3. 设置 Storage 下载权限

```sql
CREATE POLICY "允许公开下载APK" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'mood_images' AND name LIKE 'releases/%');
```

### 4. 插入初始配置

```sql
INSERT INTO app_config (key, value) VALUES
  ('latest_version',     '1.0.1'),
  ('update_url_android', '<APK Public URL>'),
  ('update_url_ios',     '<App Store URL>'),
  ('force_update',       'false');
```

---

## 二、日常发版

### 方式一：一键脚本（推荐）

```bash
# 普通更新
./release.sh 1.0.2

# 强制更新
./release.sh 1.0.2 --force
```

脚本自动完成：拉取代码 → 构建 APK → 上传 Storage → 更新数据库 → 打 Git tag。

> 首次使用前，编辑 `release.sh` 顶部填入 `SUPABASE_URL` 和 `SUPABASE_SERVICE_ROLE_KEY`（在 Supabase Dashboard → Settings → API 获取）。

### 方式二：手动操作

### Android

1. 构建 APK：`flutter build apk --release`
2. 上传 `build/app/outputs/flutter-apk/app-release.apk` 到 Storage `releases/` 目录（覆盖旧文件）
3. 更新数据库：

```sql
UPDATE app_config SET value = '1.0.2' WHERE key = 'latest_version';
-- 如需强制更新：
-- UPDATE app_config SET value = 'true' WHERE key = 'force_update';
```

### iOS

1. Xcode Archive → 上传到 App Store Connect
2. 更新数据库：

```sql
UPDATE app_config SET value = '1.0.2' WHERE key = 'latest_version';
```

> iOS 端点击更新会跳转 App Store 页面，不走 APK 下载流程。

---

## 三、app_config 字段说明

| key | 说明 | 示例 |
|-----|------|------|
| `latest_version` | 最新版本号（语义化版本） | `1.0.2` |
| `update_url_android` | Android APK 直链 | `https://xxx.supabase.co/.../app-release.apk` |
| `update_url_ios` | iOS App Store 链接 | `https://apps.apple.com/app/xxx` |
| `force_update` | 是否强制更新 | `true` / `false` |

---

## 四、常见操作 SQL

```sql
-- 查看当前配置
SELECT * FROM app_config;

-- 仅更新版本号（非强制）
UPDATE app_config SET value = '1.0.3' WHERE key = 'latest_version';

-- 开启强制更新
UPDATE app_config SET value = 'true' WHERE key = 'force_update';

-- 关闭强制更新
UPDATE app_config SET value = 'false' WHERE key = 'force_update';

-- 修改 Android 下载链接
UPDATE app_config SET value = '<新URL>' WHERE key = 'update_url_android';
```
