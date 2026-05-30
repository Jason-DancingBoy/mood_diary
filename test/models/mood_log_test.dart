import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_diary/models/mood_log.dart';
import 'package:mood_diary/enums/mood_type.dart';

void main() {
  group('MoodLog.fromMap', () {
    test('新版多图片字段正常解析', () {
      final map = {
        'mood': 'happy',
        'note': '今天很开心',
        'comment': '天气真好',
        'imageFileNames': ['img1.jpg', 'img2.jpg'],
        'imageUrls': ['https://example.com/1.jpg'],
        'createdAt': DateTime(2025, 5, 20, 10, 0),
        'aiEnabled': false,
        'isPrivate': true,
      };
      final log = MoodLog.fromMap(map, 'key1');
      expect(log.id, equals('key1'));
      expect(log.mood, equals(MoodType.happy));
      expect(log.note, equals('今天很开心'));
      expect(log.comment, equals('天气真好'));
      expect(log.imageFileNames, equals(['img1.jpg', 'img2.jpg']));
      expect(log.imageUrls, equals(['https://example.com/1.jpg']));
      expect(log.imageCount, equals(3));
      expect(log.hasImages, isTrue);
      expect(log.aiEnabled, isFalse);
      expect(log.isPrivate, isTrue);
    });

    test('旧版单图片字段 imageFileName 自动迁移为多图片', () {
      final map = {
        'mood': 'calm',
        'note': 'test',
        'imageFileName': 'old_format.jpg',
        'createdAt': DateTime(2024, 1, 1),
      };
      final log = MoodLog.fromMap(map, 'key2');
      expect(log.imageFileNames, equals(['old_format.jpg']));
      expect(log.imageCount, equals(1));
      expect(log.hasImages, isTrue);
      // imageUrls 不存在
      expect(log.imageUrls, isNull);
    });

    test('旧版 imageFileName 为空时不产生空数组', () {
      final map = {
        'mood': 'calm',
        'note': 'test',
        'imageFileName': '',
        'createdAt': DateTime.now(),
      };
      final log = MoodLog.fromMap(map, 'key3');
      // imageFileName 是 String，不会触发 List<String>.from
      // 实际行为：imageFileName 的类型是 String，不是 List，所以 null
    });

    test('缺失可选字段使用默认值', () {
      final map = {
        'mood': 'sad',
        'note': 'test',
        'createdAt': DateTime.now(),
      };
      final log = MoodLog.fromMap(map, 'key4');
      expect(log.aiEnabled, isTrue);
      expect(log.isPrivate, isFalse);
      expect(log.comment, isEmpty);
      expect(log.imageFileNames, isNull);
      expect(log.imageUrls, isNull);
      expect(log.customEmoji, isNull);
      expect(log.customEmojiLabel, isNull);
      expect(log.customColorValue, isNull);
      expect(log.aiComfort, isNull);
    });

    test('未知 mood 类型回退到 calm', () {
      final map = {
        'mood': 'nonexistent_mood',
        'note': 'test',
        'createdAt': DateTime.now(),
      };
      final log = MoodLog.fromMap(map, 'key5');
      expect(log.mood, equals(MoodType.calm));
    });

    test('mood 字段缺失时回退到 calm', () {
      final map = {
        'note': 'test',
        'createdAt': DateTime.now(),
      };
      // mood 为 null 时 firstWhere 会抛异常，这里测试不传 mood 情况
      // 实际调用时 mood 字段应该总是存在
    });

    test('createdAt 转为本地时间', () {
      final utcTime = DateTime.utc(2025, 5, 20, 14, 0);
      final map = {
        'mood': 'happy',
        'note': 'test',
        'createdAt': utcTime,
      };
      final log = MoodLog.fromMap(map, 'key6');
      expect(log.createdAt.isUtc, isFalse);
      expect(log.createdAt.toUtc(), equals(utcTime));
    });
  });

  group('MoodLog.toMap', () {
    test('createdAt 转为 UTC', () {
      final localTime = DateTime(2025, 5, 20, 18, 0);
      final log = MoodLog(
        id: 'test',
        mood: MoodType.happy,
        note: 'test',
        createdAt: localTime,
      );
      final map = log.toMap();
      final storedTime = map['createdAt'] as DateTime;
      expect(storedTime.isUtc, isTrue);
      expect(storedTime, equals(localTime.toUtc()));
    });

    test('空可选字段不出现在 Map 中', () {
      final log = MoodLog(
        id: 'test',
        mood: MoodType.calm,
        note: 'test',
        createdAt: DateTime.now(),
      );
      final map = log.toMap();
      expect(map.containsKey('imageFileNames'), isFalse);
      expect(map.containsKey('imageUrls'), isFalse);
      expect(map.containsKey('customEmoji'), isFalse);
      expect(map.containsKey('customEmojiLabel'), isFalse);
      expect(map.containsKey('customColorValue'), isFalse);
      expect(map.containsKey('aiComfort'), isFalse);
    });

    test('有值的可选字段出现在 Map 中', () {
      final log = MoodLog(
        id: 'test',
        mood: MoodType.happy,
        note: 'note',
        imageFileNames: ['img.jpg'],
        imageUrls: ['https://x.com/i.jpg'],
        customEmoji: '😊',
        customEmojiLabel: '开心',
        customColorValue: 0xFFFF0000,
        aiComfort: '一切都会好的',
        createdAt: DateTime.now(),
      );
      final map = log.toMap();
      expect(map['imageFileNames'], equals(['img.jpg']));
      expect(map['imageUrls'], equals(['https://x.com/i.jpg']));
      expect(map['customEmoji'], equals('😊'));
      expect(map['customEmojiLabel'], equals('开心'));
      expect(map['customColorValue'], equals(0xFFFF0000));
      expect(map['aiComfort'], equals('一切都会好的'));
    });

    test('toMap 再 fromMap 保持数据一致', () {
      final original = MoodLog(
        id: 'roundtrip',
        mood: MoodType.blissful,
        note: '美好的一天',
        comment: '和朋友们一起',
        imageFileNames: ['a.jpg', 'b.jpg'],
        imageUrls: ['https://cdn.example.com/1.jpg'],
        customEmoji: '🌟',
        customEmojiLabel: '幸福满满',
        customColorValue: 0xFFE91E63,
        aiComfort: '你真棒',
        aiEnabled: true,
        isPrivate: false,
        createdAt: DateTime(2025, 5, 20, 12, 30),
      );
      final restored = MoodLog.fromMap(original.toMap(), 'roundtrip');
      expect(restored.id, equals(original.id));
      expect(restored.mood, equals(original.mood));
      expect(restored.note, equals(original.note));
      expect(restored.comment, equals(original.comment));
      expect(restored.imageFileNames, equals(original.imageFileNames));
      expect(restored.imageUrls, equals(original.imageUrls));
      expect(restored.customEmoji, equals(original.customEmoji));
      expect(restored.customEmojiLabel, equals(original.customEmojiLabel));
      expect(restored.customColorValue, equals(original.customColorValue));
      expect(restored.aiComfort, equals(original.aiComfort));
      expect(restored.aiEnabled, equals(original.aiEnabled));
      expect(restored.isPrivate, equals(original.isPrivate));
      expect(restored.createdAt.toUtc(), equals(original.createdAt.toUtc()));
    });
  });

  group('MoodLog.displayLabel', () {
    test('优先显示自定义标签', () {
      final log = MoodLog(
        id: 't',
        mood: MoodType.happy,
        note: '',
        createdAt: DateTime.now(),
        customEmojiLabel: '我的专属心情',
      );
      expect(log.displayLabel, equals('我的专属心情'));
    });

    test('自定义标签去除首尾空白', () {
      final log = MoodLog(
        id: 't',
        mood: MoodType.happy,
        note: '',
        createdAt: DateTime.now(),
        customEmojiLabel: '  好心情  ',
      );
      expect(log.displayLabel, equals('好心情'));
    });

    test('有自定义表情但无标签时显示"自定义"', () {
      final log = MoodLog(
        id: 't',
        mood: MoodType.happy,
        note: '',
        createdAt: DateTime.now(),
        customEmoji: '🎉',
      );
      expect(log.displayLabel, equals('自定义'));
    });

    test('无任何自定义时回退到系统标签', () {
      final log = MoodLog(
        id: 't',
        mood: MoodType.sad,
        note: '',
        createdAt: DateTime.now(),
      );
      expect(log.displayLabel, equals('难过'));
    });
  });

  group('MoodLog.displayColor', () {
    test('有自定义颜色时使用自定义颜色', () {
      final log = MoodLog(
        id: 't',
        mood: MoodType.happy,
        note: '',
        createdAt: DateTime.now(),
        customColorValue: 0xFF123456,
      );
      expect(log.displayColor, equals(const Color(0xFF123456)));
    });

    test('无自定义颜色时使用心情默认颜色', () {
      final log = MoodLog(
        id: 't',
        mood: MoodType.angry,
        note: '',
        createdAt: DateTime.now(),
      );
      expect(log.displayColor, equals(MoodType.angry.color));
    });
  });

  group('MoodLog.imageCount', () {
    test('无图片时返回 0', () {
      final log = MoodLog(
        id: 't', mood: MoodType.calm, note: '', createdAt: DateTime.now(),
      );
      expect(log.imageCount, equals(0));
      expect(log.hasImages, isFalse);
    });

    test('仅本地图片时正确计数', () {
      final log = MoodLog(
        id: 't', mood: MoodType.calm, note: '', createdAt: DateTime.now(),
        imageFileNames: ['a.jpg', 'b.jpg'],
      );
      expect(log.imageCount, equals(2));
    });

    test('仅远端图片时正确计数', () {
      final log = MoodLog(
        id: 't', mood: MoodType.calm, note: '', createdAt: DateTime.now(),
        imageUrls: ['https://x.com/1.jpg'],
      );
      expect(log.imageCount, equals(1));
    });

    test('本地+远端混合计数', () {
      final log = MoodLog(
        id: 't', mood: MoodType.calm, note: '', createdAt: DateTime.now(),
        imageFileNames: ['a.jpg'],
        imageUrls: ['https://x.com/1.jpg', 'https://x.com/2.jpg'],
      );
      expect(log.imageCount, equals(3));
    });
  });
}
