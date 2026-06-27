// translation_service.dart - 翻译服务（在线API + 离线词库）
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'database_service.dart';
import 'cet6_dictionary_service.dart';

class TranslationService {
  final DatabaseService _databaseService;
  final Dio _dio;
  final Cet6DictionaryService _cet6Service = Cet6DictionaryService.instance;
  
  bool _isOnline = true;
  List<CustomVocabulary>? _cachedVocabulary;
  DateTime? _vocabularyCacheTime;
  
  // 火山引擎API配置（豆包同源大模型）
  // 请在火山引擎控制台获取您的API密钥：https://console.volcengine.com/iam/keymanage/
  static const String VOLCENGINE_API_URL = 'https://translate.volcengineapi.com';
  static const String VOLCENGINE_API_KEY = 'YOUR_VOLCENGINE_API_KEY'; // 替换为您的Access Key ID
  static const String VOLCENGINE_API_SECRET = 'YOUR_VOLCENGINE_API_SECRET'; // 替换为您的Secret Access Key
  
  TranslationService(this._databaseService) : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  
  // 初始化CET-6离线词库（APP启动时异步加载，不卡顿UI）
  Future<void> initialize() async {
    try {
      // 设置加载进度回调
      _cet6Service.setProgressCallback((progress) {
        // 可以在这里更新加载进度UI
      });
      
      // 异步加载词库，不阻塞主线程
      await _cet6Service.loadDictionary();
    } catch (e) {
      // 词库加载失败，不影响APP启动
    }
  }
  
  // 获取CET-6词库加载状态
  bool get isCet6Loaded => _cet6Service.isLoaded;
  
  // 获取已加载词条数
  int get cet6LoadedCount => _cet6Service.loadedCount;
  
  // OCR识别后的文本预处理 - 单词拆分和错字修正
  String _preprocessOcrText(String text) {
    if (text.isEmpty) return text;
    
    // 清理多余空格和特殊字符
    String cleaned = text.trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\s\u4e00-\u9fff.,!?;:()""''，。！？；：（）「」【】]'), '')
        .replaceAll(RegExp(r'[.,!?;:]([^\s])'), r'$1 $2')
        .trim();
    
    // OCR常见错字修正表
    final ocrCorrections = {
      'l': 'I',  // 字母l可能是大写I
      'O': '0',  // 字母O可能是数字0
      '|': 'I',  // 竖线可能是I
      'rn': 'm',  // rn组合可能是m
      'vv': 'w',  // vv可能是w
    };
    
    // 修正常见OCR错误
    for (var entry in ocrCorrections.entries) {
      cleaned = cleaned.replaceAll(entry.key, entry.value);
    }
    
