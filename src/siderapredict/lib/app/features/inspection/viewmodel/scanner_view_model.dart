import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:siderapredict/app/routes/app_router.dart';
import 'package:siderapredict/app/routes/app_routes.dart';

typedef PhotoCaptureHandler = Future<XFile?> Function();

class ScannerViewModel extends ChangeNotifier {
  ScannerViewModel({required this.cameras, PhotoCaptureHandler? captureHandler})
    : _captureHandler = captureHandler;

  final List<CameraDescription> cameras;
  final PhotoCaptureHandler? _captureHandler;
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  FlashMode _flashMode = FlashMode.auto;
  int _flashStep = 0;
  bool _isCapturing = false;
  double _rollDegrees = 0;
  double _pitchDegrees = 0;

  CameraController? get controller => _controller;
  Future<void>? get initializeControllerFuture => _initializeControllerFuture;
  FlashMode get flashMode => _flashMode;
  bool get isCapturing => _isCapturing;
  double get rollDegrees => _rollDegrees;
  double get pitchDegrees => _pitchDegrees;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  IconData get flashIcon {
    switch (_flashMode) {
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.highlight;
      case FlashMode.off:
        return Icons.flash_off;
    }
  }

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
      ResolutionPreset.max,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller!.initialize().then((_) async {
      await _controller!.setFlashMode(_flashMode);
      try {
        await _controller!.setFocusMode(FocusMode.auto);
        await _controller!.setExposureMode(ExposureMode.auto);
      } catch (_) {}
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

  Future<void> disableFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      await _controller!.setFlashMode(FlashMode.off);
      _flashMode = FlashMode.off;
      _flashStep = 2; // Index for FlashMode.off in toggleFlash logic
      notifyListeners();
    } catch (_) {}
  }

  Future<XFile?> capture() async {
    if (_isCapturing) {
      return null;
    }

    final captureHandler = _captureHandler;
    if (captureHandler != null) {
      _isCapturing = true;
      notifyListeners();
      try {
        return await captureHandler();
      } finally {
        _isCapturing = false;
        notifyListeners();
      }
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return null;
    }
    _isCapturing = true;
    notifyListeners();

    try {
      if (_initializeControllerFuture != null) {
        await _initializeControllerFuture;
      }

      try {
        await _controller!.setFocusMode(FocusMode.locked);
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));

      final picture = await _controller!.takePicture();

      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (_) {}

      _isCapturing = false;
      notifyListeners();
      return picture;
    } catch (e) {
      _isCapturing = false;
      notifyListeners();
      rethrow;
    }
  }

  void onClosePressed(BuildContext context) {
    Navigator.of(context).pop();
  }

  VoidCallback closeAction(BuildContext context) {
    return () => onClosePressed(context);
  }

  VoidCallback? captureAction(BuildContext context) {
    if (isCapturing) return null;
    return () => onCapturePressed(context);
  }

  Future<void> onCapturePressed(BuildContext context) async {
    try {
      final picture = await capture();
      if (picture == null || !context.mounted) return;

      await disableFlash();
      if (!context.mounted) return;

      Navigator.of(context).pushNamed(
        AppRoutes.processing,
        arguments: ProcessingArgs(imagePath: picture.path),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao capturar: $error')));
    }
  }

  @override
  void dispose() {
    _accelerometerSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
