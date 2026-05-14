import 'dart:math';
import '../enums/mood_type.dart';
import '../enums/message_log_range.dart';
import '../models/mood_log.dart';

class MessageService {
  static final _random = Random();

  static const List<MoodType> _positiveMoods = [
    MoodType.happy,
    MoodType.calm,
    MoodType.blissful,
    MoodType.surprise,
  ];

  static const List<String> _cognitivePatterns = [
    '总是',
    '从不',
    '永远',
    '没人',
    '没有人',
    '都不',
    '一定',
    '不可能',
    '我不行',
    '完了',
    '完蛋',
    '没有希望',
    '没戏了',
    '没有价值',
    '自己不够',
  ];

  // ===== 主题关键词 =====
  static const Map<String, List<String>> _themeKeywords = {
    '工作': ['工作', '上班', '加班', '同事', '老板', '项目', '任务', '会议', '报告', '绩效'],
    '学习': ['学习', '考试', '作业', '课程', '老师', '学校', '读书', '复习', '知识', '进步'],
    '家庭': ['家人', '父母', '孩子', '爸爸', '妈妈', '爷爷', '奶奶', '丈夫', '妻子', '亲戚'],
    '朋友': ['朋友', '同学', '闺蜜', '哥们', '聚会', '聊天', '陪伴', '支持', '友谊'],
    '健康': ['身体', '生病', '医院', '医生', '锻炼', '运动', '饮食', '睡眠', '疲惫', '健康'],
    '爱情': ['恋爱', '男友', '女友', '喜欢', '感情', '分手', '结婚', '约会', '暧昧'],
    '自我': ['自己', '成长', '改变', '反思', '目标', '梦想', '未来', '过去', '现在'],
    '压力': ['压力', '焦虑', '紧张', '担心', '害怕', '恐惧', '不安', '崩溃', '负担'],
    '成就': ['成功', '完成', '进步', '突破', '骄傲', '自信', '满意', '收获'],
    '休闲': ['休息', '娱乐', '旅行', '电影', '音乐', '游戏', '放松', '假期'],
  };

  // ===== 情感强度词汇 =====
  static const Map<String, List<String>> _emotionIntensity = {
    '强烈正面': ['超级', '非常', '特别', '极度', '无比', '太棒了', '爱死', '兴奋'],
    '温和正面': ['还好', '不错', '开心', '愉快', '满意', '舒服', '轻松'],
    '强烈负面': ['超级', '非常', '特别', '极度', '无比', '太糟了', '崩溃', '绝望'],
    '温和负面': ['有点', '稍微', '还行', '一般', '郁闷', '烦躁', '疲惫'],
  };

  // ===== 积极心理学研究结论 =====
  static const List<Map<String, String>> _positivePsychologyInsights = [
    {'text': '研究表明，表达感恩可以显著提升幸福感。', 'author': '积极心理学'},
    {'text': '心流状态——完全沉浸于活动的状态——是幸福的最佳体验。', 'author': '米哈里·契克森米哈伊'},
    {'text': '坚持记录感恩日记的人在多项幸福指标上都表现更好。', 'author': '积极心理学研究'},
    {'text': '乐观不是天生特质，而是一种可以培养的思维方式。', 'author': '积极心理学'},
    {'text': '良好的人际关系是预测幸福和长寿最强的因素。', 'author': '哈佛成人发展研究'},
    {'text': '助人行为会激活大脑的奖励中心，利他本身就是一种回报。', 'author': '社会神经科学'},
    {'text': '接纳负面情绪，反而能减少其影响。', 'author': '接纳与承诺疗法'},
    {'text': '设定明确的目标并追求意义感，是幸福的核心要素。', 'author': '积极心理学'},
  ];

