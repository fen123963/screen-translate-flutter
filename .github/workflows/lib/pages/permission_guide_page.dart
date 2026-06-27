// permission_guide_page.dart - 权限引导页面（全机型兼容版）
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/vendor_config.dart';

class PermissionGuidePage extends StatefulWidget {
  const PermissionGuidePage({super.key});

  @override
  State<PermissionGuidePage> createState() => _PermissionGuidePageState();
}

class _PermissionGuidePageState extends State<PermissionGuidePage> {
  final MethodChannel _channel = const MethodChannel('com.translatortools.screen_translator/methods');
  
  bool _overlayPermission = false;
  bool _screenshotPermission = false;
  bool _batteryOptimization = false;
  bool _notificationPermission = false;
  
  String _manufacturer = 'generic';
  String _model = '';
  int _androidVersion = 0;
  
  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _getDeviceInfo();
  }
  
  Future<void> _checkPermissions() async {
    try {
      final overlay = await _channel.invokeMethod<bool>('checkOverlayPermission') ?? false;
      final notification = await _channel.invokeMethod<bool>('checkNotificationPermission') ?? false;
      setState(() {
        _overlayPermission = overlay;
        _notificationPermission = notification;
      });
    } catch (e) {
      setState(() {
        _overlayPermission = false;
        _notificationPermission = false;
      });
    }
  }
  
  Future<void> _getDeviceInfo() async {
    try {
      final manufacturer = await _channel.invokeMethod<String>('getManufacturer') ?? 'generic';
      final model = await _channel.invokeMethod<String>('getModel') ?? '';
      final version = await _channel.invokeMethod<int>('getAndroidVersion') ?? 0;
      
      setState(() {
        _manufacturer = manufacturer;
        _model = model;
        _androidVersion = version;
      });
      
      VendorConfig().init(manufacturer);
    } catch (e) {
      setState(() {
        _manufacturer = 'generic';
        _model = '';
        _androidVersion = 0;
      });
    }
  }
  
  Future<void> _requestOverlayPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestOverlayPermission') ?? false;
      setState(() => _overlayPermission = result);
    } catch (e) {
      // ignore
    }
  }
  
  Future<void> _requestScreenshotPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestScreenshotPermission') ?? false;
      setState(() => _screenshotPermission = result);
    } catch (e) {
      // ignore
    }
  }
  
  Future<void> _openVendorOverlaySettings() async {
    try {
      await _channel.invokeMethod('openVendorOverlaySettings');
    } catch (e) {
      await _channel.invokeMethod('openAppSettings');
    }
  }
  
  Future<void> _openBatteryOptimization() async {
    try {
      await _channel.invokeMethod('openBatteryOptimization');
    } catch (e) {
      // ignore
    }
  }
  
  Future<void> _requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
      final granted = await _channel.invokeMethod<bool>('checkNotificationPermission') ?? false;
      setState(() => _notificationPermission = granted);
    } catch (e) {
      // ignore
    }
  }
  
  bool get _allPermissionsGranted {
    return _overlayPermission;
  }
  
  void _navigateToHome() {
    Navigator.pushReplacementNamed(context, '/home');
  }
  
  @override
  Widget build(BuildContext context) {
    final vendorConfig = VendorConfig();
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            Icon(
              Icons.translate,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              '屏幕翻译',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '版本 1.0.0',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${vendorConfig.brandName} ${_model} · Android ${_androidVersion}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 40),
            
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '权限说明',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    _buildPermissionItem(
                      icon: Icons.floating_window,
                      title: '悬浮窗权限',
                      subtitle: vendorConfig.overlayPermissionGuide,
                      granted: _overlayPermission,
                      onTap: _openVendorOverlaySettings,
                      requestBtn: _requestOverlayPermission,
                    ),
                    const SizedBox(height: 12),
                    
                    _buildPermissionItem(
                      icon: Icons.screenshot,
                      title: '屏幕录制权限',
                      subtitle: vendorConfig.screenshotPermissionGuide,
                      granted: _screenshotPermission,
                      onTap: _requestScreenshotPermission,
                      requestBtn: _requestScreenshotPermission,
                    ),
                    const SizedBox(height: 12),
                    
                    if (vendorConfig.needsBatteryOptimizationExemption)
                      _buildPermissionItem(
                        icon: Icons.battery_full,
                        title: '后台保活设置',
                        subtitle: vendorConfig.batteryOptimizationGuide,
                        granted: _batteryOptimization,
                        onTap: _openBatteryOptimization,
                        requestBtn: _openBatteryOptimization,
                      ),
                    const SizedBox(height: 12),
                    
                    _buildPermissionItem(
                      icon: Icons.notifications,
                      title: '通知权限',
                      subtitle: '请开启通知权限以确保后台服务正常运行',
                      granted: _notificationPermission,
                      onTap: _requestNotificationPermission,
                      requestBtn: _requestNotificationPermission,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            Card(
              color: Colors.blue[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '${vendorConfig.brandName}机型注意事项',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                    ),
                    const SizedBox(height: 8),
                    _buildBrandSpecificNotes(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _allPermissionsGranted ? _navigateToHome : null,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  backgroundColor: _allPermissionsGranted 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[400],
                ),
                child: const Text(
                  '开始使用',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            TextButton(
              onPressed: _navigateToHome,
              child: const Text(
                '跳过引导（可能影响功能）',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool granted,
    required VoidCallback onTap,
    required VoidCallback requestBtn,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: granted ? Colors.green : Colors.orange,
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      trailing: granted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : ElevatedButton(
              onPressed: requestBtn,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                '去开启',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
      onTap: onTap,
    );
  }
  
  Widget _buildBrandSpecificNotes() {
    final vendorConfig = VendorConfig();
    
    switch (vendorConfig.manufacturer) {
      case 'xiaomi':
      case 'redmi':
      case 'mi':
        return const Text(
          '• 请在「安全中心 > 应用管理 > 屏幕翻译」中允许后台弹出\n'
          '• 建议关闭省电模式以确保后台识别正常\n'
          '• MIUI 14+用户请在设置中开启"显示悬浮窗"',
          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
        );
      case 'huawei':
      case 'honor':
        return const Text(
          '• 请在「应用启动管理」中设置为手动管理，允许自启动和后台活动\n'
          '• 鸿蒙系统用户请确保应用在多任务列表中不被锁定\n'
          '• 部分机型需在「电池优化」中排除本应用',
          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
        );
      case 'oppo':
      case 'realme':
        return const Text(
          '• 请在「电池 > 应用冻结」中关闭屏幕翻译的冻结\n'
          '• ColorOS用户请在「设置 > 隐私 > 权限管理」中开启悬浮窗\n'
          '• 建议添加到后台活动白名单',
          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
        );
      case 'oneplus':
        return const Text(
          '• 请在「设置 > 电池 > 电池优化」中选择"不优化"\n'
          '• 建议关闭后台进程限制\n'
          '• 悬浮窗权限在「设置 > 应用 > 应用管理」中开启',
          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
        );
      case 'vivo':
      case 'iqoo':
        return const Text(
          '• 请在「电池 > 后台高耗电」中允许屏幕翻译\n'
          '• OriginOS用户请在「权限管理」中开启悬浮窗\n'
          '• 建议关闭省电模式',
          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
        );
      case 'samsung':
        return const Text(
          '• 请在「设置 > 应用 > 屏幕翻译 > 权限」中开启"在其他应用上层显示"\n'
          '• 建议关闭应用程序省电功能\n'
          '• 确保通知权限已开启',
          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
        );
      default:
        return const Text(
          '• 请确保悬浮窗和屏幕录制权限已开启\n'
          '• 建议在电池设置中关闭应用优化',
          style: TextStyle(fontSize: 12, color: Colors.blue[700]),
        );
    }
  }
}