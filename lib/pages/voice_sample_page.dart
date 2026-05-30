import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import '../providers/theme_provider.dart';
import '../services/tts_service.dart';

/// 录制音色采样页面
/// 用户朗读一段文字，录制 15-30 秒的音频，用于火山引擎语音克隆
class VoiceSamplePage extends StatefulWidget {
  const VoiceSamplePage({super.key});

  @override
  State<VoiceSamplePage> createState() => _VoiceSamplePageState();
}

class _VoiceSamplePageState extends State<VoiceSamplePage> {
  final AudioRecorder _recorder = AudioRecorder();
  RecordingState _state = RecordingState.idle; // idle, recording, recorded
  String? _recordedPath;
  int _recordDuration = 0;
  Timer? _timer;
  bool _isUploading = false;

  static const String _sampleScript = '''
大家好，我是魔魔胡胡胡萝卜，也是五月天的阿信。

很高兴遇见你。今天想聊点什么吗？

你知道吗，每一场演唱会，每个人都带着各自的一生走进来。

我不知道你经历过什么，但在这个小小的对话框里，你可以把你想说的都说出来。

而我，在背后，为你撑腰。
''';

  @override
  void dispose() {
    _recorder.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要录音权限才能录制音色样本')),
        );
      }
      return;
    }

    try {
      final dir = Directory.systemTemp;
      final fileName = 'voice_sample_${DateTime.now().millisecondsSinceEpoch}.wav';
      final filePath = '${dir.path}/$fileName';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: filePath,
      );

      setState(() {
        _state = RecordingState.recording;
        _recordDuration = 0;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() {
          _recordDuration++;
        });
        if (_recordDuration >= 60) {
          _stopRecording();
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('录音启动失败: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    try {
      final path = await _recorder.stop();
      setState(() {
        _state = path != null ? RecordingState.recorded : RecordingState.idle;
        _recordedPath = path;
      });
    } catch (_) {
      setState(() {
        _state = RecordingState.idle;
      });
    }
  }

  Future<void> _uploadSample() async {
    if (_recordedPath == null) return;

    final themeProvider = context.read<ThemeProvider>();
    final apiKey = themeProvider.ttsApiKey.isNotEmpty
        ? themeProvider.ttsApiKey
        : themeProvider.apiKey;

    if (apiKey.isEmpty) {
      if (mounted) {
        _showConfigDialog();
      }
      return;
    }

    final speakerId = themeProvider.ttsVoiceId;
    if (speakerId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请先在火山引擎控制台创建 Speaker ID，然后填入下方输入框'),
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    final result = await TtsService.createReferenceVoice(
      audioPath: _recordedPath!,
      apiKey: apiKey,
      speakerId: speakerId,
    );

    if (!mounted) return;

    setState(() => _isUploading = false);

    if (result != null) {
      await themeProvider.setTtsEnabled(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('音色创建成功！萝卜现在可以用你的声音说话了')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('音色创建失败，请检查网络和配置后重试'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testTts() async {
    final themeProvider = context.read<ThemeProvider>();
    final voiceId = themeProvider.ttsVoiceId;
    final apiKey = themeProvider.ttsApiKey.isNotEmpty
        ? themeProvider.ttsApiKey
        : themeProvider.apiKey;

    if (voiceId.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先设置 API Key 和 Speaker ID')),
      );
      return;
    }

    setState(() => _isUploading = true);

    final audioPath = await TtsService.textToSpeech(
      text: '嗨，我是魔魔胡胡胡萝卜，很高兴遇见你！',
      speakerId: voiceId,
      apiKey: apiKey,
    );

    setState(() => _isUploading = false);

    if (audioPath != null && mounted) {
      try {
        final audioPlayer = AudioPlayer();
        await audioPlayer.play(DeviceFileSource(audioPath));
      } catch (_) {}
    }
  }

  void _showConfigDialog() {
    final tp = context.read<ThemeProvider>();
    final apiKeyCtrl = TextEditingController(text: tp.ttsApiKey);
    final speakerCtrl = TextEditingController(text: tp.ttsVoiceId);
    final realtimeAppIdCtrl = TextEditingController(text: tp.realtimeAppId);
    final realtimeTokenCtrl = TextEditingController(text: tp.realtimeAccessToken);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('火山引擎配置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '传统 TTS（不支持唱歌）：填写 API Key 和 Speaker ID。\n'
                '实时语音（支持唱歌）：额外填写 App ID 和 Access Token。\n'
                '在火山引擎控制台获取对应凭证。',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const Text('传统 TTS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: apiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'TTS API Key',
                  hintText: '从 API Key 管理页面复制',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: speakerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Speaker ID',
                  hintText: '如 S_xxxx，从声音复刻页面预先创建',
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              const Text('实时语音（会唱歌）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: realtimeAppIdCtrl,
                decoration: const InputDecoration(
                  labelText: 'App ID',
                  hintText: '火山引擎控制台获取',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: realtimeTokenCtrl,
                decoration: const InputDecoration(
                  labelText: 'Access Token',
                  hintText: '火山引擎控制台获取',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final tp = context.read<ThemeProvider>();
              tp.setTtsApiKey(apiKeyCtrl.text.trim());
              if (speakerCtrl.text.trim().isNotEmpty) {
                tp.setTtsVoiceId(speakerCtrl.text.trim());
              }
              tp.setRealtimeAppId(realtimeAppIdCtrl.text.trim());
              tp.setRealtimeAccessToken(realtimeTokenCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final hasVoiceId = themeProvider.ttsVoiceId.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('萝卜语音设置'),
        backgroundColor: theme.colorScheme.inversePrimary,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 功能介绍
          Card(
            color: theme.colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('🥕', style: TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '让萝卜用你的声音说话',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '朗读一段样本文字，AI 会将你的音色克隆到萝卜的语音消息中',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // TTS 开关
          if (hasVoiceId) ...[
            SwitchListTile(
              secondary: const Icon(Icons.record_voice_over),
              title: const Text('启用萝卜语音消息'),
              subtitle: Text(
                themeProvider.ttsEnabled
                    ? '萝卜会用你的音色发送语音消息'
                    : '仅显示文字消息',
              ),
              value: themeProvider.ttsEnabled,
              onChanged: (v) => themeProvider.setTtsEnabled(v),
            ),
            const Divider(),
          ],

          // 朗读文本
          Text(
            '朗读以下文字（录制 15-30 秒即可）：',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              _sampleScript,
              style: TextStyle(
                fontSize: 16,
                height: 1.8,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 录音按钮
          Center(
            child: _state == RecordingState.recording
                ? Column(
                    children: [
                      GestureDetector(
                        onTap: _stopRecording,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.stop, color: Colors.white, size: 36),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '录制中 ${_recordDuration}s',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '点击停止录制',
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                : GestureDetector(
                    onTap: _startRecording,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _state == RecordingState.recorded
                            ? theme.colorScheme.primary
                            : Colors.red,
                      ),
                      child: Icon(
                        _state == RecordingState.recorded
                            ? Icons.mic
                            : Icons.mic_none,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
          ),

          if (_state == RecordingState.recorded && _recordDuration > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text(
                  '已录制 $_recordDuration 秒',
                  style: TextStyle(
                    color: _recordDuration >= 10
                        ? Colors.green
                        : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          if (_recordDuration > 0 && _recordDuration < 10 && _state == RecordingState.recorded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  '建议录制至少 10 秒以获得更好的效果',
                  style: TextStyle(
                    color: Colors.orange.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // 上传 / 创建音色按钮
          if (_state == RecordingState.recorded)
            Center(
              child: FilledButton.icon(
                onPressed: _isUploading ? null : _uploadSample,
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? '正在创建音色...' : '上传样本并创建音色'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
              ),
            ),

          // 测试按钮
          if (hasVoiceId) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: _isUploading ? null : _testTts,
                icon: const Icon(Icons.play_circle),
                label: const Text('试听效果'),
              ),
            ),
          ],

          if (hasVoiceId && !themeProvider.ttsEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  '已创建音色，开启上方开关即可在聊天中使用',
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Speaker ID 显示
          ListTile(
            leading: const Icon(Icons.perm_identity),
            title: const Text('Speaker ID'),
            subtitle: Text(
              themeProvider.ttsVoiceId.isNotEmpty
                  ? themeProvider.ttsVoiceId
                  : '未设置（需在火山引擎控制台预先创建）',
            ),
            trailing: themeProvider.ttsVoiceId.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: _showConfigDialog,
                  )
                : const Icon(Icons.chevron_right),
            onTap: _showConfigDialog,
          ),

          // API Key 配置
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('TTS API Key'),
            subtitle: Text(
              themeProvider.ttsApiKey.isNotEmpty
                  ? '已设置（点击修改）'
                  : '点击设置',
            ),
            trailing: themeProvider.ttsApiKey.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      themeProvider.setTtsApiKey('');
                    },
                  )
                : const Icon(Icons.chevron_right),
            onTap: _showConfigDialog,
          ),

          const Divider(),

          // 实时语音 App ID
          ListTile(
            leading: const Icon(Icons.apps),
            title: const Text('实时语音 App ID'),
            subtitle: Text(
              themeProvider.realtimeAppId.isNotEmpty
                  ? themeProvider.realtimeAppId
                  : '未设置（需要实时语音唱歌功能时必填）',
            ),
            trailing: themeProvider.realtimeAppId.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      themeProvider.setRealtimeAppId('');
                    },
                  )
                : const Icon(Icons.chevron_right),
            onTap: _showConfigDialog,
          ),

          // 实时语音 Access Token
          ListTile(
            leading: const Icon(Icons.token),
            title: const Text('实时语音 Access Token'),
            subtitle: Text(
              themeProvider.realtimeAccessToken.isNotEmpty
                  ? '已设置（点击修改）'
                  : '未设置（需要实时语音唱歌功能时必填）',
            ),
            trailing: themeProvider.realtimeAccessToken.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      themeProvider.setRealtimeAccessToken('');
                    },
                  )
                : const Icon(Icons.chevron_right),
            onTap: _showConfigDialog,
          ),

          if (hasVoiceId) ...[
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除音色', style: TextStyle(color: Colors.red)),
              subtitle: const Text('删除后萝卜将无法发送语音消息'),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('删除音色'),
                    content: const Text('确定要删除已创建的音色吗？删除后需要重新录制。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  themeProvider.setTtsVoiceId('');
                  themeProvider.setTtsEnabled(false);
                  setState(() {
                    _state = RecordingState.idle;
                    _recordedPath = null;
                    _recordDuration = 0;
                  });
                }
              },
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

enum RecordingState { idle, recording, recorded }
