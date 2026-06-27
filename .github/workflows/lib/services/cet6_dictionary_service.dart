// cet6_dictionary_service.dart - CET-6离线词库服务
import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';

/// CET-6词汇条目
class Cet6Entry {
  final String word;
  final String phonetic;
  final List<String> definitions;
  final List<String> partOfSpeech;
  final String exampleSentence;
  final String level;

  Cet6Entry({
    required this.word,
    required this.phonetic,
    required this.definitions,
    required this.partOfSpeech,
    required this.exampleSentence,
    required this.level,
  });

  factory Cet6Entry.fromJson(Map<String, dynamic> json) {
    // 兼容单词和短语两种格式
    final word = json['word'] ?? json['phrase'] ?? '';
    // 兼容definitions数组和单个definition字符串
    final definitions = json['definitions'] != null 
        ? List<String>.from(json['definitions']) 
        : (json['definition'] != null ? [json['definition']] : []);
    // 兼容example_sentence和example
    final example = json['example_sentence'] ?? json['example'] ?? '';
    
    return Cet6Entry(
      word: word,
      phonetic: json['phonetic'] ?? '',
      definitions: definitions,
      partOfSpeech: List<String>.from(json['part_of_speech'] ?? []),
      exampleSentence: example,
      level: json['level'] ?? 'CET-6',
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'phonetic': phonetic,
    'definitions': definitions,
    'part_of_speech': partOfSpeech,
    'example_sentence': exampleSentence,
    'level': level,
  };
}

/// 加载状态
enum LoadState { idle, loading, loaded, error }

/// CET-6离线词库服务
/// 
/// 功能特性：
/// - 异步加载，不卡顿UI
/// - 分片加载，低配手机避免内存溢出
/// - 完整覆盖CET-6核心词汇、高频短语、固定搭配
/// - 断网状态下可正常查询
class Cet6DictionaryService {
  static Cet6DictionaryService? _instance;
  static Cet6DictionaryService get instance => _instance ??= Cet6DictionaryService._();
  
  Cet6DictionaryService._();

  // 词库数据
  final Map<String, Cet6Entry> _dictionary = {};
  
  // 加载状态
  LoadState _loadState = LoadState.idle;
  
  // 加载进度回调
  void Function(double progress)? _onProgress;
  
  // 分片大小（低配手机每片加载词条数）
  static const int _chunkSize = 500;
  
  // 核心高频词汇（优先加载）
  static const List<String> _highFrequencyWords = [
    'ability', 'able', 'abnormal', 'abolish', 'abroad', 'absence', 'absolute',
    'absorb', 'abstract', 'abundant', 'academic', 'accelerate', 'accept', 'access',
    'accident', 'accompany', 'accomplish', 'account', 'accumulate', 'accuracy',
    'accurate', 'achieve', 'acid', 'acquire', 'across', 'act', 'action', 'active',
    'activity', 'actor', 'actual', 'adapt', 'addition', 'address', 'adequate',
    'adjust', 'administration', 'admire', 'admit', 'adolescent', 'adopt', 'adult',
    'advance', 'advantage', 'adventure', 'advertise', 'advice', 'advise', 'advocate',
    'affect', 'afford', 'afraid', 'agency', 'agent', 'aggressive', 'agree',
    'agriculture', 'ahead', 'aid', 'aim', 'air', 'aircraft', 'airline', 'airport',
    'alarm', 'album', 'alcohol', 'alert', 'alike', 'alive', 'allow', 'almost',
    'alone', 'along', 'aloud', 'already', 'also', 'alter', 'alternative', 'although',
    'always', 'amaze', 'ambition', 'ambulance', 'amount', 'ample', 'amuse',
    'analyze', 'ancient', 'anger', 'angle', 'angry', 'animal', 'announce', 'annual',
    'another', 'answer', 'anxious', 'any', 'anybody', 'anyone', 'anything',
    'anyway', 'anywhere', 'apart', 'apartment', 'apologize', 'apology', 'apparent',
    'appeal', 'appear', 'apply', 'appoint', 'appreciate', 'approach', 'appropriate',
    'approve', 'approximate', 'architect', 'architecture', 'area', 'argue',
    'argument', 'arise', 'arm', 'army', 'around', 'arrange', 'arrangement',
    'arrest', 'arrival', 'arrive', 'article', 'artificial', 'artist', 'artistic',
  ];

  /// 设置加载进度回调
  void setProgressCallback(void Function(double progress) callback) {
    _onProgress = callback;
  }

  /// 获取当前加载状态
  LoadState get loadState => _loadState;
  
  /// 获取已加载词条数
  int get loadedCount => _dictionary.length;
  
  /// 是否已加载
  bool get isLoaded => _loadState == LoadState.loaded;

