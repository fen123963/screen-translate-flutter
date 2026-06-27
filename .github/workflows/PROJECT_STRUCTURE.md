# 项目目录结构说明

screen_translator/                          # 项目根目录
├── .github/                                # GitHub配置
│   └── workflows/                          # CI/CD流水线
│       └── android_build.yml               # Android自动打包脚本
├── android/                                # Android原生代码
│   ├── app/                                # 应用模块
│   │   ├── build.gradle                    # 应用构建配置
│   │   └── src/main/
│   │       ├── AndroidManifest.xml         # 权限和组件声明
│   │       └── kotlin/                      # Kotlin源码
│   │           └── com/translatortools/screen_translator/
│   │               └── MainActivity.kt     # 原生入口
│   └── settings.gradle                      # Gradle设置
├── lib/                                    # Flutter Dart代码
│   ├── main.dart                          # 应用入口
│   ├── models/                            # 数据模型
│   │   └── app_state.dart                 # 全局状态
│   ├── pages/                            # 页面
│   │   ├── home_page.dart                 # 首页
│   │   ├── settings_page.dart            # 设置页
│   │   ├── history_page.dart             # 历史记录页
│   │   ├── custom_vocabulary_page.dart   # 自定义词汇库页
│   │   └── permission_guide_page.dart   # 权限引导页
│   ├── services/                         # 服务层
│   │   ├── app_settings_service.dart     # 设置服务
│   │   ├── database_service.dart        # 数据库服务
│   │   ├── translation_service.dart      # 翻译服务
│   │   ├── screen_capture_service.dart  # 截图服务
│   │   ├── tts_service.dart             # TTS语音服务
│   │   └── connectivity_service.dart    # 网络状态服务
│   ├── widgets/                          # 自定义组件
│   │   ├── floating_ball_widget.dart    # 悬浮球组件
│   │   └── translation_popup_widget.dart # 翻译弹窗组件
│   └── assets/                          # 资源文件
│       ├── cedict.db                    # 离线词典（需下载）
│       └── fonts/                       # 字体文件
├── pubspec.yaml                         # 项目配置
├── analysis_options.yaml               # 代码规范配置
└── BUILD_COMMANDS.md                   # 本地打包命令

# 主要功能模块说明

1. **权限管理** (permission_guide_page.dart)
   - 悬浮窗权限申请
   - 截图权限申请
   - 首次启动引导

2. **屏幕识别** (screen_capture_service.dart)
   - 定时截图
   - 顶部区域裁剪
   - 画面变化检测
   - ML Kit文字识别

3. **翻译服务** (translation_service.dart)
   - 火山引擎API（在线）
   - CC-CEDICT离线词库
   - 自定义词汇库
   - 中英自动识别

4. **悬浮球** (floating_ball_widget.dart)
   - 拖动定位
   - 边缘吸附
   - 点击开关

5. **翻译弹窗** (translation_popup_widget.dart)
   - 可拖动定位
   - 透明度可调
   - 原文/译文切换
   - 复制/朗读功能

6. **历史记录** (history_page.dart)
   - 本地存储
   - 查看/复制/删除
   - 时间格式化

7. **自定义词汇** (custom_vocabulary_page.dart)
   - 添加/删除词汇
   - 批量导入
   - 分类管理
