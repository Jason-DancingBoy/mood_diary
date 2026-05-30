import 'package:flutter/material.dart';
import '../enums/mood_type.dart';

class MoodLog {
  final String id;
  final MoodType mood;
  final String note;
  final String comment;
  final List<String>? imageFileNames; // 本地图片文件名
  final List<String>? imageUrls; // 远端图片 URL（从云端恢复时使用）
  final String? voiceFilePath; // 本地录音文件路径
  final String? voiceUrl; // 远端录音 URL
  final int? voiceDuration; // 录音时长（秒）
  final String? customEmoji;
  final String? customEmojiLabel;
  final int? customColorValue;
  final DateTime createdAt;
  final String? aiComfort;
  final bool aiEnabled;
  final bool isPrivate;
  final double? energy;
  final double? pleasantness;
  final String? emotionWord;
  final String? quadrant;

  // 兼容旧版本：获取第一张图片
  String? get imageFileName => imageFileNames?.isNotEmpty == true ? imageFileNames!.first : null;
  // 获取所有可显示的图片数量（本地 + 远端）
  int get imageCount => (imageFileNames?.length ?? 0) + (imageUrls?.length ?? 0);
  // 是否有任何图片
  bool get hasImages => imageCount > 0;
  bool get hasVoice => voiceFilePath != null || voiceUrl != null;

  MoodLog({
    required this.id,
    required this.mood,
    required this.note,
    this.comment = '',
    this.imageFileNames,
    this.imageUrls,
    this.voiceFilePath,
    this.voiceUrl,
    this.voiceDuration,
    this.customEmoji,
    this.customEmojiLabel,
    this.customColorValue,
    required this.createdAt,
    this.aiComfort,
    this.aiEnabled = true,
    this.isPrivate = false,
    this.energy,
    this.pleasantness,
    this.emotionWord,
    this.quadrant,
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

    List<String>? imageUrls;
    if (map['imageUrls'] != null) {
      imageUrls = List<String>.from(map['imageUrls'] as List);
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
      imageUrls: imageUrls,
      voiceFilePath: map['voiceFilePath'] as String?,
      voiceUrl: map['voiceUrl'] as String?,
      voiceDuration: map['voiceDuration'] as int?,
      customEmoji: map['customEmoji'] as String?,
      customEmojiLabel: map['customEmojiLabel'] as String?,
      customColorValue: map['customColorValue'] as int?,
      createdAt: (map['createdAt'] as DateTime).toLocal(),
      aiComfort: map['aiComfort'] as String?,
      aiEnabled: (map['aiEnabled'] as bool?) ?? true,
      isPrivate: (map['isPrivate'] as bool?) ?? false,
      energy: (map['energy'] as num?)?.toDouble(),
      pleasantness: (map['pleasantness'] as num?)?.toDouble(),
      emotionWord: map['emotionWord'] as String?,
      quadrant: map['quadrant'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mood': mood.name,
      'note': note,
      'comment': comment,
      if (imageFileNames != null && imageFileNames!.isNotEmpty) 'imageFileNames': imageFileNames,
      if (imageUrls != null && imageUrls!.isNotEmpty) 'imageUrls': imageUrls,
      if (voiceFilePath != null) 'voiceFilePath': voiceFilePath,
      if (voiceUrl != null) 'voiceUrl': voiceUrl,
      if (voiceDuration != null) 'voiceDuration': voiceDuration,
      if (customEmoji != null) 'customEmoji': customEmoji,
      if (customEmojiLabel != null) 'customEmojiLabel': customEmojiLabel,
      if (customColorValue != null) 'customColorValue': customColorValue,
      'createdAt': createdAt.toUtc(),
      if (aiComfort != null) 'aiComfort': aiComfort,
      'aiEnabled': aiEnabled,
      'isPrivate': isPrivate,
      if (energy != null) 'energy': energy,
      if (pleasantness != null) 'pleasantness': pleasantness,
      if (emotionWord != null) 'emotionWord': emotionWord,
      if (quadrant != null) 'quadrant': quadrant,
    };
  }

  Color? get customColor => customColorValue != null ? Color(customColorValue!) : null;
  String get displayLabel {
    if (customEmojiLabel != null && customEmojiLabel!.trim().isNotEmpty) {
      return customEmojiLabel!.trim();
    }
    if (customEmoji != null) {
      return '自定义';
    }
    if (emotionWord != null && emotionWord!.isNotEmpty) {
      return emotionWord!;
    }
    return mood.label;
  }
  Color get displayColor => customColor ?? mood.color;

  double get effectiveEnergy => energy ?? mood.toMoodMeterEnergy();
  double get effectivePleasantness => pleasantness ?? mood.toMoodMeterPleasantness();
  String get effectiveEmotionWord => (emotionWord != null && emotionWord!.isNotEmpty) ? emotionWord! : mood.label;
  String get effectiveQuadrant {
    if (quadrant != null) return quadrant!;
    if (effectiveEnergy >= 0 && effectivePleasantness >= 0) return 'yellow';
    if (effectiveEnergy >= 0 && effectivePleasantness < 0) return 'red';
    if (effectiveEnergy < 0 && effectivePleasantness >= 0) return 'green';
    return 'blue';
  }
}