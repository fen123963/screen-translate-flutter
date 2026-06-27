// database_service.dart - SQLite数据库服务（离线词库）
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../data/vocabulary_data.dart';

class DatabaseService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<void> init() async {
    await database;
  }
  
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'cedict.db');
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // 创建CC-CEDICT词典表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cedict (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        traditional TEXT NOT NULL,
        simplified TEXT NOT NULL,
        pinyin TEXT NOT NULL,
        definition TEXT NOT NULL,
        UNIQUE(simplified, traditional)
      )
    ''');
    
    // 创建索引提高查询速度
    await db.execute('CREATE INDEX IF NOT EXISTS idx_simplified ON cedict(simplified)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_traditional ON cedict(traditional)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_definition ON cedict(definition)');
    
    // 创建自定义词汇表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS custom_vocabulary (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL UNIQUE,
        translation TEXT,
        category TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    
    // 创建翻译历史表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS translation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        original_text TEXT NOT NULL,
        translated_text TEXT NOT NULL,
        source_language TEXT NOT NULL,
        target_language TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
    ''');
    
    await db.execute('CREATE INDEX IF NOT EXISTS idx_timestamp ON translation_history(timestamp DESC)');
    
    // 初始化内置词典数据
    await _initBuiltinDictionary(db);
  }
  
  Future<void> _initBuiltinDictionary(Database db) async {
    await db.transaction((txn) async {
      for (var word in ccCedictData) {
        try {
          await txn.insert('cedict', word);
        } catch (e) {
          // ignore duplicate insert
        }
      }
    });
  }
  
  // 离线词典查询
  Future<List<DictionaryEntry>> searchDictionary(String query) async {
    final db = await database;
    final results = await db.query(
      'cedict',
      where: 'simplified LIKE ? OR traditional LIKE ? OR definition LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      limit: 20,
    );
    
    return results.map((map) => DictionaryEntry.fromMap(map)).toList();
  }
  
  // 添加自定义词汇
  Future<void> addCustomVocabulary(String word, String? translation, String? category) async {
    final db = await database;
    await db.insert(
      'custom_vocabulary',
      {
        'word': word,
        'translation': translation,
        'category': category,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // 获取自定义词汇
  Future<List<CustomVocabulary>> getCustomVocabulary() async {
    final db = await database;
    final results = await db.query('custom_vocabulary', orderBy: 'created_at DESC');
    return results.map((map) => CustomVocabulary.fromMap(map)).toList();
  }
  
  // 删除自定义词汇
  Future<void> deleteCustomVocabulary(int id) async {
    final db = await database;
    await db.delete('custom_vocabulary', where: 'id = ?', whereArgs: [id]);
  }
  
  // 批量导入自定义词汇
  Future<void> importCustomVocabulary(List<Map<String, String>> words) async {
    final db = await database;
    final batch = db.batch();
    
    for (var word in words) {
      final wordText = word['word'];
      if (wordText == null || wordText.isEmpty) continue;
      
      batch.insert(
        'custom_vocabulary',
        {
          'word': wordText,
          'translation': word['translation'],
          'category': word['category'],
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    
    await batch.commit(noResult: true);
  }
  
  // 保存翻译历史
  Future<void> saveHistory(Map<String, dynamic> history) async {
    final db = await database;
    await db.insert('translation_history', history, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  
  // 获取翻译历史
  Future<List<Map<String, dynamic>>> getHistory({int limit = 100}) async {
    final db = await database;
    final results = await db.query(
      'translation_history',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results;
  }
  
  // 删除单条历史
  Future<void> deleteHistory(int id) async {
    final db = await database;
    await db.delete('translation_history', where: 'id = ?', whereArgs: [id]);
  }
  
  // 清空所有历史
  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('translation_history');
  }
  
  // 导出词典为文件（用于备份）
  Future<String> exportDictionary() async {
    final db = await database;
    final results = await db.query('cedict');
    
    final buffer = StringBuffer();
    for (var row in results) {
      final traditional = row['traditional'] as String;
      final simplified = row['simplified'] as String;
      final pinyin = row['pinyin'] as String;
      final definition = row['definition'] as String;
      buffer.writeln('$traditional $simplified [$pinyin] $definition');
    }
    
    return buffer.toString();
  }
  
  // 从CEDICT格式文件导入词典
  Future<int> importFromFile(String content) async {
    final db = await database;
    int count = 0;
    
    final lines = content.split('\n');
    final batch = db.batch();
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      
      // 解析CEDICT格式: 繁體 簡體 [pinyin] definition
      try {
        final match = RegExp(r'^([^\s]+)\s+([^\s]+)\s+\[([^\]]+)\]\s+(.+)$').firstMatch(line);
        if (match != null) {
          batch.insert(
            'cedict',
            {
              'traditional': match.group(1)!,
              'simplified': match.group(2)!,
              'pinyin': match.group(3)!,
              'definition': match.group(4)!,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          count++;
        }
      } catch (e) {
        // 忽略格式错误的行
      }
    }
    
    await batch.commit(noResult: true);
    return count;
  }
  
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}

// 词典条目模型
class DictionaryEntry {
  final int? id;
  final String traditional;
  final String simplified;
  final String pinyin;
  final String definition;
  
  DictionaryEntry({
    this.id,
    required this.traditional,
    required this.simplified,
    required this.pinyin,
    required this.definition,
  });
  
  factory DictionaryEntry.fromMap(Map<String, dynamic> map) {
    return DictionaryEntry(
      id: map['id'] as int?,
      traditional: map['traditional'] as String,
      simplified: map['simplified'] as String,
      pinyin: map['pinyin'] as String,
      definition: map['definition'] as String,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'traditional': traditional,
      'simplified': simplified,
      'pinyin': pinyin,
      'definition': definition,
    };
  }
}

// 自定义词汇模型
class CustomVocabulary {
  final int? id;
  final String word;
  final String? translation;
  final String? category;
  final DateTime createdAt;
  
  CustomVocabulary({
    this.id,
    required this.word,
    this.translation,
    this.category,
    required this.createdAt,
  });
  
  factory CustomVocabulary.fromMap(Map<String, dynamic> map) {
    return CustomVocabulary(
      id: map['id'] as int?,
      word: map['word'] as String,
      translation: map['translation'] as String?,
      category: map['category'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'translation': translation,
      'category': category,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
}
