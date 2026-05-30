import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/token_usage.dart';

class TokenUsageTracker {
  TokenUsageTracker._();

  static final TokenUsageTracker _instance = TokenUsageTracker._();
  static TokenUsageTracker get instance => _instance;

  final List<TokenUsage> _entries = [];
  bool _loaded = false;

  String? _filePath;

  Future<String> get _storagePath async {
    if (_filePath != null) return _filePath!;
    final appDir = await getApplicationDocumentsDirectory();
    _filePath = '${appDir.path}/token_usage.json';
    return _filePath!;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final path = await _storagePath;
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final list = jsonDecode(content) as List<dynamic>;
        for (final item in list) {
          _entries.add(TokenUsage.fromMap(item as Map<String, dynamic>));
        }
      }
    } catch (e) {
      debugPrint('TokenUsageTracker 加载失败: $e');
    }
  }

  Future<void> _save() async {
    try {
      final path = await _storagePath;
      final file = File(path);
      await file.writeAsString(
        jsonEncode(_entries.map((e) => e.toMap()).toList()),
      );
    } catch (e) {
      debugPrint('TokenUsageTracker 保存失败: $e');
    }
  }

  /// 记录一次 API 调用
  Future<void> record({
    required String source,
    required String model,
    required int promptTokens,
    required int completionTokens,
  }) async {
    await _ensureLoaded();
    _entries.add(TokenUsage(
      source: source,
      model: model,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: promptTokens + completionTokens,
      timestamp: DateTime.now(),
    ));
    await _save();
  }

  /// 本月统计
  Future<MonthlyStats> getMonthlyStats() async {
    await _ensureLoaded();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    int totalPrompt = 0;
    int totalCompletion = 0;
    int callCount = 0;

    for (final entry in _entries) {
      if (entry.timestamp.isAfter(monthStart) ||
          entry.timestamp.isAtSameMomentAs(monthStart)) {
        totalPrompt += entry.promptTokens;
        totalCompletion += entry.completionTokens;
        callCount++;
      }
    }

    return MonthlyStats(
      promptTokens: totalPrompt,
      completionTokens: totalCompletion,
      totalTokens: totalPrompt + totalCompletion,
      callCount: callCount,
    );
  }

  /// 本月按来源分类统计
  Future<Map<String, SourceStats>> getSourceBreakdown() async {
    await _ensureLoaded();
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final map = <String, SourceStats>{};

    for (final entry in _entries) {
      if (entry.timestamp.isAfter(monthStart) ||
          entry.timestamp.isAtSameMomentAs(monthStart)) {
        final stats = map.putIfAbsent(
          entry.source,
          () => SourceStats(source: entry.source),
        );
        stats.promptTokens += entry.promptTokens;
        stats.completionTokens += entry.completionTokens;
        stats.callCount++;
      }
    }

    return map;
  }

  /// 所有历史总统计
  Future<MonthlyStats> getTotalStats() async {
    await _ensureLoaded();
    int totalPrompt = 0;
    int totalCompletion = 0;

    for (final entry in _entries) {
      totalPrompt += entry.promptTokens;
      totalCompletion += entry.completionTokens;
    }

    return MonthlyStats(
      promptTokens: totalPrompt,
      completionTokens: totalCompletion,
      totalTokens: totalPrompt + totalCompletion,
      callCount: _entries.length,
    );
  }
}

class MonthlyStats {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final int callCount;

  MonthlyStats({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.callCount,
  });
}

class SourceStats {
  final String source;
  int promptTokens = 0;
  int completionTokens = 0;
  int callCount = 0;

  SourceStats({required this.source});

  int get totalTokens => promptTokens + completionTokens;
}
