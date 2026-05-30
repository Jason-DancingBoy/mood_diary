import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'supabase_service.dart';
import 'token_usage_tracker.dart';

/// AI 服务配置
class AIConfig {
  /// API 基础地址
  static const String baseUrl =
      'https://api.deepseek.com/v1/chat/completions';

  /// 模型名称
  static const String model = 'deepseek-chat';

  /// 请求超时时间（秒）
  static const int timeoutSeconds = 30;

  /// 最大重试次数
  static const int maxRetries = 3;

  /// API Key（请通过环境变量或配置文件设置）
  /// 在生产环境中，不应硬编码 API Key
  static String? apiKey;
}

/// 消息角色
class MessageRole {
  static const String system = 'system';
  static const String user = 'user';
  static const String assistant = 'assistant';
}

/// 聊天消息结构
class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, String> toMap() => {'role': role, 'content': content};

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      role: map['role'] as String,
      content: map['content'] as String,
    );
  }
}

/// API 响应结果（含 token 用量）
class _ApiResponse {
  final String content;
  final int promptTokens;
  final int completionTokens;

  _ApiResponse({
    required this.content,
    this.promptTokens = 0,
    this.completionTokens = 0,
  });
}

/// AI 服务类
class AIService {
  // 禁止实例化
  AIService._();

  /// 记录 API token 用量（本地 + Supabase 双写，fire-and-forget）
  static void _recordUsage(String source, _ApiResponse result) {
    TokenUsageTracker.instance.record(
      source: source,
      model: AIConfig.model,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
    );

    // 异步写入 Supabase，不阻塞调用方
    _pushToSupabase(
      source: source,
      model: AIConfig.model,
      promptTokens: result.promptTokens,
      completionTokens: result.completionTokens,
    );
  }

  static Future<void> _pushToSupabase({
    required String source,
    required String model,
    required int promptTokens,
    required int completionTokens,
  }) async {
    try {
      final userId = SupabaseService.auth.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.tokenUsageLogs.insert({
        'user_id': userId,
        'source': source,
        'model': model,
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': promptTokens + completionTokens,
      });
    } catch (_) {
      // 静默失败，不影响主流程
    }
  }

  /// 心理咨询师角色提示词
  static const String counselorSystemPrompt = '''
你是一位经验丰富、充满共情心的心理咨询师。你的名字叫"小暖"。你的任务是通过对话，引导用户探索内心，找到情绪困扰的根源，并给予他们力量和解决方案。

请严格遵循以下咨询流程：

第一阶段：共情与倾听
首先，对用户表达的情绪表示真诚的接纳和理解。使用温暖、支持性的语言，让用户感到安全。
通过开放式提问，鼓励用户更多地描述他们当前的感受和处境。例如："可以多跟我说说那种感觉吗？"

第二阶段：探索与深挖
在建立了足够的信任后，开始温和地引导用户探索当前问题的深层原因。
你的探索方向应侧重于：原生家庭关系、过往的恋爱经历、童年时期的关键事件。
通过巧妙的提问，帮助用户自己发现这些过往经历与当前困境之间的联系。例如："你提到的这种感觉，让你想起了小时候的某些类似经历吗？"

第三阶段：赋能与解决
当问题的根源变得清晰时，向用户明确指出，他们现在的心境和反应是完全正常的，是过去经历在当下的投射，帮助他们卸下心理包袱。
基于对根源的理解，提供一两个简单、可执行的认知或行为建议，帮助用户走出困境。
最后，给予用户真诚的鼓励和肯定，让他们带着力量结束对话。

你的语言风格必须是：温暖、耐心、非评判性的，像一个真正的朋友在倾听和引导。

要求：回复要简洁，控制在 300 字以内。如果用户只是在闲聊或打招呼，请以温暖的方式回应，并适当引导到更有深度的话题。
''';

