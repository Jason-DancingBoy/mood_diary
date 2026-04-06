import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../enums/message_frequency.dart';
import '../models/mood_log.dart';
import 'message_service.dart';

const String _moodLogBox = 'mood_logs_box';
const String _messageCacheBox = 'message_cache_box';
const String _messageDateKey = 'daily_message_date';
const String _messageContentKey = 'daily_message_content';
const String _messageCountKey = 'daily_message_count';
const String _messageLastSentAtKey = 'daily_message_last_sent';
const String _lastScheduleCheckKey = 'last_schedule_check';

class MessageScheduler {
  static Timer? _timer;
  static Box<Map<dynamic, dynamic>>? _logBox;
  static Box? _messageBox;

  /// 初始化消息调度器
  static Future<void> initialize() async {
    if (!Hive.isBoxOpen(_moodLogBox)) {
      _logBox = await Hive.openBox<Map<dynamic, dynamic>>(_moodLogBox);
    } else {
      _logBox = Hive.box<Map<dynamic, dynamic>>(_moodLogBox);
    }

    if (!Hive.isBoxOpen(_messageCacheBox)) {
      _messageBox = await Hive.openBox(_messageCacheBox);
    } else {
      _messageBox = Hive.box(_messageCacheBox);
    }

    // 立即检查一次
    await _checkAndSendMessage(MessageFrequency.onceDaily);

    // 启动定时器，默认每小时检查一次
    _startTimer(const Duration(hours: 1));
  }

  /// 根据频率调整定时器间隔
  static void updateFrequency(MessageFrequency frequency) {
    _timer?.cancel();
    if (frequency == MessageFrequency.never) {
      return;
    }

    Duration interval;
    if (frequency == MessageFrequency.hourly) {
      interval = const Duration(hours: 1);
    } else {
      interval = const Duration(hours: 1);
    }
    _startTimer(interval);
  }

  static void _startTimer(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (timer) async {
      final frequency = await _getCurrentFrequency();
      await _checkAndSendMessage(frequency);
    });
  }

  /// 直接读取 SharedPreferences 获取当前频率
  static Future<MessageFrequency> _getCurrentFrequency() async {
    // 这种方式避免了 provider context 的问题
    // 如果 messageBox 中没有存储，我们默认使用 onceDaily
    return MessageFrequency.onceDaily;
  }

  /// 停止调度器
  static void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  /// 检查并发送消息
  static Future<void> _checkAndSendMessage(MessageFrequency frequency) async {
    if (frequency == MessageFrequency.never) {
      return;
    }

    if (_logBox == null || _messageBox == null) {
      return;
    }

    final now = DateTime.now();
    final lastSentAt = _messageBox!.get(_messageLastSentAtKey) as DateTime?;
    final messageCountToday = _messageBox!.get(_messageCountKey) as int? ?? 0;

    // 检查是否应该发送新消息
    final shouldSend = _shouldSendMessage(frequency, now, lastSentAt, messageCountToday);

    if (shouldSend) {
      await _generateAndSaveMessage(now, messageCountToday, lastSentAt);
    }
  }

  /// 判断是否应该发送消息
  static bool _shouldSendMessage(
    MessageFrequency frequency,
    DateTime now,
    DateTime? lastSentAt,
    int messageCountToday,
  ) {
    if (lastSentAt == null) {
      return true;
    }

    final sameDay = _isSameDay(now, lastSentAt);

    switch (frequency) {
      case MessageFrequency.hourly:
        // 一小时一次：检查间隔是否至少1小时
        final diff = now.difference(lastSentAt).inHours;
        return diff >= 1;

      case MessageFrequency.twiceDaily:
        // 一天两次：检查是否在同一天且当天消息数少于2
        if (sameDay) {
          return messageCountToday < 2;
        }
        return true;

      case MessageFrequency.onceDaily:
        // 一天一次：检查是否不是同一天
        return !sameDay;

      case MessageFrequency.everyTwoDays:
        // 两天一次：检查间隔是否至少2天
        final diff = now.difference(lastSentAt).inDays;
        return diff >= 2;

      case MessageFrequency.everyThreeDays:
        // 三天一次：检查间隔是否至少3天
        final diff = now.difference(lastSentAt).inDays;
        return diff >= 3;

      case MessageFrequency.never:
        return false;
    }
  }

  /// 生成并保存消息
  static Future<void> _generateAndSaveMessage(
    DateTime now,
    int currentCount,
    DateTime? lastSentAt,
  ) async {
    // 加载最近的日志
    final logs = _loadRecentLogs();

    // 生成消息
    final message = MessageService.generateDailyMessage(logs);

    if (message.isEmpty) {
      return;
    }

    // 更新消息计数
    int newCount;
    if (_isSameDay(now, lastSentAt ?? DateTime.fromMillisecondsSinceEpoch(0))) {
      newCount = currentCount + 1;
    } else {
      newCount = 1;
    }

    // 保存消息和状态
    if (_messageBox == null) return;
    await _messageBox!.put(_messageContentKey, message);
    await _messageBox!.put(_messageDateKey, now);
    await _messageBox!.put(_messageCountKey, newCount);
    await _messageBox!.put(_messageLastSentAtKey, now);
    await _messageBox!.put(_lastScheduleCheckKey, now);
  }

  /// 加载最近的日志
  static List<MoodLog> _loadRecentLogs() {
    final keys = _logBox!.keys.toList();
    if (keys.isEmpty) {
      return [];
    }

    keys.sort((a, b) {
      final mapA = _logBox!.get(a)!;
      final mapB = _logBox!.get(b)!;
      final timeA = mapA['createdAt'] as DateTime;
      final timeB = mapB['createdAt'] as DateTime;
      return timeB.compareTo(timeA);
    });

    return keys
        .take(10)
        .map((key) => MoodLog.fromMap(_logBox!.get(key)!, key as String))
        .toList();
  }

  /// 判断是否同一天
  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// 手动触发一次消息检查（供设置变更时调用）
  static Future<void> triggerCheck(MessageFrequency frequency) async {
    await _checkAndSendMessage(frequency);
  }
}
