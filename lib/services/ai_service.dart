import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _apiKey = 'sk-a29fe46ce1af4a6e9d921fe5636cad7a';
  static const String _baseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const String _model = 'qwen-turbo';

  /// 心理咨询师角色提示词
  static const String _counselorSystemPrompt = '''
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
  static const String _comfortSystemPrompt = '''
你是一个温暖、治愈、共情能力极强的心理疗愈师，名字叫"小暖"。用户刚刚写了一条心情日记。请你阅读用户的内容，根据用户的心情给予适当的回应。如果是正面情绪，给予鼓励和分享喜悦；如果是负面情绪，给予安慰和支持。要求：1. 语气要温柔、像老朋友一样，不要说教，不要讲大道理。2. 站在用户的角度表示理解（共情）。3. 回复要简短，控制在 200 字以内。
''';

  /// 心情日记安慰
  static Future<String> getComfort(String mood, String content, {bool offlineMode = false}) async {
    if (offlineMode) {
      return '';
    }
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': _comfortSystemPrompt},
            {'role': 'user', 'content': '用户的心情：$mood\n日记内容：$content'},
          ],
          'max_tokens': 400,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] as String;
        return aiResponse.trim();
      } else {
        throw Exception('API 请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return '虽然不知道发生了什么，但我陪着你。';
    }
  }

  /// 聊天消息结构
  static const int roleUser = 0;
  static const int roleAssistant = 1;

  /// 多轮对话聊天
  /// [messages] 之前的对话历史，每项为 [role, content]，role: 0=用户, 1=AI
  /// [newMessage] 用户新发送的消息
  static Future<String> chat(List<List<String>> messages, String newMessage, {bool offlineMode = false}) async {
    if (offlineMode) {
      return '当前处于离线模式，无法与小暖对话。请检查网络设置。';
    }

    try {
      // 构建消息列表
      final List<Map<String, String>> apiMessages = [
        {'role': 'system', 'content': _counselorSystemPrompt},
      ];

      // 添加历史消息
      for (final msg in messages) {
        if (msg.length >= 2) {
          final role = int.tryParse(msg[0]) == roleUser ? 'user' : 'assistant';
          apiMessages.add({'role': role, 'content': msg[1]});
        }
      }

      // 添加新消息
      apiMessages.add({'role': 'user', 'content': newMessage});

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': apiMessages,
          'max_tokens': 800,
          'temperature': 0.8,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['message']['content'] as String;
        return aiResponse.trim();
      } else {
        throw Exception('API 请求失败: ${response.statusCode}');
      }
    } catch (e) {
      return '抱歉，我现在有点累了，没能听清你说什么。能不能再说一遍呢？';
    }
  }
}