    return cleaned;
  }
  
  // 智能分词 - 根据中英文混合文本拆分单词
  List<String> _smartTokenize(String text) {
    final tokens = <String>[];
    final buffer = StringBuffer();
    bool lastWasChinese = false;
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final isChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(char);
      final isWordChar = RegExp(r'[a-zA-Z0-9\'-]').hasMatch(char);
      
      if (isChinese) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString().trim());
          buffer.clear();
        }
        // 中文按字符或词组分割（简单实现：连续中文作为一组）
        if (!lastWasChinese || tokens.isEmpty) {
          buffer.write(char);
        } else {
          tokens.add(buffer.toString().trim());
          buffer.clear();
          buffer.write(char);
        }
        lastWasChinese = true;
      } else if (isWordChar) {
        if (lastWasChinese && buffer.isNotEmpty) {
          tokens.add(buffer.toString().trim());
          buffer.clear();
        }
        buffer.write(char);
        lastWasChinese = false;
      } else {
        // 分隔符
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString().trim());
          buffer.clear();
        }
        lastWasChinese = false;
      }
    }
    
    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString().trim());
    }
    
    // 过滤空token
    return tokens.where((t) => t.isNotEmpty).toList();
  }
  
  // 检测文本语言
  LanguageType detectLanguage(String text) {
    final chineseChars = RegExp(r'[\u4e00-\u9fff]').allMatches(text).length;
    final englishChars = RegExp(r'[a-zA-Z]').allMatches(text).length;
    
    if (chineseChars > englishChars) {
      return LanguageType.chinese;
    } else if (englishChars > 0) {
      return LanguageType.english;
    } else {
      return LanguageType.english;  // 默认
    }
  }
  
  // 设置网络状态
  void setOnlineStatus(bool isOnline) {
    _isOnline = isOnline;
  }
  
  // 获取当前网络状态
  bool get isOnline => _isOnline;
  
  // 自动翻译（根据文本内容自动判断方向）
  // 翻译优先级：离线六级词库 > 自定义词汇 > 云端大模型
  Future<String> translate(String text, {bool? useOnline}) async {
    // 如果未指定，使用当前网络状态
    final shouldUseOnline = useOnline ?? _isOnline;
    if (text.trim().isEmpty) {
      return '';
    }
    
    // OCR预处理
    final processedText = _preprocessOcrText(text);
    if (processedText.isEmpty) {
      return '';
    }
    
    // 检测语言
    final sourceLang = detectLanguage(text);
    final targetLang = sourceLang == LanguageType.chinese 
        ? LanguageType.english 
        : LanguageType.chinese;
    
    // 优先级1：离线CET-6词库（无网络时优先使用）
    final cet6Result = await _translateWithCet6(text, sourceLang);
    if (cet6Result.isNotEmpty) {
      return cet6Result;
    }
    
    // 优先级2：自定义词汇库
    final customResult = await _checkCustomVocabulary(text);
    if (customResult != null) {
      return customResult;
    }
    
    // 优先级3：云端大模型（有网络时）
    if (shouldUseOnline) {
      try {
        final onlineResult = await _translateOnline(
          text,
          sourceLang == LanguageType.chinese ? 'zh' : 'en',
          targetLang == LanguageType.chinese ? 'zh' : 'en',
        );
        if (onlineResult.isNotEmpty) {
          return onlineResult;
        }
      } catch (e) {
        // 在线翻译失败，使用备用离线词库
      }
    }
    
    // 备用：原有离线基础词库
    final offlineResult = await _translateOffline(text, sourceLang);
    if (offlineResult.isNotEmpty) {
      return offlineResult;
    }
    
    return '';
  }
  
  // 使用CET-6离线词库翻译（优先级最高）
  Future<String> _translateWithCet6(String text, LanguageType sourceLang) async {
    try {
      if (text.isEmpty) return '';
      
      // 如果CET-6词库未加载，先触发异步加载
      if (!_cet6Service.isLoaded) {
        // 后台触发加载，不阻塞翻译
        _cet6Service.loadDictionary();
      }
      
      // 优先级1：先尝试完整短语匹配（支持空格分隔的短语如 "abide by"）
      final fullMatch = await _cet6Service.lookup(text.trim());
      if (fullMatch != null) {
        final parts = <String>[];
        parts.add(fullMatch.word);
        if (fullMatch.phonetic.isNotEmpty) {
          parts.add(fullMatch.phonetic);
        }
        if (fullMatch.definitions.isNotEmpty) {
          parts.add(fullMatch.definitions.join('; '));
        }
        if (fullMatch.exampleSentence.isNotEmpty) {
          parts.add('例句: ${fullMatch.exampleSentence}');
        }
        return parts.join('\n');
      }
      
      // 优先级2：智能分词查询
      final tokens = _smartTokenize(text);
      if (tokens.isEmpty) return '';
      
      final translations = <String>[];
      for (var token in tokens) {
        // 查询CET-6词库
        final entry = await _cet6Service.lookup(token);
        if (entry != null) {
          // 构建完整释义（多释义+词性+例句）
          final parts = <String>[];
          parts.add(entry.word);
          if (entry.phonetic.isNotEmpty) {
            parts.add(entry.phonetic);
          }
          if (entry.definitions.isNotEmpty) {
            parts.add(entry.definitions.join('; '));
          }
          if (entry.exampleSentence.isNotEmpty) {
            parts.add('例句: ${entry.exampleSentence}');
          }
          translations.add(parts.join('\n'));
        } else {
          // CET-6词库没有的单词，尝试基础词库
          final results = await _databaseService.searchDictionary(token);
          if (results.isNotEmpty) {
            if (sourceLang == LanguageType.chinese) {
              translations.add(results.map((e) => e.definition).join('; '));
            } else {
              translations.add(results.map((e) => '${e.simplified} ${e.pinyin}').join('; '));
            }
          } else {
            translations.add(token);
          }
        }
      }
      
      return translations.join('\n');
    } catch (e) {
      return '';
    }
  }
  
  // 在线翻译 - 火山引擎API（豆包同源大模型）
  // 覆盖百万级词汇：基础词汇、短语、俚语、专业术语、技术词汇
  Future<String> _translateOnline(String text, String from, String to) async {
    try {
      if (VOLCENGINE_API_KEY != 'YOUR_VOLCENGINE_API_KEY' && VOLCENGINE_API_SECRET != 'YOUR_VOLCENGINE_API_SECRET') {
        final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final nonce = _generateNonce();
        
        final queryParams = {
          'Action': 'TranslateText',
          'Version': '2020-06-01',
          'SourceLanguage': from,
          'TargetLanguage': to,
          'SourceText': text,
          'AccessKeyId': VOLCENGINE_API_KEY,
          'Timestamp': timestamp.toString(),
          'Nonce': nonce,
        };
        
        final signature = _generateSignature(queryParams);
        queryParams['Signature'] = signature;
        
        final url = Uri.parse(VOLCENGINE_API_URL).replace(queryParameters: queryParams);
        
        final response = await _dio.get(
          url.toString(),
          options: Options(
            headers: {
              'Content-Type': 'application/json',
            },
          ),
        );
        
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data;
          if (data['ResponseMetadata']?['Error'] == null) {
            if (data['TranslationList'] != null && (data['TranslationList'] as List).isNotEmpty) {
              return data['TranslationList'][0]['Translation'] as String;
            }
          }
        }
      }
      
      return await _translateWithMyMemory(text, from, to);
      
    } catch (e) {
      return '';
    }
  }
  
  String _generateNonce() {
    final random = Random();
    return random.nextInt(999999999).toString();
  }
  
  String _generateSignature(Map<String, dynamic> params) {
    final sortedKeys = params.keys.toList()..sort();
    final queryString = sortedKeys.map((key) => '$key=${Uri.encodeComponent(params[key].toString())}').join('&');
    final stringToSign = 'GET\n/translate\n$queryString';
    
    final hmac = Hmac(sha256, VOLCENGINE_API_SECRET.codeUnits);
    final digest = hmac.convert(stringToSign.codeUnits);
    return base64.encode(digest.bytes);
  }
  
  // MyMemory免费翻译API（备用）
  Future<String> _translateWithMyMemory(String text, String from, String to) async {
    try {
      final langPair = '$from|$to';
      final url = 'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=${Uri.encodeComponent(langPair)}';
      
      final response = await _dio.get(url);
      
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['responseStatus'] == 200 && data['responseData'] != null) {
          return data['responseData']['translatedText'] as String;
        }
      }
      
      return '';
    } catch (e) {
      return '';
    }
  }
  
  // 离线词库翻译
  Future<String> _translateOffline(String text, LanguageType sourceLang) async {
    try {
      if (text.isEmpty) return '';
      
      // 使用智能分词
      final tokens = _smartTokenize(text);
      
      if (tokens.isEmpty) return '';
      
      // 查询词典 - 遍历所有分词
      final translations = <String>[];
      for (var token in tokens) {
        final results = await _databaseService.searchDictionary(token);
        if (results.isNotEmpty) {
          if (sourceLang == LanguageType.chinese) {
            translations.add(results.map((e) => e.definition).join('; '));
          } else {
            translations.add(results.map((e) => '${e.simplified} ${e.pinyin}').join('; '));
          }
        } else {
          translations.add(token);
        }
      }
      
      return translations.join(' ');
    } catch (e) {
      return '';
    }
  }
  
  // 检查自定义词汇库（带缓存）
  Future<String?> _checkCustomVocabulary(String text) async {
    try {
      if (text.isEmpty) return null;
      
      final now = DateTime.now();
      // 缓存有效期5分钟
      if (_cachedVocabulary == null || 
          _vocabularyCacheTime == null || 
          now.difference(_vocabularyCacheTime!) > const Duration(minutes: 5)) {
        _cachedVocabulary = await _databaseService.getCustomVocabulary();
        _vocabularyCacheTime = now;
      }
      
      final lowerText = text.toLowerCase();
      
      for (var item in _cachedVocabulary!) {
        final lowerWord = item.word.toLowerCase();
        // 精确匹配优先
        if (lowerWord == lowerText) {
          return item.translation;
        }
        // 单词边界匹配（避免子串误匹配）
        if (RegExp(r'\b' + RegExp.escape(lowerWord) + r'\b').hasMatch(lowerText)) {
          return item.translation;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // 批量翻译（并发控制，最大并发数5）
  Future<List<TranslationResult>> translateBatch(
    List<String> texts, {
    bool? useOnline,
  }) async {
    final results = <TranslationResult>[];
    const maxConcurrency = 5;
    
    for (var i = 0; i < texts.length; i += maxConcurrency) {
      final batch = texts.sublist(i, i + maxConcurrency > texts.length ? texts.length : i + maxConcurrency);
      final futures = batch.map((text) async {
        final translation = await translate(text, useOnline: useOnline);
        return TranslationResult(
          original: text,
          translated: translation,
          sourceLanguage: detectLanguage(text) == LanguageType.chinese ? 'zh' : 'en',
          targetLanguage: detectLanguage(text) == LanguageType.chinese ? 'en' : 'zh',
        );
      });
      results.addAll(await Future.wait(futures));
    }
    
    return results;
  }
  
  // 翻译单词（带发音）
  Future<WordTranslation> translateWord(String word, {bool? useOnline}) async {
    final lang = detectLanguage(word);
    final translation = await translate(word, useOnline: useOnline);
    
    return WordTranslation(
      word: word,
      translation: translation,
      language: lang,
      hasPinyin: lang == LanguageType.chinese,
    );
  }
  
  void dispose() {
    _dio.close();
  }
}

// 语言类型枚举
enum LanguageType {
  chinese,
  english,
}

// 翻译结果
class TranslationResult {
  final String original;
  final String translated;
  final String sourceLanguage;
  final String targetLanguage;
  
  TranslationResult({
    required this.original,
    required this.translated,
    required this.sourceLanguage,
    required this.targetLanguage,
  });
}

// 单词翻译结果
class WordTranslation {
  final String word;
  final String translation;
  final LanguageType language;
  final bool hasPinyin;
  
  WordTranslation({
    required this.word,
    required this.translation,
    required this.language,
    required this.hasPinyin,
  });
}
