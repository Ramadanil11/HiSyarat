/// HandTalk App Constants
/// Konstanta aplikasi BISINDO sign language
/// Pattern: Flat-page (seperti spedi project)

class AppConstants {
  AppConstants._();

  // ─── App Identity ───────────────────────────────────────────────────────────
  static const String appName = 'HandTalk';
  static const String appTagline = 'Berkomunikasi dengan BISINDO';
  static const String appTheme = 'Community Empowerment';
  static const String appDescription = 'Orthomorphic-Providential';
  static const String appVersion = '1.0.0';

  // ─── Database ───────────────────────────────────────────────────────────────
  static const String dbName = 'handtalk.db';
  static const int dbVersion = 2;

  // ─── Timing ─────────────────────────────────────────────────────────────────
  static const int splashDuration = 3; // detik

  // ─── AI / Detection ─────────────────────────────────────────────────────────
  static const double defaultAccuracy = 87.5;
  static const double confidenceThreshold = 0.7;
  static const double aiConfidenceThreshold = 0.5; // Minimum AI confidence
  static const int poseDetectionInterval = 100; // ms
  static const String tfliteModelName = 'bisindo_model.tflite';
  static const String labelsFileName = 'labels.json';
  static const int modelInputSize = 224; // Input image size for model

  // ─── User Roles ─────────────────────────────────────────────────────────────
  static const List<String> roles = [
    'learner',
    'instructor',
    'admin',
  ];

  // ─── Gesture Directions ─────────────────────────────────────────────────────
  static const List<String> directions = [
    'up',
    'down',
    'left',
    'right',
    'forward',
    'backward',
    'circular_cw',
    'circular_ccw',
    'static',
  ];

  // ─── Difficulty Levels ──────────────────────────────────────────────────────
  static const List<String> difficulties = [
    'beginner',
    'intermediate',
    'advanced',
    'expert',
  ];

  // ─── Asset Paths ────────────────────────────────────────────────────────────
  static const String seedDataPath = 'assets/data/bisindo_seed_data.json';
  static const String gestureImagesPath = 'assets/images/gestures/';
  static const String aiModelPath = 'assets/models/';

  // ─── API / Endpoints (jika diperlukan) ──────────────────────────────────────
  static const int connectionTimeout = 30000; // ms
  static const int receiveTimeout = 30000; // ms

  // ─── Pagination ─────────────────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ─── Validation ─────────────────────────────────────────────────────────────
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;
  static const int minPasswordLength = 6;
}
