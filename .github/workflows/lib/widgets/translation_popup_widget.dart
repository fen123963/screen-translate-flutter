// translation_popup_widget.dart - 翻译结果弹窗组件
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TranslationPopupWidget extends StatefulWidget {
  final Offset position;
  final String originalText;
  final String translatedText;
  final double opacity;
  final Function(Offset) onPositionChanged;
  final VoidCallback onClose;
  final Function(String) onSpeak;
  final Function(String) onCopy;

  const TranslationPopupWidget({
    super.key,
    required this.position,
    required this.originalText,
    required this.translatedText,
    required this.opacity,
    required this.onPositionChanged,
    required this.onClose,
    required this.onSpeak,
    required this.onCopy,
  });

  @override
  State<TranslationPopupWidget> createState() => _TranslationPopupWidgetState();
}

class _TranslationPopupWidgetState extends State<TranslationPopupWidget> {
  bool _isDragging = false;
  bool _showOriginal = true;
  late Offset _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.position;
  }

  @override
  void didUpdateWidget(TranslationPopupWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _currentPosition = widget.position;
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _currentPosition = Offset(
      (_currentPosition.dx + details.delta.dx).clamp(0, MediaQuery.of(context).size.width - 280),
      (_currentPosition.dy + details.delta.dy).clamp(0, MediaQuery.of(context).size.height - 200),
    );
    widget.onPositionChanged(_currentPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _currentPosition.dx,
      top: _currentPosition.dy,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.opacity,
          child: Container(
            width: 280,
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isDragging ? 0.3 : 0.15),
                  blurRadius: _isDragging ? 16 : 8,
                  spreadRadius: _isDragging ? 4 : 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动条
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Icon(
                        Icons.drag_indicator,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: widget.onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
                
                // 内容区域
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 切换按钮
                      Row(
                        children: [
                          _buildToggleButton(
                            label: '原文',
                            isActive: _showOriginal,
                            onTap: () => setState(() => _showOriginal = true),
                          ),
                          const SizedBox(width: 8),
                          _buildToggleButton(
                            label: '译文',
                            isActive: !_showOriginal,
                            onTap: () => setState(() => _showOriginal = false),
                          ),
                          const Spacer(),
                          // 复制按钮
                          IconButton(
                            icon: const Icon(Icons.copy, size: 20),
                            onPressed: () {
                              final text = _showOriginal ? widget.originalText : widget.translatedText;
                              Clipboard.setData(ClipboardData(text: text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                              );
                            },
                            tooltip: '复制',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 8),
                          // 朗读按钮
                          IconButton(
                            icon: const Icon(Icons.volume_up, size: 20),
                            onPressed: () {
                              final text = _showOriginal ? widget.originalText : widget.translatedText;
                              widget.onSpeak(text);
                            },
                            tooltip: '朗读',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // 文本内容
                      Container(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: SingleChildScrollView(
                          child: Text(
                            _showOriginal ? widget.originalText : widget.translatedText,
                            style: TextStyle(
                              fontSize: 14,
                              color: _showOriginal 
                                  ? Theme.of(context).textTheme.bodyLarge?.color
                                  : Colors.blue[700],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[700],
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
