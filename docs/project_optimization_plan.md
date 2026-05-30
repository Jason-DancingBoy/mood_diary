# 项目优化计划：从个人练手 → 有竞争力的面试项目

> 目标：在不改变项目核心功能的前提下，补齐工程化短板，使简历项目在面试中经得起深挖。
> 预计总工时：4-6 天（每天 4-6 有效小时）

---

## Phase 1：错误监控 & 可观测性（0.5 天）

### 1.1 Sentry 接入

- [ ] `flutter pub add sentry_flutter`
- [ ] `main.dart` 中初始化 Sentry，配置 DSN、环境（debug/release）、采样率
- [ ] 全局 FlutterError.onError 捕获 + PlatformDispatcher 捕获
- [ ] runZonedGuarded 兜底未捕获异常
- [ ] 手动上报关键业务异常（API 超时、数据库写入失败、AI 接口异常）

### 1.2 关键链路埋点

- [ ] 封装一个轻量 Trace 类（参考 OAM 信令回溯思想）
- [ ] 埋点节点：
  - App 冷启动 → 首帧渲染耗时
  - 登录 → Token 刷新 → 跳转首页
  - 创建心情 → 本地存储 → 远端同步
  - AI 对话 → API 请求 → 流式/非流式响应 → 解析展示
- [ ] 每个 Trace 节点记录时间戳、是否成功、错误信息（如有）
- [ ] Debug 模式下输出 Trace 链路日志，Release 模式仅上报异常节点

### 1.3 交付物

- [ ] Sentry 后台能看到 crash/error 事件
- [ ] 一份 `docs/oam_design.md`，描述从 OAM 视角设计的 App 质量保障方案（PM 指标、FM 告警、信令回溯）

---

## Phase 2：性能优化（1 天）

### 2.1 建立基线

- [ ] 用 Flutter DevTools Performance 跑一遍所有核心页面，记录当前帧率
- [ ] 用 Dart DevTools Memory 记录内存曲线
- [ ] 用 `time` 记录冷启动首帧时间
- [ ] 建立性能基线文档

### 2.2 排查 & 修复（按优先级）

- [ ] **减少不必要的 rebuild**
  - 检查 Provider Consumer 粒度，将 Consumer 下沉到最小 rebuild 单元
  - 对列表 Item 使用 Selector 替代 Consumer
  - 给不随动画变化的子树加 RepaintBoundary
- [ ] **首屏启动优化**
  - `main()` 中推迟非关键初始化（Hive、图片目录预创建）
  - Supabase 初始化是否可以懒加载
  - 首屏骨架屏
- [ ] **列表滚动优化**
  - 确认所有列表使用 ListView.builder
  - 复杂 Item Widget 构造函数加 const
  - 图片列表使用预裁剪/缩略图
- [ ] **图片内存管理**
  - 确认 ImageCache maximumSize/maximumSizeBytes 配置合理
  - 心情列表缩略图 vs 详情大图使用不同缓存策略

### 2.3 写复盘文档

- [ ] 每个优化项记录：优化前指标 → 优化手段 → 优化后指标
- [ ] 至少一个 case 能拿出数字（如"列表滚动帧率从 38fps 提升到 58fps"）

---

## Phase 3：测试覆盖（1 天）

### 3.1 Service 层单元测试

- [ ] `AIService` 测试（Mock HTTP，验证 prompt 拼接、异常处理）
- [ ] `RemoteMoodService` 测试（Mock Supabase Client）
- [ ] `FriendChatService` 测试
- [ ] `VersionService` 测试
- [ ] `MessageScheduler` 测试

### 3.2 Widget 测试

- [ ] `LoginPage`：输入框交互、按钮状态
- [ ] `MoodListPage`：列表渲染、空状态
- [ ] `AIChatPage`：消息发送、loading 状态

### 3.3 交付物

- [ ] `flutter test --coverage` 通过，Service 层覆盖率 > 60%

---

## Phase 4：自定义后端（1.5 天）

> 核心目的：证明你有全栈能力，不只是 BaaS 消费者

### 4.1 技术选型：Dart Frog

```
# 新建 backend 目录
dart_frog create backend
```

### 4.2 实现 2-3 个接口

