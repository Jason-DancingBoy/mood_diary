import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../enums/message_frequency.dart';
import '../enums/message_log_range.dart';

class ThemeProvider with ChangeNotifier {
  Color _fontColor = Colors.black;
  bool _offlineMode = false;
  MessageFrequency _messageFrequency = MessageFrequency.onceDaily;
  MessageLogRange _messageLogRange = MessageLogRange.threeDays;
  bool _nightMode = false;
  bool _followSystem = true; // 默认为跟随系统
  Color? _previousFontColor; // 用于保存关闭夜间模式前的字体颜色
  String _apiKey = '';
  Color? _userBubbleColor;
  Color? _otherBubbleColor;
  String? _chatBgPath;
  bool _showMoodToFriends = true;
  bool _luoBoInterventionEnabled = false;
  bool _useTraditionalChinese = false;
  bool _ttsEnabled = false;
  String _ttsVoiceId = '';
  String _ttsApiKey = '';
  String _realtimeAppId = '';
  String _realtimeAccessToken = '';
  bool _noEssayMode = false;
  bool _proactiveChatEnabled = false;
  bool _voiceEmotionEnabled = true;

  Color get fontColor => _fontColor;
  Color? get userBubbleColor => _userBubbleColor;
  Color? get otherBubbleColor => _otherBubbleColor;
  String? get chatBgPath => _chatBgPath;
  bool get offlineMode => _offlineMode;
  MessageFrequency get messageFrequency => _messageFrequency;
  MessageLogRange get messageLogRange => _messageLogRange;
  bool get nightMode => _nightMode;
  bool get followSystem => _followSystem;
  String get apiKey => _apiKey;
  bool get showMoodToFriends => _showMoodToFriends;
  bool get luoBoInterventionEnabled => _luoBoInterventionEnabled;
  bool get useTraditionalChinese => _useTraditionalChinese;
  bool get ttsEnabled => _ttsEnabled;
  String get ttsVoiceId => _ttsVoiceId;
  String get ttsApiKey => _ttsApiKey;
  String get realtimeAppId => _realtimeAppId;
  String get realtimeAccessToken => _realtimeAccessToken;
  bool get noEssayMode => _noEssayMode;
  bool get proactiveChatEnabled => _proactiveChatEnabled;
  bool get voiceEmotionEnabled => _voiceEmotionEnabled;

