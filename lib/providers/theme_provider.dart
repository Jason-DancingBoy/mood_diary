import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/message_frequency.dart';
import '../enums/message_log_range.dart';

class ThemeProvider with ChangeNotifier {
  Color _fontColor = Colors.black;
  bool _offlineMode = false;
  MessageFrequency _messageFrequency = MessageFrequency.onceDaily;
  MessageLogRange _messageLogRange = MessageLogRange.threeDays;

  Color get fontColor => _fontColor;
  bool get offlineMode => _offlineMode;
  MessageFrequency get messageFrequency => _messageFrequency;
  MessageLogRange get messageLogRange => _messageLogRange;

  ThemeProvider() {
    _loadFontColor();
    _loadOfflineMode();
    _loadMessageFrequency();
    _loadMessageLogRange();
  }

  Future<void> _loadFontColor() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('fontColor') ?? Colors.black.toARGB32();
    _fontColor = Color(colorValue);
    notifyListeners();
  }

  Future<void> _loadOfflineMode() async {
    final prefs = await SharedPreferences.getInstance();
    _offlineMode = prefs.getBool('offlineMode') ?? false;
    notifyListeners();
  }

  Future<void> _loadMessageFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    final int index = prefs.getInt('messageFrequency') ?? MessageFrequency.onceDaily.index;
    _messageFrequency = MessageFrequencyExtension.fromIndex(index);
    notifyListeners();
  }

  Future<void> _loadMessageLogRange() async {
    final prefs = await SharedPreferences.getInstance();
    final int index = prefs.getInt('messageLogRange') ?? MessageLogRange.threeDays.index;
    _messageLogRange = MessageLogRangeExtension.fromIndex(index);
    notifyListeners();
  }

  Future<void> setFontColor(Color color) async {
    _fontColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fontColor', color.toARGB32());
  }

  Future<void> setMessageFrequency(MessageFrequency frequency) async {
    _messageFrequency = frequency;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('messageFrequency', frequency.storageIndex);
  }

  Future<void> setMessageLogRange(MessageLogRange range) async {
    _messageLogRange = range;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('messageLogRange', range.storageIndex);
  }

  Future<void> setOfflineMode(bool value) async {
    _offlineMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offlineMode', value);
  }
}