- [ ] **GET /api/mood-stats?user_id=xxx&range=weekly**
  - 聚合心情数据，返回情绪趋势（Avg、Min、Max、分布）
  - 逻辑放在后端而不在客户端算，展示你的后端思维
- [ ] **POST /api/ai-comfort**
  - 代理 DeepSeek API，隐藏 API Key
  - 服务端做 Token 计数、请求限流、异常 fallback
  - 支持流式响应（SSE）
- [ ] **GET /api/health**
  - 健康检查接口，返回数据库连接状态、AI API 可达性

### 4.3 部署

- [ ] 用 Docker 打包，推到个人服务器 / 免费 PaaS（Railway/Render）
- [ ] Flutter 端将对应请求切换到自建后端

### 4.4 交付物

- [ ] `backend/` 目录下有完整代码
- [ ] `backend/README.md` 有 API 文档 + 部署说明
- [ ] Postman / Bruno collection 方便面试演示

---

## Phase 5：AI 流式输出（0.5 天）

- [ ] DeepSeek API 改为 `stream: true`
- [ ] 解析 SSE 事件流（`data: [DONE]` 终止）
- [ ] 打字机效果显示（逐字/逐 chunk 追加）
- [ ] 添加停止生成按钮

---

## Phase 6：CI/CD（0.5 天）

### 6.1 GitHub Actions

- [ ] 创建 `.github/workflows/ci.yml`
- [ ] PR 触发：`flutter analyze` + `flutter test` + `flutter build apk --debug`
- [ ] main 分支合并触发：`flutter build apk --release` + `flutter build ipa`

### 6.2 代码质量

- [ ] `analysis_options.yaml` 加强 lint 规则
- [ ] 统一错误处理模式：Service 层返回 `Result<T>` 类型（Success/Failure），Provider 层处理状态转换
- [ ] 字符串常量化（中文提示词/UI 文案抽到一个文件）

---

## Phase 7：简历话术（0.5 天）

> 原则：只说"I did X"，不如说"I did X, which improved Y by Z%"

### 项目描述模板

```
独立开发并持续迭代（v1.0.1 → v1.1.5，16 个版本）的全平台心情日记 App，
覆盖 Android / iOS / Linux / macOS / Windows。

核心工作：
- 设计 PostgreSQL RLS 多租户数据隔离方案，基于 Supabase Realtime 
  实现好友心情实时同步，保证不同用户间数据完全隔离
- 基于 Prompt Engineering 设计三阶段心理咨询对话框架（共情→深挖→赋能），
  集成 DeepSeek API 并实现 SSE 流式响应，优化首 Token 延迟至 1.2s
- 参考通信 OAM 体系建立 App 质量保障方案：Sentry 全量 Error/Crash 
  监控 + 关键业务链路埋点（Trace 节点覆盖冷启动→登录→核心业务闭环）
- 通过 Provider Selector 细粒度控制 Widget rebuild + ImageCache 
  策略调优，列表滚动帧率从 38fps 提升至 58fps
- 搭建 Dart Frog 自定义后端，实现心情数据聚合统计 + AI 请求代理，
  降低客户端 40% 计算负担

技术栈：Flutter / Dart / Provider / Supabase / PostgreSQL / Dart Frog / Sentry / DeepSeek API / SSE
```

---

## 执行顺序建议

```
Day 1: Phase 1（错误监控 + OAM 文档） + Phase 6（CI/CD，跑着不费脑）
Day 2: Phase 2（性能优化，最耗时，精力最好时做）
Day 3: Phase 3（测试覆盖） + Phase 5（AI 流式，相对轻松）
Day 4: Phase 4（自定义后端，技术挑战最大）
Day 5: Phase 7（简历话术，收尾打磨） + 整体 Review
```

---

## 完成标准

- [ ] `flutter analyze` 零 warning
- [ ] `flutter test --coverage` 通过，service 层覆盖率 ≥ 60%
- [ ] `.github/workflows/ci.yml` 存在且能跑通
- [ ] Sentry 后台有至少一条测试 crash
- [ ] 性能优化有前后对比数字（≥ 1 个 case）
- [ ] `backend/` 目录存在，≥ 2 个可调用的 API
- [ ] AI 对话支持流式输出 + 打字机效果
- [ ] 简历话术已更新到实际简历中
- [ ] `docs/oam_design.md` 和 `docs/performance_review.md` 完成
