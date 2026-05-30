import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// 豆包端到端实时语音大模型 API 的二进制帧编解码
class RealtimeBinaryFrame {
  RealtimeBinaryFrame._();

  // ── 协议常量 ──
  static const int _protocolVersion = 1;
  static const int _headerSizeFlag = 1; // 4 字节 header

  // Message Type (高 4 位 of byte 1)
  static const int msgFullClientRequest = 0x1;
  static const int msgFullServerResponse = 0x9;
  static const int msgAudioOnlyResponse = 0xB;
  static const int msgError = 0xF;

  // Serialization (高 4 位 of byte 2)
  static const int serRaw = 0x0;
  static const int serJson = 0x1;

  // Compression (低 4 位 of byte 2)
  static const int compNone = 0x0;

  // Flags (低 4 位 of byte 1)
  static const int flagEvent = 0x4;

  // ── 客户端事件 ID ──
  static const int evtStartConnection = 1;
  static const int evtFinishConnection = 2;
  static const int evtStartSession = 100;
  static const int evtFinishSession = 102;
  static const int evtChatTTSText = 500;

  // ── 服务端事件 ID ──
  static const int evtConnectionStarted = 50;
  static const int evtConnectionFailed = 51;
  static const int evtSessionStarted = 150;
  static const int evtSessionFailed = 153;
  static const int evtTTSSentenceStart = 350;
  static const int evtTTSResponse = 352;
  static const int evtTTSEnded = 359;
  static const int evtDialogCommonError = 599;

  // ── 编码：Connect 级事件 ──
  static List<int> encodeConnectEvent(int eventId, String connectId) {
    final buf = BytesBuilder();
    _writeHeader(buf, msgFullClientRequest, flagEvent, serJson, compNone);
    _writeInt32(buf, eventId);
    _writeStringWithSize(buf, connectId);
    // Connect 事件 payload 直接跟在 connect_id 后面
    final payload = utf8.encode('{}');
    _writeInt32(buf, payload.length);
    buf.add(payload);
    return buf.toBytes();
  }

  // ── 编码：Session 级事件 (JSON payload) ──
  static List<int> encodeSessionJsonEvent(int eventId, String sessionId, String jsonPayload) {
    final buf = BytesBuilder();
    _writeHeader(buf, msgFullClientRequest, flagEvent, serJson, compNone);
    _writeInt32(buf, eventId);
    _writeStringWithSize(buf, sessionId);
    final payload = utf8.encode(jsonPayload);
    _writeInt32(buf, payload.length);
    buf.add(payload);
    return buf.toBytes();
  }

  // ── 编码：ChatTTSText (流式分片) ──
  static List<int> encodeChatTTSText(String sessionId, String content, {bool start = false, bool end = false}) {
    final json = jsonEncode({'start': start, 'content': content, 'end': end});
    return encodeSessionJsonEvent(evtChatTTSText, sessionId, json);
  }

  // ── 解码服务端消息 ──
  static ParsedServerMessage? decode(List<int> raw) {
    if (raw.length < 4) return null;
    final header = raw.sublist(0, 4);
    final messageType = (header[1] >> 4) & 0xF;
    final flags = header[1] & 0xF;
    final serMethod = (header[2] >> 4) & 0xF;
    final isJson = serMethod == serJson;

    int offset = 4;
    int? event;

    // Event
    if ((flags & flagEvent) != 0) {
      if (offset + 4 > raw.length) return null;
      event = _readInt32(raw, offset);
      offset += 4;
    }

    // Session ID (Session 级事件)
    String? sessionId;
    if (_needsSessionId(event)) {
      if (offset + 4 > raw.length) return null;
      final len = _readInt32(raw, offset);
      offset += 4;
      if (offset + len > raw.length) return null;
      sessionId = utf8.decode(raw.sublist(offset, offset + len));
      offset += len;
    }

    // Payload
    Uint8List? payload;
    if (offset + 4 <= raw.length) {
      final payloadLen = _readInt32(raw, offset);
      offset += 4;
      if (payloadLen > 0 && offset + payloadLen <= raw.length) {
        payload = Uint8List.fromList(raw.sublist(offset, offset + payloadLen));
      }
    }

    return ParsedServerMessage(
      messageType: messageType,
      event: event,
      sessionId: sessionId,
      isJson: isJson,
      payload: payload,
    );
  }

