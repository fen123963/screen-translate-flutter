// floating_ball_widget.dart - 悬浮球组件
import 'package:flutter/material.dart';

class FloatingBallWidget extends StatefulWidget {
  final Offset position;
  final Function(Offset) onPositionChanged;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const FloatingBallWidget({
    super.key,
    required this.position,
    required this.onPositionChanged,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<FloatingBallWidget> createState() => _FloatingBallWidgetState();
}

class _FloatingBallWidgetState extends State<FloatingBallWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isDragging = false;
  late Offset _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.position;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(FloatingBallWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.position != widget.position) {
      _currentPosition = widget.position;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    setState(() => _isDragging = true);
    _animationController.forward();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _currentPosition = Offset(
      (_currentPosition.dx + details.delta.dx).clamp(0, MediaQuery.of(context).size.width - 60),
      (_currentPosition.dy + details.delta.dy).clamp(0, MediaQuery.of(context).size.height - 60),
    );
    widget.onPositionChanged(_currentPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() => _isDragging = false);
    _animationController.reverse();
    
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    double newX = _currentPosition.dx;
    if (newX < screenWidth / 2) {
      newX = 10;
    } else {
      newX = screenWidth - 70;
    }
    
    _currentPosition = Offset(newX, _currentPosition.dy.clamp(0, screenHeight - 60));
    widget.onPositionChanged(_currentPosition);
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
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_isDragging ? 0.4 : 0.2),
                  blurRadius: _isDragging ? 16 : 8,
                  spreadRadius: _isDragging ? 4 : 2,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.translate,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
