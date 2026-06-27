// app_settings_service.dart - 应用设置管理
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  final SharedPreferences _prefs;
  
  // 设置键名
  static const String KEY_DARK_MODE = 'dark_mode';
  static const String KEY_TRANSLATION_OPACITY = 'translation_opacity';
  static const String KEY_CAPTURE_INTERVAL = 'capture_interval';
  static const String KEY_TOP_CROP_HEIGHT = 'top_crop_height';
  static const String KEY_FIRST_LAUNCH = 'first_launch';
  static const String KEY_OVERLAY_PERMISSION_GRANTED = 'overlay_permission_granted';
  static const String KEY_CUSTOM_VOCABULARY = 'custom_vocabulary';
  
  AppSettingsService(this._prefs);
  
  // 夜间模式
  bool get isDarkMode => _prefs.getBool(KEY_DARK_MODE) ?? false;
  void setDarkMode(bool value) => _prefs.setBool(KEY_DARK_MODE, value);
  
  // 译文透明度
  double get translationOpacity => _prefs.getDouble(KEY_TRANSLATION_OPACITY) ?? 0.9;
  void setTranslationOpacity(double value) => _prefs.setDouble(KEY_TRANSLATION_OPACITY, value);
  
  // 识别间隔（秒）
  int get captureInterval => _prefs.getInt(KEY_CAPTURE_INTERVAL) ?? 2;
  void setCaptureInterval(int value) => _prefs.setInt(KEY_CAPTURE_INTERVAL, value);
  
  // 顶部裁剪高度（像素）
  int get topCropHeight => _prefs.getInt(KEY_TOP_CROP_HEIGHT) ?? 0;
  void setTopCropHeight(int value) => _prefs.setInt(KEY_TOP_CROP_HEIGHT, value);
  
  // 首次启动标志
  bool get isFirstLaunch => _prefs.getBool(KEY_FIRST_LAUNCH) ?? true;
  void setFirstLaunch(bool value) => _prefs.setBool(KEY_FIRST_LAUNCH, value);
  
  // 悬浮窗权限已授权标志
  bool get overlayPermissionGranted => _prefs.getBool(KEY_OVERLAY_PERMISSION_GRANTED) ?? false;
  void setOverlayPermissionGranted(bool value) => _prefs.setBool(KEY_OVERLAY_PERMISSION_GRANTED, value);
  
  // 自定义词汇库
  List<String> get customVocabulary {
    return _prefs.getStringList(KEY_CUSTOM_VOCABULARY) ?? [];
  }
  
  void addCustomVocabulary(String word) {
    final list = customVocabulary;
    if (!list.contains(word)) {
      list.add(word);
      _prefs.setStringList(KEY_CUSTOM_VOCABULARY, list);
    }
  }
  
  void removeCustomVocabulary(String word) {
    final list = customVocabulary;
    list.remove(word);
    _prefs.setStringList(KEY_CUSTOM_VOCABULARY, list);
  }
  
  void importCustomVocabulary(List<String> words) {
    final list = customVocabulary;
    for (var word in words) {
      if (!list.contains(word)) {
        list.add(word);
      }
    }
    _prefs.setStringList(KEY_CUSTOM_VOCABULARY, list);
  }
  
  void clearCustomVocabulary() {
    _prefs.setStringList(KEY_CUSTOM_VOCABULARY, []);
  }
  
  // 重置所有设置
  void resetAllSettings() {
    setDarkMode(false);
    setTranslationOpacity(0.9);
    setCaptureInterval(2);
    setTopCropHeight(0);
  }
}
