// 文件: lib/widgets/log_editor_dialog.dart

import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../enums/mood_type.dart';
import '../enums/mood_quadrant.dart';
import '../models/mood_log.dart';
import '../providers/theme_provider.dart';
import '../services/image_manager.dart';
import '../services/voice_service.dart';
import 'mood_meter_grid.dart';
import 'ai_emotion_questionnaire_dialog.dart';

class LogEditorDialog extends StatefulWidget {
  final MoodLog? initialLog;
  final Function(
    MoodType,
    String,
    bool,
    String?,
    int?,
    String?,
    List<String>?,
    String?,
    int?, [
    double? energy,
    double? pleasantness,
    String? emotionWord,
    String? quadrant,
  ]) onSave;

  const LogEditorDialog({super.key, this.initialLog, required this.onSave});

  @override
  State<LogEditorDialog> createState() => _LogEditorDialogState();
}

class _LogEditorDialogState extends State<LogEditorDialog> {
  late MoodType _selectedMood;
  late TextEditingController _noteController;
  late bool _aiEnabled;

  // 图片相关 - 支持多图片
  List<String> _imageFileNames = [];
  List<String> _tempImagePaths = [];

  // 语音相关
  String? _voiceFilePath;
  int? _voiceDuration;
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Mood Meter fields
  double? _energy;
  double? _pleasantness;
  String? _emotionWord;
  String? _quadrant;

  @override
  void initState() {
    super.initState();
    _selectedMood = widget.initialLog?.mood ?? MoodType.calm;
    _noteController = TextEditingController(
      text: widget.initialLog?.note ?? '',
    );
    _aiEnabled = widget.initialLog?.aiEnabled ?? true;

    // 初始化图片
    if (widget.initialLog?.imageFileNames != null) {
      _imageFileNames = List.from(widget.initialLog!.imageFileNames!);
    }
    // 初始化语音
    _voiceFilePath = widget.initialLog?.voiceFilePath;
    _voiceDuration = widget.initialLog?.voiceDuration;
    // 初始化 Mood Meter 字段
    _energy = widget.initialLog?.energy;
    _pleasantness = widget.initialLog?.pleasantness;
    _emotionWord = widget.initialLog?.emotionWord;
    _quadrant = widget.initialLog?.quadrant;
    _loadImagePreviews();
  }

  Future<void> _loadImagePreviews() async {
    if (_imageFileNames.isEmpty) return;
    final paths = <String>[];
    for (final fileName in _imageFileNames) {
      final path = await ImageManager.getImagePathAsync(fileName);
      paths.add(path);
    }
    if (mounted) {
      setState(() {
        _tempImagePaths = paths;
      });
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    // 允许选择多张图片，最多9张
    final pickedFiles = await picker.pickMultiImage(
      limit: 9 - _imageFileNames.length,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (pickedFiles.isNotEmpty) {
      final newFileNames = <String>[];
      final newPaths = <String>[];
      for (final pickedFile in pickedFiles) {
        final savedFileName = await ImageManager.saveImageToFile(pickedFile);
        newFileNames.add(savedFileName);
        newPaths.add(pickedFile.path);
      }
      setState(() {
        _imageFileNames.addAll(newFileNames);
        _tempImagePaths.addAll(newPaths);
      });
    }
  }

  Future<void> _removeImage(int index) async {
    if (index >= 0 && index < _imageFileNames.length) {
      await ImageManager.deleteImage(_imageFileNames[index]);
      setState(() {
        _imageFileNames.removeAt(index);
        if (index < _tempImagePaths.length) {
          _tempImagePaths.removeAt(index);
        }
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _recordingTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await VoiceService.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请授予录音权限')),
        );
      }
      return;
    }

    final filePath = await VoiceService.startRecording();
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法开始录音')),
        );
      }
      return;
    }