  ThemeProvider() {
    _loadFontColor();
    _loadOfflineMode();
    _loadMessageFrequency();
    _loadMessageLogRange();
    _loadNightMode();
    _loadFollowSystem();
    _loadApiKey();
    _loadBubbleColors();
    _loadChatBg();
    _loadShowMoodToFriends();
    _loadLuoBoInterventionEnabled();
    _loadUseTraditionalChinese();
    _loadTtsEnabled();
    _loadTtsVoiceId();
    _loadTtsApiKey();
    _loadRealtimeAppId();
    _loadRealtimeAccessToken();
    _loadNoEssayMode();
    _loadProactiveChatEnabled();
    _loadVoiceEmotionEnabled();
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

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('apiKey') ?? '';
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

  Future<void> setApiKey(String value) async {
    _apiKey = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', value);
  }

  Future<void> clearApiKey() async {
    _apiKey = '';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('apiKey');
  }

  /// 导入 JSON 配置，一键设置所有 API 密钥。
  /// 返回 null 表示全部成功，否则返回错误信息。
  /// 支持的 JSON 格式：
  /// {
  ///   "apiKey": "sk-...",           // DeepSeek API Key
  ///   "ttsVoiceId": "...",          // 火山引擎音色 ID
  ///   "ttsApiKey": "...",           // 火山引擎 API Key
  ///   "realtimeAppId": "...",       // 火山引擎实时语音 App ID
  ///   "realtimeAccessToken": "..."  // 火山引擎实时语音 Access Token
  /// }
  /// 所有字段均可选，只更新提供的字段。
  Future<String?> importApiConfig(String jsonText) async {
    if (jsonText.trim().isEmpty) return '配置文本为空';

    Map<String, dynamic> config;
    try {
      config = jsonDecode(jsonText.trim()) as Map<String, dynamic>;
    } catch (e) {
      return 'JSON 格式无效，请检查后重试';
    }

    final prefs = await SharedPreferences.getInstance();

    if (config.containsKey('apiKey')) {
      final v = config['apiKey'];
      if (v is String && v.isNotEmpty) {
        _apiKey = v;
        await prefs.setString('apiKey', v);
      } else {
        return 'apiKey 字段无效（需要非空字符串）';
      }
    }

    if (config.containsKey('ttsApiKey')) {
      final v = config['ttsApiKey'];
      if (v is String && v.isNotEmpty) {
        _ttsApiKey = v;
        await prefs.setString('ttsApiKey', v);
      } else {
        return 'ttsApiKey 字段无效（需要非空字符串）';
      }
    }

    if (config.containsKey('ttsVoiceId')) {
      final v = config['ttsVoiceId'];
      if (v is String && v.isNotEmpty) {
        _ttsVoiceId = v;
        await prefs.setString('ttsVoiceId', v);
      } else {
        return 'ttsVoiceId 字段无效（需要非空字符串）';
      }
    }

    if (config.containsKey('realtimeAppId')) {
      final v = config['realtimeAppId'];
      if (v is String && v.isNotEmpty) {
        _realtimeAppId = v;
        await prefs.setString('realtimeAppId', v);
      } else {
        return 'realtimeAppId 字段无效（需要非空字符串）';
      }
    }

    if (config.containsKey('realtimeAccessToken')) {
      final v = config['realtimeAccessToken'];
      if (v is String && v.isNotEmpty) {
        _realtimeAccessToken = v;
        await prefs.setString('realtimeAccessToken', v);
      } else {
        return 'realtimeAccessToken 字段无效（需要非空字符串）';
      }
    }

    notifyListeners();
    return null;
  }

  Future<void> _loadNightMode() async {
    final prefs = await SharedPreferences.getInstance();
    _nightMode = prefs.getBool('nightMode') ?? false;
    notifyListeners();
  }

  Future<void> setNightMode(bool value) async {
    _nightMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nightMode', value);
    
    if (value) {
      // 开启夜间模式：保存当前字体颜色，并设置为白色
      _previousFontColor = _fontColor;
      setFontColor(Colors.white);
    } else {
      // 关闭夜间模式：恢复之前保存的字体颜色，或使用默认黑色
      final restoreColor = _previousFontColor ?? Colors.black;
      setFontColor(restoreColor);
    }
  }

  Future<void> _loadFollowSystem() async {
    final prefs = await SharedPreferences.getInstance();
    _followSystem = prefs.getBool('followSystem') ?? true; // 默认跟随系统
    notifyListeners();
  }

  Future<void> setFollowSystem(bool value) async {
    _followSystem = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('followSystem', value);
  }

  Future<void> _loadBubbleColors() async {
    final prefs = await SharedPreferences.getInstance();
    final userColor = prefs.getInt('userBubbleColor');
    _userBubbleColor = userColor != null ? Color(userColor) : null;
    final otherColor = prefs.getInt('otherBubbleColor');
    _otherBubbleColor = otherColor != null ? Color(otherColor) : null;
    notifyListeners();
  }

  Future<void> setUserBubbleColor(Color? color) async {
    _userBubbleColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (color != null) {
      await prefs.setInt('userBubbleColor', color.toARGB32());
    } else {
      await prefs.remove('userBubbleColor');
    }
  }

  Future<void> setOtherBubbleColor(Color? color) async {
    _otherBubbleColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (color != null) {
      await prefs.setInt('otherBubbleColor', color.toARGB32());
    } else {
      await prefs.remove('otherBubbleColor');
    }
  }

  Future<void> _loadChatBg() async {
    final prefs = await SharedPreferences.getInstance();
    _chatBgPath = prefs.getString('chatBgPath');
    notifyListeners();
  }

  Future<void> setChatBgPath(String? path) async {
    _chatBgPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      await prefs.setString('chatBgPath', path);
    } else {
      await prefs.remove('chatBgPath');
    }
  }

