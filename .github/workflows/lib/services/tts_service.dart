// tts_service.dart - 文字转语音服务
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  
  // 当前语言
  String _currentLanguage = 'en-US';
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    // 设置默认参数
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    
    // 设置支持的语言
    await _flutterTts.setLanguage('en-US');
    
    // 监听状态
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });
    
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
    
    _isInitialized = true;
  }
  
  // 朗读文本
  Future<void> speak(String text, [String? language]) async {
    if (text.trim().isEmpty) {
      return;
    }
    
    if (!_isInitialized) {
      await init();
    }
    
    if (_isSpeaking) {
      await stop();
    }
    
    // 根据语言设置语音
    if (language != null) {
      await setLanguage(language);
    }
    
    await _flutterTts.speak(text);
  }
  
  // 停止朗读
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }
  
  // 暂停朗读
  Future<void> pause() async {
    await _flutterTts.pause();
    _isSpeaking = false;
  }
  
  // 设置语言
  Future<void> setLanguage(String language) async {
    String flutterLang;
    
    if (language.contains('zh') || language.contains('chinese')) {
      flutterLang = 'zh-CN';
    } else if (language.contains('en') || language.contains('english')) {
      flutterLang = 'en-US';
    } else {
      flutterLang = 'en-US';
    }
    
    await _flutterTts.setLanguage(flutterLang);
    _currentLanguage = flutterLang;
  }
  
  // 设置语速
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0));
  }
  
  // 设置音量
  Future<void> setVolume(double volume) async {
    await _flutterTts.setVolume(volume.clamp(0.0, 1.0));
  }
  
  // 设置音调
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch.clamp(0.5, 2.0));
  }
  
  // 获取支持的语言列表
  Future<List<dynamic>> getLanguages() async {
    return await _flutterTts.getLanguages;
  }
  
  // 获取当前是否正在朗读
  bool get isSpeaking => _isSpeaking;
  
  // 获取当前语言
  String get currentLanguage => _currentLanguage;
  
  // 测试语音
  Future<void> testVoice() async {
    await speak('This is a test', 'en-US');
  }
  
  // 朗读中文
  Future<void> speakChinese(String text) async {
    await setLanguage('zh-CN');
    await speak(text);
  }
  
  // 朗读英文
  Future<void> speakEnglish(String text) async {
    await setLanguage('en-US');
    await speak(text);
  }
  
  // 朗读单词（自动判断语言）
  Future<void> speakWord(String word) async {
    // 判断是否为中文
    final isChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(word);
    
    if (isChinese) {
      await speakChinese(word);
    } else {
      await speakEnglish(word);
    }
  }
  
  void dispose() {
    _flutterTts.stop();
    _flutterTts.close();
    _isInitialized = false;
  }
}
