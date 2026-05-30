import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mood_diary/enums/mood_type.dart';

void main() {
  group('MoodType', () {
    test('所有心情标签唯一', () {
      final labels = MoodType.values.map((e) => e.label).toList();
      expect(labels.toSet().length, equals(labels.length),
          reason: '每种心情的 label 不应重复：$labels');
    });

    test('所有心情颜色唯一', () {
      final colorValues = MoodType.values.map((e) => e.color.value).toList();
      expect(colorValues.toSet().length, equals(colorValues.length),
          reason: '每种心情的 color 不应重复');
    });

    test('所有心情背景色唯一', () {
      final bgColorValues = MoodType.values.map((e) => e.bgColor.value).toList();
      expect(bgColorValues.toSet().length, equals(bgColorValues.length),
          reason: '每种心情的 bgColor 不应重复');
    });

    test('score 范围在 1-10', () {
      for (final m in MoodType.values) {
        expect(m.score, inInclusiveRange(1, 10),
            reason: '${m.name}.score 应为 1-10，实际为 ${m.score}');
      }
    });

    test('正面情绪 score ≥ 6', () {
      const positive = [
        MoodType.blissful,
        MoodType.happy,
        MoodType.calm,
        MoodType.surprise,
      ];
      for (final m in positive) {
        expect(m.score, greaterThanOrEqualTo(6),
            reason: '${m.name} 是正面情绪，score 应 ≥ 6，实际为 ${m.score}');
      }
    });

    test('负面情绪 score ≤ 4', () {
      const negative = [
        MoodType.sad,
        MoodType.anxious,
        MoodType.guilty,
        MoodType.angry,
        MoodType.fear,
        MoodType.disgust,
      ];
      for (final m in negative) {
        expect(m.score, lessThanOrEqualTo(4),
            reason: '${m.name} 是负面情绪，score 应 ≤ 4，实际为 ${m.score}');
      }
    });

    test('每种心情有非空 icon', () {
      for (final m in MoodType.values) {
        expect(m.icon, isNotNull);
        expect(m.icon, isA<IconData>());
      }
    });

    test('MoodType.values 长度为 10', () {
      expect(MoodType.values.length, equals(10),
          reason: '新增或删除心情类型时需确认测试覆盖是否仍需更新');
    });
  });
}
