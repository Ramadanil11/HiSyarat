import 'package:flutter_test/flutter_test.dart';
import 'package:handtalk/core/app_logger.dart';

void main() {
  setUp(() {
    AppLogger.clear();
  });

  group('AppLogger', () {
    test('debug adds log entry', () {
      AppLogger.debug('Test debug message');

      expect(AppLogger.logs.length, 1);
      expect(AppLogger.logs.first.level, LogLevel.debug);
      expect(AppLogger.logs.first.message, 'Test debug message');
    });

    test('info adds log entry', () {
      AppLogger.info('Test info message', source: 'TestSource');

      expect(AppLogger.logs.length, 1);
      expect(AppLogger.logs.first.level, LogLevel.info);
      expect(AppLogger.logs.first.source, 'TestSource');
    });

    test('warning adds log entry with error', () {
      final error = Exception('test error');
      AppLogger.warning('Test warning', error: error);

      expect(AppLogger.logs.length, 1);
      expect(AppLogger.logs.first.level, LogLevel.warning);
      expect(AppLogger.logs.first.error, error);
    });

    test('error adds log entry with stack trace', () {
      final error = Exception('test error');
      final stack = StackTrace.current;
      AppLogger.error('Test error', error, stack);

      expect(AppLogger.logs.length, 1);
      expect(AppLogger.logs.first.level, LogLevel.error);
      expect(AppLogger.logs.first.error, error);
      expect(AppLogger.logs.first.stackTrace, stack);
    });

    test('fatal adds log entry', () {
      AppLogger.fatal('Critical failure');

      expect(AppLogger.logs.length, 1);
      expect(AppLogger.logs.first.level, LogLevel.fatal);
    });

    test('getLogsByLevel filters correctly', () {
      AppLogger.debug('debug 1');
      AppLogger.info('info 1');
      AppLogger.error('error 1');
      AppLogger.debug('debug 2');
      AppLogger.error('error 2');

      final debugLogs = AppLogger.getLogsByLevel(LogLevel.debug);
      final errorLogs = AppLogger.getLogsByLevel(LogLevel.error);

      expect(debugLogs.length, 2);
      expect(errorLogs.length, 2);
    });

    test('errorLogs returns only error and fatal', () {
      AppLogger.debug('debug');
      AppLogger.info('info');
      AppLogger.warning('warning');
      AppLogger.error('error');
      AppLogger.fatal('fatal');

      expect(AppLogger.errorLogs.length, 2);
    });

    test('clear removes all logs', () {
      AppLogger.debug('test 1');
      AppLogger.info('test 2');
      AppLogger.error('test 3');

      AppLogger.clear();

      expect(AppLogger.logs, isEmpty);
    });

    test('export produces string output', () {
      AppLogger.info('test message');

      final exported = AppLogger.export();

      expect(exported, contains('test message'));
      expect(exported, contains('INFO'));
    });

    test('respects max log entries limit', () {
      // Add more than 500 entries
      for (int i = 0; i < 510; i++) {
        AppLogger.debug('Message $i');
      }

      expect(AppLogger.logs.length, 500);
      // First entries should be removed
      expect(AppLogger.logs.first.message, 'Message 10');
    });

    test('onLog callback is called', () {
      LogEntry? capturedEntry;
      AppLogger.onLog = (entry) {
        capturedEntry = entry;
      };

      AppLogger.info('callback test');

      expect(capturedEntry, isNotNull);
      expect(capturedEntry!.message, 'callback test');

      // Cleanup
      AppLogger.onLog = null;
    });
  });

  group('LogEntry', () {
    test('toString formats correctly', () {
      final entry = LogEntry(
        timestamp: DateTime(2024, 1, 1, 12, 30, 45),
        level: LogLevel.error,
        message: 'Test error message',
        source: 'AuthService',
      );

      final str = entry.toString();

      expect(str, contains('12:30:45'));
      expect(str, contains('ERROR'));
      expect(str, contains('[AuthService]'));
      expect(str, contains('Test error message'));
    });

    test('toString includes error when present', () {
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        message: 'Failed',
        error: Exception('something went wrong'),
      );

      final str = entry.toString();
      expect(str, contains('Error:'));
      expect(str, contains('something went wrong'));
    });
  });
}
