# 本地打包命令 - 备用方案
# 有电脑时执行以下命令即可生成APK安装包

# ===== Android APK 构建 =====

# Debug调试版（快速构建，适合开发测试）
flutter build apk --debug

# Release发布版（生产环境使用，需要签名）
flutter build apk --release

# 生成独立的分离式APK（体积更小）
flutter build apk --release --split-per-abi

# ===== 生成的APK位置 =====
# Debug版: build/app/outputs/flutter-apk/app-debug.apk
# Release版: build/app/outputs/flutter-apk/app-release.apk

# ===== Windows/Linux桌面应用 =====
# flutter build windows
# flutter build linux
# flutter build macos

# ===== Web应用 =====
# flutter build web

# ===== iOS应用（需要macOS） =====
# flutter build ios
# flutter build ios --release

# ===== 清理构建缓存 =====
# flutter clean

# ===== 获取依赖 =====
# flutter pub get

# ===== 运行分析 =====
# flutter analyze

# ===== 测试 =====
# flutter test
