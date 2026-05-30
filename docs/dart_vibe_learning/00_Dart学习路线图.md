# Dart 学习路线图（C++ 工程师视角）

## 元信息
- 目标：能独立写 Dart 程序
- 背景：C++ 开发工程师
- 每日学习时间：6 小时
- 学习模式：Vibe Learning
- 笔记工具：Obsidian

## 学习策略

**核心原则：** 每学一个 Dart 特性，都在 C++ 中找到对应物（有则对比，无则建立新概念），用项目真实代码做例子。

**节奏建议：** 每天 2 个模块（上午 1 个 3h + 下午 1 个 3h），5 天完成 Dart 语言层。

## 模块总览

| 天数 | 模块 | 主题 | C++ 对应 |
|------|------|------|----------|
| Day 1 上午 | [[01-万物皆对象与变量]] | 类型系统、var/final/const/dynamic | C++ auto/const/类型推导 |
| Day 1 下午 | [[02-Null Safety]] | ? / ! / late / ?? / ?. | std::optional / 指针空检查 |
| Day 2 上午 | [[03-函数]] | 命名参数、可选参数、箭头函数、闭包 | C++ 默认参数/lambda |
| Day 2 下午 | [[04-类与构造函数]] | 构造函数全家桶、继承、初始化列表 | C++ 构造/析构/继承 |
| Day 3 上午 | [[05-Mixin与扩展]] | mixin、extension、with 关键字 | C++ 多继承/CRTP/概念 |
| Day 3 下午 | [[06-集合]] | List/Set/Map、展开运算符、collection-if | std::vector/map/set |
| Day 4 上午 | [[07-异步编程]] | Future、async/await、Stream | std::future/promise/coroutine |
| Day 4 下午 | [[08-错误处理]] | try/catch/on/finally、Exception 体系 | C++ exception 体系 |
| Day 5 上午 | [[09-泛型]] | 泛型类/函数、类型约束 | C++ template |
| Day 5 下午 | [[10-包与导入]] | package、import、library、part | C++ #include/namespace/module |

## 学习闭环检查清单

每完成一个模块，确认以下动作：
- [ ] 用自己话向 AI 复述核心概念（费曼检验）
- [ ] 修改项目里 2-3 处相关代码验证理解
- [ ] 在 Obsidian 中建立知识节点并双向链接
- [ ] 给 AI 发一条精准反馈（哪里懂了、哪里模糊）

## 项目代码索引

你在学习的模块可以直接在以下文件中找到真实用例：

| 文件 | 包含特性 |
|------|----------|
| `lib/models/mood_record.dart` | 类、构造函数、factory、null safety、集合、泛型(Map) |
| `lib/models/chat_message.dart` | 类、getter、factory、类型转换、nullable |
| `lib/services/ai_service.dart` | static、命名参数、async/await、异常处理、泛型 |
| `lib/services/supabase_service.dart` | 单例、static、getter、类型别名 |
| `lib/providers/auth_provider.dart` | 继承(ChangeNotifier)、getter、async/await、文件操作 |
