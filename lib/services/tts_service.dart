import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class TtsService {
  TtsService._();

  static const String _baseUrl = 'https://openspeech.bytedance.com';

  static String _generateReqId() {
    final r = Random();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return '${bytes[0].toRadixString(16).padLeft(2, '0')}'
        '${bytes[1].toRadixString(16).padLeft(2, '0')}'
        '${bytes[2].toRadixString(16).padLeft(2, '0')}'
        '${bytes[3].toRadixString(16).padLeft(2, '0')}'
        '-${bytes[4].toRadixString(16).padLeft(2, '0')}'
        '${bytes[5].toRadixString(16).padLeft(2, '0')}'
        '-${bytes[6].toRadixString(16).padLeft(2, '0')}'
        '${bytes[7].toRadixString(16).padLeft(2, '0')}'
        '-${bytes[8].toRadixString(16).padLeft(2, '0')}'
        '${bytes[9].toRadixString(16).padLeft(2, '0')}'
        '-${bytes[10].toRadixString(16).padLeft(2, '0')}'
        '${bytes[11].toRadixString(16).padLeft(2, '0')}'
        '${bytes[12].toRadixString(16).padLeft(2, '0')}'
        '${bytes[13].toRadixString(16).padLeft(2, '0')}'
        '${bytes[14].toRadixString(16).padLeft(2, '0')}'
        '${bytes[15].toRadixString(16).padLeft(2, '0')}';
  }

  /// 声音复刻 - 上传音频样本绑定到 speaker_id
  static Future<String?> createReferenceVoice({
    required String audioPath,
    required String apiKey,
    required String speakerId,
  }) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        debugPrint('TTS: 音频文件不存在: $audioPath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final response = await Dio().post(
        '$_baseUrl/api/v3/tts/voice_clone',
        data: {
          'speaker_id': speakerId,
          'audio': {'data': base64Audio, 'format': 'wav'},
          'language': 0,
          'extra_params': {'voice_clone_denoise_model_id': ''},
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Api-Key': apiKey,
            'X-Api-Request-Id': _generateReqId(),
          },
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200) {
        debugPrint('TTS: 声音复刻上传成功 speaker_id=$speakerId');
        return speakerId;
      }

      debugPrint('TTS: 声音复刻失败: ${response.statusCode} ${response.data}');
      return null;
    } on DioException catch (e) {
      debugPrint('TTS: 声音复刻网络错误: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('TTS: 声音复刻错误: $e');
      return null;
    }
  }

  /// 文字转语音（V3 HTTP Chunked 单向流式）
  /// [contextText] 语音指令，用自然语言控制语气/情绪，如 "用温暖、略带开心的语气说话"
  /// [speechRate] 语速 [-50, 100]，100=2倍速，-50=0.5倍速
  /// [pitch] 音调 [-12, 12]
  static Future<String?> textToSpeech({
    required String text,
    required String speakerId,
    required String apiKey,
    String resourceId = 'seed-icl-2.0',
    String? contextText,
    int speechRate = 0,
    int pitch = 0,
  }) async {
    try {
      final audioParams = <String, dynamic>{
        'format': 'mp3',
        'sample_rate': 24000,
      };
      if (speechRate != 0) {
        audioParams['speech_rate'] = speechRate;
      }

      final reqParams = <String, dynamic>{
        'text': text,
        'speaker': speakerId,
        'model': 'seed-tts-2.0-expressive',
        'audio_params': audioParams,
      };

      final additions = <String, dynamic>{};
      if (contextText != null && contextText.isNotEmpty) {
        additions['context_texts'] = [contextText];
      }
      if (pitch != 0) {
        additions['post_process'] = {'pitch': pitch};
      }
      if (additions.isNotEmpty) {
        reqParams['additions'] = jsonEncode(additions);
      }

      debugPrint('TTS: 请求参数 speechRate=$speechRate pitch=$pitch contextText=$contextText');
      debugPrint('TTS: additions=${jsonEncode(additions)}');

      final response = await Dio().post(
        '$_baseUrl/api/v3/tts/unidirectional',
        data: {
          'user': {'uid': 'mood_diary'},
          'req_params': reqParams,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Api-Key': apiKey,
            'X-Api-Resource-Id': resourceId,
            'X-Api-Request-Id': _generateReqId(),
          },
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        debugPrint('TTS: 语音生成失败 HTTP ${response.statusCode}');
        return null;
      }

      final stream = response.data.stream as Stream<List<int>>;
      final audioBytes = <int>[];
      var buffer = '';
      String? errorMsg;

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          try {
            final json = jsonDecode(trimmed);
            final code = json['code'] as int?;
            if (code == 20000000) break;
            if (code != 0 && code != null) {
              errorMsg = json['message'] as String? ?? 'code=$code';
              break;
            }
            final data = json['data'] as String?;
            if (data != null && data.isNotEmpty) {
              audioBytes.addAll(base64Decode(data));
            }
          } catch (_) {
            // skip unparseable lines
          }
        }
        if (errorMsg != null) break;
      }

      if (errorMsg != null) {
        debugPrint('TTS: 语音生成失败: $errorMsg');
        debugPrint('TTS: 完整响应流已结束，audioBytes=${audioBytes.length}');
        return null;
      }

      if (audioBytes.isEmpty) {
        debugPrint('TTS: 未收到音频数据');
        return null;
      }

      final dir = await getTemporaryDirectory();
      final fileName = 'tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
      final filePath = p.join(dir.path, fileName);
      await File(filePath).writeAsBytes(audioBytes);
      debugPrint('TTS: 语音生成成功 size=${audioBytes.length}');
      return filePath;
    } on DioException catch (e) {
      debugPrint('TTS: 网络错误: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('TTS: 错误: $e');
      return null;
    }
  }

  /// 获取音频时长（秒），粗略估算
  static int estimateDuration(String filePath) {
    try {
      final sizeInBytes = File(filePath).lengthSync();
      return (sizeInBytes / 16000).round().clamp(1, 300);
    } catch (_) {
      return 0;
    }
  }
}
