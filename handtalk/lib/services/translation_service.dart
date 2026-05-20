/// HandTalk Translation Service
/// Plain Dart class - instance baru setiap penggunaan
/// Mengelola terjemahan teks ↔ bahasa isyarat, kosakata, kategori, dan statistik

import '../core/database_helper.dart';
import '../core/constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Models
// ═══════════════════════════════════════════════════════════════════════════════

/// Model untuk data kosakata (vocabularies)
class VocabularyModel {
  final int? id;
  final String word;
  final String? meaning;
  final int? categoryId;
  final int? gestureId;
  final String difficulty;
  final String? usageExample;
  final String? pronunciationGuide;
  final bool isActive;
  final DateTime? createdAt;

  VocabularyModel({
    this.id,
    required this.word,
    this.meaning,
    this.categoryId,
    this.gestureId,
    this.difficulty = 'beginner',
    this.usageExample,
    this.pronunciationGuide,
    this.isActive = true,
    this.createdAt,
  });

  /// Membuat VocabularyModel dari Map (hasil query database)
  factory VocabularyModel.fromMap(Map<String, dynamic> map) {
    return VocabularyModel(
      id: map['id'] as int?,
      word: map['word'] as String? ?? '',
      meaning: map['meaning'] as String?,
      categoryId: map['category_id'] as int?,
      gestureId: map['gesture_id'] as int?,
      difficulty: map['difficulty'] as String? ?? 'beginner',
      usageExample: map['usage_example'] as String?,
      pronunciationGuide: map['pronunciation_guide'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }

  /// Konversi ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'meaning': meaning,
      'category_id': categoryId,
      'gesture_id': gestureId,
      'difficulty': difficulty,
      'usage_example': usageExample,
      'pronunciation_guide': pronunciationGuide,
      'is_active': isActive ? 1 : 0,
    };
  }
}

/// Model untuk data kategori
class CategoryModel {
  final int? id;
  final String name;
  final String? description;
  final String? iconName;
  final String? colorHex;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;

  CategoryModel({
    this.id,
    required this.name,
    this.description,
    this.iconName,
    this.colorHex,
    this.sortOrder = 0,
    this.isActive = true,
    this.createdAt,
  });

  /// Membuat CategoryModel dari Map (hasil query database)
  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      iconName: map['icon_name'] as String?,
      colorHex: map['color_hex'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }

  /// Konversi ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'color_hex': colorHex,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
    };
  }
}

/// Model untuk data gesture (bahasa isyarat)
class GestureModel {
  final int? id;
  final String name;
  final String? description;
  final int? categoryId;
  final String difficulty;
  final String direction;
  final String handType;
  final String? imagePath;
  final String? videoPath;
  final String? landmarkData;
  final bool isActive;
  final DateTime? createdAt;

  GestureModel({
    this.id,
    required this.name,
    this.description,
    this.categoryId,
    this.difficulty = 'beginner',
    this.direction = 'static',
    this.handType = 'both',
    this.imagePath,
    this.videoPath,
    this.landmarkData,
    this.isActive = true,
    this.createdAt,
  });

  /// Membuat GestureModel dari Map (hasil query database)
  factory GestureModel.fromMap(Map<String, dynamic> map) {
    return GestureModel(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      categoryId: map['category_id'] as int?,
      difficulty: map['difficulty'] as String? ?? 'beginner',
      direction: map['direction'] as String? ?? 'static',
      handType: map['hand_type'] as String? ?? 'both',
      imagePath: map['image_path'] as String?,
      videoPath: map['video_path'] as String?,
      landmarkData: map['landmark_data'] as String?,
      isActive: (map['is_active'] as int?) == 1,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? ''),
    );
  }

  /// Konversi ke Map untuk database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'difficulty': difficulty,
      'direction': direction,
      'hand_type': handType,
      'image_path': imagePath,
      'video_path': videoPath,
      'landmark_data': landmarkData,
      'is_active': isActive ? 1 : 0,
    };
  }
}

/// Model hasil terjemahan
class TranslationResult {
  final String sourceText;
  final String translatedText;
  final double confidence;
  final List<VocabularyModel> matchedVocabs;
  final List<GestureModel> matchedGestures;
  final String direction; // 'text_to_sign' atau 'sign_to_text'

