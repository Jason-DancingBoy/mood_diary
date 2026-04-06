import 'package:flutter/material.dart';
import '../enums/mood_type.dart';

class MoodLog {
  final String id;
  final MoodType mood;
  final String note;
  final String comment;
  final List<String>? imageFileNames; // 支持多图片
  final String? customEmoji;
  final String? customEmojiLabel;
  final int? customColorValue;
  final DateTime createdAt;
  final String? aiComfort;
  final bool aiEnabled;

  // 兼容旧版本：获取第一张图片
  String? get imageFileName => imageFileNames?.isNotEmpty == true ? imageFileNames!.first : null;
  // 获取图片数量
  int get imageCount => imageFileNames?.length ?? 0;

  MoodLog({
    required this.id,
    required this.mood,
    required this.note,
    this.comment = '',
    this.imageFileNames,
    this.customEmoji,
    this.customEmojiLabel,
    this.customColorValue,
    required this.createdAt,
    this.aiComfort,
    this.aiEnabled = true,
  });

  factory MoodLog.fromMap(Map<dynamic, dynamic> map, String key) {
    // 兼容旧版本：处理单图片或多图片
    List<String>? imageFileNames;
    if (map['imageFileNames'] != null) {
      imageFileNames = List<String>.from(map['imageFileNames'] as List);
    } else if (map['imageFileName'] != null) {
      // 旧版本单图片，转换为多图片
      imageFileNames = [map['imageFileName'] as String];
    }

    return MoodLog(
      id: key,
      mood: MoodType.values.firstWhere(
        (e) => e.name == map['mood'],
        orElse: () => MoodType.calm,
      ),
      note: map['note'] as String,
      comment: (map['comment'] as String?) ?? '',
      imageFileNames: imageFileNames,
      customEmoji: map['customEmoji'] as String?,
      customEmojiLabel: map['customEmojiLabel'] as String?,
      customColorValue: map['customColorValue'] as int?,
      createdAt: (map['createdAt'] as DateTime).toLocal(),
      aiComfort: map['aiComfort'] as String?,
      aiEnabled: (map['aiEnabled'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mood': mood.name,
      'note': note,
      'comment': comment,
      if (imageFileNames != null && imageFileNames!.isNotEmpty) 'imageFileNames': imageFileNames,
      if (customEmoji != null) 'customEmoji': customEmoji,
      if (customEmojiLabel != null) 'customEmojiLabel': customEmojiLabel,
      if (customColorValue != null) 'customColorValue': customColorValue,
      'createdAt': createdAt.toUtc(),
      if (aiComfort != null) 'aiComfort': aiComfort,
      'aiEnabled': aiEnabled,
    };
  }

  Color? get customColor => customColorValue != null ? Color(customColorValue!) : null;
  String get displayLabel {
    // 优先级：自定义标签 > 系统心情标签
    if (customEmojiLabel != null && customEmojiLabel!.trim().isNotEmpty) {
      return customEmojiLabel!.trim();
    }
    return mood.label;
  }
  Color get displayColor => customColor ?? mood.color;
}