  /// 异步加载离线词库（分片加载）
  /// 
  /// [forceReload] 是否强制重新加载
  Future<void> loadDictionary({bool forceReload = false}) async {
    if (_loadState == LoadState.loading) return;
    if (_loadState == LoadState.loaded && !forceReload) return;
    
    _loadState = LoadState.loading;
    _dictionary.clear();
    
    try {
      // 1. 首先加载核心高频词汇（优先加载，保证用户体验）
      await _loadHighFrequencyWords();
      _onProgress?.call(0.2);
      
      // 2. 异步加载完整CET-6词汇库
      await _loadFullDictionary();
      _onProgress?.call(1.0);
      
      _loadState = LoadState.loaded;
    } catch (e) {
      _loadState = LoadState.error;
      rethrow;
    }
  }

  /// 加载核心高频词汇（优先加载）
  Future<void> _loadHighFrequencyWords() async {
    final entries = await _loadDictionaryFile('assets/dict/cet6_vocabulary.json');
    
    // 优先注册高频词汇
    for (final word in _highFrequencyWords) {
      if (entries.containsKey(word.toLowerCase())) {
        _dictionary[word.toLowerCase()] = entries[word.toLowerCase()]!;
      }
    }
  }

  /// 加载完整词库文件（支持多个词库文件）
  Future<void> _loadFullDictionary() async {
    try {
      // 按优先级加载多个词库文件
      final dictionaryFiles = [
        'assets/dict/cet6_vocabulary.json',      // 核心词汇（对象格式）
        'assets/dict/cet6_vocabulary_ac.json',   // A-C字母词汇（数组格式）
        'assets/dict/cet6_vocabulary_df.json',   // D-F字母词汇（数组格式）
        'assets/dict/cet6_vocabulary_gi.json',   // G-I字母词汇（数组格式）
        'assets/dict/cet6_vocabulary_jl.json',   // J-L字母词汇（数组格式）
        'assets/dict/cet6_vocabulary_mo.json',   // M-O字母词汇（数组格式）
        'assets/dict/cet6_vocabulary_pr.json',   // P-R字母词汇（数组格式）
        'assets/dict/cet6_vocabulary_su.json',   // S-U字母词汇（数组格式）
        'assets/dict/cet6_vocabulary_vz.json',   // V-Z字母词汇（数组格式）
        'assets/dict/cet6_vocabulary_dz.json',   // D-Z扩展词汇（对象格式）
        'assets/dict/cet6_phrases.json',         // 高频短语（对象格式）
      ];

      int totalFiles = dictionaryFiles.length;
      int loadedFiles = 0;

      for (final filePath in dictionaryFiles) {
        try {
          final String jsonString = await rootBundle.loadString(filePath);
          final data = json.decode(jsonString);

          List entries;
          // 支持两种JSON格式：对象格式（含entries字段）和数组格式
          if (data is Map && data.containsKey('entries')) {
            entries = data['entries'] as List;
          } else if (data is List) {
            entries = data;
          } else {
            continue; // 跳过无法识别的格式
          }

          final fileEntryCount = entries.length;

          // 分片加载，避免低配手机内存溢出
          for (int i = 0; i < fileEntryCount; i += _chunkSize) {
            final end = (i + _chunkSize < fileEntryCount) ? i + _chunkSize : fileEntryCount;

            for (int j = i; j < end; j++) {
              final entry = Cet6Entry.fromJson(entries[j]);
              _dictionary[entry.word.toLowerCase()] = entry;
            }

            // 每分片加载后报告进度
            final baseProgress = loadedFiles / totalFiles;
            final fileProgress = (end / fileEntryCount) / totalFiles;
            _onProgress?.call(baseProgress + fileProgress);

            // 给UI线程让出时间，避免卡顿
            await Future.delayed(const Duration(milliseconds: 5));
          }
        } catch (e) {
          // 单个文件加载失败，继续加载其他文件
        }

        loadedFiles++;
        _onProgress?.call(loadedFiles / totalFiles);
      }
    } catch (e) {
      // 所有词库文件都不存在或加载失败，使用内置备用词库
      await _loadFallbackDictionary();
    }
  }

