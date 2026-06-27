// app_state.dart - 全局应用状态管理
import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';
import '../services/translation_service.dart';
import '../services/screen_capture_service.dart';
import '../services/tts_service.dart';
import '../services/connectivity_service.dart';
import '../services/database_service.dart';

class AppState extends ChangeNotifier {
  final AppSettingsService settings;
  final TranslationService translationService;
  final ScreenCaptureService screenCaptureService;
  final TtsService ttsService;
  final ConnectivityService connectivityService;
  final DatabaseService databaseService;
  
  // 状态标志
  bool _isOverlayEnabled = false;
  bool _isCapturing = false;
  String _lastCapturedText = '';
  String _currentTranslation = '';
  String _currentOriginalText = '';
  Offset _floatingBallPosition = const Offset(50, 200);
  Offset _popupPosition = const Offset(50, 300);
  bool _isPopupVisible = false;
  List<TranslationHistory> _history = [];
  
  AppState({
    required this.settings,
    required this.translationService,
    required this.screenCaptureService,
    required this.ttsService,
    required this.connectivityService,
    required this.databaseService,
  }) {
    _isDarkMode = settings.isDarkMode;
    _translationOpacity = settings.translationOpacity;
    _captureInterval = settings.captureInterval;
    _topCropHeight = settings.topCropHeight;
  }
  
  // Getter
  bool get isOverlayEnabled => _isOverlayEnabled;
  bool get isCapturing => _isCapturing;
  String get lastCapturedText => _lastCapturedText;
  String get currentTranslation => _currentTranslation;
  String get currentOriginalText => _currentOriginalText;
  Offset get floatingBallPosition => _floatingBallPosition;
  Offset get popupPosition => _popupPosition;
  bool get isPopupVisible => _isPopupVisible;
  List<TranslationHistory> get history => _history;
  
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  String _networkType = 'unknown';
  String get networkType => _networkType;
  
  late bool _isDarkMode;
  bool get isDarkMode => _isDarkMode;
  
  late double _translationOpacity;
  double get translationOpacity => _translationOpacity;
  
  late int _captureInterval;
  int get captureInterval => _captureInterval;
  
  late int _topCropHeight;
  int get topCropHeight => _topCropHeight;
  
  // Setter
  void setOverlayEnabled(bool value) {
    _isOverlayEnabled = value;
    notifyListeners();
  }
  
  void setCapturing(bool value) {
    _isCapturing = value;
    notifyListeners();
  }
  
  void setLastCapturedText(String text) {
    _lastCapturedText = text;
    notifyListeners();
  }
  
  void setCurrentTranslation(String original, String translation) {
    _currentOriginalText = original;
    _currentTranslation = translation;
    _isPopupVisible = true;
    notifyListeners();
  }
  
  void setFloatingBallPosition(Offset position) {
    _floatingBallPosition = position;
    notifyListeners();
  }
  
  void setPopupPosition(Offset position) {
    _popupPosition = position;
    notifyListeners();
  }
  
  void hidePopup() {
    _isPopupVisible = false;
    notifyListeners();
  }
  
  void showPopup() {
    _isPopupVisible = true;
    notifyListeners();
  }
  
  void setDarkMode(bool value) {
    _isDarkMode = value;
    settings.setDarkMode(value);
    notifyListeners();
  }
  
  void setTranslationOpacity(double value) {
    _translationOpacity = value;
    settings.setTranslationOpacity(value);
    notifyListeners();
  }
  
  void setCaptureInterval(int value) {
    _captureInterval = value;
    settings.setCaptureInterval(value);
    notifyListeners();
  }
  
  void setTopCropHeight(int value) {
    _topCropHeight = value;
    settings.setTopCropHeight(value);
    notifyListeners();
  }
  
  void setNetworkStatus(bool isConnected, String type) {
    _isConnected = isConnected;
    _networkType = type;
    notifyListeners();
  }
  
  void addToHistory(TranslationHistory item) {
    _history.insert(0, item);
    // 持久化到数据库（异步执行）
    databaseService.saveHistory(item.toMap()).catchError((_) {});
    notifyListeners();
  }
  
  Future<void> loadHistoryFromDb() async {
    final dbHistory = await databaseService.getHistory();
    _history = dbHistory.map((map) => TranslationHistory.fromMap(map)).toList();
    notifyListeners();
  }
  
  void loadHistory(List<TranslationHistory> items) {
    _history = items;
    notifyListeners();
  }
  
  void removeFromHistory(int index) {
    if (index < _history.length) {
      final item = _history[index];
      _history.removeAt(index);
      // 从数据库删除（安全处理ID可能为空的情况）
      if (item.id != null) {
        databaseService.deleteHistory(item.id!).catchError((_) {});
      }
      notifyListeners();
    }
  }
  
  void clearHistory() {
    _history.clear();
    databaseService.clearHistory().catchError((_) {});
    notifyListeners();
  }
  
  void speakText(String text, String language) {
    ttsService.speak(text, language);
  }
  
  @override
  void dispose() {
    screenCaptureService.dispose();
    ttsService.dispose();
    connectivityService.dispose();
    translationService.dispose();
    super.dispose();
  }
}

// 翻译历史记录模型
class TranslationHistory {
  final int? id;
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final DateTime timestamp;
  
  TranslationHistory({
    this.id,
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.timestamp,
  });
  
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'original_text': originalText,
      'translated_text': translatedText,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
  
  factory TranslationHistory.fromMap(Map<String, dynamic> map) {
    return TranslationHistory(
      id: map['id'] as int?,
      originalText: map['original_text'] as String,
      translatedText: map['translated_text'] as String,
      sourceLanguage: map['source_language'] as String,
      targetLanguage: map['target_language'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}
