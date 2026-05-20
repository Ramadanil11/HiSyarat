import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:convert';
import '../../core/constants.dart';

/// Hasil klasifikasi dari model TFLite
class ClassificationResult {
  final String label;
  final double confidence;
  final Map<String, double> allProbabilities;
  final DateTime timestamp;

  const ClassificationResult({
    required this.label,
    required this.confidence,
    required this.allProbabilities,
    required this.timestamp,
  });

  factory ClassificationResult.empty() => ClassificationResult(
        label: '',
        confidence: 0.0,
        allProbabilities: {},
        timestamp: DateTime.now(),
      );

  bool get isValid => label.isNotEmpty && confidence > 0;

  @override
  String toString() =>
      'ClassificationResult(label: $label, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Service untuk menjalankan inference model TFLite BISINDO
/// Singleton pattern untuk efisiensi memori
class TFLiteClassifier {
  static TFLiteClassifier? _instance;
  static TFLiteClassifier get instance => _instance ??= TFLiteClassifier._();

  TFLiteClassifier._();

  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  bool _isLoading = false;

  // Model configuration
  static const String _modelFileName = 'bisindo_model.tflite';
  static const String _labelsFileName = 'labels.json';
  static const int _inputSize = 224;

  // ImageNet normalization values
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  bool get isInitialized => _isInitialized;
  List<String> get labels => List.unmodifiable(_labels);
  int get numClasses => _labels.length;

  /// Initialize the TFLite model and labels
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    if (_isLoading) return false;

    _isLoading = true;

    try {
      // Load model
      final modelPath = '${AppConstants.aiModelPath}$_modelFileName';
      debugPrint('[TFLite] Loading model from: $modelPath');

      _interpreter = await Interpreter.fromAsset(modelPath);

      // Log model info
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      debugPrint('[TFLite] Input shape: ${inputTensor.shape}');
      debugPrint('[TFLite] Output shape: ${outputTensor.shape}');

      // Load labels
      await _loadLabels();

      _isInitialized = true;
      _isLoading = false;
      debugPrint('[TFLite] Model initialized successfully!');
      debugPrint('[TFLite] Classes (${_labels.length}): $_labels');
      return true;
    } catch (e) {
      debugPrint('[TFLite] Error initializing model: $e');
      _isLoading = false;
      return false;
    }
  }

  /// Load class labels from JSON file
  Future<void> _loadLabels() async {
    try {
      final labelsPath = '${AppConstants.aiModelPath}$_labelsFileName';
      final jsonString = await rootBundle.loadString(labelsPath);
      final data = json.decode(jsonString);

      if (data is Map && data.containsKey('labels')) {
        _labels = List<String>.from(data['labels']);
      } else if (data is List) {
        _labels = List<String>.from(data);
      }

      debugPrint('[TFLite] Loaded ${_labels.length} labels');
    } catch (e) {
      debugPrint('[TFLite] Error loading labels: $e');
      // Fallback: A-Z
      _labels = List.generate(26, (i) => String.fromCharCode(65 + i));
    }
  }

  /// Classify a camera image frame
  /// Returns ClassificationResult with predicted label and confidence
  Future<ClassificationResult> classifyFrame(CameraImage image) async {
    if (!_isInitialized || _interpreter == null) {
      return ClassificationResult.empty();
    }

    try {
      // Preprocess: convert CameraImage to normalized float tensor
      // Model expects NHWC: [1, 224, 224, 3]
      final input = _preprocessCameraImage(image);
      if (input == null) return ClassificationResult.empty();

      // Output buffer: [1, 26]
      final output = List.generate(1, (_) => List.filled(26, 0.0));

      // Run inference
      _interpreter!.run(input, output);

      // Post-process: softmax and get top prediction
      final probabilities = _softmax(output[0]);

      int maxIdx = 0;
      double maxProb = 0.0;
      for (int i = 0; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIdx = i;
        }
      }

      // Build probability map
      final allProbs = <String, double>{};
      for (int i = 0; i < probabilities.length && i < _labels.length; i++) {
        allProbs[_labels[i]] = probabilities[i];
      }

      final label = maxIdx < _labels.length ? _labels[maxIdx] : 'Unknown';

      return ClassificationResult(
        label: label,
        confidence: maxProb,
        allProbabilities: allProbs,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[TFLite] Error during classification: $e');
      return ClassificationResult.empty();
    }
  }