  // ── 内部工具 ──

  static void _writeHeader(BytesBuilder buf, int msgType, int flags, int ser, int comp) {
    buf.addByte((_protocolVersion << 4) | _headerSizeFlag);
    buf.addByte((msgType << 4) | flags);
    buf.addByte((ser << 4) | comp);
    buf.addByte(0);
  }

  static void _writeInt32(BytesBuilder buf, int value) {
    buf.addByte((value >> 24) & 0xFF);
    buf.addByte((value >> 16) & 0xFF);
    buf.addByte((value >> 8) & 0xFF);
    buf.addByte(value & 0xFF);
  }

  static void _writeStringWithSize(BytesBuilder buf, String s) {
    final bytes = utf8.encode(s);
    _writeInt32(buf, bytes.length);
    buf.add(bytes);
  }

  static int _readInt32(List<int> data, int offset) {
    return (data[offset] << 24) |
        (data[offset + 1] << 16) |
        (data[offset + 2] << 8) |
        data[offset + 3];
  }

  static bool _needsSessionId(int? event) =>
      event != null && event != evtConnectionStarted && event != evtConnectionFailed;
}

/// 解析后的服务端消息
class ParsedServerMessage {
  final int messageType;
  final int? event;
  final String? sessionId;
  final bool isJson;
  final Uint8List? payload;

  ParsedServerMessage({
    required this.messageType,
    this.event,
    this.sessionId,
    required this.isJson,
    this.payload,
  });

  String? get payloadAsString {
    if (payload == null || !isJson) return null;
    return utf8.decode(payload!);
  }