  // ===== 积极消息适用名言（关于幸福、成长、自我实现）=====
  static const List<Map<String, String>> _positiveQuotes = [
    {'text': '幸福不是等待，而是勇敢选择。', 'author': '阿德勒'},
    {'text': '幸福是生命的意义和目的，是人生的终极目标。', 'author': '亚里士多德'},
    {'text': '心流状态——完全沉浸于活动的状态——是幸福的最佳体验。', 'author': '米哈里·契克森米哈伊'},
    {'text': '顶峰的体验是生命中最值得活着的时刻。', 'author': '马斯洛'},
    {'text': '良好的人际关系是预测幸福和长寿最强的因素。', 'author': '哈佛成人发展研究'},
    {'text': '研究表明，表达感恩可以显著提升幸福感。', 'author': '积极心理学'},
    {'text': '乐观不是天生特质，而是一种可以培养的思维方式。', 'author': '积极心理学'},
    {'text': '每一个不曾起舞的日子，都是对生命的辜负。', 'author': '尼采'},
    {'text': '自我实现是一个过程，而不是一个结果。', 'author': '马斯洛'},
    {'text': '心若改变，态度就改变；态度改变，习惯就改变；习惯改变，人生就改变。', 'author': '马斯洛'},
    {'text': '知足者富。', 'author': '老子'},
    {'text': '上善若水，水善利万物而不争。', 'author': '老子'},
    {'text': '你若爱，生活哪里都可爱。', 'author': '丰子恺'},
    {'text': '我们反复做的事情成就了我们，因此卓越不是一种行为，而是一种习惯。', 'author': '亚里士多德'},
    {'text': '成为真实的自己，是人生最深的渴望。', 'author': '卡尔·罗杰斯'},
    {'text': '接纳真实的自己，是成长的起点。', 'author': '卡尔·罗杰斯'},
    {'text': '认识你自己，就是开始新一轮的自由。', 'author': '荣格'},
    {'text': '大脑是可塑的，你每一次的思考都在重塑它。', 'author': '神经科学'},
    {'text': '生如夏花之绚烂，死如秋叶之静美。', 'author': '泰戈尔'},
    {'text': '坚持记录感恩日记的人在多项幸福指标上都表现更好。', 'author': '积极心理学研究'},
  ];

  // ===== 支持性消息适用名言（关于接纳、勇气、韧性）=====
  static const List<Map<String, String>> _supportiveQuotes = [
    {'text': '在最深的绝望里，遇见最美的风景。', 'author': '几米'},
    {'text': '世界以痛吻我，要我报之以歌。', 'author': '泰戈尔'},
    {'text': '凡杀不死我的，必使我更强大。', 'author': '尼采'},
    {'text': '那没有杀死我的，使我更加强大。', 'author': '尼采'},
    {'text': '人知道自己为什么而活，就能承受任何一种生活。', 'author': '尼采'},
    {'text': '当你穿过了暴风雨，你就不再是原来那个人了。', 'author': '村上春树'},
    {'text': '人不度己，谁能度之？', 'author': '慧律法师'},
    {'text': '既往不恋，当下不杂，未来不迎。', 'author': '曾国藩'},
    {'text': '不完满才是人生。', 'author': '季羡林'},
    {'text': '给自己时间，不要焦急，一步一步来，一日一日过。', 'author': '三毛'},
    {'text': '不要问生命的意义是什么，而要意识到你正在被生命询问。', 'author': '弗兰克尔'},
    {'text': '人所拥有的任何东西都可以被剥夺，唯独最后的自由——选择态度的自由——不能。', 'author': '弗兰克尔'},
    {'text': '在任何特定的环境中人永远还有最后一种自由：选择态度的自由。', 'author': '弗兰克尔'},
    {'text': '接纳真实的自己，是成长的起点。', 'author': '卡尔·罗杰斯'},
    {'text': '当一个人真正被倾听时，改变就开始发生了。', 'author': '卡尔·罗杰斯'},
    {'text': '与自己和解，是人生最重要的事。', 'author': '荣格'},
    {'text': '人生的意义由自己赋予。', 'author': '阿德勒'},
    {'text': '过去不重要，重要的是你如何看待过去。', 'author': '阿德勒'},
    {'text': '未被表达的情绪永远不会消亡，它们只是被活埋了。', 'author': '弗洛伊德'},
    {'text': '引发情绪的不是事件本身，而是我们对事件的解读。', 'author': '阿尔伯特·艾利斯'},
    {'text': '接纳负面情绪，反而能减少其影响。', 'author': '接纳与承诺疗法'},
    {'text': '不完美并不等于不好，完美主义是最大的敌人。', 'author': '阿尔伯特·艾利斯'},
    {'text': '无用之用，方为大用。', 'author': '庄子'},
    {'text': '祸兮，福之所倚；福兮，祸之所伏。', 'author': '老子'},
    {'text': '我们不是因为看见而相信，而是因为相信而看见。', 'author': '阿德勒'},
    {'text': '知之而后有定，定而后能静。', 'author': '大学'},
  ];

