import 'dart:math';
import 'dart:ui' show Size;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'bisindo_alphabet_data.dart';
import 'tflite_classifier.dart';

/// Result dari gesture recognition
class GestureResult {
  final String? detectedLetter;
  final double confidence;
  final String description;
  final String instruction;
  final bool handsDetected;
  final DateTime timestamp;
  final String recognitionMethod; // 'ai' atau 'rule-based'

  const GestureResult({
    this.detectedLetter,
    this.confidence = 0.0,
    this.description = '',
    this.instruction = '',
    this.handsDetected = false,
    required this.timestamp,
    this.recognitionMethod = '',
  });

  factory GestureResult.empty() =>
      GestureResult(timestamp: DateTime.now());

  factory GestureResult.detected({
    required String letter,
    required double confidence,
    required String description,
    required String instruction,
    String method = 'rule-based',
  }) =>
      GestureResult(
        detectedLetter: letter,
        confidence: confidence,
        description: description,
        instruction: instruction,
        handsDetected: true,
        timestamp: DateTime.now(),
        recognitionMethod: method,
      );

  factory GestureResult.handsOnly() =>
      GestureResult(handsDetected: true, timestamp: DateTime.now());
}

/// Mode pengenalan gestur
enum RecognitionMode {
  /// Gunakan model AI (TFLite) sebagai primary
  aiPrimary,

  /// Gunakan rule-based sebagai primary
  ruleBased,

  /// Hybrid: AI dulu, fallback ke rule-based jika confidence rendah
  hybrid,
}

/// Service untuk mengenali gestur BISINDO dari kamera
/// Mendukung 3 mode: AI (TFLite), Rule-based, dan Hybrid
class GestureRecognizer {
  final PoseDetector _poseDetector;
  final TFLiteClassifier _classifier;
  bool _isProcessing = false;

  // Recognition mode
  RecognitionMode _mode = RecognitionMode.hybrid;
  RecognitionMode get mode => _mode;

  // AI confidence threshold - di bawah ini fallback ke rule-based
  static const double _aiConfidenceThreshold = 0.5;

  // Stabilization buffer
  final List<String> _recentResults = [];
  static const int _stabilizationWindow = 5;

  // Throttle
  DateTime _lastProcessTime = DateTime.now();
  static const Duration _processInterval = Duration(milliseconds: 300);

  // Stats
  int _aiDetections = 0;
  int _ruleDetections = 0;
  int get aiDetections => _aiDetections;
  int get ruleDetections => _ruleDetections;

  GestureRecognizer()
      : _poseDetector = PoseDetector(
          options: PoseDetectorOptions(
            mode: PoseDetectionMode.stream,
            model: PoseDetectionModel.base,
          ),
        ),
        _classifier = TFLiteClassifier.instance;

  /// Initialize AI model (call this at app startup)
  Future<bool> initializeAI() async {
    final success = await _classifier.initialize();
    if (success) {
      _mode = RecognitionMode.hybrid;
      debugPrint('[GestureRecognizer] AI model loaded - Hybrid mode active');
    } else {
      _mode = RecognitionMode.ruleBased;
      debugPrint(
          '[GestureRecognizer] AI model not available - Rule-based mode');
    }
    return success;
  }

  /// Set recognition mode
  void setMode(RecognitionMode mode) {
    if (mode == RecognitionMode.aiPrimary && !_classifier.isInitialized) {
      debugPrint('[GestureRecognizer] Cannot set AI mode - model not loaded');
      return;
    }
    _mode = mode;
    debugPrint('[GestureRecognizer] Mode changed to: ${mode.name}');
  }

  /// Process a camera frame and return gesture result
  Future<GestureResult> processFrame(
      CameraImage image, CameraDescription camera) async {
    final now = DateTime.now();
    if (now.difference(_lastProcessTime) < _processInterval) {
      return GestureResult.empty();
    }
    if (_isProcessing) return GestureResult.empty();

    _isProcessing = true;
    _lastProcessTime = now;

    try {
      // ===== AI-BASED DETECTION =====
      if (_mode == RecognitionMode.aiPrimary ||
          _mode == RecognitionMode.hybrid) {
        final aiResult = await _classifyWithAI(image);

        if (aiResult != null) {
          if (_mode == RecognitionMode.aiPrimary ||
              aiResult.confidence >= _aiConfidenceThreshold) {
            _aiDetections++;
            _addToBuffer(aiResult.label);
            final stableLetter = _getStableResult();

            if (stableLetter != null) {
              final gesture = BisindoAlphabetData.getByLetter(stableLetter);
              _isProcessing = false;
              return GestureResult.detected(
                letter: stableLetter,
                confidence: aiResult.confidence,
                description: gesture?.description ??
                    'Isyarat BISINDO: $stableLetter',
                instruction: gesture?.instruction ??
                    'Lakukan isyarat $stableLetter',
                method: 'ai',
              );
            }

            _isProcessing = false;
            return GestureResult.handsOnly();
          }
          // If hybrid and AI confidence is low, fall through to rule-based
        }
      }

      // ===== RULE-BASED DETECTION (fallback or primary) =====
      if (_mode == RecognitionMode.ruleBased ||
          _mode == RecognitionMode.hybrid) {
        final result = await _classifyWithRules(image, camera);
        _isProcessing = false;
        return result;
      }

      _isProcessing = false;
      return GestureResult.empty();
    } catch (e) {
      debugPrint('[GestureRecognizer] Error processing frame: $e');
      _isProcessing = false;
      return GestureResult.empty();
    }
  }

