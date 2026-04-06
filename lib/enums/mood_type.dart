import 'package:flutter/material.dart';

enum MoodType {
  happy,
  calm,
  sad,
  anxious,
  angry,
  blissful,
  fear,
  surprise,
  disgust,
}

extension MoodExtension on MoodType {
  String get label {
    switch (this) {
      case MoodType.happy:
        return '开心';
      case MoodType.calm:
        return '平静';
      case MoodType.sad:
        return '难过';
      case MoodType.anxious:
        return '焦虑';
      case MoodType.angry:
        return '生气';
      case MoodType.blissful:
        return '幸福';
      case MoodType.fear:
        return '恐惧';
      case MoodType.surprise:
        return '惊讶';
      case MoodType.disgust:
        return '厌恶';
    }
  }

  IconData get icon {
    switch (this) {
      case MoodType.happy:
        return Icons.sentiment_satisfied;
      case MoodType.calm:
        return Icons.sentiment_neutral;
      case MoodType.sad:
        return Icons.sentiment_dissatisfied;
      case MoodType.anxious:
        return Icons.sentiment_very_dissatisfied;
      case MoodType.angry:
        return Icons.sentiment_very_dissatisfied;
      case MoodType.blissful:
        return Icons.sentiment_very_satisfied;
      case MoodType.fear:
        return Icons.warning; // ⚠️ 恐惧/危险
      case MoodType.surprise:
        return Icons.sentiment_satisfied_alt; // 😲 张嘴惊讶状
      case MoodType.disgust:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  static final Map<MoodType, Color> _colors = {
    MoodType.happy: Colors.pink,
    MoodType.calm: Colors.teal,
    MoodType.sad: Colors.blue,
    MoodType.anxious: Colors.purple,
    MoodType.angry: Colors.red,
    MoodType.blissful: Colors.deepOrangeAccent,
    MoodType.fear: Colors.indigo, // 恐惧：靛蓝色 (深沉、压抑的感觉) 或者 Colors.blueGrey
    MoodType.surprise: Colors.amber, // 惊讶：琥珀色/金黄色 (像灯泡亮起或震惊的金光)
    MoodType.disgust: Colors.lime, // 厌恶：黄绿色 (这种颜色通常让人联想到变质食物或恶心感)
  };

  static final Map<MoodType, Color> _bgColors = {
    MoodType.happy: Colors.pink.withValues(alpha: 0.15),
    MoodType.calm: Colors.teal.withValues(alpha: 0.15),
    MoodType.sad: Colors.blue.withValues(alpha: 0.15),
    MoodType.anxious: Colors.purple.withValues(alpha: 0.15),
    MoodType.angry: Colors.red.withValues(alpha: 0.15),
    MoodType.blissful: Colors.deepOrangeAccent.withValues(alpha: 0.15),
    MoodType.fear: Colors.indigo.withValues(
      alpha: 0.15,
    ), // 恐惧：靛蓝色 (深沉、压抑的感觉) 或者 Colors.blueGrey
    MoodType.surprise: Colors.amber.withValues(
      alpha: 0.15,
    ), // 惊讶：琥珀色/金黄色 (像灯泡亮起或震惊的金光)
    MoodType.disgust: Colors.lime.withValues(
      alpha: 0.15,
    ), // 厌恶：黄绿色 (这种颜色通常让人联想到变质食物或恶心感)
  };

  Color get color => _colors[this]!;
  Color get bgColor => _bgColors[this]!;

  /// 心情分数 (1-10分，越高越积极)
  int get score {
    switch (this) {
      case MoodType.blissful:
        return 10; // 幸福
      case MoodType.happy:
        return 8; // 开心
      case MoodType.calm:
        return 7; // 平静
      case MoodType.surprise:
        return 6; // 惊讶
      case MoodType.anxious:
        return 4; // 焦虑
      case MoodType.sad:
        return 3; // 难过
      case MoodType.fear:
        return 2; // 恐惧
      case MoodType.angry:
        return 2; // 生气
      case MoodType.disgust:
        return 1; // 厌恶
    }
  }
}