  TranslationResult({
    required this.sourceText,
    required this.translatedText,
    required this.confidence,
    this.matchedVocabs = const [],
    this.matchedGestures = const [],
    required this.direction,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Service: TranslationService
// ═══════════════════════════════════════════════════════════════════════════════

/// Service terjemahan - plain class, buat instance baru setiap penggunaan
class TranslationService {
  final DatabaseHelper _db = DatabaseHelper();

  // ─── Terjemahan Teks ke Bahasa Isyarat ────────────────────────────────────

  /// Menerjemahkan teks ke bahasa isyarat (mock AI)
  /// Mencari kosakata yang cocok dan gesture terkait
  Future<TranslationResult> translateTextToSign(String text) async {
    // Pecah teks menjadi kata-kata untuk pencarian
    final words = text.toLowerCase().trim().split(RegExp(r'\s+'));

    final List<VocabularyModel> matchedVocabs = [];
    final List<GestureModel> matchedGestures = [];
    final List<String> translatedParts = [];

    // Cari setiap kata di database vocabularies
    for (final word in words) {
      final vocabResults = await _db.query(
        'vocabularies',
        where: 'LOWER(word) = ? AND is_active = 1',
        whereArgs: [word],
      );

      if (vocabResults.isNotEmpty) {
        final vocab = VocabularyModel.fromMap(vocabResults.first);
        matchedVocabs.add(vocab);

        // Cari gesture terkait jika ada
        if (vocab.gestureId != null) {
          final gestureResult = await _db.queryById('gestures', vocab.gestureId!);
          if (gestureResult != null) {
            final gesture = GestureModel.fromMap(gestureResult);
            matchedGestures.add(gesture);
            translatedParts.add('[${gesture.name}]');
          } else {
            translatedParts.add('[${vocab.word}]');
          }
        } else {
          translatedParts.add('[${vocab.word}]');
        }
      } else {
        // Kata tidak ditemukan, gunakan spelling (huruf per huruf)
        translatedParts.add('{$word}');
      }
    }

    // Hitung confidence berdasarkan jumlah kata yang cocok
    final matchRatio =
        words.isEmpty ? 0.0 : matchedVocabs.length / words.length;
    final confidence = matchRatio * AppConstants.defaultAccuracy / 100.0;

    final translatedText = translatedParts.isNotEmpty
        ? translatedParts.join(' ')
        : '[Tidak ditemukan terjemahan]';

    return TranslationResult(
      sourceText: text,
      translatedText: translatedText,
      confidence: confidence,
      matchedVocabs: matchedVocabs,
      matchedGestures: matchedGestures,
      direction: 'text_to_sign',
    );
  }

  // ─── Terjemahan Bahasa Isyarat ke Teks ────────────────────────────────────

  /// Menerjemahkan gesture (nama gesture) ke teks
  /// Mencari gesture yang cocok dan kosakata terkait
  Future<TranslationResult> translateSignToText(String gesture) async {
    final List<VocabularyModel> matchedVocabs = [];
    final List<GestureModel> matchedGestures = [];

    // Cari gesture berdasarkan nama
    final gestureResults = await _db.query(
      'gestures',
      where: 'LOWER(name) = ? AND is_active = 1',
      whereArgs: [gesture.toLowerCase().trim()],
    );

    String translatedText = '';
    double confidence = 0.0;

    if (gestureResults.isNotEmpty) {
      final gestureModel = GestureModel.fromMap(gestureResults.first);
      matchedGestures.add(gestureModel);

      // Cari kosakata yang terkait dengan gesture ini
      final vocabResults = await _db.query(
        'vocabularies',
        where: 'gesture_id = ? AND is_active = 1',
        whereArgs: [gestureModel.id],
      );

      if (vocabResults.isNotEmpty) {
        final vocab = VocabularyModel.fromMap(vocabResults.first);
        matchedVocabs.add(vocab);
        translatedText = vocab.meaning ?? vocab.word;
      } else {
        translatedText = gestureModel.description ?? gestureModel.name;
      }

      confidence = AppConstants.defaultAccuracy / 100.0;
    } else {
      // Gesture tidak ditemukan
      translatedText = '[Gesture tidak dikenali: $gesture]';
      confidence = 0.0;
    }

    return TranslationResult(
      sourceText: gesture,
      translatedText: translatedText,
      confidence: confidence,
      matchedVocabs: matchedVocabs,
      matchedGestures: matchedGestures,
      direction: 'sign_to_text',
    );
  }

  // ─── Simpan Terjemahan ke Database ────────────────────────────────────────

  /// Menyimpan hasil terjemahan ke tabel translations
  /// Mengembalikan ID terjemahan yang baru disimpan
  Future<int> saveTranslation(
    String sourceText,
    String translatedText,
    String direction,
    int charCount,
    int wordCount,
  ) async {
    // Tentukan source_language dan target_language berdasarkan arah
    final sourceLanguage = direction == 'text_to_sign' ? 'id' : 'bisindo';
    final targetLanguage = direction == 'text_to_sign' ? 'bisindo' : 'id';

    final id = await _db.insert('translations', {
      'source_text': sourceText,
      'translated_text': translatedText,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'confidence_score': AppConstants.defaultAccuracy / 100.0,
      'is_verified': 0,
    });

    return id;
  }

  // ─── Simpan Riwayat Terjemahan ────────────────────────────────────────────

  /// Menyimpan riwayat terjemahan user ke tabel translation_history
  Future<void> saveHistory(
    int userId,
    int translationId,
    String sessionId,
  ) async {
    await _db.insert('translation_history', {
      'user_id': userId,
      'input_type': 'text',
      'input_data': translationId.toString(),
      'translated_text': '',
      'confidence_score': AppConstants.defaultAccuracy / 100.0,
      'session_id': sessionId,
    });
  }

  // ─── Kosakata ─────────────────────────────────────────────────────────────

  /// Mendapatkan kosakata berdasarkan kata
  Future<VocabularyModel?> getVocabularyByWord(String word) async {
    try {
      final results = await _db.query(
        'vocabularies',
        where: 'LOWER(word) = ? AND is_active = 1',
        whereArgs: [word.toLowerCase().trim()],
      );

      if (results.isEmpty) return null;
      return VocabularyModel.fromMap(results.first);
    } catch (e) {
      return null;
    }
  }

  // ─── Kategori ─────────────────────────────────────────────────────────────

  /// Mendapatkan semua kategori yang aktif
  Future<List<CategoryModel>> getAllCategories() async {
    try {
      final results = await _db.query(
        'categories',
        where: 'is_active = 1',
        orderBy: 'sort_order ASC, name ASC',
      );

      return results.map((map) => CategoryModel.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Mendapatkan kosakata berdasarkan kategori
  Future<List<VocabularyModel>> getVocabulariesByCategory(
      int categoryId) async {
    try {
      final results = await _db.query(
        'vocabularies',
        where: 'category_id = ? AND is_active = 1',
        whereArgs: [categoryId],
        orderBy: 'word ASC',
      );

      return results.map((map) => VocabularyModel.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Pencarian Kosakata ───────────────────────────────────────────────────

  /// Mencari kosakata berdasarkan query (pencarian parsial)
  Future<List<VocabularyModel>> searchVocabularies(String query) async {
    try {
      final results = await _db.query(
        'vocabularies',
        where: '(LOWER(word) LIKE ? OR LOWER(meaning) LIKE ?) AND is_active = 1',
        whereArgs: ['%${query.toLowerCase()}%', '%${query.toLowerCase()}%'],
        orderBy: 'word ASC',
        limit: AppConstants.defaultPageSize,
      );

      return results.map((map) => VocabularyModel.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Dashboard Statistik ──────────────────────────────────────────────────

  /// Mendapatkan statistik untuk dashboard
  /// Mengembalikan Map berisi total gestures, vocabularies, categories,
  /// translations, sessions, dan akurasi AI
  Future<Map<String, dynamic>> getDashboardStats(int userId) async {
    try {
      // Total gesture aktif
      final totalGestures = await _db.count(
        'gestures',
        where: 'is_active = 1',
      );

      // Total kosakata aktif
      final totalVocabularies = await _db.count(
        'vocabularies',
        where: 'is_active = 1',
      );

      // Total kategori aktif
      final totalCategories = await _db.count(
        'categories',
        where: 'is_active = 1',
      );

      // Total terjemahan user (dari translation_history)
      final totalTranslations = await _db.count(
        'translation_history',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Total sesi unik user
      final sessionResults = await _db.rawQuery(
        'SELECT COUNT(DISTINCT session_id) as count FROM translation_history WHERE user_id = ?',
        [userId],
      );
      final totalSessions = sessionResults.isNotEmpty
          ? (sessionResults.first['count'] as int? ?? 0)
          : 0;

      // Akurasi AI dari model aktif
      final aiResults = await _db.query(
        'ai_model_data',
        where: 'is_active = 1',
        orderBy: 'updated_at DESC',
        limit: 1,
      );
      final aiAccuracy = aiResults.isNotEmpty
          ? (aiResults.first['accuracy'] as num?)?.toDouble() ??
              AppConstants.defaultAccuracy
          : AppConstants.defaultAccuracy;

      return {
        'totalGestures': totalGestures,
        'totalVocabularies': totalVocabularies,
        'totalCategories': totalCategories,
        'totalTranslations': totalTranslations,
        'totalSessions': totalSessions,
        'aiAccuracy': aiAccuracy,
      };
    } catch (e) {
      // Kembalikan default jika terjadi error
      return {
        'totalGestures': 0,
        'totalVocabularies': 0,
        'totalCategories': 0,
        'totalTranslations': 0,
        'totalSessions': 0,
        'aiAccuracy': AppConstants.defaultAccuracy,
      };
    }
  }
}