  // ===== 开场白 =====
  static const List<String> _positiveOpenings = [
    '看到你的记录，小暖心里暖暖的。',
    '今天的阳光和你记录的心情一样明媚呢。',
    '每次看到你认真记录，小暖都觉得被治愈了。',
    '你知道吗？你的每一次记录都在为自己积累幸福的证据。',
    '小暖发现了一个小秘密：愿意面对自己的人，本身就很勇敢。',
    '今天小暖读到你的心情，感觉像喝了一杯温暖的茶。',
    '你的记录里藏着金子般的光芒，小暖看到了。',
    '在这喧嚣的世界里，能安静记录心情的你，真的很特别。',
    '小暖想说：谢谢你愿意和我分享你的内心世界。',
    '读着你的记录，小暖仿佛看到了一个在努力生活的灵魂。',
    '你的每一条记录都是与自己对话的勇气。',
    '小暖被你认真对待生活的样子打动了。',
  ];

  static const List<String> _supportiveOpenings = [
    '小暖看到你最近的记录，想抱抱你。',
    '不管世界怎样，你愿意记录下来就已经很棒了。',
    '小暖想说，你的感受都很重要。',
    '有时候，承认自己累了也是一种力量。',
    '小暖读到了你最近的心情，想轻轻告诉你：一切都会好的。',
    '看到你现在的状态，小暖想陪你坐一会儿。',
    '不管你正在经历什么，小暖都在这里。',
    '小暖听到了你内心的声音，它很重要。',
    '如果你现在有点难过，小暖愿意陪着你。',
    '每个人的心情都有高低起伏，这很正常。',
  ];

  static const List<String> _noLogsOpenings = [
    '今天小暖来看你了。',
    '嗨，小暖在这里等你呢。',
    '小暖有个小小的请求想对你说。',
    '今天还没看到你的记录，小暖有点想你了。',
  ];

  // ===== 描述语 =====
  static const List<String> _positiveDescriptions = [
    '这种对生活的觉察真的很珍贵。',
    '你正在学会与自己的情绪相处，这是很棒的一步。',
    '持续记录本身就是一种自我关爱的方式。',
    '小暖很开心能见证你的成长。',
    '你对情绪的敏感度正在提升，这是一项很重要的能力。',
    '记录心情就像给心灵做瑜伽，需要坚持，但值得。',
    '你正在培养一种让自己更了解自己的好习惯。',
    '心理学上说，能够命名情绪就能管理情绪，你在这样做。',
    '这种觉察力是很多人在练习冥想很久才能获得的。',
  ];

  static const List<String> _supportiveDescriptions = [
    '你能把这些感受记录下来，说明你正在面对它们。',
    '有时候，光是承认"我不太好"就已经是疗愈的开始。',
    '情绪没有好坏之分，它们都是生命的一部分。',
    '小暖理解你的感受，它们都是真实的。',
    '给自己一些时间和空间来感受，不用急。',
    '不管你现在的心情如何，都值得被看见。',
  ];

