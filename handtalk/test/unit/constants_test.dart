import 'package:flutter_test/flutter_test.dart';
import 'package:handtalk/core/constants.dart';

void main() {
  group('AppConstants', () {
    test('app identity values are set', () {
      expect(AppConstants.appName, 'HandTalk');
      expect(AppConstants.appVersion, '1.0.0');
      expect(AppConstants.appTheme, 'Community Empowerment');
    });

    test('database config is valid', () {
      expect(AppConstants.dbName, isNotEmpty);
      expect(AppConstants.dbVersion, greaterThan(0));
    });

    test('AI thresholds are within valid range', () {
      expect(AppConstants.confidenceThreshold, greaterThan(0.0));
      expect(AppConstants.confidenceThreshold, lessThanOrEqualTo(1.0));
      expect(AppConstants.aiConfidenceThreshold, greaterThan(0.0));
      expect(AppConstants.aiConfidenceThreshold, lessThanOrEqualTo(1.0));
      expect(AppConstants.defaultAccuracy, greaterThan(0.0));
      expect(AppConstants.defaultAccuracy, lessThanOrEqualTo(100.0));
    });

    test('roles list is not empty', () {
      expect(AppConstants.roles, isNotEmpty);
      expect(AppConstants.roles, contains('learner'));
      expect(AppConstants.roles, contains('instructor'));
      expect(AppConstants.roles, contains('admin'));
    });

    test('difficulties list is ordered', () {
      expect(AppConstants.difficulties, isNotEmpty);
      expect(AppConstants.difficulties.first, 'beginner');
      expect(AppConstants.difficulties.last, 'expert');
    });

    test('validation constants are reasonable', () {
      expect(AppConstants.minUsernameLength, greaterThan(0));
      expect(AppConstants.maxUsernameLength, greaterThan(AppConstants.minUsernameLength));
      expect(AppConstants.minPasswordLength, greaterThanOrEqualTo(6));
    });

    test('pagination defaults are valid', () {
      expect(AppConstants.defaultPageSize, greaterThan(0));
      expect(AppConstants.maxPageSize, greaterThan(AppConstants.defaultPageSize));
    });

    test('model input size is valid', () {
      expect(AppConstants.modelInputSize, 224);
    });

    test('asset paths are set', () {
      expect(AppConstants.seedDataPath, isNotEmpty);
      expect(AppConstants.gestureImagesPath, isNotEmpty);
      expect(AppConstants.aiModelPath, isNotEmpty);
    });
  });
}
