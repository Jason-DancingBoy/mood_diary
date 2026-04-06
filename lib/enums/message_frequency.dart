enum MessageFrequency {
  hourly,
  twiceDaily,
  onceDaily,
  everyTwoDays,
  everyThreeDays,
  never,
}

extension MessageFrequencyExtension on MessageFrequency {
  String get label {
    switch (this) {
      case MessageFrequency.hourly:
        return '一小时一次';
      case MessageFrequency.twiceDaily:
        return '一天两次';
      case MessageFrequency.onceDaily:
        return '一天一次';
      case MessageFrequency.everyTwoDays:
        return '两天一次';
      case MessageFrequency.everyThreeDays:
        return '三天一次';
      case MessageFrequency.never:
        return '不发送';
    }
  }

  int get storageIndex {
    return index;
  }

  static MessageFrequency fromIndex(int index) {
    if (index < 0 || index >= MessageFrequency.values.length) {
      return MessageFrequency.onceDaily;
    }
    return MessageFrequency.values[index];
  }
}
