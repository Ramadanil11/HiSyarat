/// HandTalk Feedback Service
/// Plain Dart class - instance baru setiap penggunaan
/// Mengelola feedback user terhadap hasil terjemahan dan akurasi AI

import '../core/database_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Model: FeedbackModel
// ═══════════════════════════════════════════════════════════════════════════════

/// Model untuk data feedback user
class FeedbackModel {
  final int? id;
  final int userId;
  final String type;
  final String? subject;
  final String message;
  final int? rating;
  final int? relatedGestureId;
  final int? relatedTranslationId;
  final String status;
  final String? adminResponse;
  final DateTime? respondedAt;
  final DateTime? createdAt;

  FeedbackModel({
    this.id,
    required this.userId,
    this.type = 'general',
    this.subject,
    required this.message,
    this.rating,
    this.relatedGestureId,
    this.relatedTranslationId,
    this.status = 'pending',
    this.adminResponse,
    this.respondedAt,
    this.createdAt,
  });

  /// Membuat FeedbackModel dari Map (hasil query database)
  factory FeedbackModel.fromMap(Map<String, dynamic> map) {
    return FeedbackModel(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 0,
      type: map['type'] as String? ?? 'general',
      subject: map['subject'] as String?,
      message: map['message'] as String? ?? '',
      rating: map['rating'] as int?,
      relatedGestureId: map['related_gesture_id'] as int?,
      relatedTranslationId: map['related_translation_id'] as int?,
      status: map['status'] as String? ?? 'pending',
      adminResponse: map['admin_response'] as String?,
      respondedAt: map['responded_at'] != null
          ? DateTime.tryParse(map['responded_at'] as String)
          : null,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }

  /// Konversi FeedbackModel ke Map untuk insert/update database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'type': type,
      'subject': subject,
      'message': message,
      'rating': rating,
      'related_gesture_id': relatedGestureId,
      'related_translation_id': relatedTranslationId,
      'status': status,
      'admin_response': adminResponse,
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Service: FeedbackService
// ═══════════════════════════════════════════════════════════════════════════════

/// Service feedback - plain class, buat instance baru setiap penggunaan
class FeedbackService {
  final DatabaseHelper _db = DatabaseHelper();

  // ─── Submit Feedback ──────────────────────────────────────────────────────

  /// Mengirim feedback user terhadap hasil terjemahan
  /// Juga memperbarui akurasi AI di tabel ai_model_data
  Future<void> submitFeedback(
    int userId,
    int translationId,
    bool isCorrect,
    String comment,
  ) async {
    try {
      // Simpan feedback ke tabel feedbacks
      final feedbackData = FeedbackModel(
        userId: userId,
        type: 'translation',
        subject: isCorrect ? 'Terjemahan Benar' : 'Terjemahan Salah',
        message: comment.isNotEmpty ? comment : (isCorrect ? 'Benar' : 'Salah'),
        rating: isCorrect ? 5 : 1,
        relatedTranslationId: translationId,
        status: 'pending',
      );

      await _db.insert('feedbacks', feedbackData.toMap());

      // Update akurasi AI berdasarkan feedback kumulatif
      await _updateAiAccuracy();
    } catch (e) {
      // Gagal menyimpan feedback
    }
  }

  /// Memperbarui akurasi AI berdasarkan semua feedback yang ada
  Future<void> _updateAiAccuracy() async {
    try {
      // Hitung total feedback terjemahan
      final totalFeedback = await _db.count(
        'feedbacks',
        where: 'type = ?',
        whereArgs: ['translation'],
      );

      if (totalFeedback == 0) return;

      // Hitung feedback yang benar (rating >= 4 dianggap benar)
      final correctFeedback = await _db.count(
        'feedbacks',
        where: 'type = ? AND rating >= 4',
        whereArgs: ['translation'],
      );

      // Hitung akurasi baru
      final newAccuracy = (correctFeedback / totalFeedback) * 100.0;

      // Update semua model AI aktif dengan akurasi baru
      await _db.update(
        'ai_model_data',
        {
          'accuracy': newAccuracy,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'is_active = 1',
      );
    } catch (e) {
      // Gagal update akurasi, abaikan
    }
  }

  // ─── Statistik Feedback User ──────────────────────────────────────────────

  /// Mendapatkan statistik feedback user
  /// Mengembalikan Map berisi total, correct, incorrect, dan accuracy
  Future<Map<String, dynamic>> getFeedbackStats(int userId) async {
    try {
      // Total feedback user
      final total = await _db.count(
        'feedbacks',
        where: 'user_id = ? AND type = ?',
        whereArgs: [userId, 'translation'],
      );

      // Feedback benar (rating >= 4)
      final correct = await _db.count(
        'feedbacks',
        where: 'user_id = ? AND type = ? AND rating >= 4',
        whereArgs: [userId, 'translation'],
      );

      // Feedback salah (rating < 4)
      final incorrect = total - correct;

      // Hitung akurasi user
      final accuracy = total > 0 ? (correct / total) * 100.0 : 0.0;

      return {
        'total': total,
        'correct': correct,
        'incorrect': incorrect,
        'accuracy': accuracy,
      };
    } catch (e) {
      return {
        'total': 0,
        'correct': 0,
        'incorrect': 0,
        'accuracy': 0.0,
      };
    }
  }
}