  /// Preprocess CameraImage (YUV420) to normalized float tensor
  /// Output shape: [1, 224, 224, 3] (NHWC format)
  List<List<List<List<double>>>>? _preprocessCameraImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;

      // Convert YUV420 to RGB
      final rgbBytes = _yuv420ToRgb(image);
      if (rgbBytes == null) return null;

      // Create output tensor [1, 224, 224, 3] (NHWC)
      final input = List.generate(
        1,
        (_) => List.generate(
          _inputSize,
          (_) => List.generate(
            _inputSize,
            (_) => List.filled(3, 0.0),
          ),
        ),
      );

      // Resize and normalize
      final scaleX = width / _inputSize;
      final scaleY = height / _inputSize;

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final srcX = (x * scaleX).toInt().clamp(0, width - 1);
          final srcY = (y * scaleY).toInt().clamp(0, height - 1);
          final idx = (srcY * width + srcX) * 3;

          if (idx + 2 < rgbBytes.length) {
            // Normalize: (pixel/255 - mean) / std
            input[0][y][x][0] =
                (rgbBytes[idx] / 255.0 - _mean[0]) / _std[0]; // R
            input[0][y][x][1] =
                (rgbBytes[idx + 1] / 255.0 - _mean[1]) / _std[1]; // G
            input[0][y][x][2] =
                (rgbBytes[idx + 2] / 255.0 - _mean[2]) / _std[2]; // B
          }
        }
      }

      return input;
    } catch (e) {
      debugPrint('[TFLite] Error preprocessing: $e');
      return null;
    }
  }

  /// Convert YUV420/NV21 camera image to RGB bytes
  Uint8List? _yuv420ToRgb(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final rgbBytes = Uint8List(width * height * 3);

      final yPlane = image.planes[0].bytes;
      final uPlane = image.planes.length > 1 ? image.planes[1].bytes : null;
      final vPlane = image.planes.length > 2 ? image.planes[2].bytes : null;

      if (uPlane == null || vPlane == null) {
        // Grayscale fallback
        for (int i = 0; i < width * height; i++) {
          final y = yPlane[i];
          rgbBytes[i * 3] = y;
          rgbBytes[i * 3 + 1] = y;
          rgbBytes[i * 3 + 2] = y;
        }
        return rgbBytes;
      }

      final yRowStride = image.planes[0].bytesPerRow;
      final uvRowStride = image.planes[1].bytesPerRow;
      final uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
          final yIdx = row * yRowStride + col;
          final uvIdx = (row ~/ 2) * uvRowStride + (col ~/ 2) * uvPixelStride;

          final y = yPlane[yIdx];
          final u = uvIdx < uPlane.length ? uPlane[uvIdx] : 128;
          final v = uvIdx < vPlane.length ? vPlane[uvIdx] : 128;

          // YUV to RGB conversion
          int r = (y + 1.370705 * (v - 128)).round().clamp(0, 255);
          int g = (y - 0.337633 * (u - 128) - 0.698001 * (v - 128))
              .round()
              .clamp(0, 255);
          int b = (y + 1.732446 * (u - 128)).round().clamp(0, 255);

          final rgbIdx = (row * width + col) * 3;
          rgbBytes[rgbIdx] = r;
          rgbBytes[rgbIdx + 1] = g;
          rgbBytes[rgbIdx + 2] = b;
        }
      }

      return rgbBytes;
    } catch (e) {
      debugPrint('[TFLite] Error converting YUV to RGB: $e');
      return null;
    }
  }

  /// Softmax function
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(max);
    final exps = logits.map((l) => exp(l - maxLogit)).toList();
    final sumExps = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sumExps).toList();
  }

  /// Get top-K predictions
  List<MapEntry<String, double>> getTopK(
      Map<String, double> probabilities, int k) {
    final sorted = probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(k).toList();
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _labels.clear();
    _instance = null;
    debugPrint('[TFLite] Classifier disposed');
  }
}
