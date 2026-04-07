import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// AI 服务配置
class AIConfig {
  /// API 基础地址
  static const String baseUrl =
      'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';

  /// 模型名称
  static const String model = 'qwen-turbo-latest';

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

/// AI 服务类
class AIService {
  // 禁止实例化
  AIService._();

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
  }) {
    final body = {'model': model, 'messages': messages};
    if (maxTokens != null) {
      body['max_tokens'] = maxTokens;
    }
    if (temperature != null) {
      body['temperature'] = temperature;
    }
    return body;
  }

  /// 解析响应
  static String _parseResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        if (message != null && message['content'] != null) {
          return (message['content'] as String).trim();
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
  static Future<String> _postWithRetry(
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
  static Future<String> getComfort(
    String mood,
    String content, {
    bool offlineMode = false,
    String? apiKey,
  }) async {
    if (offlineMode) {
      return '';
    }

    try {
      final key = _getApiKey(apiKey);
      final messages = [
        ChatMessage(
          role: MessageRole.system,
          content: comfortSystemPrompt,
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

      final response = await _postWithRetry(
        AIConfig.baseUrl,
        _buildHeaders(key),
        body,
      );

      return response;
    } catch (e) {
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
  static Future<String> chat(
    List<dynamic> messages,
    String newMessage, {
    bool offlineMode = false,
    String? apiKey,
  }) async {
    if (offlineMode) {
      return '当前处于离线模式，无法与小暖对话。请检查网络设置。';
    }

    try {
      final key = _getApiKey(apiKey);
      final List<Map<String, String>> apiMessages = [
        ChatMessage(
          role: MessageRole.system,
          content: counselorSystemPrompt,
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
        maxTokens: 800,
        temperature: 0.8,
      );

      final response = await _postWithRetry(
        AIConfig.baseUrl,
        _buildHeaders(key),
        body,
      );

      return response;
    } catch (e) {
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

      final response = await _postWithRetry(
        AIConfig.baseUrl,
        _buildHeaders(key),
        body,
      );

      return response;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AI generateMailContent 错误: $e');
      }
      return '';
    }
  }
}
