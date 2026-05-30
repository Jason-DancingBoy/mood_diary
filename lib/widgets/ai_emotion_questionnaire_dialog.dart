import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_service.dart';
import '../providers/theme_provider.dart';
import '../enums/mood_quadrant.dart';

class AIEmotionQuestionnaireDialog extends StatefulWidget {
  const AIEmotionQuestionnaireDialog({super.key});

  @override
  State<AIEmotionQuestionnaireDialog> createState() =>
      _AIEmotionQuestionnaireDialogState();
}

class _AIEmotionQuestionnaireDialogState
    extends State<AIEmotionQuestionnaireDialog> {
  static const _questions = [
    '你现在感觉身体如何？是充满活力、疲惫不堪，还是平静中等？请描述你当下的精力状态。',
    '你现在的心情感受是怎样的？有没有什么具体的事情影响了你的情绪？',
    '如果用一句话概括你此刻的感受，你会怎么说？',
    '今天发生了什么特别的事情吗？这件事对你的情绪产生了什么影响？',
    '你希望维持现在的情绪状态，还是想做些什么来改变它？',
  ];

  int _currentIndex = 0;
  final List<String> _answers = ['', '', '', '', ''];
  final List<TextEditingController> _controllers = List.generate(
    5,
    (_) => TextEditingController(),
  );

  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _next() {
    // Save current answer
    _answers[_currentIndex] = _controllers[_currentIndex].text.trim();
    if (_answers[_currentIndex].isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先回答这个问题')),
      );
      return;
    }
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    } else {
      _submit();
    }
  }

  void _prev() {
    _answers[_currentIndex] = _controllers[_currentIndex].text.trim();
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final themeProvider = context.read<ThemeProvider>();
    final result = await AIService.analyzeEmotion(
      questions: _questions.toList(),
      answers: _answers.toList(),
      offlineMode: themeProvider.offlineMode,
      apiKey: themeProvider.apiKey,
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _isLoading = false;
        _result = result;
      });
    } else {
      setState(() {
        _isLoading = false;
        _error = '分析失败，请检查网络后重试';
      });
    }
  }

  void _confirm() {
    if (_result == null) return;
    final energy = (_result!['energy'] as double?) ?? 0;
    final pleasantness = (_result!['pleasantness'] as double?) ?? 0;
    Navigator.pop(context, {
      'energy': energy,
      'pleasantness': pleasantness,
      'emotionWord': _result!['emotionWord'] as String? ?? '',
      'quadrant': MoodQuadrant.fromEnergyPleasantness(energy, pleasantness).name,
      'triggerSummary': _result!['triggerSummary'] as String? ?? '',
      'q2Answer': _answers[1],
      'q4Answer': _answers[3],
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (_isLoading) return _buildLoading(theme);
    if (_result != null) return _buildResult(theme);
    if (_error != null) return _buildError(theme);
    return _buildQuestion(theme);
  }

  Widget _buildQuestion(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('AI 心情分析问卷', style: theme.textTheme.titleMedium),
                Text('${_currentIndex + 1}/${_questions.length}',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / _questions.length,
            ),
          ),
          const SizedBox(height: 8),
          // Question
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _questions[_currentIndex],
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Answer field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _controllers[_currentIndex],
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '请输入你的回答...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) {
                _answers[_currentIndex] = value;
              },
            ),
          ),
          const SizedBox(height: 16),
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _currentIndex > 0 ? _prev : null,
                  child: const Text('上一步'),
                ),
                ElevatedButton(
                  onPressed: _next,
                  child: Text(
                    _currentIndex == _questions.length - 1 ? '完成' : '下一步',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLoading(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text('正在分析你的心情...', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'AI 正在根据你的回答，从能量和愉悦度两个维度理解你的情绪',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildResult(ThemeData theme) {
    final energy = (_result!['energy'] as double?) ?? 0;
    final pleasantness = (_result!['pleasantness'] as double?) ?? 0;
    final emotionWord = _result!['emotionWord'] as String? ?? '';
    final analysis = _result!['analysis'] as String? ?? '';
    final quad = MoodQuadrant.fromEnergyPleasantness(energy, pleasantness);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          Text('分析完成', style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          // Result card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: quad.bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: quad.color.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: quad.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      emotionWord,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(quad.label, style: const TextStyle(fontSize: 12)),
                      backgroundColor: quad.color.withValues(alpha: 0.3),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '能量: ${energy.toStringAsFixed(1)}  愉悦度: ${pleasantness.toStringAsFixed(1)}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  analysis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: quad.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('确认并保存', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(_error ?? '未知错误', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('重试'),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
