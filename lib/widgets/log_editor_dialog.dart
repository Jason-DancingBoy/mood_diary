// 文件: lib/widgets/log_editor_dialog.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../enums/mood_type.dart';
import '../models/mood_log.dart';
import '../providers/theme_provider.dart';
import '../services/image_manager.dart';

class LogEditorDialog extends StatefulWidget {
  final MoodLog? initialLog;
  final Function(MoodType, String, bool, String?, int?, String?, List<String>?)
  onSave;

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
    final pickedFiles = await picker.pickMultiImage(limit: 9 - _imageFileNames.length);
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
    super.dispose();
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

              // 系统默认心情选择区
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

              const SizedBox(height: 24),

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
              Text('发生了什么事？', style: theme.textTheme.titleMedium),
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

                    widget.onSave(
                      _selectedMood,
                      _noteController.text.trim(),
                      isOfflineMode ? false : _aiEnabled,
                      null,
                      null,
                      null,
                      _imageFileNames.isNotEmpty ? _imageFileNames : null,
                    );
                    Navigator.pop(context);
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