  Future<void> _loadShowMoodToFriends() async {
    final prefs = await SharedPreferences.getInstance();
    _showMoodToFriends = prefs.getBool('showMoodToFriends') ?? true;
    notifyListeners();
  }

  Future<void> setShowMoodToFriends(bool value) async {
    _showMoodToFriends = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showMoodToFriends', value);
  }

  Future<void> _loadLuoBoInterventionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _luoBoInterventionEnabled = prefs.getBool('luoBoInterventionEnabled') ?? false;
    notifyListeners();
  }

  Future<void> setLuoBoInterventionEnabled(bool value) async {
    _luoBoInterventionEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('luoBoInterventionEnabled', value);
  }

  Future<void> _loadUseTraditionalChinese() async {
    final prefs = await SharedPreferences.getInstance();
    _useTraditionalChinese = prefs.getBool('useTraditionalChinese') ?? false;
    notifyListeners();
  }

  Future<void> setUseTraditionalChinese(bool value) async {
    _useTraditionalChinese = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useTraditionalChinese', value);
  }

  void toggleTraditionalChinese() {
    setUseTraditionalChinese(!_useTraditionalChinese);
  }

  Future<void> _loadTtsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _ttsEnabled = prefs.getBool('ttsEnabled') ?? false;
    notifyListeners();
  }

  Future<void> setTtsEnabled(bool value) async {
    _ttsEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ttsEnabled', value);
  }

  Future<void> _loadTtsVoiceId() async {
    final prefs = await SharedPreferences.getInstance();
    _ttsVoiceId = prefs.getString('ttsVoiceId') ?? '';
    notifyListeners();
  }

  Future<void> setTtsVoiceId(String value) async {
    _ttsVoiceId = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ttsVoiceId', value);
  }

  Future<void> _loadTtsApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _ttsApiKey = prefs.getString('ttsApiKey') ?? '';
    notifyListeners();
  }

  Future<void> setTtsApiKey(String value) async {
    _ttsApiKey = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ttsApiKey', value);
  }

  Future<void> _loadRealtimeAppId() async {
    final prefs = await SharedPreferences.getInstance();
    _realtimeAppId = prefs.getString('realtimeAppId') ?? '';
    notifyListeners();
  }

  Future<void> setRealtimeAppId(String value) async {
    _realtimeAppId = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('realtimeAppId', value);
  }

  Future<void> _loadRealtimeAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    _realtimeAccessToken = prefs.getString('realtimeAccessToken') ?? '';
    notifyListeners();
  }

  Future<void> setRealtimeAccessToken(String value) async {
    _realtimeAccessToken = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('realtimeAccessToken', value);
  }

  Future<void> _loadNoEssayMode() async {
    final prefs = await SharedPreferences.getInstance();
    _noEssayMode = prefs.getBool('noEssayMode') ?? false;
    notifyListeners();
  }

  Future<void> setNoEssayMode(bool value) async {
    _noEssayMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('noEssayMode', value);
  }

  Future<void> _loadProactiveChatEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _proactiveChatEnabled = prefs.getBool('proactiveChatEnabled') ?? false;
    notifyListeners();
  }

  Future<void> setProactiveChatEnabled(bool value) async {
    _proactiveChatEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('proactiveChatEnabled', value);
  }

  Future<void> _loadVoiceEmotionEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    _voiceEmotionEnabled = prefs.getBool('voiceEmotionEnabled') ?? true;
    notifyListeners();
  }

  Future<void> setVoiceEmotionEnabled(bool value) async {
    _voiceEmotionEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voiceEmotionEnabled', value);
  }

}