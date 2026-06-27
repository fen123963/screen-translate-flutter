// connectivity_service.dart - 网络连接状态服务
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _isConnected = true;
  String _connectionType = 'unknown';
  
  // 网络状态回调
  Function(bool isConnected, String type)? onConnectivityChanged;
  
  bool get isConnected => _isConnected;
  String get connectionType => _connectionType;
  
  Future<void> init() async {
    // 检查当前连接状态
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
    
    // 监听连接状态变化
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
  }
  
  void _updateConnectionStatus(ConnectivityResult result) {
    bool wasConnected = _isConnected;
    
    if (result == ConnectivityResult.none) {
      _isConnected = false;
      _connectionType = 'none';
    } else {
      _isConnected = true;
      
      switch (result) {
        case ConnectivityResult.wifi:
          _connectionType = 'wifi';
          break;
        case ConnectivityResult.mobile:
          _connectionType = 'mobile';
          break;
        case ConnectivityResult.ethernet:
          _connectionType = 'ethernet';
          break;
        default:
          _connectionType = 'other';
      }
    }
    
    // 如果状态发生变化，通知回调
    if (wasConnected != _isConnected && onConnectivityChanged != null) {
      onConnectivityChanged!(_isConnected, _connectionType);
    }
  }
  
  // 手动检查连接状态
  Future<bool> checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
    return _isConnected;
  }
  
  // 等待网络连接
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isConnected) return true;
    
    final completer = Completer<bool>();
    Function(bool, String)? originalCallback = onConnectivityChanged;
    
    void handleChange(bool connected, String type) {
      if (connected && !completer.isCompleted) {
        completer.complete(true);
      }
    }
    
    // 保存原始回调，设置临时回调
    onConnectivityChanged = (connected, type) {
      handleChange(connected, type);
      originalCallback?.call(connected, type);
    };
    
    // 设置超时
    Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });
    
    return completer.future;
  }
  
  // 获取连接类型描述
  String getConnectionTypeDescription() {
    switch (_connectionType) {
      case 'wifi':
        return 'WiFi';
      case 'mobile':
        return '移动网络';
      case 'ethernet':
        return '以太网';
      case 'none':
        return '无网络';
      default:
        return '未知';
    }
  }
  
  // 是否为移动网络
  bool get isMobileData => _connectionType == 'mobile';
  
  // 是否为WiFi
  bool get isWifi => _connectionType == 'wifi';
  
  void dispose() {
    _subscription?.cancel();
    onConnectivityChanged = null;
  }
}
