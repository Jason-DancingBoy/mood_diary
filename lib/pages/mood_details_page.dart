import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/mood_log.dart';
import '../services/image_manager.dart';
import '../services/ai_service.dart';
import '../widgets/log_editor_dialog.dart';
import '../enums/mood_type.dart';
import '../providers/theme_provider.dart';
import 'full_screen_image_view.dart';

class MoodDetailPage extends StatefulWidget {
  final MoodLog log;
  final Box<Map<dynamic, dynamic>> box;

  const MoodDetailPage({super.key, required this.log, required this.box});

  @override
  State<MoodDetailPage> createState() => _MoodDetailPageState();
}

class _MoodDetailPageState extends State<MoodDetailPage> {
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey _aiCardKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  // late TextEditingController _commentController; // 批注功能暂时屏蔽
  // String? _originalComment; // 批注功能暂时屏蔽
  late MoodLog _currentLog;
  String? _aiResponse;
  bool _isLoadingAi = false;
  late bool _aiEnabled;

  @override
  void initState() {
    super.initState();
    _currentLog = widget.log;
    // _commentController = TextEditingController(text: widget.log.comment); // 批注功能暂时屏蔽
    // _originalComment = widget.log.comment;
    _aiResponse = _currentLog.aiComfort;
    _aiEnabled = _currentLog.aiEnabled;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final themeProvider = Provider.of<ThemeProvider>(context);
    if (themeProvider.offlineMode && _aiResponse != null) {
      setState(() {
        _aiResponse = null;
      });
    }
    if (_aiEnabled &&
        _currentLog.aiComfort == null &&
        !_isLoadingAi &&
        !themeProvider.offlineMode) {
      _loadAiComfortIfNeeded();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _loadAiComfortIfNeeded() async {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.offlineMode) {
      return;
    }
    if (_aiEnabled && _currentLog.aiComfort == null) {
      setState(() {
        _isLoadingAi = true;
      });
      try {
        final comfort = await AIService.getComfort(
          _currentLog.mood.label,
          _currentLog.note,
          offlineMode: themeProvider.offlineMode,
        );
        if (comfort.isEmpty) {
          setState(() {
            _isLoadingAi = false;
          });
          return;
        }
        setState(() {
          _aiResponse = comfort;
          _isLoadingAi = false;
        });
        // 保存到数据库
        final updatedLog = MoodLog(
          id: _currentLog.id,
          mood: _currentLog.mood,
          note: _currentLog.note,
          comment: _currentLog.comment,
          imageFileNames: _currentLog.imageFileNames,
          createdAt: _currentLog.createdAt,
          aiComfort: comfort,
          aiEnabled: _aiEnabled,
        );
        await widget.box.put(_currentLog.id, updatedLog.toMap());
        _currentLog = updatedLog;
      } catch (e) {
        setState(() {
          _isLoadingAi = false;
        });
      }
    }
  }

  // 批注功能暂时屏蔽
  /*
  Future<void> _saveComment() async {
    final newComment = _commentController.text.trim();
    if (newComment == _originalComment) return;

    final updatedLog = MoodLog(
      id: _currentLog.id,
      mood: _currentLog.mood,
      note: _currentLog.note,
      comment: newComment,
      imageFileName: _currentLog.imageFileName,
      createdAt: _currentLog.createdAt,
      aiComfort: _currentLog.aiComfort,
      aiEnabled: _aiEnabled,
    );

    await widget.box.put(_currentLog.id, updatedLog.toMap());
    setState(() {
      _originalComment = newComment;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('批注已保存'), duration: Duration(milliseconds: 500)),
      );
    }
  }
  */

  Future<void> _saveAiEnabled(bool enabled) async {
    final updatedLog = MoodLog(
      id: _currentLog.id,
      mood: _currentLog.mood,
      note: _currentLog.note,
      comment: _currentLog.comment,
      imageFileNames: _currentLog.imageFileNames,
      createdAt: _currentLog.createdAt,
      aiComfort: _currentLog.aiComfort,
      aiEnabled: enabled,
    );

    await widget.box.put(_currentLog.id, updatedLog.toMap());
    setState(() {
      _currentLog = updatedLog;
      _aiEnabled = enabled;
    });
    // 如果开启了开关且没有AI回复，则加载AI回复
    if (enabled && _currentLog.aiComfort == null) {
      _loadAiComfortIfNeeded();
    }
  }

  Future<void> _shareMoodCard() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('未找到卡片区域');
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('图片字节数据为空');
      }
      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/mood_card_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(pngBytes, flush: true);

