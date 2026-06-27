// screen_capture_service.dart - 屏幕截图服务（全机型兼容版）
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import '../utils/vendor_config.dart';

class ScreenCaptureService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final TextRecognizer _chineseTextRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  
  final MethodChannel _methodChannel = const MethodChannel('com.translatortools.screen_translator/methods');
  final EventChannel _eventChannel = const EventChannel('com.translatortools.screen_translator/capture_events');
  
  StreamSubscription? _captureSubscription;
  Timer? _processTimer;
  
  bool _isCapturing = false;
  bool _isProcessing = false;
  String? _lastImageHash;
  
  int _intervalSeconds = 2;
  int _topCropHeight = 0;
  
  Function(String text)? onTextRecognized;
  Function()? onCaptureStarted;
  Function()? onCaptureStopped;
  
  DeviceTier _deviceTier = DeviceTier.medium;
  bool _isLowRamDevice = false;
  
  bool get isCapturing => _isCapturing;
  
  Future<void> init() async {
    try {
      final manufacturer = await _methodChannel.invokeMethod<String>('getManufacturer') ?? 'generic';
      final isLowRam = await _methodChannel.invokeMethod<bool>('isLowRamDevice') ?? false;
      final cpuCores = await _methodChannel.invokeMethod<int>('getCpuCores') ?? 4;
      final totalMemoryMb = await _methodChannel.invokeMethod<int>('getTotalMemoryMb') ?? 4096;
      
      VendorConfig().init(manufacturer);
      _isLowRamDevice = isLowRam;
      _deviceTier = VendorConfig().determineDeviceTier(isLowRam, cpuCores, totalMemoryMb);
      
      await _updateDefaultInterval();
    } catch (e) {
      _deviceTier = DeviceTier.medium;
      _isLowRamDevice = false;
    }
  }
  
  Future<void> _updateDefaultInterval() async {
    if (_isLowRamDevice) {
      _intervalSeconds = 5;
    } else if (_deviceTier == DeviceTier.low) {
      _intervalSeconds = 4;
    } else if (_deviceTier == DeviceTier.medium) {
      _intervalSeconds = 2;
    } else {
      _intervalSeconds = 1;
    }
  }
  
  Future<int> getStatusBarHeight() async {
    try {
      final height = await _methodChannel.invokeMethod<int>('getStatusBarHeightWithInsets');
      return height ?? 48;
    } catch (e) {
      return 48;
    }
  }
  
  Future<Map<String, int>> getScreenSize() async {
    try {
      final width = await _methodChannel.invokeMethod<int>('getScreenWidth') ?? 1080;
      final height = await _methodChannel.invokeMethod<int>('getScreenHeight') ?? 1920;
      return {'width': width, 'height': height};
    } catch (e) {
      return {'width': 1080, 'height': 1920};
    }
  }
  
  void startCapturing({
    int? intervalSeconds,
    int? topCropHeight,
  }) {
    if (_isCapturing) return;
    
    _isCapturing = true;
    _intervalSeconds = intervalSeconds ?? _intervalSeconds;
    _topCropHeight = topCropHeight ?? _topCropHeight;
    
    _startCaptureStream();
    _startProcessTimer();
    
    onCaptureStarted?.call();
  }
  
  void stopCapturing() {
    _isCapturing = false;
    _captureSubscription?.cancel();
    _captureSubscription = null;
    _processTimer?.cancel();
    _processTimer = null;
    _lastImageHash = null;
    
    try {
      _methodChannel.invokeMethod('stopTranslationService');
    } catch (e) {
      // ignore
    }
    
    onCaptureStopped?.call();
  }
  
  void _startCaptureStream() {
    _captureSubscription = _eventChannel.receiveBroadcastStream().listen(
      (data) async {
        if (!_isCapturing) return;
        
        if (data is Uint8List) {
          await _processFrame(data);
        }
      },
      onError: (error) {
        // ignore
      },
    );
  }
  
  void _startProcessTimer() {
    _processTimer?.cancel();
    _processTimer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (_) {
        // Timer used for rate limiting, actual processing triggered by stream
      },
    );
  }
  
  DateTime? _lastProcessTime;
  
  Future<void> _processFrame(Uint8List imageBytes) async {
    if (!_isCapturing || _isProcessing) return;
    
    final now = DateTime.now();
    if (_lastProcessTime != null && now.difference(_lastProcessTime!) < Duration(seconds: _intervalSeconds)) {
      return;
    }
    _lastProcessTime = now;
    
    _isProcessing = true;
    try {
      final imageHash = _computeSimpleHash(imageBytes);
      if (imageHash == _lastImageHash) {
        return;
      }
      _lastImageHash = imageHash;
      
      // 注意：Kotlin端已在原生层裁剪状态栏，此处不再裁剪
      final compressedImage = _compressImage(imageBytes);
      
      final text = await recognizeTextFromImage(compressedImage);
      
      if (text.isNotEmpty && onTextRecognized != null) {
        onTextRecognized!(text);
      }
    } catch (e) {
      // ignore
    } finally {
      _isProcessing = false;
    }
  }
  
  Uint8List _compressImage(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;
      
      int targetWidth = 1280;
      int targetHeight = 720;
      
      if (_isLowRamDevice) {
        targetWidth = 640;
        targetHeight = 360;
      } else if (_deviceTier == DeviceTier.low) {
        targetWidth = 960;
        targetHeight = 540;
      }
      
      final resized = img.copyResize(image, width: targetWidth, height: targetHeight);
      return img.encodePng(resized, level: 6);
    } catch (e) {
      return imageBytes;
    }
  }
  
  Future<String> recognizeTextFromImage(Uint8List imageBytes) async {
    try {
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) return '';
      
      final bgraBytes = decodedImage.getBytes(format: img.Format.bgra);
      final inputImage = InputImage.fromBytes(
        bytes: bgraBytes,
        metadata: InputImageMetadata(
          size: Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: decodedImage.width * 4,
        ),
      );
      
      String text = await _recognizeWithRecognizer(_chineseTextRecognizer, inputImage);
      
      if (text.isEmpty) {
        text = await _recognizeWithRecognizer(_textRecognizer, inputImage);
      }
      
      return text;
    } catch (e) {
      return '';
    }
  }
  
  Future<String> _recognizeWithRecognizer(TextRecognizer recognizer, InputImage inputImage) async {
    try {
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } catch (e) {
      return '';
    }
  }
  
  Uint8List _cropTop(Uint8List imageBytes, int cropHeight) {
    if (cropHeight <= 0) return imageBytes;
    
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;
      
      final safeCropHeight = cropHeight.clamp(0, image.height - 1);
      if (safeCropHeight <= 0) return imageBytes;
      
      final cropped = img.copyCrop(image, 0, safeCropHeight, image.width, image.height - safeCropHeight);
      return img.encodePng(cropped);
    } catch (e) {
      return imageBytes;
    }
  }
  
  String _computeSimpleHash(Uint8List bytes) {
    if (bytes.length < 200) {
      return bytes.toString();
    }
    
    final front = bytes.sublist(0, 100);
    final back = bytes.sublist(bytes.length - 100);
    
    return '${front.hashCode}-${back.hashCode}';
  }
  
  void dispose() {
    stopCapturing();
    onTextRecognized = null;
    onCaptureStarted = null;
    onCaptureStopped = null;
    _textRecognizer.close();
    _chineseTextRecognizer.close();
  }
}