  Map<String, dynamic>? get payloadAsJson {
    final s = payloadAsString;
    if (s == null) return null;
    try {
      return jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
// PCM → WAV 转换
// ═══════════════════════════════════════════════════════════════════════

class WavEncoder {
  WavEncoder._();

  static Uint8List encode(Uint8List pcmData, {int sampleRate = 24000, int channels = 1, int bitsPerSample = 16}) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final buf = BytesBuilder();
    // RIFF header
    buf.add(utf8.encode('RIFF'));
    _writeLE32(buf, fileSize);
    buf.add(utf8.encode('WAVE'));
    // fmt chunk
    buf.add(utf8.encode('fmt '));
    _writeLE32(buf, 16); // chunk size
    _writeLE16(buf, 1); // PCM format
    _writeLE16(buf, channels);
    _writeLE32(buf, sampleRate);
    _writeLE32(buf, byteRate);
    _writeLE16(buf, blockAlign);
    _writeLE16(buf, bitsPerSample);
    // data chunk
    buf.add(utf8.encode('data'));
    _writeLE32(buf, dataSize);
    buf.add(pcmData);

    return Uint8List.fromList(buf.toBytes());
  }

  static void _writeLE32(BytesBuilder buf, int v) {
    buf.addByte(v & 0xFF);
    buf.addByte((v >> 8) & 0xFF);
    buf.addByte((v >> 16) & 0xFF);
    buf.addByte((v >> 24) & 0xFF);
  }

  static void _writeLE16(BytesBuilder buf, int v) {
    buf.addByte(v & 0xFF);
    buf.addByte((v >> 8) & 0xFF);
  }
}

// ═══════════════════════════════════════════════════════════════════════
// RealtimeVoiceService — 文本→语音（带唱歌能力）
// ═══════════════════════════════════════════════════════════════════════

class RealtimeVoiceResult {
  final String? filePath;
  final String? error;
  final int audioByteCount;
  final List<String> ttsTypes; // 每段音频的类型：default / sing

  RealtimeVoiceResult({
    this.filePath,
    this.error,
    this.audioByteCount = 0,
    this.ttsTypes = const [],
  });

  bool get isSuccess => filePath != null;
}

class RealtimeVoiceService {
  RealtimeVoiceService._();

  static const String _host = 'openspeech.bytedance.com';
  static const String _path = '/api/v3/realtime/dialogue';
  static const String _resourceId = 'volc.speech.dialog';
  static const String _appKey = 'PlgvMymc7f3tQnJ6';

  /// 将文本合成为语音文件，返回 wav 文件路径
  static Future<RealtimeVoiceResult> synthesize({
    required String text,
    required String speakerId,
    required String appId,
    required String accessToken,
    String characterManifest = '',
    String model = '2.2.0.0',
    bool enableMusic = true,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final connectId = _generateUuid();
    final sessionId = _generateUuid();

    WebSocket? ws;
    final audioChunks = <Uint8List>[];
    final ttsTypes = <String>[];
    final completer = Completer<RealtimeVoiceResult>();
    bool sessionStarted = false;

    try {
      // 1. 建立 WebSocket
      ws = await _connect(
        appId: appId,
        accessToken: accessToken,
        connectId: connectId,
      );

      // 2. 超时保护
      Timer? timer;
      if (timeout != const Duration(seconds: 120)) {
        // Duration 比较在 Dart 中，直接用具体值
      }
      timer = Timer(const Duration(seconds: 120), () {
        if (!completer.isCompleted) {
          completer.complete(RealtimeVoiceResult(error: '语音合成超时'));
        }
      });

      // 3. 接收消息
      final sub = ws.listen((data) {
        if (completer.isCompleted) return;
        try {
          final msg = RealtimeBinaryFrame.decode(data as List<int>);
          if (msg == null) return;
          final currentWs = ws;
          if (currentWs == null) return;
          _handleMessage(
            msg: msg,
            ws: currentWs,
            sessionId: sessionId,
            connectId: connectId,
            text: text,
            speakerId: speakerId,
            characterManifest: characterManifest,
            model: model,
            enableMusic: enableMusic,
            sessionStarted: sessionStarted,
            audioChunks: audioChunks,
            ttsTypes: ttsTypes,
            onSessionStarted: () => sessionStarted = true,
            onTTSEnded: () {},
            onComplete: (result) {
              timer?.cancel();
              if (!completer.isCompleted) completer.complete(result);
            },
          );
        } catch (e) {
          debugPrint('[RealtimeVoice] 消息处理异常: $e');
        }
      }, onError: (e) {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(RealtimeVoiceResult(error: 'WebSocket 错误: $e'));
        }
      }, onDone: () {
        timer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(RealtimeVoiceResult(error: '连接已关闭'));
        }
      });

      // 4. 发送 StartConnection
      ws.add(RealtimeBinaryFrame.encodeConnectEvent(
        RealtimeBinaryFrame.evtStartConnection,
        connectId,
      ));

      // 等待完成
      final result = await completer.future;
      await sub.cancel();

      // 5. 如果有音频数据，写入 WAV 文件
      if (result.isSuccess && audioChunks.isNotEmpty) {
        final allAudio = _concatChunks(audioChunks);
        final wav = WavEncoder.encode(allAudio);
        final dir = await getTemporaryDirectory();
        final filePath = p.join(dir.path, 'realtime_${DateTime.now().millisecondsSinceEpoch}.wav');
        await File(filePath).writeAsBytes(wav);
        return RealtimeVoiceResult(
          filePath: filePath,
          audioByteCount: allAudio.length,
          ttsTypes: ttsTypes,
        );
      }

      return result;
    } catch (e) {
      if (!completer.isCompleted) {
        return RealtimeVoiceResult(error: '连接失败: $e');
      }
      return RealtimeVoiceResult(error: '未知错误');
    } finally {
      // 尝试正常关闭
      try {
        ws?.close();
      } catch (_) {}
    }
  }

  // ── WebSocket 连接 ──

  static Future<WebSocket> _connect({
    required String appId,
    required String accessToken,
    required String connectId,
  }) async {
    return WebSocket.connect(
      'wss://$_host$_path',
      headers: {
        'X-Api-App-ID': appId,
        'X-Api-Access-Key': accessToken,
        'X-Api-Resource-Id': _resourceId,
        'X-Api-App-Key': _appKey,
        'X-Api-Connect-Id': connectId,
        'User-Agent': 'MoodDiary/1.0',
      },
    );
  }

  // ── 消息处理 ──

  static void _handleMessage({
    required ParsedServerMessage msg,
    required WebSocket ws,
    required String sessionId,
    required String connectId,
    required String text,
    required String speakerId,
    required String characterManifest,
    required String model,
    required bool enableMusic,
    required bool sessionStarted,
    required List<Uint8List> audioChunks,
    required List<String> ttsTypes,
    required void Function() onSessionStarted,
    required void Function() onTTSEnded,
    required void Function(RealtimeVoiceResult) onComplete,
  }) {
    final event = msg.event;

    switch (event) {
      case RealtimeBinaryFrame.evtConnectionStarted:
        debugPrint('[RealtimeVoice] 连接已建立');
        // 发送 StartSession
        final startJson = _buildStartSession(
          speakerId: speakerId,
          characterManifest: characterManifest,
          model: model,
          enableMusic: enableMusic,
        );
        ws.add(RealtimeBinaryFrame.encodeSessionJsonEvent(
          RealtimeBinaryFrame.evtStartSession,
          sessionId,
          startJson,
        ));
        break;

      case RealtimeBinaryFrame.evtConnectionFailed:
        final err = msg.payloadAsJson?['error'] ?? '未知错误';
        onComplete(RealtimeVoiceResult(error: '连接失败: $err'));
        break;

      case RealtimeBinaryFrame.evtSessionStarted:
        debugPrint('[RealtimeVoice] 会话已启动');
        onSessionStarted();
        // 发送 ChatTTSText（一次性发送全部文本）
        ws.add(RealtimeBinaryFrame.encodeChatTTSText(
          sessionId,
          text,
          start: true,
          end: true,
        ));
        break;

      case RealtimeBinaryFrame.evtSessionFailed:
        final err = msg.payloadAsJson?['error'] ?? '未知错误';
        onComplete(RealtimeVoiceResult(error: '会话失败: $err'));
        break;

      case RealtimeBinaryFrame.evtTTSSentenceStart:
        final ttsType = msg.payloadAsJson?['tts_type'] as String? ?? 'default';
        ttsTypes.add(ttsType);
        debugPrint('[RealtimeVoice] TTS 句子开始 type=$ttsType');
        break;

      case RealtimeBinaryFrame.evtTTSResponse:
        if (msg.payload != null && msg.payload!.isNotEmpty) {
          audioChunks.add(msg.payload!);
        }
        break;

      case RealtimeBinaryFrame.evtTTSEnded:
        debugPrint('[RealtimeVoice] TTS 结束');
        onTTSEnded();
        // 发送 FinishSession + FinishConnection
        ws.add(RealtimeBinaryFrame.encodeSessionJsonEvent(
          RealtimeBinaryFrame.evtFinishSession,
          sessionId,
          '{}',
        ));
        ws.add(RealtimeBinaryFrame.encodeConnectEvent(
          RealtimeBinaryFrame.evtFinishConnection,
          connectId,
        ));
        onComplete(RealtimeVoiceResult(audioByteCount: audioChunks.fold(0, (s, c) => s + c.length)));
        break;

      case RealtimeBinaryFrame.evtDialogCommonError:
        final statusCode = msg.payloadAsJson?['status_code'] ?? '';
        final message = msg.payloadAsJson?['message'] ?? '';
        debugPrint('[RealtimeVoice] 错误: $statusCode $message');
        break;

      default:
        if (event != null) {
          debugPrint('[RealtimeVoice] 未处理事件: $event');
        }
        break;
    }
  }

  // ── StartSession JSON ──

  static String _buildStartSession({
    required String speakerId,
    required String characterManifest,
    required String model,
    required bool enableMusic,
  }) {
    final map = <String, dynamic>{
      'tts': {
        'speaker': speakerId,
        'audio_config': {
          'channel': 1,
          'format': 'pcm_s16le',
          'sample_rate': 24000,
        },
      },
      'dialog': {
        'character_manifest': characterManifest,
        'extra': {
          'input_mod': 'text',
          'enable_music': enableMusic,
          'model': model,
          'strict_audit': false,
        },
      },
    };
    return jsonEncode(map);
  }

  // ── 工具 ──

  static Uint8List _concatChunks(List<Uint8List> chunks) {
    final totalLen = chunks.fold<int>(0, (s, c) => s + c.length);
    final result = Uint8List(totalLen);
    var offset = 0;
    for (final chunk in chunks) {
      result.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return result;
  }

  static String _generateUuid() {
    final r = Random();
    final hex = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }
}