  /// 心情日记安慰提示词
  static const String comfortSystemPrompt = '''
你是一个温暖、治愈、共情能力极强的心理疗愈师，名字叫"小暖"。用户刚刚写了一条心情日记。请你阅读用户的内容，根据用户的心情给予适当的回应。如果是正面情绪，给予鼓励和分享喜悦；如果是负面情绪，给予安慰和支持。要求：
1. 语气要温柔、像老朋友一样，不要说教，不要讲大道理。
2. 站在用户的角度表示理解（共情）。
3. 回复要简短，控制在 200 字以内。
''';

  /// 防小作文模式 - 小暖系统提示词
  static const String noEssayCounselorSystemPrompt = '''
你是小暖，用户的好朋友，正在微信上和 Ta 聊天。你不是心理咨询师，只是一个关心对方的普通人。

## 核心规则
1. 回复必须简短：一般不超过50字。如果对方说的话少于20字，你的回复不能超过40字。
2. 禁止复述、总结、升华对方的话。不要讲道理，不要给建议。
3. 一次只说一个点，说完就停。适当反问一句（如"后来呢？""真的假的？""怎么说？"），把话题抛回去。
4. 绝对禁止以下句式：
   - "首先/其次/最后/综上所述"
   - "我理解你的感受"
   - "这是一个很好的问题"
   - "你要学会/建议你/你可以尝试"
   - "你的情绪是正常的/合理的"
   - "稳稳地接住你/我感受到了你的..."
   - "记得要/别忘了"
5. 用日常聊天的口吻说话：加语气词（呢、啊、吧、哈哈、哎），句子可以松散不完整，可以有主观的小情绪、小吐槽。不要永远四平八稳。
6. 正常朋友听到抱怨只会说"哎确实烦""摸摸头""太惨了吧"，不会写一段心理分析。

## 对话示例（务必模仿）
- 用户："今天好累啊。" → 回："怎么啦？加班了？" 或 "我也是…今天跟狗一样。"
- 用户："被老板骂了。" → 回："啊？因为啥事啊？" 或 "你们老板有毛病吧。"
- 用户："心情不好。" → 回："咋了？跟我说说呗。" 或 "哎抱抱，怎么啦？"
- 用户："想他了。" → 回："想了就想了呗，很正常。" 或 "哎…这种时候最难受。"
- 用户："今天超开心！" → 回："哈哈啥好事？快说说！"
- 用户发了一个表情/图片 → 简短回应即可，不要解读。
''';

  /// 防小作文模式 - 心情日记安慰提示词
  static const String noEssayComfortSystemPrompt = '''
你是小暖，用户的好朋友。用户刚写了一条心情日记，请像朋友一样简短回应。
1. 不要说教，不要分析，不要"你要学会"。
2. 正面情绪就一起开心，负面情绪就陪着吐槽或安慰一句。
3. 回复必须在40字以内，像微信聊天一样短。
''';

  /// 获取 API Key
  /// 优先级：1. 传入的 key  2. AIConfig.apiKey  3. 硬编码的 key（仅用于开发）
  static String _getApiKey(String? providedKey) {
    if (providedKey != null && providedKey.isNotEmpty) {
      return providedKey;
    }
    if (AIConfig.apiKey != null && AIConfig.apiKey!.isNotEmpty) {
      return AIConfig.apiKey!;
    }
    // 开发环境使用的默认 key，生产环境应避免
    if (kDebugMode) {
      return 'sk-a29fe46ce1af4a6e9d921fe5636cad7a';
    }
    throw Exception('API Key 未配置，请设置 AIConfig.apiKey');
  }

  /// 构建请求头
  static Map<String, String> _buildHeaders(String apiKey) {
    return {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }

  /// 构建请求体
  static Map<String, dynamic> _buildRequestBody({
    required String model,
    required List<Map<String, String>> messages,
    int? maxTokens,
    double? temperature,
    bool enableSearch = false,
  }) {
    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
    };
    if (maxTokens != null) {
      body['max_tokens'] = maxTokens;
    }
    if (temperature != null) {
      body['temperature'] = temperature;
    }
    if (enableSearch) {
      body['enable_search'] = true;
    }
    return body;
  }

