import 'mood_log.dart';

class MoodRecord {
  final String id;
  final String ownerId;
  final String? localId;
  final String moodType;
  final String note;
  final String comment;
  final List<String> imageUrls;
  final String? customEmoji;
  final String? customEmojiLabel;
  final int? customColorValue;
  final String? aiComfort;
  final bool aiEnabled;
  final DateTime createdAt;

  MoodRecord({
    required this.id,
    required this.ownerId,
    this.localId,
    required this.moodType,
    required this.note,
    this.comment = '',
    this.imageUrls = const [],
    this.customEmoji,
    this.customEmojiLabel,
    this.customColorValue,
    this.aiComfort,
    this.aiEnabled = true,
    required this.createdAt,
  });

  factory MoodRecord.fromMap(Map<String, dynamic> map) {
    return MoodRecord(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      localId: map['local_id'] as String?,
      moodType: map['mood_type'] as String,
      note: (map['note'] as String?) ?? '',
      comment: (map['comment'] as String?) ?? '',
      imageUrls: map['image_urls'] != null
          ? List<String>.from(map['image_urls'] as List)
          : <String>[],
      customEmoji: map['custom_emoji'] as String?,
      customEmojiLabel: map['custom_emoji_label'] as String?,
      customColorValue: map['custom_color_value'] as int?,
      aiComfort: map['ai_comfort'] as String?,
      aiEnabled: (map['ai_enabled'] as bool?) ?? true,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'owner_id': ownerId,
      if (localId != null) 'local_id': localId,
      'mood_type': moodType,
      'note': note,
      'comment': comment,
      'image_urls': imageUrls,
      if (customEmoji != null) 'custom_emoji': customEmoji,
      if (customEmojiLabel != null) 'custom_emoji_label': customEmojiLabel,
      if (customColorValue != null) 'custom_color_value': customColorValue,
      if (aiComfort != null) 'ai_comfort': aiComfort,
      'ai_enabled': aiEnabled,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory MoodRecord.fromLocalMoodLog(MoodLog log, String ownerId) {
    return MoodRecord(
      id: '', // Will be set by Supabase on insert
      ownerId: ownerId,
      localId: log.id,
      moodType: log.mood.name,
      note: log.note,
      comment: log.comment,
      imageUrls: const [], // Populated after image upload
      customEmoji: log.customEmoji,
      customEmojiLabel: log.customEmojiLabel,
      customColorValue: log.customColorValue,
      aiComfort: log.aiComfort,
      aiEnabled: log.aiEnabled,
      createdAt: log.createdAt,
    );
  }
}
