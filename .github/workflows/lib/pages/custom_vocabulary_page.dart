// custom_vocabulary_page.dart - 自定义词汇库页
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/app_settings_service.dart';

class CustomVocabularyPage extends StatefulWidget {
  const CustomVocabularyPage({super.key});

  @override
  State<CustomVocabularyPage> createState() => _CustomVocabularyPageState();
}

class _CustomVocabularyPageState extends State<CustomVocabularyPage> {
  List<CustomVocabulary> _vocabulary = [];
  bool _isLoading = true;
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _translationController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  Timer? _loadDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadVocabulary();
  }

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    _categoryController.dispose();
    _loadDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadVocabulary() async {
    setState(() => _isLoading = true);
    
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final vocab = await db.getCustomVocabulary();
      setState(() {
        _vocabulary = vocab;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addVocabulary() async {
    final word = _wordController.text.trim();
    final translation = _translationController.text.trim();
    final category = _categoryController.text.trim();
    
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入词汇')),
      );
      return;
    }
    
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.addCustomVocabulary(
        word,
        translation.isNotEmpty ? translation : null,
        category.isNotEmpty ? category : null,
      );
      
      // 同时保存到设置服务
      final settings = Provider.of<AppSettingsService>(context, listen: false);
      settings.addCustomVocabulary(word);
      
      _wordController.clear();
      _translationController.clear();
      _categoryController.clear();
      
      await _loadVocabulary();
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('词汇已添加')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加失败: $e')),
      );
    }
  }

  Future<void> _deleteVocabulary(int id) async {
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      await db.deleteCustomVocabulary(id);
      await _loadVocabulary();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('词汇已删除')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义词汇库'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_upload),
            onPressed: () => _showImportDialog(),
            tooltip: '批量导入',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vocabulary.isEmpty
              ? _buildEmptyState()
              : _buildVocabularyList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.book,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '词汇库为空',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加自定义词汇',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabularyList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _vocabulary.length,
      itemBuilder: (context, index) {
        final item = _vocabulary[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(
              item.word,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.translation != null)
                  Text(item.translation!),
                if (item.category != null)
                  Chip(
                    label: Text(
                      item.category!,
                      style: const TextStyle(fontSize: 12),
                    ),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: item.id != null ? () => _confirmDelete(item.id!) : null,
            ),
            isThreeLine: item.translation != null && item.category != null,
          ),
        );
      },
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('添加词汇'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _wordController,
                  decoration: const InputDecoration(
                    labelText: '词汇 *',
                    hintText: '输入要添加的词汇',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _translationController,
                  decoration: const InputDecoration(
                    labelText: '翻译',
                    hintText: '输入翻译（可选）',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(
                    labelText: '分类',
                    hintText: '输入分类（可选）',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: _addVocabulary,
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: const Text('确定要删除这个词汇吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteVocabulary(id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  void _showImportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('批量导入'),
          content: const Text(
            '支持从文件导入词汇，每行一个，格式：\n'
            'word,translation\n'
            '例如：\n'
            'hello,你好\n'
            'world,世界',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }
}