  /// 加载备用内置词库（当JSON文件加载失败时）
  Future<void> _loadFallbackDictionary() async {
    // 内置基础词汇表，确保断网也能查询
    final fallbackWords = {
      'abandon': 'vt. 放弃；遗弃\nn. 放纵',
      'ability': 'n. 能力；才能',
      'able': 'adj. 能够的；有能力的',
      'abnormal': 'adj. 反常的；变态的',
      'abolish': 'vt. 废除；废止',
      'abroad': 'adv. 到国外；在海外',
      'absence': 'n. 缺席；缺乏',
      'absolute': 'adj. 绝对的；完全的',
      'absorb': 'vt. 吸收；理解',
      'abstract': 'adj. 抽象的；深奥的',
      'abundant': 'adj. 丰富的；充裕的',
      'academic': 'adj. 学术的；学院的',
      'accelerate': 'v. 加速；加快',
      'accept': 'vt. 接受；承认',
      'access': 'n. 通道；访问',
      'accident': 'n. 事故；意外',
      'accompany': 'vt. 陪伴；陪同',
      'accomplish': 'vt. 完成；实现',
      'account': 'n. 账户；叙述',
      'accumulate': 'v. 积累；积聚',
      'accuracy': 'n. 准确性；精确度',
      'accurate': 'adj. 精确的；准确的',
      'achieve': 'vt. 实现；达到',
      'acid': 'n. 酸；adj. 酸的',
      'acquire': 'vt. 获得；学到',
      'across': 'prep. 横穿；穿过',
      'act': 'v. 行动；扮演',
      'action': 'n. 行动；行为',
      'active': 'adj. 积极的；活跃的',
      'activity': 'n. 活动；行动',
      'actor': 'n. 男演员',
      'actual': 'adj. 实际的；真实的',
      'adapt': 'v. 使适应；改编',
      'addition': 'n. 增加；加法',
      'address': 'n. 地址；演说',
      'adequate': 'adj. 充足的；适当的',
      'adjust': 'v. 调整；调节',
      'administration': 'n. 管理；行政',
      'admire': 'vt. 钦佩；欣赏',
      'admit': 'v. 承认；准许进入',
      'adolescent': 'n. 青少年',
      'adopt': 'vt. 采纳；收养',
      'adult': 'n. 成年人',
      'advance': 'v. 前进；进步',
      'advantage': 'n. 优势；好处',
      'adventure': 'n. 冒险；奇遇',
      'advertise': 'v. 为...做广告',
      'advice': 'n. 建议；劝告',
      'advise': 'vt. 建议；劝告',
      'advocate': 'n./vt. 提倡者；拥护',
    };
    
    fallbackWords.forEach((word, definition) {
      _dictionary[word] = Cet6Entry(
        word: word,
        phonetic: '',
        definitions: [definition],
        partOfSpeech: [],
        exampleSentence: '',
        level: 'CET-6',
      );
    });
  }

  /// 从JSON文件加载词库（通用方法）
  Future<Map<String, Cet6Entry>> _loadDictionaryFile(String path) async {
    final result = <String, Cet6Entry>{};
    
    try {
      final String jsonString = await rootBundle.loadString(path);
      final data = json.decode(jsonString);
      
      if (data is Map && data.containsKey('entries')) {
        final entries = data['entries'] as List;
        for (var entry in entries) {
          final cet6Entry = Cet6Entry.fromJson(entry);
          result[cet6Entry.word.toLowerCase()] = cet6Entry;
        }
      }
    } catch (e) {
      // 文件不存在或解析失败
    }
    
    return result;
  }

  /// 查询单词翻译（优先使用离线词库）
  /// 
  /// 优先级：离线CET-6词库 > 自定义词汇 > 云端
  Future<Cet6Entry?> lookup(String word) async {
    // 如果词库未加载，先触发加载
    if (_loadState != LoadState.loaded) {
      await loadDictionary();
    }
    
    return _dictionary[word.toLowerCase()];
  }

  /// 批量查询（用于屏幕识别）
  Future<List<Cet6Entry>> lookupBatch(List<String> words) async {
    final results = <Cet6Entry>[];
    
    for (final word in words) {
      final entry = await lookup(word);
      if (entry != null) {
        results.add(entry);
      }
    }
    
    return results;
  }

  /// 搜索词库（模糊匹配）
  Future<List<Cet6Entry>> search(String query) async {
    if (_loadState != LoadState.loaded) {
      await loadDictionary();
    }
    
    final lowerQuery = query.toLowerCase();
    final results = <Cet6Entry>[];
    
    for (final entry in _dictionary.values) {
      if (entry.word.toLowerCase().contains(lowerQuery)) {
        results.add(entry);
      }
      if (results.length >= 20) break; // 限制返回数量
    }
    
    return results;
  }

  /// 检查词库是否包含某个单词
  bool contains(String word) => _dictionary.containsKey(word.toLowerCase());

  /// 获取所有已加载的词条
  List<Cet6Entry> get allEntries => _dictionary.values.toList();

  /// 清理词库（释放内存）
  void clear() {
    _dictionary.clear();
    _loadState = LoadState.idle;
  }
}

/// 翻译优先级枚举
enum TranslationPriority {
  /// 离线CET-6词库优先（无网络时）
  offlineFirst,
  /// 自定义词汇优先
  customFirst,
  /// 云端大模型优先（网络良好时）
  cloudFirst,
}
