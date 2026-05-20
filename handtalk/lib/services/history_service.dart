/// HandTalk History Service
/// Plain Dart class - instance baru setiap penggunaan
/// Mengelola riwayat terjemahan user (CRUD dan statistik)

import '../core/database_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Model: HistoryModel
// ═══════════════════════════════════════════════════════════════════════════════

/// Model untuk data riwayat terjemahan
/// Termasuk data join dari tabel translations (source_text, translated_text, direction)
class HistoryModel {
  final int? id;
  final int userId;
  final String inputType;
  final String? inputData;
  final int? detectedGestureId;
  final String? translatedText;
  final double confidenceScore;
  final int? processingTimeMs;
  final bool? isCorrect;
  final String? feedbackNote;
  final String? sessionId;
  final DateTime? createdAt;

  // Data join dari tabel translations
  final String? sourceText;
  final String? translationDirection;

  HistoryModel({
    this.id,
    required this.userId,
    this.inputType = 'camera',
    this.inputData,
    this.detectedGestureId,
    this.translatedText,
    this.confidenceScore = 0.0,
    this.processingTimeMs,
    this.isCorrect,
    this.feedbackNote,
    this.sessionId,
    this.createdAt,
    this.sourceText,
    this.translationDirection,
  });

  /// Membuat HistoryModel dari Map (hasil query database dengan JOIN)
  factory HistoryModel.fromMap(Map<String, dynamic> map) {
    return HistoryModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 0,
      inputType: map['input_type'] as String? ?? 'camera',
      inputData: map['input_data'] as String?,
      detectedGestureId: map['detected_gesture_id'] as int?,
      translatedText: map['translated_text'] as String?,
      confidenceScore:
          (map['confidence_score'] as num?)?.toDouble() ?? 0.0,
      processingTimeMs: map['processing_time_ms'] as int?,
      isCorrect: map['is_correct'] == null
          ? null
          : (map['is_correct'] as int) == 1,
      feedbackNote: map['feedback_note'] as String?,
      sessionId: map['session_id'] as String?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
      // Data dari JOIN dengan tabel translations
      sourceText: map['source_text'] as String?,
      translationDirection: map['direction'] as String?,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Service: HistoryService
// ═══════════════════════════════════════════════════════════════════════════════

/// Service riwayat terjemahan - plain class, buat instance baru setiap penggunaan
class HistoryService {
  final DatabaseHelper _db = DatabaseHelper();

  // ─── Ambil Riwayat Berdasarkan User ID ────────────────────────────────────

  /// Mendapatkan semua riwayat terjemahan user
  /// Menggunakan LEFT JOIN ke tabel translations untuk data lengkap
  Future<List<HistoryModel>> getHistoryByUserId(int userId) async {
    try {
      final results = await _db.rawQuery('''
        SELECT 
          th.id,
          th.user_id,
          th.input_type,
          th.input_data,
          th.detected_gesture_id,
          th.translated_text,
          th.confidence_score,
          th.processing_time_ms,
          th.is_correct,
          th.feedback_note,
          th.session_id,
          th.created_at,
          t.source_text,
          t.translated_text AS trans_translated_text,
          CASE 
            WHEN t.source_language = 'id' AND t.target_language = 'bisindo' THEN 'text_to_sign'
            WHEN t.source_language = 'bisindo' AND t.target_language = 'id' THEN 'sign_to_text'
            ELSE 'unknown'
          END AS direction
        FROM translation_history th
        LEFT JOIN translations t ON t.id = CAST(th.input_data AS INTEGER)
        WHERE th.user_id = ?
        ORDER BY th.created_at DESC
      ''', [userId]);

      return results.map((map) => HistoryModel.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Hitung Jumlah Sesi Unik ──────────────────────────────────────────────

  /// Mendapatkan jumlah sesi unik user
  Future<int> getSessionCount(int userId) async {
    try {
      final results = await _db.rawQuery(
        'SELECT COUNT(DISTINCT session_id) as count FROM translation_history WHERE user_id = ?',
        [userId],
      );

      if (results.isEmpty) return 0;
      return results.first['count'] as int? ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── Hitung Jumlah Riwayat ────────────────────────────────────────────────

  /// Mendapatkan jumlah total riwayat terjemahan user
  Future<int> getHistoryCount(int userId) async {
    try {
      return await _db.count(
        'translation_history',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      return 0;
    }
  }

  // ─── Hapus Riwayat Berdasarkan ID ─────────────────────────────────────────

  /// Menghapus satu riwayat terjemahan berdasarkan ID
  Future<void> deleteHistory(int id) async {
    try {
      await _db.delete(
        'translation_history',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      // Gagal menghapus, abaikan error
    }
  }

  // ─── Hapus Semua Riwayat User ─────────────────────────────────────────────

  /// Menghapus semua riwayat terjemahan milik user tertentu
  Future<void> clearUserHistory(int userId) async {
    try {
      await _db.delete(
        'translation_history',
        where: 'user_id = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      // Gagal menghapus, abaikan error
    }
  }
}
