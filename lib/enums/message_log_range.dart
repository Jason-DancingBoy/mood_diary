/// 消息读取心情记录的时间范围
enum MessageLogRange {
  threeDays,
  oneWeek,
  twoWeeks,
  oneMonth,
}

extension MessageLogRangeExtension on MessageLogRange {
  String get label {
    switch (this) {
      case MessageLogRange.threeDays:
        return '最近三天';
      case MessageLogRange.oneWeek:
        return '最近一周';
      case MessageLogRange.twoWeeks:
        return '最近两周';
      case MessageLogRange.oneMonth:
        return '最近一个月';
    }
  }

  int get days {
    switch (this) {
      case MessageLogRange.threeDays:
        return 3;
      case MessageLogRange.oneWeek:
        return 7;
      case MessageLogRange.twoWeeks:
        return 14;
      case MessageLogRange.oneMonth:
        return 30;
    }
  }

  int get storageIndex {
    return index;
  }

  static MessageLogRange fromIndex(int index) {
    if (index < 0 || index >= MessageLogRange.values.length) {
      return MessageLogRange.threeDays;
    }
    return MessageLogRange.values[index];
  }
}
