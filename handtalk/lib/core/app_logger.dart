/// HandTalk App Logger
/// Centralized logging service untuk error tracking dan debugging
/// Menyimpan log ke memory buffer dan console output

import 'package:flutter/foundation.dart';

/// Level severity log
enum LogLevel { debug, info, warning, error, fatal }

/// Entry log tunggal
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final String? source;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.source,
  });

  @override
  String toString() {
    final levelStr = level.name.toUpperCase().padRight(7);
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
    final sourceStr = source != null ? '[$source] ' : '';
    final errorStr = error != null ? '\n  Error: $error' : '';
    final stackStr = stackTrace != null ? '\n  Stack: $stackTrace' : '';
    return '[$timeStr] $levelStr $sourceStr$message$errorStr$stackStr';
  }
}

/// Centralized logger - static methods untuk kemudahan akses
class AppLogger {
  AppLogger._();

  /// Buffer log di memory (max 500 entries)
  static final List<LogEntry> _logs = [];
  static const int _maxLogEntries = 500;

  /// Callback untuk custom log handler (misal: kirim ke server)
  static void Function(LogEntry entry)? onLog;

  // ─── Log Methods ──────────────────────────────────────────────────────────

  static void debug(String message, {String? source}) {
    _log(LogLevel.debug, message, source: source);
  }

  static void info(String message, {String? source}) {
    _log(LogLevel.info, message, source: source);
  }

  static void warning(String message, {Object? error, String? source}) {
    _log(LogLevel.warning, message, error: error, source: source);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error: error, stackTrace: stackTrace);
  }

  static void fatal(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.fatal, message, error: error, stackTrace: stackTrace);
  }

  // ─── Internal ─────────────────────────────────────────────────────────────

  static void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? source,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error,
      stackTrace: stackTrace,
      source: source,
    );

    // Tambah ke buffer
    _logs.add(entry);
    if (_logs.length > _maxLogEntries) {
      _logs.removeAt(0);
    }

    // Print ke console (hanya di debug mode)
    if (kDebugMode) {
      debugPrint('[HandTalk] $entry');
    }

    // Panggil custom handler jika ada
    onLog?.call(entry);
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  /// Ambil semua log entries
  static List<LogEntry> get logs => List.unmodifiable(_logs);

  /// Ambil log berdasarkan level
  static List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((l) => l.level == level).toList();
  }

  /// Ambil error logs saja
  static List<LogEntry> get errorLogs =>
      _logs.where((l) => l.level == LogLevel.error || l.level == LogLevel.fatal).toList();

  /// Hapus semua log
  static void clear() => _logs.clear();

  /// Export log sebagai string (untuk debugging/sharing)
  static String export() {
    return _logs.map((l) => l.toString()).join('\n');
  }
}
