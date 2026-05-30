# 02-Null Safety

## C++ → Dart 心智切换

> **一句话：** C++ 里任何指针都可以是 `nullptr`，你在运行时发现它；Dart 的 Null Safety 在**编译期**就强制你处理 null 的可能性。

| C++ | Dart |
|-----|------|
| `int* p = nullptr;` 指针可为空 | `int? x = null;` 可空类型 |
| `*p` 访问（运行时崩） | `x!` 强制解包（运行时崩，但你明确知道风险） |
| `if (p) { *p; }` 判空 | `if (x != null) { x.isEven; }` 类型提升 |
| `p ? *p : default_val` | `x ?? defaultVal` 空值合并 |
| `p->foo()` | `x?.foo()` 安全调用 |
| `std::optional<int>` | `int?`（内置，不需要模板） |
| 无强制初始化检查 | `late` 延迟初始化（承诺"用时一定有值"） |

---

## 一、核心语法：? / ! / ?? / ?. / late

### ? — 可空类型声明

```dart
int x = 1;       // 不可为 null
int? y = null;   // 可为 null（C++: std::optional<int> y = std::nullopt;）

String s = 'hi';       // 不可空
String? s2 = null;     // 可空

// 方法调用：不可空类型可以随意调方法
x.isEven;       // ✅
// y.isEven;    // ❌ 编译报错：y 可能为 null，不能直接调
```

### ! — 断言非空（"我确定不是 null"）

类似 C++ 里你写 `assert(p != nullptr); *p;`：

```dart
int? maybeNull = 42;
int definitely = maybeNull!;  // "我保证不是 null，编译通过，但如果我错了就运行时崩"
// C++ 对应: int definitely = *maybeNull;  // 如果 maybeNull 是 nullptr，UB/崩溃
```

项目例子 `lib/services/ai_service.dart:131`：

```dart
return AIConfig.apiKey!;  // 断言 apiKey 不为 null
```

**原则：少用 `!`。** 每用一个 `!` 就相当于你对编译器撒谎的机会。优先用 `??` 或 `if` 判空。

### ?? — 空值合并（如果为 null 就用备选值）

```dart
String? name;
print(name ?? '匿名用户');  // 如果 name 是 null，就用 '匿名用户'

// C++ 等价: name.value_or("匿名用户")  或  name ? name : "匿名用户"
```

项目里到处是——`lib/models/mood_record.dart:44`：

```dart
note: (map['note'] as String?) ?? '',    // 如果 map 里没有 note，就用空字符串
comment: (map['comment'] as String?) ?? '',
```

### ??= — 空值赋值（如果为 null 才赋值）

```dart
int? x;
x ??= 5;   // x 是 null，所以赋值为 5
x ??= 10;  // x 已经是 5 了，不管
print(x);  // 5
```

### ?. — 安全调用（不为 null 才访问）

```dart
String? name;
print(name?.length);  // name 是 null → 整个表达式返回 null，不崩
// C++ 对应：没有直接语法糖，手写 if (opt) { opt->length(); }

// 可以链式调用
user?.address?.city?.name;  // 任何一环为 null，整个链返回 null
```

### late — 延迟初始化（"我现在没法赋值，但我承诺用之前一定赋值"）

```dart
class Database {
  late final String connectionString;  // final 但不是构造时赋值

  void init(String config) {
    connectionString = config;  // 运行时赋值一次
  }

  void query() {
    print(connectionString);  // 如果 init 还没调，崩
  }
}
```

`late` 适合的场景：
- 注入依赖（构造后配置）
- Flutter 的 `late final` 在 `initState` 中初始化
- 你确定"一定会在用之前赋值"的情况

---

## 二、类型提升（Type Promotion）

Dart 编译器很聪明：如果你在 `if` 里判了 null，分支内部会自动把类型从 `int?` 提升为 `int`：

```dart
int? maybeNull = 42;

// ❌ 直接报错
// maybeNull.isEven;

// ✅ 判空后自动提升
if (maybeNull != null) {
  print(maybeNull.isEven);  // maybeNull 在这里自动变成 int（不可空）
}

// 也可以用 ?? 提前返回
int process(int? value) {
  if (value == null) return 0;
  return value * 2;  // 这里 value 提升为 int
}
```

注意：如果变量在判空之后可能被修改（比如是类成员字段），类型提升就不生效：

```dart
class Foo {
  int? _value;

  void bar() {
    if (_value != null) {
      // _value.isEven;  // ❌ 编译报错！因为 getter 每次调用可能返回不同值
      final v = _value;
      if (v != null) {
        v.isEven;  // ✅ 局部变量不会被外部修改，编译器放心提升
      }
    }
  }
}
```

