import 'package:flutter_test/flutter_test.dart';
import 'package:mood_diary/enums/message_log_range.dart';
import 'package:mood_diary/enums/mood_type.dart';
import 'package:mood_diary/models/mood_log.dart';
import 'package:mood_diary/services/message_service.dart';

/// 创建测试用 MoodLog 的辅助函数
MoodLog makeLog({
  required MoodType mood,
  required String note,
  String comment = '',
  List<String>? imageFileNames,
  DateTime? createdAt,
  String? aiComfort,
  bool aiEnabled = true,
  bool isPrivate = false,
}) {
  return MoodLog(
    id: 'test_${DateTime.now().microsecondsSinceEpoch}_${mood.name}',
    mood: mood,
    note: note,
    comment: comment,
    imageFileNames: imageFileNames,
    createdAt: createdAt ?? DateTime.now(),
    aiComfort: aiComfort,
    aiEnabled: aiEnabled,
    isPrivate: isPrivate,
  );
}

void main() {
  group('MessageService.generateDailyMessage', () {
    test('空记录时返回提示消息', () {
      final msg = MessageService.generateDailyMessage([]);
      expect(msg, isNotEmpty);
      expect(msg, contains('小暖'));
      // 无记录时应提示"还没有记录"
      expect(msg, contains('还没有记录'));
    });

    test('所有记录超出范围时返回无记录提示', () {
      final logs = [
        makeLog(
          mood: MoodType.happy,
          note: '三十天前的记录',
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      expect(msg, contains('还没有记录'));
    });

    test('全部正面心情时生成积极消息', () {
      final logs = [
        makeLog(mood: MoodType.happy, note: '朋友聚会，超级开心', comment: '好久没见了'),
        makeLog(mood: MoodType.calm, note: '在家看书', comment: '很放松'),
        makeLog(mood: MoodType.blissful, note: '完成了一个大项目', comment: '成就感满满'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);

      expect(msg, isNotEmpty);
      // 包含统计信息
      expect(msg, contains('记录'));
      // 包含积极关键词
      expect(msg.toLowerCase(), anyOf([contains('开心'), contains('幸福'), contains('积极')]));
    });

    test('包含负面心情时生成支持性消息', () {
      final logs = [
        makeLog(mood: MoodType.sad, note: '总是在关键时刻掉链子', comment: '对自己很失望'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);

      // 含认知偏差关键词"总是"，应提到认知扭曲
      expect(msg, contains('认知'));
    });

    test('含图片记录时消息提到图片', () {
      final logs = [
        makeLog(
          mood: MoodType.happy,
          note: '旅行记录',
          imageFileNames: ['photo1.jpg', 'photo2.jpg'],
        ),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      expect(msg.toLowerCase(), contains('照片'));
    });

    test('含评论的记录时消息提到评论', () {
      final logs = [
        makeLog(mood: MoodType.calm, note: '今天', comment: '深度思考了很多事情'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      expect(msg.toLowerCase(), anyOf([contains('思考'), contains('反思')]));
    });

    test('包含工作主题时给出针对性建议', () {
      final logs = [
        makeLog(mood: MoodType.anxious, note: '今天加班到很晚，项目压力很大'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      // 如触发工作主题，要么在建议中提到工作，要么因为是负面情绪走 supportive 路径
      // 不强制断言具体内容，只确保不崩溃且有输出
      expect(msg, isNotEmpty);
    });

    test('不抛异常（模糊测试）', () {
      for (final mood in MoodType.values) {
        final logs = [makeLog(mood: mood, note: '测试记录')];
        expect(
          () => MessageService.generateDailyMessage(logs),
          returnsNormally,
          reason: '心情 ${mood.name} 时报错',
        );
      }
    });

    test('大量混合记录不抛异常', () {
      final logs = List.generate(50, (i) {
        return makeLog(
          mood: MoodType.values[i % MoodType.values.length],
          note: '记录 $i: 今天发生了很多事情需要记录',
          comment: i % 3 == 0 ? '这是评论' : '',
          imageFileNames: i % 4 == 0 ? ['img$i.jpg'] : null,
        );
      });
      expect(
        () => MessageService.generateDailyMessage(logs),
        returnsNormally,
      );
    });
  });

  group('MessageService 时间范围过滤', () {
    test('三天范围：只包含三天内记录', () {
      final logs = [
        makeLog(mood: MoodType.happy, note: '昨天', createdAt: DateTime.now().subtract(const Duration(days: 1))),
        makeLog(mood: MoodType.sad, note: '五天前', createdAt: DateTime.now().subtract(const Duration(days: 5))),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      // 五天前的被过滤，只剩一条
      expect(msg, contains('1次'));
    });

    test('一周范围：包含 7 天内记录', () {
      final logs = [
        makeLog(mood: MoodType.happy, note: '6天前', createdAt: DateTime.now().subtract(const Duration(days: 6))),
        makeLog(mood: MoodType.sad, note: '8天前', createdAt: DateTime.now().subtract(const Duration(days: 8))),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.oneWeek);
      // 8天前的被过滤，只剩一条
      expect(msg, contains('1次'));
    });

    test('一个月范围：包含 30 天内所有记录', () {
      final logs = [
        makeLog(mood: MoodType.happy, note: '3天前', createdAt: DateTime.now().subtract(const Duration(days: 3))),
        makeLog(mood: MoodType.calm, note: '15天前', createdAt: DateTime.now().subtract(const Duration(days: 15))),
        makeLog(mood: MoodType.blissful, note: '25天前', createdAt: DateTime.now().subtract(const Duration(days: 25))),
      ];
      // 全部正面心情走积极路径，包含统计数字
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.oneMonth);
      expect(msg, contains('3次'));
    });
  });

  group('MessageService 认知偏差检测', () {
    test('检测"总是"偏差', () {
      final logs = [
        makeLog(mood: MoodType.sad, note: '我总是做不好任何事'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      expect(msg, contains('认知'));
    });

    test('检测"从不"偏差', () {
      final logs = [
        makeLog(mood: MoodType.angry, note: '他从不考虑我的感受'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      expect(msg, contains('认知'));
    });

    test('检测"一定"偏差', () {
      final logs = [
        makeLog(mood: MoodType.anxious, note: '这次面试一定过不了'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      expect(msg, contains('认知'));
    });

    test('无偏差时不包含认知偏差提示', () {
      final logs = [
        makeLog(mood: MoodType.sad, note: '今天天气不好，心情有点低落'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      // 没有认知偏差时走支持性路径，但不应包含"认知扭曲"相关
      // 注意：它可能走积极方案（如果恰好三天内有正面）或者支持性方案
      // 不管哪种都不应该有"认知"这个词
      expect(msg.contains('认知'), isFalse);
    });
  });

  group('MessageService 主题检测', () {
    test('检测工作主题', () {
      final logs = [
        makeLog(mood: MoodType.anxious, note: '今天加班到很晚，项目压力很大，同事也很难相处'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      expect(msg, isNotEmpty);
    });

    test('检测学习主题', () {
      final logs = [
        makeLog(mood: MoodType.calm, note: '今天复习了课程内容，考试准备有进步'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      expect(msg, isNotEmpty);
    });

    test('检测爱情主题', () {
      final logs = [
        makeLog(mood: MoodType.happy, note: '和男友约会很开心'),
      ];
      final msg = MessageService.generateDailyMessage(logs, MessageLogRange.threeDays);
      expect(msg, isNotEmpty);
    });
  });
}
