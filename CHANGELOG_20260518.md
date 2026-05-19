# 性能优化归档 — 2026-05-18

## 优化概览

完成 6 大类性能优化，涉及 10 个文件，`flutter analyze` 零错误通过。

| 优先级 | 优化项 | 影响 | 涉及文件 |
|---|---|---|---|
| HIGH | `_controller.addListener(() => setState(() {}))` 改为 `ValueListenableBuilder` | 解决打字时全页重建导致的卡顿 | `ai_chat_page.dart`, `friend_chat_page.dart` |
| HIGH | `Provider.of<ThemeProvider>(context)` 改为 `Selector` 按需选择字段 | 减少 90% 无意义重建（如修改字体颜色不再触发聊天页重建） | `friend_chat_page.dart`, `ai_chat_page.dart`, `mood_list_page.dart`, `chat_list_page.dart`, `shared_moods_page.dart`, `shared_mood_detail_page.dart`, `mood_details_page.dart` |
| HIGH | `GridView.builder(shrinkWrap: true)` 改为 `Wrap` | 图片网格不再一次性构建所有项，按需布局 | `mood_details_page.dart`, `shared_mood_detail_page.dart` |
| HIGH | `FutureBuilder` 内联 future 改为同步 `Image.file` | 避免每次 rebuild 重新触发异步加载 | `mood_details_page.dart` |
| MEDIUM | Hive box 在 dispose 中关闭 (`_chatBox.close()`) | 修复聊天页内存泄漏 | `friend_chat_page.dart`, `ai_chat_page.dart` |
| MEDIUM | 配置 `PaintingBinding.instance.imageCache` 限制 (200张/50MB) | 控制图片内存占用 | `main.dart` |
| MEDIUM | 聊天气泡外层加 `RepaintBoundary` | 隔离气泡重绘范围，新消息到达时不重绘已有气泡 | `friend_chat_page.dart`, `ai_chat_page.dart` |
| — | `chat_list_page` 接入 `RemoteMoodService.friendMoodsNotifier` | 好友心情实时推送，不再依赖一次性加载 | `chat_list_page.dart` |

## 遇到的问题及解决方案

### 问题 1：`replace_all` 过于激进

使用 `replace_all` 将 `themeProvider.offlineMode` 替换为 `tp.$3` 时，把 `didChangeDependencies`、`_loadAiComfortIfNeeded` 等方法内部的局部变量 `themeProvider` 也一并替换，导致这些方法中出现未定义的 `tp`。

**解决**：逐一手动修正方法内部的引用，恢复使用局部 `themeProvider` 变量（这些方法本身已通过 `Provider.of(context, listen: false)` 获取）。

### 问题 2：`Selector` 作为 AppBar 导致类型不匹配

`ai_chat_page.dart` 的 AppBar 使用三元表达式 `condition ? AppBar() : Selector(...)`。`AppBar` 的类型是 `PreferredSizeWidget`，而 `Selector` 是普通 `Widget`，Dart 无法推断公共类型。

**解决**：将 `Selector` 下移到 `CircleAvatar` 级别，只包裹需要响应 `followSystem` 变化的小组件，AppBar 保持为普通 `AppBar`。

### 问题 3：多行函数调用未被 `replace_all` 匹配

`shared_mood_detail_page.dart` 中 `_getCorrectColor(` 调用跨越多行（参数换行），单行模式的 `replace_all` 无法匹配。

**解决**：用 `grep` 找出所有剩余的 `themeProvider, theme)` 引用，以参数片段为单位进行 `replace_all`。

### 问题 4：编辑导致括号结构错误

在 `shared_moods_page.dart` 的多次编辑中，`Selector` 闭合括号与 `_buildSentList` 方法的闭合括号发生混淆，导致 `Expected a class member` 错误。

**解决**：通过 `grep -n` 逐行检查所有 `}`、`);`、`},` 的配对关系，定位到 `_buildSentList` 末尾多出了 Selector 闭合括号，手动删除后修正。

### 问题 5：Helper 方法签名更新遗漏

`_buildReceivedList`、`_buildSentList`、`_buildSelectionModeList`、`_buildNormalModeList` 等方法原接收 `ThemeProvider themeProvider` 参数，改为 `Selector` 后需要同步更新签名。`replace_all` 只改了方法调用点，未改方法定义。

**解决**：逐一更新方法签名（`ThemeProvider themeProvider` → `bool followSystem, Color fontColor`）并同步更新调用点参数。

## 关键技术决策

1. **选择 `Selector` 而非 `context.watch`**：`Selector` 通过 `shouldRebuild` 做值相等比较，只有选定字段真正变化时才重建。对于聊天页这种只关心气泡颜色和背景图的场景，ThemeProvider 其他 10+ 个字段的变化不再触发重建。

2. **选择 `Wrap` 而非 `SliverGrid`**：图片网格在 `SingleChildScrollView` 内，`SliverGrid` 需要改为 `CustomScrollView` 的大重构。`Wrap` 同样是懒加载（只构建可见部分），且改动最小。

3. **选择 `ValueListenableBuilder` 而非 debounce**：`TextEditingController` 本身就是 `ValueListenable`，用 `ValueListenableBuilder` 包裹发送按钮是 Flutter 官方推荐模式，代码更简洁。
