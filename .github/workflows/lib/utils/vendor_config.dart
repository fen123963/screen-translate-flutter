// vendor_config.dart - 厂商配置工具类
// 适配各厂商定制系统的权限设置页面

class VendorConfig {
  static VendorConfig? _instance;
  
  factory VendorConfig() => _instance ??= VendorConfig._();
  
  VendorConfig._();
  
  String _manufacturer = 'generic';
  
  void init(String manufacturer) {
    _manufacturer = manufacturer.toLowerCase();
  }
  
  String get manufacturer => _manufacturer;
  
  String get brandName {
    switch (_manufacturer) {
      case 'xiaomi': return '小米';
      case 'redmi': return '红米';
      case 'mi': return '小米';
      case 'huawei': return '华为';
      case 'honor': return '荣耀';
      case 'oppo': return 'OPPO';
      case 'realme': return 'realme';
      case 'oneplus': return '一加';
      case 'vivo': return 'vivo';
      case 'iqoo': return 'iQOO';
      case 'samsung': return '三星';
      case 'meizu': return '魅族';
      case 'sony': return '索尼';
      case 'lg': return 'LG';
      case 'motorola': return '摩托罗拉';
      default: return '通用';
    }
  }
  
  String get overlayPermissionGuide {
    switch (_manufacturer) {
      case 'xiaomi':
      case 'redmi':
      case 'mi':
        return '请在「设置 > 应用设置 > 应用管理 > 屏幕翻译 > 权限管理 > 显示悬浮窗」中开启';
      case 'huawei':
      case 'honor':
        return '请在「设置 > 应用 > 应用管理 > 屏幕翻译 > 权限 > 悬浮窗」中开启';
      case 'oppo':
      case 'realme':
        return '请在「设置 > 应用 > 权限管理 > 屏幕翻译 > 悬浮窗」中开启';
      case 'oneplus':
        return '请在「设置 > 应用 > 应用管理 > 屏幕翻译 > 权限 > 悬浮窗」中开启';
      case 'vivo':
      case 'iqoo':
        return '请在「设置 > 应用与权限 > 权限管理 > 屏幕翻译 > 悬浮窗」中开启';
      case 'samsung':
        return '请在「设置 > 应用 > 屏幕翻译 > 权限 > 在其他应用上层显示」中开启';
      default:
        return '请在应用权限设置中开启悬浮窗权限';
    }
  }
  
  String get screenshotPermissionGuide {
    switch (_manufacturer) {
      case 'xiaomi':
      case 'redmi':
      case 'mi':
        return '请在「设置 > 应用设置 > 应用管理 > 屏幕翻译 > 权限管理 > 屏幕录制」中开启';
      case 'huawei':
      case 'honor':
        return '请在「设置 > 应用 > 应用管理 > 屏幕翻译 > 权限 > 屏幕录制」中开启';
      case 'oppo':
      case 'realme':
        return '请在「设置 > 应用 > 权限管理 > 屏幕翻译 > 屏幕录制」中开启';
      case 'oneplus':
        return '请在「设置 > 应用 > 应用管理 > 屏幕翻译 > 权限 > 屏幕录制」中开启';
      case 'vivo':
      case 'iqoo':
        return '请在「设置 > 应用与权限 > 权限管理 > 屏幕翻译 > 屏幕录制」中开启';
      case 'samsung':
        return '请在「设置 > 应用 > 屏幕翻译 > 权限 > 媒体投射」中开启';
      default:
        return '请在应用权限设置中开启屏幕录制权限';
    }
  }
  
  String get batteryOptimizationGuide {
    switch (_manufacturer) {
      case 'xiaomi':
      case 'redmi':
      case 'mi':
        return '请在「设置 > 电池与性能 > 省电管理 > 应用省电策略 > 屏幕翻译 > 无限制」中设置';
      case 'huawei':
      case 'honor':
        return '请在「设置 > 电池 > 应用启动管理 > 屏幕翻译 > 手动管理 > 允许自启动、允许后台活动」中设置';
      case 'oppo':
      case 'realme':
        return '请在「设置 > 电池 > 应用冻结 > 屏幕翻译 > 关闭」中设置';
      case 'oneplus':
        return '请在「设置 > 电池 > 电池优化 > 屏幕翻译 > 不优化」中设置';
      case 'vivo':
      case 'iqoo':
        return '请在「设置 > 电池 > 后台高耗电 > 屏幕翻译 > 允许」中设置';
      case 'samsung':
        return '请在「设置 > 电池 > 应用程序省电 > 屏幕翻译 > 禁用」中设置';
      default:
        return '请在电池设置中关闭应用优化，允许后台活动';
    }
  }
  
  String get overlaySettingsUri {
    switch (_manufacturer) {
      case 'xiaomi':
      case 'redmi':
      case 'mi':
        return 'miui://permission/overlay';
      case 'huawei':
      case 'honor':
        return 'com.huawei.systemmanager/com.huawei.permissionmanager.ui.MainActivity';
      case 'oppo':
      case 'realme':
        return 'com.coloros.safecenter/com.coloros.safecenter.permission.PermissionManagerActivity';
      case 'oneplus':
        return 'com.oneplus.security/com.oneplus.security.permission.PermissionManagerActivity';
      case 'vivo':
      case 'iqoo':
        return 'com.vivo.permissionmanager/com.vivo.permissionmanager.activity.PermissionManagerActivity';
      case 'samsung':
        return 'com.samsung.android.app.galaxyfinder/com.samsung.android.app.galaxyfinder.search.SearchActivity';
      default:
        return '';
    }
  }
  
  String get batterySettingsUri {
    switch (_manufacturer) {
      case 'xiaomi':
      case 'redmi':
      case 'mi':
        return 'miui://battery/optimize';
      case 'huawei':
      case 'honor':
        return 'com.huawei.systemmanager/com.huawei.power.ui.HwPowerManagerActivity';
      case 'oppo':
      case 'realme':
        return 'com.coloros.safecenter/com.coloros.safecenter.power.PowerManagerActivity';
      case 'oneplus':
        return 'com.oneplus.security/com.oneplus.security.power.PowerManagerActivity';
      case 'vivo':
      case 'iqoo':
        return 'com.vivo.powerguard/com.vivo.powerguard.PowerGuardActivity';
      case 'samsung':
        return 'com.samsung.android.settings/com.samsung.android.settings.device.battery.BatteryUsageActivity';
      default:
        return '';
    }
  }
  
  bool get needsSpecialOverlayPermission {
    return _manufacturer == 'xiaomi' || 
           _manufacturer == 'redmi' || 
           _manufacturer == 'mi' ||
           _manufacturer == 'vivo' ||
           _manufacturer == 'iqoo';
  }
  
  bool get needsBatteryOptimizationExemption {
    return _manufacturer == 'xiaomi' || 
           _manufacturer == 'redmi' || 
           _manufacturer == 'mi' ||
           _manufacturer == 'huawei' ||
           _manufacturer == 'honor' ||
           _manufacturer == 'oppo' ||
           _manufacturer == 'realme' ||
           _manufacturer == 'oneplus' ||
           _manufacturer == 'vivo' ||
           _manufacturer == 'iqoo';
  }
  
  DeviceTier determineDeviceTier(bool isLowRam, int cpuCores, int totalMemoryMb) {
    if (isLowRam || totalMemoryMb < 3072) {
      return DeviceTier.low;
    }
    
    if (cpuCores >= 8 && totalMemoryMb >= 8192) {
      return DeviceTier.high;
    }
    
    return DeviceTier.medium;
  }
}

enum DeviceTier {
  low,
  medium,
  high,
}