    setState(() {
      _voiceFilePath = filePath;
      _isRecording = true;
      _recordingSeconds = 0;
    });

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingSeconds++);
      }
    });
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final (path, duration) = await VoiceService.stopRecording();
    if (!mounted) return;

    if (path != null) {
      // Move to permanent storage
      final appDir = await getApplicationDocumentsDirectory();
      final voiceDir = Directory('${appDir.path}/mood_voice');
      if (!await voiceDir.exists()) await voiceDir.create(recursive: true);
      final permPath = '${voiceDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await File(path).copy(permPath);
      await File(path).delete();

      setState(() {
        _isRecording = false;
        _voiceFilePath = permPath;
        _voiceDuration = duration;
      });
    } else {
      setState(() => _isRecording = false);
    }
  }

  Future<void> _deleteVoice() async {
    if (_voiceFilePath != null) {
      final file = File(_voiceFilePath!);
      if (await file.exists()) await file.delete();
    }
    setState(() {
      _voiceFilePath = null;
      _voiceDuration = null;
    });
  }

  Future<void> _playVoice() async {
    if (_voiceFilePath == null) return;
    final file = File(_voiceFilePath!);
    if (!await file.exists()) return;

    setState(() => _isPlaying = true);
    await _audioPlayer.play(DeviceFileSource(_voiceFilePath!));
    _audioPlayer.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  Future<void> _stopPlayback() async {
    await _audioPlayer.stop();
    if (mounted) setState(() => _isPlaying = false);
  }

  Future<void> _openMoodMeterGrid() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      backgroundColor: Colors.transparent,
      builder: (_) => MoodMeterGrid(
        initialEnergy: _energy,
        initialPleasantness: _pleasantness,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _energy = (result['energy'] as double?)?.clamp(-1.0, 1.0);
        _pleasantness = (result['pleasantness'] as double?)?.clamp(-1.0, 1.0);
        _emotionWord = result['emotionWord'] as String?;
        _quadrant = result['quadrant'] as String?;
        if (_energy != null && _pleasantness != null) {
          _selectedMood = _resolveMoodFromSelection();
        }
      });
    }
  }

  /// 优先用 emotionWord 精确匹配 MoodType，匹配不到再回退到坐标计算
  MoodType _resolveMoodFromSelection() {
    if (_emotionWord != null && _emotionWord!.isNotEmpty) {
      final matched = MoodExtension.fromEmotionWord(_emotionWord!);
      if (matched != null) return matched;
    }
    return MoodExtension.fromEnergyPleasantness(_energy!, _pleasantness!);
  }

  bool _noteAutoFilled = false;

  Future<void> _openAiQuestionnaire() async {
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      backgroundColor: Colors.transparent,
      builder: (_) => const AIEmotionQuestionnaireDialog(),
    );
    if (result != null && mounted) {
      setState(() {
        _energy = (result['energy'] as double?)?.clamp(-1.0, 1.0);
        _pleasantness = (result['pleasantness'] as double?)?.clamp(-1.0, 1.0);
        _emotionWord = result['emotionWord'] as String?;
        _quadrant = result['quadrant'] as String?;
        if (_energy != null && _pleasantness != null) {
          _selectedMood = _resolveMoodFromSelection();
        }
      });

      // Auto-fill note field with AI trigger summary (prefer) or raw Q2/Q4 answers
      final triggerSummary = result['triggerSummary'] as String?;
      final q2 = result['q2Answer'] as String?;
      final q4 = result['q4Answer'] as String?;
      final autoNote = _buildAutoNote(triggerSummary, q2, q4);
      if (autoNote != null) {
        _noteController.text = autoNote;
        _noteAutoFilled = true;
      }
    }
  }

  /// Build auto-filled note: prefer AI trigger_summary, fall back to raw Q2+Q4.
  /// Returns null if nothing to fill.
  String? _buildAutoNote(String? triggerSummary, String? q2, String? q4) {
    if (triggerSummary != null && triggerSummary.trim().isNotEmpty) {
      return triggerSummary.trim();
    }
    final parts = <String>[];
    if (q2 != null && q2.trim().isNotEmpty) parts.add(q2.trim());
    if (q4 != null && q4.trim().isNotEmpty) parts.add(q4.trim());
    return parts.isNotEmpty ? parts.join('\n') : null;
  }

  Widget _buildCoordinatePickedCard(ThemeData theme, bool isDark) {
    final quad = MoodQuadrant.fromEnergyPleasantness(_energy!, _pleasantness!);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: quad.bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: quad.color.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(color: quad.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                _emotionWord ?? quad.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: quad.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '能量 ${_energy!.toStringAsFixed(1)}   愉悦 ${_pleasantness!.toStringAsFixed(1)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _openMoodMeterGrid,
                icon: const Icon(Icons.touch_app, size: 16),
                label: const Text('重新选择'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: quad.color.withValues(alpha: 0.6)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _clearCoordinateData,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('返回快速选择'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _hasCoordinateData => _energy != null && _pleasantness != null;

  void _clearCoordinateData() {
    setState(() {
      _energy = null;
      _pleasantness = null;
      _emotionWord = null;
      _quadrant = null;
    });
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.initialLog != null;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isOfflineMode = themeProvider.offlineMode;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? '编辑心情记录' : '此刻你的心情是？',
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 心情选择区域：坐标图优先，快速选择为后备
              if (_hasCoordinateData)
                _buildCoordinatePickedCard(theme, isDark)
              else ...[
                // 快速选择：MoodType 标签
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: MoodType.values.map((mood) {
                      final isSelected = _selectedMood == mood;

                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ChoiceChip(
                          label: Text(mood.label),
                          avatar: Icon(
                            mood.icon,
                            size: 18,
                            color: isSelected ? Colors.white : mood.color,
                          ),
                          selected: isSelected,
                          selectedColor: mood.color,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedMood = mood;
                              });
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // 更多选择入口
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openMoodMeterGrid,
                        icon: const Icon(Icons.grid_view_rounded, size: 18),
                        label: const Text('心情坐标图'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openAiQuestionnaire,
                        icon: const Icon(Icons.psychology, size: 18),
                        label: const Text('让AI帮我分析'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // AI 开关
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.smart_toy, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '启用小暖回复',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '让AI小暖为这条记录提供温暖的回应',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isOfflineMode ? false : _aiEnabled,
                      onChanged: isOfflineMode
                          ? null
                          : (value) => setState(() => _aiEnabled = value),
                    ),
                  ],
                ),
              ),
              if (isOfflineMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '当前处于断网模式，已自动关闭小暖回复。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Text('发生了什么事？', style: theme.textTheme.titleMedium),
                  if (_noteAutoFilled) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      '已自动填写',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: '记录下让你产生这种心情的事情...',
                  hintStyle: TextStyle(color: theme.colorScheme.outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                autofocus: true,
              ),
              const SizedBox(height: 12),
              // 图片添加区域
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 已添加的图片预览
                  if (_tempImagePaths.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 0; i < _tempImagePaths.length; i++)
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_tempImagePaths[i]),
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(i),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  // 添加更多图片按钮
                  if (_imageFileNames.length < 9)
                    OutlinedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.add_photo_alternate),
                      label: Text(_tempImagePaths.isEmpty ? '添加图片' : '添加更多图片 (${_imageFileNames.length}/9)'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // 语音录入区域
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('语音记录', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_voiceFilePath == null && !_isRecording)
                    OutlinedButton.icon(
                      onPressed: _startRecording,
                      icon: const Icon(Icons.mic),
                      label: const Text('录制语音'),
                    )
                  else if (_isRecording)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            '录制中 ${_formatDuration(_recordingSeconds)}',
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.stop, color: Colors.red),
                            onPressed: _stopRecording,
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: _isPlaying ? _stopPlayback : _playVoice,
                          ),
                          Text(
                            _voiceDuration != null
                                ? _formatDuration(_voiceDuration!)
                                : '--:--',
                            style: theme.textTheme.bodyMedium,
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: _deleteVoice,
                            tooltip: '删除录音',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_noteController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('请写下发生的事情')));
                      return;
                    }

                    final mood = _selectedMood;
                    final note = _noteController.text.trim();
                    final ai = isOfflineMode ? false : _aiEnabled;
                    final images =
                        _imageFileNames.isNotEmpty ? _imageFileNames : null;

                    widget.onSave(mood, note, ai, null, null, null, images,
                        _voiceFilePath, _voiceDuration,
                        _energy, _pleasantness, _emotionWord, _quadrant);
                    // 非编辑模式下，返回心情数据供调用方自动分享
                    Navigator.pop(context, isEdit ? null : {
                      'mood': mood,
                      'note': note,
                      'aiEnabled': ai,
                      'imageFileNames': images,
                      'voiceFilePath': _voiceFilePath,
                      'voiceDuration': _voiceDuration,
                      'energy': _energy,
                      'pleasantness': _pleasantness,
                      'emotionWord': _emotionWord,
                      'quadrant': _quadrant,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedMood.color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isEdit ? '更新记录' : '保存心情',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