  // ===== 鼓励语 =====
  static const List<String> _encouragements = [
    '今天，让小暖陪你一起深呼吸。',
    '如果累了，就休息一下吧。你已经做得很好了。',
    '小暖想提醒你，照顾好自己也是一种能力。',
    '记住，你不需要一直坚强，偶尔的脆弱也是一种真实。',
    '今天，给自己一个小小的奖励吧，哪怕只是一杯热茶。',
    '允许自己休息，这不是懒惰，而是必要的恢复。',
    '今天的你比昨天更了解自己了，这就是进步。',
    '小暖相信你有能力度过任何困难的时刻。',
    '如果今天很难，告诉自己：没关系，明天会更好。',
    '记得喝水，记得吃饭，记得对自己温柔一点。',
  ];

  // ===== 温暖结尾 =====
  static const List<String> _warmClosings = [
    '愿你今晚有个好梦。',
    '愿你被世界温柔以待。',
    '晚安，小暖爱你。',
    '明天见，我在这里等你。',
    '不管发生什么，记得你不是一个人。',
    '今天的你也辛苦了。',
    '小暖会一直在这里陪着你。',
    '愿你找到内心的平静。',
  ];

  /// 分析日志内容，返回主题和情感洞察
  static Map<String, dynamic> _analyzeLogContent(List<MoodLog> logs) {
    final themes = <String, int>{};
    final emotions = <String, int>{};
    final hasImages = logs.any((log) => log.imageCount > 0);
    final hasComments = logs.any((log) => log.comment.isNotEmpty);
    final cognitiveBiases = <String>[];

    for (final log in logs) {
      final content = '${log.note} ${log.comment}'.toLowerCase();

      // 检测主题
      for (final entry in _themeKeywords.entries) {
        final theme = entry.key;
        final keywords = entry.value;
        if (keywords.any((keyword) => content.contains(keyword))) {
          themes[theme] = (themes[theme] ?? 0) + 1;
        }
      }

      // 检测情感强度
      for (final entry in _emotionIntensity.entries) {
        final intensity = entry.key;
        final words = entry.value;
        if (words.any((word) => content.contains(word))) {
          emotions[intensity] = (emotions[intensity] ?? 0) + 1;
        }
      }

      // 检测认知偏差
      for (final pattern in _cognitivePatterns) {
        if (content.contains(pattern)) {
          if (!cognitiveBiases.contains(pattern)) {
            cognitiveBiases.add(pattern);
          }
        }
      }
    }

    // 找出主要主题
    final mainThemes = themes.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'mainThemes': mainThemes.take(3).map((e) => e.key).toList(),
      'emotions': emotions,
      'hasImages': hasImages,
      'hasComments': hasComments,
      'cognitiveBiases': cognitiveBiases,
      'totalLogs': logs.length,
    };
  }

  /// 生成每日消息
  /// [logs] 心情记录列表
  /// [range] 读取记录的时间范围，默认三天
  static String generateDailyMessage(List<MoodLog> logs, [MessageLogRange range = MessageLogRange.threeDays]) {
    if (logs.isEmpty) {
      return _getNoLogsMessage(range);
    }

    final recentLogs = _filterRecentLogs(logs, range);
    if (recentLogs.isEmpty) {
      return _getNoLogsMessage(range);
    }

    final analysis = _analyzeLogContent(recentLogs);
    final negativeLogs = recentLogs.where((log) => !_positiveMoods.contains(log.mood)).toList();
    final hasCognitiveBias = (analysis['cognitiveBiases'] as List<String>).isNotEmpty;

    if (negativeLogs.isEmpty) {
      return _buildPositiveMessage(recentLogs, range, analysis);
    }

    return _buildSupportiveMessage(recentLogs, hasCognitiveBias, range, analysis);
  }

  static String _getNoLogsMessage(MessageLogRange range) {
    final buffer = StringBuffer();
    buffer.writeln(_pickRandom(_noLogsOpenings));
    buffer.writeln();
    buffer.writeln('小暖注意到你${range.label}还没有记录心情呢。');
    buffer.writeln(_pickRandom([
      '不着急，找个安静的时刻，写下此刻的感受吧。',
      '找个舒服的姿势，花几分钟和自己待一会儿。',
      '哪怕只是几个字，也是和自己对话的开始。',
      '今天有什么想说的吗？小暖很想听听。',
    ]));
    buffer.writeln();
    // 无记录时使用支持性名言
    buffer.writeln(_formatQuote(_pickContextualQuote(false)));
    buffer.writeln();
    buffer.writeln(_pickRandom(_warmClosings));
    return buffer.toString().trim();
  }

  static List<MoodLog> _filterRecentLogs(List<MoodLog> logs, MessageLogRange range) {
    final now = DateTime.now();
    final days = range.days;
    return logs.where((log) {
      final diff = now.difference(log.createdAt).inDays;
      return diff >= 0 && diff <= days - 1;
    }).toList();
  }

  static String _pickRandom(List<String> list) {
    return list[_random.nextInt(list.length)];
  }

  /// 根据上下文类型选择名言
  /// [isPositive] true=积极消息，false=支持性消息
  static Map<String, String> _pickContextualQuote(bool isPositive) {
    if (isPositive) {
      return _positiveQuotes[_random.nextInt(_positiveQuotes.length)];
    } else {
      return _supportiveQuotes[_random.nextInt(_supportiveQuotes.length)];
    }
  }

  static String _formatQuote(Map<String, String> quote) {
    return '"${quote['text']}" — ${quote['author']}';
  }

  static String _buildPositiveMessage(List<MoodLog> logs, MessageLogRange range, Map<String, dynamic> analysis) {
    final moodLabels = logs.map((log) => log.mood.label).toSet().join('、');
    final count = logs.length;
    final mainThemes = analysis['mainThemes'] as List<String>;
    final hasImages = analysis['hasImages'] as bool;
    final hasComments = analysis['hasComments'] as bool;

    final buffer = StringBuffer();
    buffer.writeln(_pickRandom(_positiveOpenings));
    buffer.writeln();

    // 个性化总结
    buffer.writeln('${range.label}你记录了$count次心情，主要是$moodLabels。');
    if (mainThemes.isNotEmpty) {
      buffer.writeln('小暖注意到你最近在关注${mainThemes.join('、')}方面的事情，这很好。');
    }
    if (hasImages) {
      buffer.writeln('看到你还分享了照片，这些视觉记录让你的心情故事更加生动。');
    }
    if (hasComments) {
      buffer.writeln('你写下的那些思考和反思，都被小暖认真读过了。');
    }

    buffer.writeln(_pickRandom(_positiveDescriptions));
    buffer.writeln();

    // 根据主题选择相关建议
    if (mainThemes.contains('工作')) {
      buffer.writeln('工作上的付出总会有回报，记得给自己一些认可。');
    } else if (mainThemes.contains('学习')) {
      buffer.writeln('学习是一场马拉松，坚持就是胜利。');
    } else if (mainThemes.contains('家庭')) {
      buffer.writeln('家庭的温暖是最坚实的后盾。');
    } else if (mainThemes.contains('朋友')) {
      buffer.writeln('真挚的友谊是人生最大的财富。');
    } else if (mainThemes.contains('健康')) {
      buffer.writeln('照顾好身体，才能更好地拥抱生活。');
    }

    // 使用积极消息专用名言
    buffer.writeln(_formatQuote(_pickContextualQuote(true)));

    // 额外添加一条积极心理学或脑科学知识
    if (_random.nextBool()) {
      buffer.writeln();
      final extraQuote = _positivePsychologyInsights[_random.nextInt(_positivePsychologyInsights.length)];
      buffer.writeln(_formatQuote(extraQuote));
    }

    buffer.writeln();
    buffer.writeln(_pickRandom(_encouragements));
    buffer.writeln();
    buffer.writeln(_pickRandom(_warmClosings));

    return buffer.toString().trim();
  }

  static String _buildSupportiveMessage(List<MoodLog> logs, bool hasCognitiveBias, MessageLogRange range, Map<String, dynamic> analysis) {
    final moodSummary = logs.map((log) => log.mood.label).toSet().join('、');
    final mainThemes = analysis['mainThemes'] as List<String>;
    final cognitiveBiases = analysis['cognitiveBiases'] as List<String>;
    final hasImages = analysis['hasImages'] as bool;
    final hasComments = analysis['hasComments'] as bool;

    final buffer = StringBuffer();
    buffer.writeln(_pickRandom(_supportiveOpenings));
    buffer.writeln();

    // 个性化开头
    if (mainThemes.isNotEmpty) {
      buffer.writeln('小暖看到你最近在经历${mainThemes.join('、')}方面的事情，${range.label}记录了$moodSummary的情绪。');
    } else {
      buffer.writeln('${range.label}$moodSummary的情绪是真实的，小暖都收到了。');
    }

    if (hasImages) {
      buffer.writeln('你分享的照片，让小暖更能感受到你的心情。');
    }
    if (hasComments) {
      buffer.writeln('你写下的那些深层思考，小暖都认真读过了。');
    }

    if (hasCognitiveBias) {
      buffer.writeln('小暖注意到你可能有${cognitiveBiases.take(2).join('、')}这样的想法。心理学上，这叫做"认知扭曲"——大脑有时会用不准确的方式解读现实。');
      buffer.writeln(_pickRandom([
        '荣格曾说，最可怕的事情是完全接受自己——其实更可怕的是用错误的尺子衡量自己。',
        '阿德勒提醒我们：我们不是因为看见而相信，而是因为相信而看见。',
        '试着问自己：这个想法有证据支持吗？有没有其他可能的解释？',
      ]));
    } else {
      buffer.writeln(_pickRandom(_supportiveDescriptions));
    }

    buffer.writeln();

    // 根据主题提供针对性支持
    if (mainThemes.contains('工作')) {
      buffer.writeln('工作压力大时，记得给自己喘息的空间。');
    } else if (mainThemes.contains('学习')) {
      buffer.writeln('学习路上难免有挫折，但每一步都在积累。');
    } else if (mainThemes.contains('家庭')) {
      buffer.writeln('家庭关系有时候复杂，但爱一直都在。');
    } else if (mainThemes.contains('朋友')) {
      buffer.writeln('友谊需要维护，也需要理解。');
    } else if (mainThemes.contains('健康')) {
      buffer.writeln('身体发出信号时，要认真倾听。');
    } else if (mainThemes.contains('爱情')) {
      buffer.writeln('感情的事，没有标准答案，只有真心。');
    } else if (mainThemes.contains('自我')) {
      buffer.writeln('自我探索的旅程，从不轻松，但值得。');
    }

    // 使用支持性消息专用名言
    buffer.writeln(_formatQuote(_pickContextualQuote(false)));

    // 添加实用建议
    buffer.writeln();
    if (hasCognitiveBias) {
      buffer.writeln(_pickRandom([
        '小技巧：当你发现自己在用"总是""从不"思考时，试着找到反例。比如"虽然这件事没做好，但上次那件事我做得还不错"。',
        '尝试用"有时候""在某些情况下"来替代"总是""从不"，会让思维更灵活。',
        '认知行为疗法建议：把想法写下来，然后问自己：如果朋友有同样的想法，我会怎么安慰他？',
      ]));
    } else {
      buffer.writeln(_pickRandom([
        '允许自己有这样的感受，这是情绪自我调节的第一步。',
        '如果感觉好一点了，别忘了给自己一个小奖励。',
        '记住，情绪就像天气，会来也会走。',
      ]));
    }

    buffer.writeln();
    buffer.writeln(_pickRandom(_encouragements));
    buffer.writeln();
    buffer.writeln(_pickRandom(_warmClosings));

    return buffer.toString().trim();
  }
}