  /// Classify using AI model (TFLite)
  Future<ClassificationResult?> _classifyWithAI(CameraImage image) async {
    if (!_classifier.isInitialized) return null;

    try {
      final result = await _classifier.classifyFrame(image);
      if (result.isValid) {
        debugPrint(
            '[AI] Detected: ${result.label} (${(result.confidence * 100).toStringAsFixed(1)}%)');
        return result;
      }
    } catch (e) {
      debugPrint('[AI] Classification error: $e');
    }
    return null;
  }

  /// Classify using rule-based pose detection (original method)
  Future<GestureResult> _classifyWithRules(
      CameraImage image, CameraDescription camera) async {
    try {
      final inputImage = _convertCameraImage(image, camera);
      if (inputImage == null) return GestureResult.empty();

      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        _recentResults.clear();
        return GestureResult.empty();
      }

      final pose = poses.first;
      final hasHands = _hasHandLandmarks(pose);

      if (!hasHands) return GestureResult.empty();

      final classification = _classifyGesture(pose);

      if (classification != null) {
        _ruleDetections++;
        _addToBuffer(classification.letter);

        final stableLetter = _getStableResult();
        if (stableLetter != null) {
          final gesture = BisindoAlphabetData.getByLetter(stableLetter);
          if (gesture != null) {
            return GestureResult.detected(
              letter: stableLetter,
              confidence: classification.confidence,
              description: gesture.description,
              instruction: gesture.instruction,
              method: 'rule-based',
            );
          }
        }
        return GestureResult.handsOnly();
      }

      return GestureResult.handsOnly();
    } catch (e) {
      debugPrint('[Rules] Error: $e');
      return GestureResult.empty();
    }
  }

  /// Add result to stabilization buffer
  void _addToBuffer(String letter) {
    _recentResults.add(letter);
    if (_recentResults.length > _stabilizationWindow) {
      _recentResults.removeAt(0);
    }
  }

  /// Convert CameraImage to InputImage
  InputImage? _convertCameraImage(
      CameraImage image, CameraDescription camera) {
    try {
      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation);
      if (rotation == null) return null;

      final plane = image.planes.first;

      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('Error converting camera image: $e');
      return null;
    }
  }

  /// Check if pose has hand landmarks
  bool _hasHandLandmarks(Pose pose) {
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    return (leftWrist != null && leftWrist.likelihood > 0.5) ||
        (rightWrist != null && rightWrist.likelihood > 0.5);
  }

  /// Classify gesture based on pose landmarks (rule-based)
  _ClassResult? _classifyGesture(Pose pose) {
    final lw = pose.landmarks[PoseLandmarkType.leftWrist];
    final rw = pose.landmarks[PoseLandmarkType.rightWrist];
    final le = pose.landmarks[PoseLandmarkType.leftElbow];
    final re = pose.landmarks[PoseLandmarkType.rightElbow];
    final ls = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rs = pose.landmarks[PoseLandmarkType.rightShoulder];
    final li = pose.landmarks[PoseLandmarkType.leftIndex];
    final ri = pose.landmarks[PoseLandmarkType.rightIndex];
    final lt = pose.landmarks[PoseLandmarkType.leftThumb];
    final rt = pose.landmarks[PoseLandmarkType.rightThumb];
    final lp = pose.landmarks[PoseLandmarkType.leftPinky];
    final rp = pose.landmarks[PoseLandmarkType.rightPinky];

    if (lw == null || rw == null || le == null || re == null) return null;

    // Shoulder width as reference scale
    final sw = (ls != null && rs != null) ? (ls.x - rs.x).abs() : 200.0;

    // Wrist distance
    final wristDist = _dist(lw, rw);
    final handsClose = wristDist < sw * 0.5;
    final handsTouching = wristDist < sw * 0.25;

    // Hand heights
    final rHandHigh = rs != null && rw.y < rs.y;
    final lHandHigh = ls != null && lw.y < ls.y;
    final bothUp = rHandHigh && lHandHigh;

    // Finger spread
    final lSpread = (li != null && lp != null) ? _dist(li, lp) : 0.0;
    final rSpread = (ri != null && rp != null) ? _dist(ri, rp) : 0.0;

    // Thumb up
    final lThumbUp = lt != null && lt.y < lw.y - 30;
    final rThumbUp = rt != null && rt.y < rw.y - 30;

    // Index up
    final rIndexUp = ri != null && ri.y < rw.y - 40;

    // Pinky up
    final rPinkyUp = rp != null && rp.y < rw.y - 40;

    // ===== CLASSIFICATION RULES =====

    // Y: Thumb + pinky out (shaka)
    if (rThumbUp && !rIndexUp && rPinkyUp && rSpread > sw * 0.15) {
      return _ClassResult('Y', 0.75);
    }

    // I: Only pinky up
    if (!rThumbUp && !rIndexUp && rPinkyUp && rSpread < sw * 0.15) {
      return _ClassResult('I', 0.70);
    }

    // L: Thumb + index forming L
    if (rThumbUp &&
        rIndexUp &&
        rSpread < sw * 0.2 &&
        (ri!.x - rt!.x).abs() > sw * 0.15) {
      return _ClassResult('L', 0.72);
    }

    // D: Only index up
    if (!rThumbUp && rIndexUp && rSpread < sw * 0.12) {
      return _ClassResult('D', 0.72);
    }

    // V: Two fingers up, spread
    if (!rThumbUp && rIndexUp && rSpread > sw * 0.1 && rSpread < sw * 0.25) {
      return _ClassResult('V', 0.68);
    }

    // W: Three fingers up
    if (!rThumbUp && rHandHigh && rSpread > sw * 0.2 && rSpread < sw * 0.35) {
      return _ClassResult('W', 0.63);
    }

    // B: Four fingers up, no thumb
    if (!rThumbUp && rHandHigh && rSpread > sw * 0.3) {
      return _ClassResult('B', 0.65);
    }

    // F: OK sign - thumb+index circle, others up
    if (rThumbUp && rIndexUp && rSpread > sw * 0.25) {
      return _ClassResult('F', 0.62);
    }

    // K: Thumb + two fingers
    if (rThumbUp &&
        rIndexUp &&
        rSpread > sw * 0.12 &&
        rSpread < sw * 0.22) {
      return _ClassResult('K', 0.62);
    }

    // A: Fist with thumb to side
    if (handsClose &&
        lSpread < sw * 0.15 &&
        rSpread < sw * 0.15 &&
        lThumbUp) {
      return _ClassResult('A', 0.70);
    }

    // O: Hands forming circle
    if (handsTouching && lSpread < sw * 0.2 && rSpread < sw * 0.2) {
      return _ClassResult('O', 0.62);
    }

    // C: Curved hand
    if (rHandHigh &&
        rSpread > sw * 0.12 &&
        rSpread < sw * 0.22 &&
        !rIndexUp) {
      return _ClassResult('C', 0.58);
    }

    // S/E: Fist - both closed
    if (handsClose &&
        lSpread < sw * 0.1 &&
        rSpread < sw * 0.1 &&
        !lThumbUp &&
        !rThumbUp) {
      return _ClassResult('S', 0.62);
    }

    // G: Pointing sideways
    if (ri != null &&
        (ri.x - rw.x).abs() > sw * 0.3 &&
        (ri.y - rw.y).abs() < sw * 0.15) {
      return _ClassResult('G', 0.60);
    }

    // R: Crossed fingers (index up, tight spread)
    if (rIndexUp && rSpread < sw * 0.08) {
      return _ClassResult('R', 0.58);
    }

    // M/N: Fist variations, both hands up close
    if (bothUp &&
        handsClose &&
        lSpread < sw * 0.15 &&
        rSpread < sw * 0.15) {
      return _ClassResult('M', 0.55);
    }

    // H/U: Two fingers up, close together
    if (!rThumbUp &&
        rIndexUp &&
        rSpread > sw * 0.05 &&
        rSpread < sw * 0.12) {
      return _ClassResult('U', 0.60);
    }

    return null;
  }

  /// Get stable result from buffer
  String? _getStableResult() {
    if (_recentResults.length < 3) return null;

    final counts = <String, int>{};
    for (final r in _recentResults) {
      counts[r] = (counts[r] ?? 0) + 1;
    }

    String? best;
    int bestCount = 0;
    counts.forEach((letter, count) {
      if (count > bestCount) {
        bestCount = count;
        best = letter;
      }
    });

    if (bestCount >= (_stabilizationWindow * 0.6).ceil()) return best;
    return null;
  }

  double _dist(PoseLandmark a, PoseLandmark b) {
    return sqrt(pow(a.x - b.x, 2) + pow(a.y - b.y, 2));
  }

  void reset() {
    _recentResults.clear();
    _isProcessing = false;
    _aiDetections = 0;
    _ruleDetections = 0;
  }

  Future<void> dispose() async {
    await _poseDetector.close();
    _recentResults.clear();
    // Note: Don't dispose classifier here as it's a singleton
    // It will be disposed when the app closes
  }
}

class _ClassResult {
  final String letter;
  final double confidence;
  const _ClassResult(this.letter, this.confidence);
}
