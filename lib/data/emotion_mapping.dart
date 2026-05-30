import 'dart:math';

class EmotionEntry {
  final String chinese;
  final double energy;
  final double pleasantness;
  final String quadrant;
  final int displayPriority;

  const EmotionEntry({
    required this.chinese,
    required this.energy,
    required this.pleasantness,
    required this.quadrant,
    this.displayPriority = 0,
  });

  double distanceTo(double e, double p) {
    return sqrt(pow(energy - e, 2) + pow(pleasantness - p, 2));
  }
}

const List<EmotionEntry> emotionEntries = [
  // ========== Red Quadrant: High Energy, Unpleasant ==========
  EmotionEntry(chinese: '愤怒', energy: 0.8, pleasantness: -0.8, quadrant: 'red', displayPriority: 10),
  EmotionEntry(chinese: '暴怒', energy: 0.95, pleasantness: -0.9, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '恼火', energy: 0.6, pleasantness: -0.5, quadrant: 'red', displayPriority: 8),
  EmotionEntry(chinese: '烦躁', energy: 0.5, pleasantness: -0.4, quadrant: 'red', displayPriority: 9),
  EmotionEntry(chinese: '焦虑', energy: 0.7, pleasantness: -0.7, quadrant: 'red', displayPriority: 10),
  EmotionEntry(chinese: '紧张', energy: 0.6, pleasantness: -0.5, quadrant: 'red', displayPriority: 8),
  EmotionEntry(chinese: '恐慌', energy: 0.9, pleasantness: -0.8, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '恐惧', energy: 0.8, pleasantness: -0.9, quadrant: 'red', displayPriority: 8),
  EmotionEntry(chinese: '害怕', energy: 0.7, pleasantness: -0.8, quadrant: 'red', displayPriority: 7),
  EmotionEntry(chinese: '惊吓', energy: 0.95, pleasantness: -0.85, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '惊慌', energy: 0.9, pleasantness: -0.75, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '嫉妒', energy: 0.5, pleasantness: -0.6, quadrant: 'red', displayPriority: 6),
  EmotionEntry(chinese: '憎恨', energy: 0.8, pleasantness: -0.9, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '不公平', energy: 0.6, pleasantness: -0.7, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '压力', energy: 0.6, pleasantness: -0.4, quadrant: 'red', displayPriority: 9),
  EmotionEntry(chinese: '崩溃', energy: 0.7, pleasantness: -0.95, quadrant: 'red', displayPriority: 6),
  EmotionEntry(chinese: '抗拒', energy: 0.3, pleasantness: -0.5, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '反感', energy: 0.4, pleasantness: -0.7, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '不满', energy: 0.3, pleasantness: -0.4, quadrant: 'red', displayPriority: 6),
  EmotionEntry(chinese: '恼怒', energy: 0.7, pleasantness: -0.6, quadrant: 'red', displayPriority: 7),
  EmotionEntry(chinese: '激动(负面)', energy: 0.8, pleasantness: -0.5, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '冲动', energy: 0.7, pleasantness: -0.3, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '受挫', energy: 0.4, pleasantness: -0.6, quadrant: 'red', displayPriority: 7),
  EmotionEntry(chinese: '被冒犯', energy: 0.6, pleasantness: -0.7, quadrant: 'red', displayPriority: 4),
  EmotionEntry(chinese: '愤慨', energy: 0.75, pleasantness: -0.75, quadrant: 'red', displayPriority: 5),
  EmotionEntry(chinese: '敌意', energy: 0.7, pleasantness: -0.8, quadrant: 'red', displayPriority: 3),
  EmotionEntry(chinese: '抓狂', energy: 0.85, pleasantness: -0.6, quadrant: 'red', displayPriority: 6),
  EmotionEntry(chinese: '坐立不安', energy: 0.55, pleasantness: -0.45, quadrant: 'red', displayPriority: 5),

  // ========== Yellow Quadrant: High Energy, Pleasant ==========
  EmotionEntry(chinese: '快乐', energy: 0.7, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 10),
  EmotionEntry(chinese: '兴奋', energy: 0.9, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 9),
  EmotionEntry(chinese: '激动', energy: 0.85, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '狂喜', energy: 0.95, pleasantness: 0.9, quadrant: 'yellow', displayPriority: 5),
  EmotionEntry(chinese: '幸福', energy: 0.5, pleasantness: 0.9, quadrant: 'yellow', displayPriority: 10),
  EmotionEntry(chinese: '欢喜', energy: 0.6, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '自豪', energy: 0.6, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '骄傲', energy: 0.5, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '乐观', energy: 0.4, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '希望', energy: 0.3, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '渴望', energy: 0.7, pleasantness: 0.5, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '期待', energy: 0.5, pleasantness: 0.5, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '热爱', energy: 0.7, pleasantness: 0.9, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '惊喜', energy: 0.8, pleasantness: 0.5, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '精力充沛', energy: 0.8, pleasantness: 0.4, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '活跃', energy: 0.6, pleasantness: 0.4, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '开心', energy: 0.5, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 9),
  EmotionEntry(chinese: '欢快', energy: 0.7, pleasantness: 0.75, quadrant: 'yellow', displayPriority: 7),
  EmotionEntry(chinese: '满足', energy: 0.3, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 8),
  EmotionEntry(chinese: '热情', energy: 0.75, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '兴高采烈', energy: 0.85, pleasantness: 0.85, quadrant: 'yellow', displayPriority: 5),
  EmotionEntry(chinese: '得意', energy: 0.5, pleasantness: 0.65, quadrant: 'yellow', displayPriority: 5),
  EmotionEntry(chinese: '感激', energy: 0.2, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '有动力', energy: 0.6, pleasantness: 0.55, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '受鼓舞', energy: 0.55, pleasantness: 0.7, quadrant: 'yellow', displayPriority: 6),
  EmotionEntry(chinese: '雀跃', energy: 0.8, pleasantness: 0.8, quadrant: 'yellow', displayPriority: 5),
  EmotionEntry(chinese: '兴致勃勃', energy: 0.65, pleasantness: 0.6, quadrant: 'yellow', displayPriority: 5),

  // ========== Blue Quadrant: Low Energy, Unpleasant ==========
  EmotionEntry(chinese: '悲伤', energy: -0.6, pleasantness: -0.7, quadrant: 'blue', displayPriority: 10),
  EmotionEntry(chinese: '伤心', energy: -0.5, pleasantness: -0.7, quadrant: 'blue', displayPriority: 9),
  EmotionEntry(chinese: '忧郁', energy: -0.6, pleasantness: -0.5, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '抑郁', energy: -0.7, pleasantness: -0.8, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '沮丧', energy: -0.4, pleasantness: -0.6, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '失落', energy: -0.5, pleasantness: -0.5, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '失望', energy: -0.3, pleasantness: -0.6, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '绝望', energy: -0.8, pleasantness: -0.9, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '无助', energy: -0.7, pleasantness: -0.7, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '无力', energy: -0.8, pleasantness: -0.5, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '孤独', energy: -0.6, pleasantness: -0.6, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '寂寞', energy: -0.5, pleasantness: -0.5, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '思念', energy: -0.3, pleasantness: -0.2, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '内疚', energy: -0.4, pleasantness: -0.6, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '羞愧', energy: -0.5, pleasantness: -0.7, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '懊悔', energy: -0.4, pleasantness: -0.5, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '后悔', energy: -0.4, pleasantness: -0.55, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '厌倦', energy: -0.5, pleasantness: -0.5, quadrant: 'blue', displayPriority: 5),
  EmotionEntry(chinese: '疲惫', energy: -0.7, pleasantness: -0.3, quadrant: 'blue', displayPriority: 8),
  EmotionEntry(chinese: '疲倦', energy: -0.8, pleasantness: -0.2, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '无聊', energy: -0.4, pleasantness: -0.3, quadrant: 'blue', displayPriority: 7),
  EmotionEntry(chinese: '冷漠', energy: -0.7, pleasantness: -0.6, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '麻木', energy: -0.7, pleasantness: -0.4, quadrant: 'blue', displayPriority: 5),
  EmotionEntry(chinese: '空虚', energy: -0.5, pleasantness: -0.6, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '消沉', energy: -0.6, pleasantness: -0.55, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '自卑', energy: -0.5, pleasantness: -0.7, quadrant: 'blue', displayPriority: 5),
  EmotionEntry(chinese: '委屈', energy: -0.3, pleasantness: -0.6, quadrant: 'blue', displayPriority: 6),
  EmotionEntry(chinese: '心碎', energy: -0.6, pleasantness: -0.85, quadrant: 'blue', displayPriority: 5),

  // ========== Green Quadrant: Low Energy, Pleasant ==========
  EmotionEntry(chinese: '平静', energy: -0.5, pleasantness: 0.5, quadrant: 'green', displayPriority: 10),
  EmotionEntry(chinese: '安宁', energy: -0.6, pleasantness: 0.6, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '宁静', energy: -0.7, pleasantness: 0.5, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '平和', energy: -0.4, pleasantness: 0.6, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '从容', energy: -0.3, pleasantness: 0.4, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '淡定', energy: -0.5, pleasantness: 0.3, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '放松', energy: -0.4, pleasantness: 0.5, quadrant: 'green', displayPriority: 9),
  EmotionEntry(chinese: '舒缓', energy: -0.6, pleasantness: 0.4, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '舒适', energy: -0.3, pleasantness: 0.7, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '惬意', energy: -0.2, pleasantness: 0.8, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '自在', energy: -0.2, pleasantness: 0.6, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '悠闲', energy: -0.5, pleasantness: 0.7, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '满足', energy: -0.3, pleasantness: 0.8, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '感恩', energy: -0.2, pleasantness: 0.7, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '感动', energy: 0.0, pleasantness: 0.8, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '温馨', energy: -0.3, pleasantness: 0.8, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '温暖', energy: -0.1, pleasantness: 0.7, quadrant: 'green', displayPriority: 7),
  EmotionEntry(chinese: '安心', energy: -0.4, pleasantness: 0.6, quadrant: 'green', displayPriority: 8),
  EmotionEntry(chinese: '安全', energy: -0.5, pleasantness: 0.5, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '信任', energy: -0.3, pleasantness: 0.5, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '尊重', energy: -0.2, pleasantness: 0.4, quadrant: 'green', displayPriority: 5),
  EmotionEntry(chinese: '欣赏', energy: -0.1, pleasantness: 0.6, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '敬佩', energy: 0.0, pleasantness: 0.7, quadrant: 'green', displayPriority: 5),
  EmotionEntry(chinese: '敬畏', energy: -0.2, pleasantness: 0.5, quadrant: 'green', displayPriority: 4),
  EmotionEntry(chinese: '同情', energy: -0.5, pleasantness: 0.3, quadrant: 'green', displayPriority: 5),
  EmotionEntry(chinese: '满足感', energy: -0.3, pleasantness: 0.7, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '释然', energy: -0.4, pleasantness: 0.5, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '踏实', energy: -0.4, pleasantness: 0.6, quadrant: 'green', displayPriority: 6),
  EmotionEntry(chinese: '充实', energy: -0.2, pleasantness: 0.5, quadrant: 'green', displayPriority: 6),
];

EmotionEntry findNearestEmotion(double energy, double pleasantness) {
  EmotionEntry nearest = emotionEntries.first;
  double minDist = nearest.distanceTo(energy, pleasantness);
  for (final entry in emotionEntries) {
    final dist = entry.distanceTo(energy, pleasantness);
    if (dist < minDist) {
      minDist = dist;
      nearest = entry;
    }
  }
  return nearest;
}

List<EmotionEntry> getEmotionsByQuadrant(String quadrant) {
  return emotionEntries.where((e) => e.quadrant == quadrant).toList();
}

List<EmotionEntry> getDisplayEmotions({int limit = 30}) {
  final sorted = List<EmotionEntry>.from(emotionEntries)
    ..sort((a, b) => b.displayPriority.compareTo(a.displayPriority));
  return sorted.take(limit).toList();
}

List<EmotionEntry> getNearbyEmotions(double energy, double pleasantness, {int count = 6}) {
  final sorted = List<EmotionEntry>.from(emotionEntries)
    ..sort((a, b) => a.distanceTo(energy, pleasantness).compareTo(b.distanceTo(energy, pleasantness)));
  return sorted.take(count).toList();
}
