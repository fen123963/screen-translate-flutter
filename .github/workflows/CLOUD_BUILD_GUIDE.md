# Trae Solo云端打包完整操作流程

## 📋 前置准备

1. **GitHub账号** - 用于存储代码和触发CI/CD
2. **Git安装** - 用于代码版本管理

## 🚀 第一步：创建GitHub仓库

### 1.1 在GitHub创建新仓库

1. 访问 https://github.com/new
2. 填写仓库信息：
   - Repository name: `screen-translator`
   - Description: 屏幕实时中英互译翻译APP
   - 选择 Private 或 Public
   - **不要**勾选 "Initialize this repository with a README"

### 1.2 初始化本地Git仓库

打开终端（Windows用PowerShell），执行：

```powershell
# 进入项目目录
cd d:\Trae\BC\识别\screen_translator

# 初始化Git仓库
git init

# 添加所有文件
git add .

# 提交代码
git commit -m "Initial commit: 屏幕翻译APP完整代码"

# 添加远程仓库（替换 YOUR_USERNAME 为你的GitHub用户名）
git remote add origin https://github.com/YOUR_USERNAME/screen-translator.git

# 推送到GitHub
git branch -M main
git push -u origin main
```

## 🔐 第二步：配置签名密钥（发布版APK必需）

### 2.1 创建签名密钥

```powershell
# 在项目根目录执行，生成签名密钥
keytool -genkey -v -keystore upload-keystore.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

按提示填写信息，记住密码。

### 2.2 配置GitHub Secrets

1. 进入GitHub仓库页面
2. 点击 **Settings** → **Secrets and variables** → **Actions**
3. 点击 **New repository secret**，添加以下密钥：

| Secret Name | Value | 说明 |
|------------|-------|------|
| KEYSTORE_BASE64 | (密钥库base64) | 执行 `base64 upload-keystore.jks` 获取 |
| KEYSTORE_PASSWORD | (密钥库密码) | 创建时填写的密码 |
| KEY_ALIAS | upload | 别名 |
| KEY_PASSWORD | (密钥密码) | 密钥密码 |

**获取base64方法**：
```powershell
# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

## ✅ 第三步：启用GitHub Actions

1. 推送代码后，GitHub会自动检测 `.github/workflows/android_build.yml`
2. 进入仓库 **Actions** 页面，你会看到工作流已就绪
3. 手动触发：
   - 点击 "Build Android APK" workflow
   - 点击 "Run workflow"
   - 选择分支，点击 "Run workflow"

## 📦 第四步：下载APK

### 方法1：通过Actions下载

1. 进入仓库 **Actions** 页面
2. 选择构建任务
3. 点击构建成功的任务
4. 在 "Artifacts" 部分找到：
   - `release-apk` - Release正式版（推荐）
   - `debug-apk` - Debug测试版

### 方法2：通过Releases下载

1. 创建tag并推送：
```powershell
git tag v1.0.0
git push origin v1.0.0
```

2. 进入仓库 **Releases** 页面
3. 点击对应版本
4. 下载附件中的APK文件

## 📱 第五步：安装到手机

1. 将APK文件传输到手机
2. 在手机上找到APK文件
3. 点击安装（如果提示安全警告，允许安装未知来源应用）
4. 打开APP，按引导授权悬浮窗和截图权限

## 🔧 常见问题

### Q1: 构建失败怎么办？

检查Actions日志：
1. 进入仓库 **Actions** 页面
2. 点击失败的构建
3. 查看日志找到错误原因

常见错误：
- `pubspec.yaml` 依赖版本不兼容 → 更新依赖版本
- 缺少原生配置 → 检查AndroidManifest.xml
- 签名密钥错误 → 重新配置Secrets

### Q2: 如何更新代码？

```powershell
# 修改代码后
git add .
git commit -m "修复XXX问题"
git push
```

GitHub会自动重新构建。

### Q3: 如何下载旧版本APK？

1. 进入仓库 **Actions** 页面
2. 左侧选择构建任务
3. 找到历史记录中的构建
4. 下载Artifacts

### Q4: 如何关闭自动构建？

删除或重命名 `.github/workflows/android_build.yml` 文件。

## 📊 工作流程说明

```
代码推送 → GitHub Actions 自动触发
    ↓
1. 拉取代码
2. 配置Flutter环境
3. 配置Java/Android SDK
4. 安装依赖 (flutter pub get)
5. 构建APK
    ↓
成功 → 上传APK到Artifacts
失败 → 查看日志修复问题
```

## 🎯 APK下载链接格式

构建完成后，APK的下载链接格式：

```
https://github.com/YOUR_USERNAME/screen-translator/suites/XXX/artifacts/YYY
```

手机浏览器打开此链接即可下载。

## 💡 提示

- Release APK比Debug APK体积小约50%
- 首次构建约需5-10分钟
- APKs会保留30天（Actions）或90天（Release）
- 建议创建tag来标记正式版本

## 📞 遇到问题？

1. 查看Actions日志中的具体错误
2. 检查代码是否有语法错误
3. 确认GitHub Secrets配置正确
4. 查看官方文档：
   - Flutter: https://flutter.dev/docs
   - GitHub Actions: https://docs.github.com/actions
