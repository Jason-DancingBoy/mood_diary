import 'package:flutter_test/flutter_test.dart';
import 'package:mood_diary/models/chat_message.dart';

void main() {
  group('ChatMessage.fromList 版本兼容', () {
    // V1 格式：仅 3 字段 [isUser, content, timestamp]
    test('V1 格式 (3 字段) 正确解析', () {
      final list = [
        true,
        'hello',
        '2025-05-20T10:00:00.000Z',
      ];
      final msg = ChatMessage.fromList(list);
      expect(msg.isUser, isTrue);
      expect(msg.content, equals('hello'));
      expect(msg.timestamp, equals(DateTime.parse('2025-05-20T10:00:00.000Z')));
      expect(msg.id, isNull);
      expect(msg.senderName, isNull);
      expect(msg.imageUrl, isNull);
      expect(msg.audioUrl, isNull);
      expect(msg.audioDuration, isNull);
      expect(msg.showSenderHeader, isFalse);
      expect(msg.senderEmoji, isNull);
      expect(msg.senderAvatarAssetPath, isNull);
      expect(msg.isAiMessage, isFalse);
    });

    // V1.5 (4-7 字段) - 过渡格式
    test('V1 旧版兼容 senderName (4 字段)', () {
      final list = [
        false,
        'hi',
        '2025-05-20T10:00:00.000Z',
        '小明',
      ];
      final msg = ChatMessage.fromList(list);
      expect(msg.senderName, equals('小明'));
    });

    test('V1 旧版兼容 imageUrl (5 字段)', () {
      final list = [
        false,
        'hi',
        '2025-05-20T10:00:00.000Z',
        '小明',
        'https://example.com/img.jpg',
      ];
      final msg = ChatMessage.fromList(list);
      expect(msg.senderName, equals('小明'));
      expect(msg.imageUrl, equals('https://example.com/img.jpg'));
    });

    // V2 格式：8 字段 [isUser, content, timestamp, id, senderName, imageUrl, audioUrl, audioDuration]
    test('V2 格式 (8 字段) 正确解析', () {
      final list = [
        false,
        '你好',
        '2025-05-20T10:00:00.000Z',
        'msg_001',
        '小红',
        'https://x.com/pic.jpg',
        '',
        0,
      ];
      final msg = ChatMessage.fromList(list);
      expect(msg.id, equals('msg_001'));
      expect(msg.senderName, equals('小红'));
      expect(msg.imageUrl, equals('https://x.com/pic.jpg'));
      expect(msg.audioUrl, isNull);
      expect(msg.audioDuration, isNull);
      expect(msg.showSenderHeader, isFalse);
      expect(msg.senderEmoji, isNull);
    });

    // V3 格式：9 字段，第 9 个是 showSenderHeader
    test('V3 格式 (9 字段) 新增 showSenderHeader', () {
      final list = [
        false, 'hi', '2025-05-20T10:00:00.000Z', '', '', '', '', 0,
        true,
      ];
      final msg = ChatMessage.fromList(list);
      expect(msg.showSenderHeader, isTrue);
      expect(msg.senderEmoji, isNull);
      expect(msg.senderAvatarAssetPath, isNull);
    });

    // V3.5 格式：11 字段，含 senderEmoji, senderAvatarAssetPath
    test('V3 格式 (11 字段) 含 senderEmoji 和 senderAvatarAssetPath', () {
      final list = [
        false, 'hi', '2025-05-20T10:00:00.000Z', '', '', '', '', 0,
        true,
        '😊',
        'assets/carrot.jpg',
      ];
      final msg = ChatMessage.fromList(list);
      expect(msg.showSenderHeader, isTrue);
      expect(msg.senderEmoji, equals('😊'));
      expect(msg.senderAvatarAssetPath, equals('assets/carrot.jpg'));
      expect(msg.isAiMessage, isFalse);
    });

    // V4 格式：12 字段，新增 isAiMessage
    test('V4 格式 (12 字段) 新增 isAiMessage', () {
      final list = [
        false,
        'AI 生成的回复',
        '2025-05-20T10:00:00.000Z',
        '',
        '',
        '',
        '',
        0,
        false,
        '',
        '',
        true,
      ];
      final msg = ChatMessage.fromList(list);
      expect(msg.isAiMessage, isTrue);
    });

    test('V4 格式完整字段：含语音消息 + AI 标记', () {
      final list = [
        false,
        '语音回复内容',
        '2025-05-20T10:00:00.000Z',
        'voice_msg_01',
        '小暖',
        '',
        'https://cdn.example.com/voice.mp3',
        30,
        false,
        '🥕',
        'assets/carrot.jpg',
        true,
      ];
      final msg = ChatMessage.fromList(list);
      expect(msg.id, equals('voice_msg_01'));
      expect(msg.senderName, equals('小暖'));
      expect(msg.audioUrl, equals('https://cdn.example.com/voice.mp3'));
      expect(msg.audioDuration, equals(30));
      expect(msg.senderEmoji, equals('🥕'));
      expect(msg.senderAvatarAssetPath, equals('assets/carrot.jpg'));
      expect(msg.isAiMessage, isTrue);
    });
  });

  group('ChatMessage.fromList 边界情况', () {
    test('空字符串 id 视为 null', () {
      final list = [true, 'test', '2025-05-20T10:00:00.000Z', '', '', '', '', 0];
      final msg = ChatMessage.fromList(list);
      expect(msg.id, isNull);
    });

    test('空字符串 audioUrl 视为 null', () {
      final list = [true, 'test', '2025-05-20T10:00:00.000Z', '', '', '', '', 0];
      final msg = ChatMessage.fromList(list);
      expect(msg.audioUrl, isNull);
    });

    test('audioDuration 为 0 时视为 null (V2 格式)', () {
      final list = [true, 'test', '2025-05-20T10:00:00.000Z', '', '', 'https://x.com/v.mp3', 0];
      final msg = ChatMessage.fromList(list);
      // 7 字段走 V1 旧路径：audioDuration 是 list[6]，为 0 不自动转 null
      expect(msg.audioDuration, equals(0));
      // V2 路径 (8 字段) 才做 0→null 转换
      final v2list = [true, 'test', '2025-05-20T10:00:00.000Z', '', '', '', 'https://x.com/v.mp3', 0];
      final v2msg = ChatMessage.fromList(v2list);
      expect(v2msg.audioDuration, isNull);
    });
  });

  group('ChatMessage.toList ↔ fromList 互逆', () {
    test('完整字段 roundtrip', () {
      final original = ChatMessage(
        isUser: false,
        id: 'abc123',
        content: '这是一条完整的消息',
        imageUrl: 'https://cdn.example.com/photo.jpg',
        audioUrl: 'https://cdn.example.com/voice.mp3',
        audioDuration: 45,
        timestamp: DateTime(2025, 5, 20, 10, 30),
        senderName: '小红',
        showSenderHeader: true,
        senderEmoji: '😊',
        senderAvatarAssetPath: 'assets/carrot.jpg',
        isAiMessage: true,
      );
      final restored = ChatMessage.fromList(original.toList());
      expect(restored.isUser, equals(original.isUser));
      expect(restored.id, equals(original.id));
      expect(restored.content, equals(original.content));
      expect(restored.imageUrl, equals(original.imageUrl));
      expect(restored.audioUrl, equals(original.audioUrl));
      expect(restored.audioDuration, equals(original.audioDuration));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.senderName, equals(original.senderName));
      expect(restored.showSenderHeader, equals(original.showSenderHeader));
      expect(restored.senderEmoji, equals(original.senderEmoji));
      expect(restored.senderAvatarAssetPath, equals(original.senderAvatarAssetPath));
      expect(restored.isAiMessage, equals(original.isAiMessage));
    });

    test('最简字段 roundtrip', () {
      final original = ChatMessage(
        isUser: true,
        content: 'hello',
        timestamp: DateTime.now(),
      );
      final restored = ChatMessage.fromList(original.toList());
      expect(restored.isUser, equals(original.isUser));
      expect(restored.content, equals(original.content));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.id, isNull);
    });

    test('仅含图片的 roundtrip', () {
      final original = ChatMessage(
        isUser: true,
        content: '',
        imageUrl: 'https://x.com/img.jpg',
        timestamp: DateTime.now(),
      );
      final restored = ChatMessage.fromList(original.toList());
      expect(restored.imageUrl, equals('https://x.com/img.jpg'));
      expect(restored.audioUrl, isNull);
    });

    test('仅含语音的 roundtrip', () {
      final original = ChatMessage(
        isUser: true,
        content: '',
        audioUrl: 'https://x.com/voice.mp3',
        audioDuration: 20,
        timestamp: DateTime.now(),
      );
      final restored = ChatMessage.fromList(original.toList());
      expect(restored.audioUrl, equals('https://x.com/voice.mp3'));
      expect(restored.audioDuration, equals(20));
      expect(restored.isVoiceMessage, isTrue);
    });
  });

  group('ChatMessage.fromMap (Supabase 格式)', () {
    test('自己发的消息 isUser=true, senderName=null', () {
      final map = {
        'id': 'm1',
        'sender_id': 'user_123',
        'content': '你好吗',
        'created_at': '2025-05-20T10:00:00.000Z',
      };
      final msg = ChatMessage.fromMap(map, 'user_123');
      expect(msg.isUser, isTrue);
      expect(msg.senderName, isNull);
      expect(msg.id, equals('m1'));
      expect(msg.content, equals('你好吗'));
    });

    test('别人发的消息 isUser=false, senderName 来自 sender_nickname', () {
      final map = {
        'id': 'm2',
        'sender_id': 'other_456',
        'content': '我很好',
        'sender_nickname': '小红',
        'created_at': '2025-05-20T10:01:00.000Z',
      };
      final msg = ChatMessage.fromMap(map, 'user_123');
      expect(msg.isUser, isFalse);
      expect(msg.senderName, equals('小红'));
    });

    test('AI 消息 isAiMessage=true, isUser=false', () {
      final map = {
        'id': 'm3',
        'sender_id': 'user_123',
        'content': 'AI analysis',
        'is_ai_message': true,
        'created_at': '2025-05-20T10:02:00.000Z',
      };
      final msg = ChatMessage.fromMap(map, 'user_123');
      expect(msg.isAiMessage, isTrue);
      expect(msg.isUser, isFalse);
    });

    test('含图片和语音的 fromMap', () {
      final map = {
        'id': 'm4',
        'sender_id': 'other_789',
        'content': '语音消息内容',
        'image_url': 'https://cdn.example.com/photo.jpg',
        'audio_url': 'https://cdn.example.com/voice.mp3',
        'audio_duration': 60,
        'sender_nickname': '小明',
        'created_at': '2025-05-20T10:03:00.000Z',
      };
      final msg = ChatMessage.fromMap(map, 'user_123');
      expect(msg.imageUrl, equals('https://cdn.example.com/photo.jpg'));
      expect(msg.audioUrl, equals('https://cdn.example.com/voice.mp3'));
      expect(msg.audioDuration, equals(60));
      expect(msg.isVoiceMessage, isTrue);
    });

    test('content 为 null 时回退为空字符串', () {
      final map = {
        'sender_id': 'user_123',
        'created_at': '2025-05-20T10:00:00.000Z',
      };
      final msg = ChatMessage.fromMap(map, 'user_123');
      expect(msg.content, equals(''));
    });
  });

  group('ChatMessage.isVoiceMessage', () {
    test('有 audioUrl 时为 true', () {
      final msg = ChatMessage(
        isUser: true,
        content: '语音',
        audioUrl: 'https://x.com/v.mp3',
        timestamp: DateTime.now(),
      );
      expect(msg.isVoiceMessage, isTrue);
    });

    test('无 audioUrl 时为 false', () {
      final msg = ChatMessage(
        isUser: true,
        content: '文字',
        timestamp: DateTime.now(),
      );
      expect(msg.isVoiceMessage, isFalse);
    });
  });
}
