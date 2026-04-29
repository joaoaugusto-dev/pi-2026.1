import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ScannerViewModel extends ChangeNotifier {
  ScannerViewModel({required this.cameras});

  final List<CameraDescription> cameras;
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  FlashMode _flashMode = FlashMode.auto;
  int _flashStep = 0;
  bool _isCapturing = false;
  double _rollDegrees = 0;
  double _pitchDegrees = 0;
  final ImagePicker _picker = ImagePicker();

  CameraController? get controller => _controller;
  Future<void>? get initializeControllerFuture => _initializeControllerFuture;
  FlashMode get flashMode => _flashMode;
  bool get isCapturing => _isCapturing;
  double get rollDegrees => _rollDegrees;
  double get pitchDegrees => _pitchDegrees;
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  void init() {
    _initCamera();
    _listenForLevel();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    int backIdx = cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
    );
    if (backIdx == -1) backIdx = 0;

    _controller?.dispose();
    _controller = CameraController(
      cameras[backIdx],
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller!.initialize().then((_) async {
      await _controller!.setFlashMode(_flashMode);
      notifyListeners();
    });
    notifyListeners();
  }

  void _listenForLevel() {
    _accelerometerSub = accelerometerEventStream().listen((event) {
      
      final roll = math.atan2(event.x, event.z) * 180 / math.pi;
      final pitch = math.atan2(event.y, event.z) * 180 / math.pi;

      
      const double alpha = 0.15; 
      _rollDegrees = (alpha * roll) + ((1 - alpha) * _rollDegrees);
      _pitchDegrees = (alpha * pitch) + ((1 - alpha) * _pitchDegrees);
      
      notifyListeners();
    });
  }

  Future<void> toggleFlash() async {
    if (_controller == null) return;
    _flashStep = (_flashStep + 1) % 4;
    FlashMode newMode;
    switch (_flashStep) {
      case 0:
        newMode = FlashMode.auto;
        break;
      case 1:
        newMode = FlashMode.always;
        break;
      case 2:
        newMode = FlashMode.off;
        break;
      case 3:
      default:
        newMode = FlashMode.torch;
        break;
    }
    await _controller!.setFlashMode(newMode);
    _flashMode = newMode;
    notifyListeners();
  }

  Future<XFile?> capture() async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) {
      return null;
    }
    _isCapturing = true;
    notifyListeners();

    try {
      if (_initializeControllerFuture != null) {
        await _initializeControllerFuture;
      }
      final picture = await _controller!.takePicture();
      _isCapturing = false;
      notifyListeners();
      return picture;
    } catch (e) {
      _isCapturing = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<XFile?> pickFromGallery() async {
    return await _picker.pickImage(source: ImageSource.gallery);
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
