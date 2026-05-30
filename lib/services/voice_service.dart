import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:record/record.dart';
import 'package:storage_client/storage_client.dart';
import 'supabase_service.dart';

class VoiceService {
  VoiceService._();

  static AudioRecorder? _recorder;

  static AudioRecorder get _r => _recorder ??= AudioRecorder();

  /// 是否正在录音
  static Future<bool> isRecording() => _r.isRecording();

  /// 是否有录音权限
  static Future<bool> hasPermission() => _r.hasPermission();

  /// 开始录音，返回录音文件的本地路径
  /// 返回 null 表示权限未授予；抛出异常表示其他错误
  static Future<String?> startRecording() async {
    final hasPermission = await _r.hasPermission();
    if (!hasPermission) return null;

    final dir = Directory.systemTemp;
    final fileName =
        'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final filePath = p.join(dir.path, fileName);

    try {
      await _r.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 22050,
        ),
        path: filePath,
      );
    } catch (_) {
      // AAC-LC may fail on some devices, try default encoder
      try {
        await _r.start(
          const RecordConfig(),
          path: filePath,
        );
      } catch (e) {
        rethrow;
      }
    }
    return filePath;
  }

  /// 停止录音，返回 (文件路径, 时长秒数)
  static Future<(String?, int)> stopRecording() async {
    try {
      final path = await _r.stop();
      if (path == null) return (null, 0);

      // 估算时长（AAC 64kbps, 22050Hz 单声道）
      final file = File(path);
      final sizeInBytes = await file.length();
      // 粗略估算：64kbps = 8KB/s
      final duration = (sizeInBytes / 8000).round();
      return (path, duration.clamp(1, 300));
    } catch (e) {
      return (null, 0);
    }
  }

  /// 取消录音（删除本地文件）
  static Future<void> cancelRecording() async {
    try {
      final path = await _r.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (_) {}
  }

  /// 上传录音到 Supabase Storage，返回公开 URL
  static Future<String?> uploadVoice(String filePath) async {
    try {
      final userId = SupabaseService.auth.currentUser!.id;
      final file = File(filePath);
      if (!await file.exists()) return null;

      final bytes = await file.readAsBytes();
      final fileName = p.basename(filePath);
      final remotePath = '$userId/voice/$fileName';

      final ext = p.extension(fileName).toLowerCase();
      final contentType = ext == '.mp3'
          ? 'audio/mpeg'
          : ext == '.wav'
              ? 'audio/wav'
              : 'audio/mp4';
      await SupabaseService.storage.uploadBinary(
        remotePath,
        bytes,
        fileOptions: FileOptions(contentType: contentType),
      );
      return SupabaseService.storage.getPublicUrl(remotePath);
    } catch (e) {
      return null;
    }
  }

  /// 释放录音资源
  static void dispose() {
    _recorder?.dispose();
    _recorder = null;
  }
}
