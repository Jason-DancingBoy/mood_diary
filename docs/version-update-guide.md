# 版本更新操作手册

## 初始化（仅首次）

在 Supabase SQL Editor 执行建表语句：

```sql
CREATE TABLE IF NOT EXISTS app_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "App config is viewable by everyone" ON app_config;
CREATE POLICY "App config is viewable by everyone"
    ON app_config FOR SELECT
    USING (true);

INSERT INTO app_config (key, value)
VALUES ('latest_version', '1.0.0'),
       ('update_url_android', ''),
       ('update_url_ios', ''),
       ('force_update', 'false'),
       ('update_note', '')
ON CONFLICT (key) DO NOTHING;
```

---

## 架构

```
┌──────────┐    检查版本     ┌──────────────┐
│  客户端   │ ◄────────────── │   Supabase   │
│  (App)   │                │  app_config  │
└────┬─────┘                └──────────────┘
     │  发现新版本，弹窗
     │  点击"立即更新"
     ▼
┌──────────┐    下载 APK     ┌──────────────┐
│  浏览器   │ ◄────────────── │   Supabase   │
│  下载APK  │                │   Storage    │
└────┬─────┘                └──────────────┘
     │  下载完成，点击安装
     ▼
  安装新版本
```

---

## 发布新版本

### 1. 改版本号

```yaml
# pubspec.yaml
version: 1.0.1+2
```

`1.0.1` = 版本名，`2` = 构建号。

### 2. 构建 APK

```bash
flutter build apk --release
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

### 3. 上传 APK 到 Supabase Storage

Supabase Dashboard → Storage → `mood_images` → 新建文件夹 `releases` → 上传 APK，建议命名 `app-release-1.0.1.apk`。

上传后点击文件，复制 **公开 URL**：
```
https://<项目ID>.supabase.co/storage/v1/object/public/mood_images/releases/app-release-1.0.1.apk
```

### 4. 更新 Supabase 配置

```sql
UPDATE app_config SET value = '1.0.1' WHERE key = 'latest_version';
UPDATE app_config SET value = 'https://<项目ID>.supabase.co/storage/v1/object/public/mood_images/releases/app-release-1.0.1.apk' WHERE key = 'update_url_android';
UPDATE app_config SET value = 'false' WHERE key = 'force_update';
UPDATE app_config SET value = '修复了一些已知问题，优化体验' WHERE key = 'update_note';
```

### 5. 验证

```sql
SELECT * FROM app_config;
```

| key | value |
|-----|-------|
| latest_version | 1.0.1 |
| update_url_android | https://.../releases/app-release-1.0.1.apk |
| update_url_ios | |
| force_update | false |
| update_note | 修复了一些已知问题，优化体验 |

### 6. 用户端效果

用户下次打开 App → 弹窗：

```
┌──────────────────────────┐
│  🔄 发现新版本             │
│                          │
│  新版本 1.0.1 已发布       │
│  修复了一些问题，优化体验    │
│                          │
│   [稍后再说]   [立即更新]   │
└──────────────────────────┘
```

---

## 字段说明

| 字段 | 说明 |
|------|------|
| `latest_version` | 最新版本号，`x.y.z` 格式 |
| `update_url_android` | APK 公开下载链接（Supabase Storage URL） |
| `update_url_ios` | iOS App Store 链接（暂留空） |
| `force_update` | `true` = 弹窗不可关闭；`false` = 可关闭 |
| `update_note` | 更新说明文本（可选） |

---

## 版本比较规则

逐段比较 `x.y.z`：

| 当前版本 | 最新版本 | 是否提示 |
|----------|----------|----------|
| 1.0.0 | 1.0.1 | ✅ |
| 1.0.9 | 1.1.0 | ✅ |
| 1.9.9 | 2.0.0 | ✅ |
| 1.0.0 | 1.0.0 | ❌ |

---

## 注意事项

- **先上传 APK 再更新配置**，否则用户看到提示但下载链接 404
- APK 命名带版本号（如 `app-release-1.0.1.apk`），方便管理历史版本
- Storage 桶 `mood_images` 是公开的，任何人可通过 URL 下载 APK
- 用户下载 APK 后需手动点击安装，首次安装需在系统设置中允许"安装未知应用"
- iOS 不支持侧载 APK，`update_url_ios` 留空，上架 App Store 后再填

---

## 回滚

如果新版本有问题，回退配置即可：

```sql
-- 回退到上一个版本
UPDATE app_config SET value = '1.0.0' WHERE key = 'latest_version';

-- 指向旧版 APK（如果旧文件还在 Storage 中）
UPDATE app_config SET value = 'https://<项目ID>.supabase.co/storage/v1/object/public/mood_images/releases/app-release-1.0.0.apk' WHERE key = 'update_url_android';
```