      if (!mounted) return;
      await Share.shareXFiles([XFile(tempFile.path)], subject: '看看我的心情');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('截图失败')));
      }
    }
  }

  void _editOriginalLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      backgroundColor: Colors.transparent,
      builder: (context) => LogEditorDialog(
        initialLog: _currentLog,
        onSave:
            (
              newMood,
              newNote,
              newAiEnabled,
              newCustomEmoji,
              newCustomColorValue,
              newCustomEmojiLabel,
              newImageFileNames,
            ) async {
              final offlineMode = Provider.of<ThemeProvider>(
                context,
                listen: false,
              ).offlineMode;
              final updatedLog = MoodLog(
                id: _currentLog.id,
                mood: newMood,
                note: newNote,
                comment: _currentLog.comment,
                imageFileNames: newImageFileNames ?? _currentLog.imageFileNames,
                customEmoji: newCustomEmoji,
                customEmojiLabel: newCustomEmojiLabel,
                customColorValue: newCustomColorValue,
                createdAt: _currentLog.createdAt,
                aiComfort: offlineMode
                    ? null
                    : (newAiEnabled ? _currentLog.aiComfort : null),
                aiEnabled: offlineMode ? false : newAiEnabled,
              );
              await widget.box.put(_currentLog.id, updatedLog.toMap());
              if (mounted) {
                setState(() {
                  _currentLog = updatedLog;
                  _aiEnabled = offlineMode ? false : newAiEnabled;
                  if (!(_aiEnabled)) {
                    _aiResponse = null; // 清除UI中的AI回复
                  }
                });
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('记录已更新')));
              }
            },
      ),
    );
  }

  Future<void> _pickAndAddImages() async {
    final ImagePicker picker = ImagePicker();
    // 允许选择多张图片，最多9张
    final maxAdd = 9 - (_currentLog.imageFileNames?.length ?? 0);
    if (maxAdd <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已达到最大图片数量限制（9张）')));
      return;
    }
    
    final pickedFiles = await picker.pickMultiImage(limit: maxAdd);
    if (pickedFiles.isEmpty) return;

    try {
      final newFileNames = <String>[];
      for (final pickedFile in pickedFiles) {
        final fileName = await ImageManager.saveImageToFile(pickedFile);
        newFileNames.add(fileName);
      }

      final currentFileNames = _currentLog.imageFileNames ?? [];
      final updatedFileNames = [...currentFileNames, ...newFileNames];

      final updatedLog = MoodLog(
        id: _currentLog.id,
        mood: _currentLog.mood,
        note: _currentLog.note,
        comment: _currentLog.comment,
        imageFileNames: updatedFileNames,
        createdAt: _currentLog.createdAt,
        aiComfort: _currentLog.aiComfort,
        aiEnabled: _aiEnabled,
      );

      await widget.box.put(_currentLog.id, updatedLog.toMap());

      if (mounted) {
        setState(() {
          _currentLog = updatedLog;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('图片已添加')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存图片失败: $e')));
      }
    }
  }

  Future<void> _removeImageAt(int index) async {
    if (_currentLog.imageFileNames == null || index < 0 || index >= _currentLog.imageFileNames!.length) return;

    // 删除图片文件
    await ImageManager.deleteImage(_currentLog.imageFileNames![index]);

    // 更新列表
    final updatedFileNames = List<String>.from(_currentLog.imageFileNames!);
    updatedFileNames.removeAt(index);

    final updatedLog = MoodLog(
      id: _currentLog.id,
      mood: _currentLog.mood,
      note: _currentLog.note,
      comment: _currentLog.comment,
      imageFileNames: updatedFileNames.isNotEmpty ? updatedFileNames : null,
      createdAt: _currentLog.createdAt,
      aiComfort: _currentLog.aiComfort,
      aiEnabled: _aiEnabled,
    );

    await widget.box.put(_currentLog.id, updatedLog.toMap());

    if (mounted) {
      setState(() {
        _currentLog = updatedLog;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片已删除')));
    }
  }

  void _viewFullImage(int index) async {
    if (_currentLog.imageFileNames == null || index < 0 || index >= _currentLog.imageFileNames!.length) return;
    
    final fileName = _currentLog.imageFileNames![index];
    final imagePath = await ImageManager.getImagePathAsync(fileName);
    if (imagePath.isEmpty || !await File(imagePath).exists()) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageView(
          imagePath: imagePath,
          imageFileNames: _currentLog.imageFileNames,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appBarColor =
        theme.colorScheme.inversePrimary ?? theme.colorScheme.primary;
    final appBarTextColor =
        theme.colorScheme.onPrimaryContainer ?? Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录详情'),
        backgroundColor: appBarColor,
        foregroundColor: appBarTextColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareMoodCard,
            tooltip: '分享心情卡片',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editOriginalLog,
            tooltip: '编辑心情和笔记',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                key: _cardKey,
                child: Card(
                  color: _currentLog.mood.bgColor,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  _currentLog.customColor ??
                                  _currentLog.mood.color,
                              child: _currentLog.customEmoji != null
                                  ? Text(
                                      _currentLog.customEmoji!,
                                      style: const TextStyle(fontSize: 24),
                                    )
                                  : Icon(
                                      _currentLog.mood.icon,
                                      color: Colors.white,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _currentLog.displayLabel,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.fontColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '笔记:',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: themeProvider.fontColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _currentLog.note.isNotEmpty
                              ? _currentLog.note
                              : '（无）',
                          style: TextStyle(
                            fontSize: 16,
                            color: themeProvider.fontColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '日期: ${_currentLog.createdAt.toString()}',
                          style: TextStyle(
                            color: themeProvider.fontColor.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_currentLog.imageFileNames != null && _currentLog.imageFileNames!.isNotEmpty) ...[
                const SizedBox(height: 24),
                // 多图片网格显示
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _currentLog.imageFileNames!.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        InkWell(
                          onTap: () => _viewFullImage(index),
                          borderRadius: BorderRadius.circular(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: FutureBuilder<String>(
                              future: ImageManager.getImagePathAsync(
                                _currentLog.imageFileNames![index],
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done &&
                                    snapshot.hasData &&
                                    File(snapshot.data!).existsSync()) {
                                  return Image.file(
                                    File(snapshot.data!),
                                    fit: BoxFit.cover,
                                  );
                                }
                                return Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                            ),
                          ),
                        ),
                        // 删除按钮
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImageAt(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                // 添加更多图片按钮
                if (_currentLog.imageFileNames!.length < 9)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _pickAndAddImages,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('添加更多图片'),
                    ),
                  ),
              ] else ...[
                const SizedBox(height: 24),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _pickAndAddImages,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('添加图片'),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'AI 机制',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: themeProvider.fontColor,
                    ),
                  ),
                  // TextButton(
                  //   onPressed: () {
                  //     if (_aiCardKey.currentContext != null) {
                  //       Scrollable.ensureVisible(
                  //         _aiCardKey.currentContext!,
                  //         duration: const Duration(milliseconds: 400),
                  //         alignment: 0.4,
                  //       );
                  //     }
                  //   },
                  //   child: const Text('让小暖居中'),
                  // ),
                ],
              ),

              // AI 开关
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: themeProvider.fontColor,
                              ),
                            ),
                            Text(
                              '让AI小暖为这条记录提供温暖的回应',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: themeProvider.fontColor.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: themeProvider.offlineMode ? false : _aiEnabled,
                        onChanged: themeProvider.offlineMode
                            ? null
                            : (value) => _saveAiEnabled(value),
                      ),
                    ],
                  ),
                ),
              ),
              if (themeProvider.offlineMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '当前处于断网模式，小暖回复已禁用。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              if (!themeProvider.offlineMode &&
                  (_aiResponse != null || _isLoadingAi)) ...[
                Container(
                  key: _aiCardKey,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.favorite, color: Colors.purple.shade300),
                          const SizedBox(width: 8),
                          Text(
                            '小暖对你说',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoadingAi)
                        const CircularProgressIndicator()
                      else
                        Text(
                          _aiResponse!,
                          style: TextStyle(
                            fontSize: 14,
                            color: themeProvider.fontColor,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 批注功能暂时屏蔽
              /*
            Text(
              '批注:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: '添加或编辑您的批注...',
                  hintStyle: TextStyle(color: theme.colorScheme.outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                ),
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                onChanged: (value) {
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (_commentController.text.trim() != _originalComment) {
                      _saveComment();
                    }
                  });
                },
              ),
            ),
            */
            ],
          ),
        ),
      ),
    );
  }
}