---

## 三、在你项目里的真实用例

`lib/models/mood_record.dart:4-18`——Null Safety 的典型应用：

```dart
class MoodRecord {
  final String id;              // 不可空：必须有值
  final String ownerId;         // 不可空
  final String? localId;        // 可空：本地记录有 localId，云端记录没有
  final String moodType;        // 不可空
  final String note;            // 不可空
  final String comment;         // 不可空（看构造函数：默认 ''）
  final List<String> imageUrls; // 不可空（默认 []）
  final String? audioUrl;       // 可空：不是每条记录都有语音
  final int? audioDuration;     // 可空：没有语音就没有时长
  final String? customEmoji;    // 可空：用户可能没自定义
  final String? customEmojiLabel;
  final int? customColorValue;
  final String? aiComfort;      // 可空：可能没开 AI 安慰
  final bool aiEnabled;         // 不可空（默认 true）
  final DateTime createdAt;     // 不可空
```

感受一下：哪些字段"一定存在"就用不可空类型，哪些字段"可能存在也可能没有"就用 `?`。这让字段的语义一目了然。

再看构造函数里 `Map` 取值的安全处理（`lib/models/mood_record.dart:42-56`）：

```dart
audioUrl: map['audio_url'] as String?,       // 直接转，可能是 null
audioDuration: map['audio_duration'] as int?, // 同上
aiEnabled: (map['ai_enabled'] as bool?) ?? true,  // 如果 null 则默认 true
```

---

## 四、C++ 程序员最容易踩的坑

### 坑 1：`late` 是"延迟炸弹"

```dart
late String name;

void main() {
  print(name);  // ❌ 运行时崩：LateInitializationError
}
```

`late` 不给默认值，编译器不检查你是否真的赋值了——只有运行到那行才知道。C++ 里没有类似的东西（最接近的可能是未初始化的引用，但编译器会警告）。

> **原则：能不用 `late` 就不用。** 优先让字段在声明时或构造函数中初始化。

### 坑 2：`!` 的滥用

C++ 程序员习惯了"判空就不崩"，可能会习惯性写 `x!`：

```dart
String? name;
print(name!.length);  // 崩！和不判空直接 *nullptr 一样
```

Dart 社区共识：`!` 是"我对编译器说别管了"的信号。每用一个 `!` 就该问自己——**能不能用 `??` 替代？**

### 坑 3：类型提升 vs C++ 的指针判空

```cpp
// C++: 判空后你只是"知道"不空，类型没变
int* p = getPtr();
if (p) {
  int val = *p;  // 仍然需要解引用
}
```

```dart
// Dart: 判空后类型真的从 int? 变成 int
int? p = getValue();
if (p != null) {
  p.isEven;  // p 的类型是 int，不需要 ! 或任何解包操作
}
```

---

## 探索发散触发点

> 选 1-2 个深入探索，向 AI 追问。

1. **原理深挖：** Dart 编译器怎么实现 Null Safety 的类型提升？编译后的 JavaScript/机器码里，`int?` 和 `int` 有区别吗？（提示：搜 "Dart NNBD implementation" 或 "Dart null safety under the hood"）
2. **实操验证：** 在你的 `mood_record.dart` 里，试着把 `String? localId` 改成 `String localId`，看看编译器在哪些地方报错？从报错信息反推代码里哪些地方可能真的没给它赋值。
3. **场景延伸：** C++ 的 `std::optional` 和 Dart 的 `?` 有什么本质区别？为什么 Dart 把 null safety 做到类型系统层面而 C++ 用库解决？

---

## 费曼检验

1. 用你自己的话解释：`String`、`String?`、`late String` 三者的区别是什么？
2. `??` 和 `?.` 各自解决什么问题？给一个同时用两个的代码例子。
3. 下面代码哪里有问题？
   ```dart
   String? name;
   void greet() {
     if (name != null) {
       print('你好，${name.length}个字的名字');
     }
   }
   ```
   （提示：考虑 `name` 是一个 getter 的情况）

---

## 图谱链接

- 本模块 ← [[01-万物皆对象与变量]]（`String?` 的 `?` 承接上一模块的疑问）
- 本模块 → [[03-函数]]（函数参数里 `int?` 的可选参数）
- 本模块 → [[04-类与构造函数]]（`final` 字段 + `?` 怎么在构造函数里处理）
- 本模块 → [[mood_record.dart 源码]]

---

*记录日期：2026-05-26 | 上一个模块：[[01-万物皆对象与变量]] | 下一个模块：[[03-函数]]*
