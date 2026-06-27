// home_page.dart - 首页（修复版）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/translation_service.dart';
import '../widgets/floating_ball_widget.dart';
import '../widgets/translation_popup_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey _captureKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupTextRecognitionCallback();
      }
    });
  }
  
  @override
  void dispose() {
    // 清理回调，防止内存泄漏
    final appState = Provider.of<AppState>(context, listen: false);
    appState.screenCaptureService.onTextRecognized = null;
    appState.screenCaptureService.stopCapturing();
    super.dispose();
  }

  void _setupTextRecognitionCallback() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.screenCaptureService.onTextRecognized = (text) async {
      if (text.trim().isEmpty) return;
      
      // 调用翻译服务
      final translation = await appState.translationService.translate(text);
      
      if (translation.isNotEmpty) {
        // 更新状态显示翻译结果
        appState.setCurrentTranslation(text, translation);
        
        // 添加到历史记录
        final lang = appState.translationService.detectLanguage(text);
        appState.addToHistory(TranslationHistory(
          originalText: text,
          translatedText: translation,
          sourceLanguage: lang == LanguageType.chinese ? 'zh' : 'en',
          targetLanguage: lang == LanguageType.chinese ? 'en' : 'zh',
          timestamp: DateTime.now(),
        ));
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            key: _captureKey,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(),
                    Expanded(
                      child: _buildContent(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Consumer<AppState>(
            builder: (context, appState, child) {
              if (!appState.isOverlayEnabled) {
                return const SizedBox.shrink();
              }
              return FloatingBallWidget(
                position: appState.floatingBallPosition,
                onPositionChanged: (pos) {
                  appState.setFloatingBallPosition(pos);
                },
                onTap: () {
                  appState.setOverlayEnabled(false);
                  appState.screenCaptureService.stopCapturing();
                },
              );
            },
          ),
          
          Consumer<AppState>(
            builder: (context, appState, child) {
              if (!appState.isPopupVisible) {
                return const SizedBox.shrink();
              }
              return TranslationPopupWidget(
                position: appState.popupPosition,
                originalText: appState.currentOriginalText,
                translatedText: appState.currentTranslation,
                opacity: appState.translationOpacity,
                onPositionChanged: (pos) {
                  appState.setPopupPosition(pos);
                },
                onClose: () {
                  appState.hidePopup();
                },
                onSpeak: (text) {
                  appState.speakText(text, 
                    appState.currentOriginalText.contains(RegExp(r'[\u4e00-\u9fff]')) 
                        ? 'zh' 
                        : 'en'
                  );
                },
                onCopy: (text) {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '屏幕翻译',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.history),
                onPressed: () {
                  Navigator.pushNamed(context, '/history');
                },
                tooltip: '历史记录',
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
                tooltip: '设置',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFeatureCard(
                icon: Icons.translate,
                title: '实时屏幕翻译',
                description: '开启悬浮球后，自动识别并翻译屏幕上任意位置的文字',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                icon: Icons.language,
                title: '中英双向互译',
                description: '自动识别中文或英文，无需手动切换翻译方向',
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              
              _buildFeatureCard(
                icon: Icons.wifi_off,
                title: '离线词库支持',
                description: '无网络时使用内置离线词库，保证基本翻译功能',
                color: Colors.orange,
              ),
              const SizedBox(height: 32),
              
              if (!appState.isOverlayEnabled)
                ElevatedButton.icon(
                  onPressed: () async {
                    final granted = await _requestPermissions();
                    if (granted) {
                      appState.setOverlayEnabled(true);
                      appState.screenCaptureService.startCapturing(
                        intervalSeconds: appState.captureInterval,
                        topCropHeight: appState.topCropHeight,
                      );
                    }
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('开启屏幕翻译'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () {
                    appState.setOverlayEnabled(false);
                    appState.screenCaptureService.stopCapturing();
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('关闭屏幕翻译'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              
              const SizedBox(height: 32),
              
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/vocabulary');
                },
                icon: const Icon(Icons.book),
                label: const Text('自定义词汇库'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _requestPermissions() async {
    try {
      const channel = MethodChannel('com.translatortools.screen_translator/methods');
      
      // 检查悬浮窗权限
      final overlayGranted = await channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      if (!overlayGranted) {
        final requested = await channel.invokeMethod<bool>('requestOverlayPermission') ?? false;
        if (!requested) return false;
      }
      
      return true;
    } catch (e) {
      // 开发环境可能没有MethodChannel，提示用户手动开启权限
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请在设置中开启悬浮窗权限')),
      );
      return false;
    }
  }
}
