import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// Service untuk mengelola kamera device
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  int _currentCameraIndex = 0;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _controller?.value.isStreamingImages ?? false;

  /// Initialize available cameras
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('No cameras available');
        return;
      }
      // Default to front camera for sign language
      _currentCameraIndex = _cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      if (_currentCameraIndex < 0) _currentCameraIndex = 0;
    } catch (e) {
      debugPrint('Error initializing cameras: $e');
    }
  }

  /// Start camera with specified resolution
  Future<bool> startCamera({
    ResolutionPreset resolution = ResolutionPreset.medium,
  }) async {
    if (_cameras.isEmpty) await initialize();
    if (_cameras.isEmpty) return false;

    try {
      // Dispose existing controller
      await _controller?.dispose();

      _controller = CameraController(
        _cameras[_currentCameraIndex],
        resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _controller!.initialize();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error starting camera: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Start image stream for real-time processing
  Future<void> startImageStream(
    void Function(CameraImage image) onImage,
  ) async {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isStreamingImages) return;

    try {
      await _controller!.startImageStream(onImage);
    } catch (e) {
      debugPrint('Error starting image stream: $e');
    }
  }

  /// Stop image stream
  Future<void> stopImageStream() async {
    if (_controller == null) return;
    if (!_controller!.value.isStreamingImages) return;

    try {
      await _controller!.stopImageStream();
    } catch (e) {
      debugPrint('Error stopping image stream: $e');
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_cameras.length < 2) return;

    _currentCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    await startCamera();
  }

  /// Check if using front camera
  bool get isFrontCamera =>
      _cameras.isNotEmpty &&
      _cameras[_currentCameraIndex].lensDirection == CameraLensDirection.front;

  /// Dispose camera resources
  Future<void> dispose() async {
    await stopImageStream();
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