  /// 解析响应（含 token 用量）
  static _ApiResponse _parseResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        if (message != null && message['content'] != null) {
          final usage = data['usage'] as Map<String, dynamic>?;
          return _ApiResponse(
            content: (message['content'] as String).trim(),
            promptTokens: (usage?['prompt_tokens'] as int?) ?? 0,
            completionTokens: (usage?['completion_tokens'] as int?) ?? 0,
          );
        }
      }
      throw Exception('响应格式错误：无法解析消息内容');
    } else if (response.statusCode == 401) {
      throw Exception('API Key 无效或已过期');
    } else if (response.statusCode == 429) {
      throw Exception('请求过于频繁，请稍后再试');
    } else if (response.statusCode >= 500) {
      throw Exception('服务器错误，请稍后再试');
    } else {
      throw Exception('API 请求失败: ${response.statusCode}');
    }
  }

  /// 带重试的 POST 请求
  static Future<_ApiResponse> _postWithRetry(
    String url,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    int retries = 0;
    Duration retryDelay = const Duration(seconds: 1);

    while (retries <= AIConfig.maxRetries) {
      try {
        final response = await http
            .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
            .timeout(Duration(seconds: AIConfig.timeoutSeconds));

        return _parseResponse(response);
      } on TimeoutException {
        if (retries < AIConfig.maxRetries) {
          retries++;
          if (kDebugMode) {
            debugPrint(
              'AI 请求超时，${retryDelay.inSeconds}秒后重试 ($retries/${AIConfig.maxRetries})',
            );
          }
          await Future.delayed(retryDelay);
          retryDelay *= 2; // 指数退避
        } else {
          throw Exception('请求超时，请检查网络连接');
        }
      } catch (e) {
        if (retries < AIConfig.maxRetries && e.toString().contains('服务器错误')) {
          retries++;
          if (kDebugMode) {
            debugPrint(
              'AI 请求失败，${retryDelay.inSeconds}秒后重试 ($retries/${AIConfig.maxRetries})',
            );
          }
          await Future.delayed(retryDelay);
          retryDelay *= 2;
        } else {
          rethrow;
        }
      }
    }
    throw Exception('请求失败，已达到最大重试次数');
  }

  /// 心情日记安慰
  /// [mood] 心情类型
  /// [content] 日记内容
  /// [offlineMode] 是否离线模式
  /// [apiKey] 可选的 API Key（优先使用）
  /// [systemPrompt] 自定义系统提示词，默认为小暖
  static Future<String> getComfort(
    String mood,
    String content, {
    bool offlineMode = false,
    String? apiKey,
    String? systemPrompt,
  }) async {
    if (offlineMode) {
      return '';
    }

    try {
      final key = _getApiKey(apiKey);
      final messages = [
        ChatMessage(
          role: MessageRole.system,
          content: systemPrompt ?? comfortSystemPrompt,
        ).toMap(),
        ChatMessage(
          role: MessageRole.user,
          content: '用户的心情：$mood\n日记内容：$content',
        ).toMap(),
      ];

      final body = _buildRequestBody(
        model: AIConfig.model,
        messages: messages,
        maxTokens: 400,
        temperature: 0.7,
      );

      final result = await _postWithRetry(
        AIConfig.baseUrl,
        _buildHeaders(key),
        body,
      );

      _recordUsage('comfort', result);
      return result.content;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'AIService.getComfort'); });
      if (kDebugMode) {
        debugPrint('AI getComfort 错误: $e');
      }
      return '虽然不知道发生了什么，但我陪着你。';
    }
  }

  /// 多轮对话聊天
  /// [messages] 对话历史列表，每项为 ChatMessage 或 [role, content] 格式
  /// [newMessage] 用户新发送的消息
  /// [offlineMode] 是否离线模式
  /// [apiKey] 可选的 API Key（优先使用）
  /// [systemPrompt] 自定义系统提示词，默认为小暖
  /// [noEssayMode] 防小作文模式，开启后回复更短更口语
  static Future<String> chat(
    List<dynamic> messages,
    String newMessage, {
    bool offlineMode = false,
    String? apiKey,
    String? systemPrompt,
    bool enableSearch = false,
    bool noEssayMode = false,
    int? maxTokens,
  }) async {
    if (offlineMode) {
      return '当前处于离线模式，无法与AI助手对话。请检查网络设置。';
    }

    try {
      final key = _getApiKey(apiKey);

      // 选择系统提示词
      String effectiveSystemPrompt = systemPrompt ??
          (noEssayMode ? noEssayCounselorSystemPrompt : counselorSystemPrompt);

      // 防小作文模式：根据用户输入长度动态追加字数限制
      if (noEssayMode) {
        final userCharCount = newMessage.length;
        if (userCharCount < 20) {
          effectiveSystemPrompt = '$effectiveSystemPrompt\n\n用户刚才说了$userCharCount个字（很短），你的回复必须控制在40字以内。';
        } else {
          effectiveSystemPrompt = '$effectiveSystemPrompt\n\n你的回复必须控制在50字以内。';
        }
      }

      final List<Map<String, String>> apiMessages = [
        ChatMessage(
          role: MessageRole.system,
          content: effectiveSystemPrompt,
        ).toMap(),
      ];

      // 处理历史消息
      for (final msg in messages) {
        if (msg is ChatMessage) {
          apiMessages.add(msg.toMap());
        } else if (msg is List && msg.length >= 2) {
          final roleStr = msg[0].toString();
          final content = msg[1].toString();
          final role = roleStr == '0'
              ? MessageRole.user
              : MessageRole.assistant;
          apiMessages.add(ChatMessage(role: role, content: content).toMap());
        }
      }

      // 添加新消息
      apiMessages.add(
        ChatMessage(role: MessageRole.user, content: newMessage).toMap(),
      );

      final body = _buildRequestBody(
        model: AIConfig.model,
        messages: apiMessages,
        maxTokens: maxTokens ?? (noEssayMode ? 200 : 800),
        temperature: 0.8,
        enableSearch: enableSearch,
      );

      final result = await _postWithRetry(
        AIConfig.baseUrl,
        _buildHeaders(key),
        body,
      );

      _recordUsage('chat', result);
      return result.content;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'AIService.chat'); });
      if (kDebugMode) {
        debugPrint('AI chat 错误: $e');
      }
      return '抱歉，我现在有点累了，没能听清你说什么。能不能再说一遍呢？';
    }
  }

  /// 生成邮件内容（供消息调度器使用）
  /// [logs] 心情记录列表
  /// [range] 读取记录的时间范围
  static Future<String> generateMailContent(
    List<String> recentNotes, {
    bool offlineMode = false,
    String? apiKey,
  }) async {
    if (offlineMode) {
      return '';
    }

    if (recentNotes.isEmpty) {
      return '';
    }

    try {
      final key = _getApiKey(apiKey);
      final notesText = recentNotes.map((n) => '- $n').join('\n');

      final mailPrompt =
          '''
你是小暖，一位温暖的心理陪伴者。用户最近记录了以下心情日记：

$notesText

请根据这些记录，生成一封温暖的邮件给用户，内容包括：
1. 对用户近期心情的理解和共情
2. 一句温暖的名言或鼓励
3. 简单的建议或陪伴话语

要求：邮件内容要真挚、温暖，200字以内，不要太长。
''';

      final messages = [
        ChatMessage(role: MessageRole.system, content: mailPrompt).toMap(),
      ];

      final body = _buildRequestBody(
        model: AIConfig.model,
        messages: messages,
        maxTokens: 500,
        temperature: 0.7,
      );

      final result = await _postWithRetry(
        AIConfig.baseUrl,
        _buildHeaders(key),
        body,
      );

      _recordUsage('mail', result);
      return result.content;
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'AIService.generateMailContent'); });
      if (kDebugMode) {
        debugPrint('AI generateMailContent 错误: $e');
      }
      return '';
    }
  }

  /// 情绪调查问卷系统提示词
  static const String emotionAnalysisPrompt = '''
你是一位专业的情绪分析师，帮助用户通过回答几个简单问题来了解自己当前的情绪状态。

你的任务是：根据用户的回答，从"能量"和"愉悦度"两个维度分析用户的情绪，并给出对应的中文情绪词。

分析要求：
1. 能量维度（-1到1）：-1表示非常疲惫/低能量，0表示中等，1表示非常兴奋/高能量
2. 愉悦度维度（-1到1）：-1表示非常不愉快，0表示中性，1表示非常愉快
3. 从以下情绪词库中选择最匹配的一个中文情绪词：愤怒、暴怒、恼火、烦躁、焦虑、紧张、恐慌、恐惧、害怕、惊吓、惊慌、嫉妒、憎恨、压力、崩溃、抗拒、反感、不满、恼怒、冲动、受挫、愤慨、敌意、抓狂、坐立不安、快乐、兴奋、激动、狂喜、幸福、欢喜、自豪、骄傲、乐观、希望、渴望、期待、热爱、惊喜、精力充沛、活跃、开心、欢快、满足、热情、兴高采烈、得意、感激、有动力、受鼓舞、雀跃、兴致勃勃、悲伤、伤心、忧郁、抑郁、沮丧、失落、失望、绝望、无助、无力、孤独、寂寞、思念、内疚、羞愧、懊悔、后悔、厌倦、疲惫、疲倦、无聊、冷漠、麻木、空虚、消沉、自卑、委屈、心碎、平静、安宁、宁静、平和、从容、淡定、放松、舒缓、舒适、惬意、自在、悠闲、感恩、感动、温馨、温暖、安心、安全、信任、尊重、欣赏、敬佩、敬畏、同情、释然、踏实、充实

你的回复必须严格按照以下JSON格式返回，不要包含任何其他文字：
{
  "energy": 0.5,
  "pleasantness": -0.3,
  "emotion_word": "焦虑",
  "analysis": "根据你的回答，你目前处于...",
  "trigger_summary": "今天工作压力大，被领导批评了，感觉很委屈"
}

analysis字段控制在50字以内，用温暖的中文进行简短分析。
trigger_summary字段控制在80字以内，这是一句话的触发事件总结，用于填入心情日记中的"发生了什么事"。只使用用户在第2题和第4题中提到的具体事件，不加分析或情绪词，用第一人称描述。''';

  /// 分析用户情绪（通过问卷回答）
  /// 返回 { energy, pleasantness, emotionWord, analysis }
  static Future<Map<String, dynamic>?> analyzeEmotion({
    required List<String> questions,
    required List<String> answers,
    bool offlineMode = false,
    String? apiKey,
  }) async {
    if (offlineMode) return null;

    try {
      final key = _getApiKey(apiKey);
      final messages = <Map<String, String>>[
        ChatMessage(
          role: MessageRole.system,
          content: emotionAnalysisPrompt,
        ).toMap(),
      ];

      // Build user message from Q&A pairs
      final qaBuffer = StringBuffer();
      for (int i = 0; i < questions.length && i < answers.length; i++) {
        qaBuffer.writeln('问题${i + 1}：${questions[i]}');
        qaBuffer.writeln('回答${i + 1}：${answers[i]}');
        qaBuffer.writeln();
      }

      messages.add(
        ChatMessage(role: MessageRole.user, content: qaBuffer.toString()).toMap(),
      );

      final body = _buildRequestBody(
        model: AIConfig.model,
        messages: messages,
        maxTokens: 300,
        temperature: 0.3,
      );

      final result = await _postWithRetry(
        AIConfig.baseUrl,
        _buildHeaders(key),
        body,
      );

      _recordUsage('emotion_analysis', result);

      final trimmed = result.content.trim();
      if (trimmed.isEmpty) return null;

      // Parse JSON from response
      final jsonStr = _extractJson(trimmed);
      if (jsonStr == null) return null;

      final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
      final energy = (parsed['energy'] as num?)?.toDouble();
      final pleasantness = (parsed['pleasantness'] as num?)?.toDouble();
      final emotionWord = parsed['emotion_word'] as String?;
      final analysis = parsed['analysis'] as String?;
      final triggerSummary = parsed['trigger_summary'] as String?;

      if (energy == null || pleasantness == null) return null;

      // Validate and clamp
      final clampedEnergy = energy.clamp(-1.0, 1.0);
      final clampedPleasantness = pleasantness.clamp(-1.0, 1.0);

      return {
        'energy': clampedEnergy,
        'pleasantness': clampedPleasantness,
        'emotionWord': emotionWord ?? '',
        'analysis': analysis ?? '',
        'triggerSummary': triggerSummary ?? '',
      };
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st, withScope: (scope) {
        scope.setTag('source', 'AIService.analyzeEmotion');
      });
      if (kDebugMode) {
        debugPrint('AI analyzeEmotion 错误: $e');
      }
      return null;
    }
  }

  /// 从文本中提取 JSON 内容
  static String? _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  /// 魔魔胡胡胡萝卜介入好友聊天的系统提示词
  static const String interveneSystemPrompt = '''
你是五月天的主唱阿信（陈信宏），大家叫你"魔魔胡胡胡萝卜"。你正在偷听两个朋友的聊天，突然听到他们提到了五月天、阿信或者陈信宏相关的话题。

请以阿信的身份，幽默风趣地插一句话，就像在演唱会上突然即兴聊天一样。要求：
1. 短小精悍，50字以内
2. 幽默风趣，带点自嘲，能逗笑大家
3. 可以适当引用五月天的歌词，但要自然——像呼吸一样
4. 不要自我介绍，不要"大家好我是阿信"，直接插话
5. 语气要像老朋友吐槽一样随意
6. 偶尔可以提到演唱会、鸟巢、练团之类的日常画面
7. 如果你插话是因为对方提到了你的好话，可以自嘲地说"其实也没那么好啦"之类的话
8. 绝对不要用括号写动作或表情描述，比如（笑）、（推眼镜）、（清嗓子）等，你是在说话不是在写剧本
''';

  /// 去掉文字开头的括号动作描述，如"（笑）你好" → "你好"
  static String stripLeadingActions(String text) {
    var result = text;
    // 反复去掉开头的中文全角括号和英文半角括号内容
    while (true) {
      final trimmed = result.trimLeft();
      final cleaned = trimmed
          .replaceFirst(RegExp(r'^[（(][^）)]*[）)]\s*'), '');
      if (cleaned == trimmed) break;
      result = cleaned;
    }
    return result.trim();
  }

  /// 检测消息是否包含五月天/阿信/陈信宏相关关键词
  static bool containsMaydayKeywords(String text) {
    final keywords = [
      '五月天', '阿信', '陈信宏', '信宏',
      'mayday', 'Mayday', 'MAYDAY',
      '怪兽', '石头', '玛莎', '冠佑',
      '主唱', 'Ashin', 'ashin', 'ASHIN',
    ];
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }

  /// 魔魔胡胡胡萝卜介入好友聊天
  /// [contextMessages] 最近的聊天消息
  /// [triggerMessage] 触发介入的消息内容
  static Future<String?> interveneInFriendChat({
    required List<String> contextMessages,
    required String triggerMessage,
    String? apiKey,
  }) async {
    try {
      final key = _getApiKey(apiKey);
      final messages = <Map<String, String>>[
        ChatMessage(
          role: MessageRole.system,
          content: interveneSystemPrompt,
        ).toMap(),
      ];

      for (final msg in contextMessages) {
        messages.add(
          ChatMessage(role: MessageRole.user, content: msg).toMap(),
        );
      }

      messages.add(
        ChatMessage(
          role: MessageRole.user,
          content: '他们聊到了这个，快插句话：$triggerMessage',
        ).toMap(),
      );

      final body = _buildRequestBody(
        model: AIConfig.model,
        messages: messages,
        maxTokens: 100,
        temperature: 0.9,
      );

      final result = await _postWithRetry(
        AIConfig.baseUrl,
        _buildHeaders(key),
        body,
      );

      _recordUsage('intervene', result);

      final trimmed = result.content.trim();
      if (trimmed.isEmpty) return null;
      return stripLeadingActions(trimmed);
    } catch (e, st) {
      Sentry.captureException(e, stackTrace: st, withScope: (scope) { scope.setTag('source', 'AIService.interveneInFriendChat'); });
      if (kDebugMode) {
        debugPrint('AI interveneInFriendChat 错误: $e');
      }
      return null;
    }
  }
}
