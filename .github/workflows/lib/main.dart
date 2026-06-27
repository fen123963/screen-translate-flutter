// main.dart - 应用入口（修复版）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/app_settings_service.dart';
import 'services/database_service.dart';
import 'services/translation_service.dart';
import 'services/screen_capture_service.dart';
import 'services/tts_service.dart';
import 'services/connectivity_service.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'pages/history_page.dart';
import 'pages/custom_vocabulary_page.dart';
import 'pages/permission_guide_page.dart';
import 'widgets/floating_ball_widget.dart';
import 'widgets/translation_popup_widget.dart';
import 'models/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化服务
  final prefs = await SharedPreferences.getInstance();
  final databaseService = DatabaseService();
  await databaseService.init();
  
  final appSettings = AppSettingsService(prefs);
  final translationService = TranslationService(databaseService);
  // 初始化CET-6离线词库（异步加载，不阻塞APP启动）
  translationService.initialize();
  final screenCaptureService = ScreenCaptureService();
  final ttsService = TtsService();
  await ttsService.init();
  
  final connectivityService = ConnectivityService();
  await connectivityService.init();
  
  // 创建应用状态
  final appState = AppState(
    settings: appSettings,
    translationService: translationService,
    screenCaptureService: screenCaptureService,
    ttsService: ttsService,
    connectivityService: connectivityService,
    databaseService: databaseService,
  );
  
  // 设置网络状态变化回调 - 自动切换在线/离线翻译
  connectivityService.onConnectivityChanged = (isConnected, type) {
    // 网络状态变化时通知用户
    appState.setNetworkStatus(isConnected, type);
    // 通知翻译服务切换模式
    translationService.setOnlineStatus(isConnected);
  };
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        Provider<AppSettingsService>.value(value: appSettings),
        Provider<DatabaseService>.value(value: databaseService),
        Provider<TranslationService>.value(value: translationService),
        Provider<ScreenCaptureService>.value(value: screenCaptureService),
        Provider<TtsService>.value(value: ttsService),
        Provider<ConnectivityService>.value(value: connectivityService),
      ],
      child: const ScreenTranslatorApp(),
    ),
  );
}

class ScreenTranslatorApp extends StatelessWidget {
  const ScreenTranslatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: '屏幕翻译',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: appState.isDarkMode ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: appState.isDarkMode ? Brightness.dark : Brightness.light,
            ),
            appBarTheme: AppBarTheme(
              centerTitle: true,
              elevation: 0,
              backgroundColor: Colors.transparent,
              foregroundColor: appState.isDarkMode ? Colors.white : Colors.black87,
              systemOverlayStyle: appState.isDarkMode 
                  ? SystemUiOverlayStyle.light 
                  : SystemUiOverlayStyle.dark,
            ),
          ),
          home: const PermissionGuidePage(),
          routes: {
            '/home': (context) => const HomePage(),
            '/settings': (context) => const SettingsPage(),
            '/history': (context) => const HistoryPage(),
            '/vocabulary': (context) => const CustomVocabularyPage(),
          },
        );
      },
    );
  }
}
