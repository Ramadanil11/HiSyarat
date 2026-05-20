/// HandTalk Database Helper
/// Singleton pattern - SQLite database management
/// 9 tabel utama dengan foreign keys dan seed data

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'constants.dart';

class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  /// Mendapatkan instance database (lazy initialization)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Inisialisasi database
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Konfigurasi database - aktifkan foreign keys
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Membuat semua tabel saat database pertama kali dibuat
  Future<void> _onCreate(Database db, int version) async {
    // ─── 1. Tabel Users ───────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT UNIQUE,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL DEFAULT '',
        full_name TEXT,
        role TEXT NOT NULL DEFAULT 'learner',
        avatar_path TEXT,
        preferred_language TEXT DEFAULT 'id',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ─── 2. Tabel Categories ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        icon_name TEXT,
        color_hex TEXT,
        sort_order INTEGER DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ─── 3. Tabel Gestures ────────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE gestures (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        category_id INTEGER,
        difficulty TEXT NOT NULL DEFAULT 'beginner',
        direction TEXT DEFAULT 'static',
        hand_type TEXT DEFAULT 'both',
        image_path TEXT,
        video_path TEXT,
        landmark_data TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    // ─── 4. Tabel Vocabularies ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE vocabularies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        meaning TEXT,
        category_id INTEGER,
        gesture_id INTEGER,
        difficulty TEXT NOT NULL DEFAULT 'beginner',
        usage_example TEXT,
        pronunciation_guide TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL,
        FOREIGN KEY (gesture_id) REFERENCES gestures(id) ON DELETE SET NULL
      )
    ''');

    // ─── 5. Tabel Translations ────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_text TEXT NOT NULL,
        translated_text TEXT NOT NULL,
        source_language TEXT NOT NULL DEFAULT 'id',
        target_language TEXT NOT NULL DEFAULT 'bisindo',
        gesture_id INTEGER,
        confidence_score REAL DEFAULT 0.0,
        is_verified INTEGER NOT NULL DEFAULT 0,
        verified_by INTEGER,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (gesture_id) REFERENCES gestures(id) ON DELETE SET NULL,
        FOREIGN KEY (verified_by) REFERENCES users(id) ON DELETE SET NULL
      )
    ''');

    // ─── 6. Tabel Audio Data ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE audio_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vocabulary_id INTEGER,
        gesture_id INTEGER,
        audio_path TEXT NOT NULL,
        duration_ms INTEGER,
        language TEXT NOT NULL DEFAULT 'id',
        speaker_type TEXT DEFAULT 'tts',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (vocabulary_id) REFERENCES vocabularies(id) ON DELETE CASCADE,
        FOREIGN KEY (gesture_id) REFERENCES gestures(id) ON DELETE CASCADE
      )
    ''');

    // ─── 7. Tabel Translation History ────────────────────────────────────────
    await db.execute('''
      CREATE TABLE translation_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        input_type TEXT NOT NULL DEFAULT 'camera',
        input_data TEXT,
        detected_gesture_id INTEGER,
        translated_text TEXT,
        confidence_score REAL DEFAULT 0.0,
        processing_time_ms INTEGER,
        is_correct INTEGER,
        feedback_note TEXT,
        session_id TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (detected_gesture_id) REFERENCES gestures(id) ON DELETE SET NULL
      )
    ''');

    // ─── 8. Tabel AI Model Data ──────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE ai_model_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model_name TEXT NOT NULL,
        model_version TEXT NOT NULL,
        model_type TEXT NOT NULL DEFAULT 'pose_detection',
        model_path TEXT,
        accuracy REAL DEFAULT 0.0,
        total_training_samples INTEGER DEFAULT 0,
        total_gestures_supported INTEGER DEFAULT 0,
        config_json TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_trained_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // ─── 9. Tabel Feedbacks ──────────────────────────────────────────────────
    await db.execute('''
      CREATE TABLE feedbacks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        type TEXT NOT NULL DEFAULT 'general',
        subject TEXT,
        message TEXT NOT NULL,
        rating INTEGER,
        related_gesture_id INTEGER,
        related_translation_id INTEGER,
        status TEXT NOT NULL DEFAULT 'pending',
        admin_response TEXT,
        responded_at TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (related_gesture_id) REFERENCES gestures(id) ON DELETE SET NULL,
        FOREIGN KEY (related_translation_id) REFERENCES translations(id) ON DELETE SET NULL
      )
    ''');

    // ─── Indexes untuk performa query ─────────────────────────────────────────
    await db.execute(
        'CREATE INDEX idx_gestures_category ON gestures(category_id)');
    await db.execute(
        'CREATE INDEX idx_gestures_difficulty ON gestures(difficulty)');
    await db.execute(
        'CREATE INDEX idx_vocabularies_category ON vocabularies(category_id)');
    await db.execute(
        'CREATE INDEX idx_vocabularies_gesture ON vocabularies(gesture_id)');
    await db.execute(
        'CREATE INDEX idx_translations_gesture ON translations(gesture_id)');
    await db.execute(
        'CREATE INDEX idx_translation_history_user ON translation_history(user_id)');
    await db.execute(
        'CREATE INDEX idx_translation_history_session ON translation_history(session_id)');
    await db.execute(
        'CREATE INDEX idx_feedbacks_user ON feedbacks(user_id)');
    await db.execute(
        'CREATE INDEX idx_feedbacks_status ON feedbacks(status)');

    // ─── Seed initial AI model data ───────────────────────────────────────────
    await _seedInitialAiModelData(db);
  }

  /// Upgrade database jika versi berubah
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migrasi dari v1 ke v2: tambah kolom salt pada tabel users
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE users ADD COLUMN salt TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  /// Seed data AI model awal
  Future<void> _seedInitialAiModelData(Database db) async {
    await db.insert('ai_model_data', {
      'model_name': 'BISINDO Pose Detector',
      'model_version': '1.0.0',
      'model_type': 'pose_detection',
      'model_path': 'assets/models/bisindo_pose_v1.tflite',
      'accuracy': AppConstants.defaultAccuracy,
      'total_training_samples': 5000,
      'total_gestures_supported': 26,
      'config_json': jsonEncode({
        'input_size': [256, 256],
        'num_landmarks': 33,
        'confidence_threshold': AppConstants.confidenceThreshold,
        'detection_interval_ms': AppConstants.poseDetectionInterval,
        'supported_hand_types': ['left', 'right', 'both'],
      }),
      'is_active': 1,
      'last_trained_at': DateTime.now().toIso8601String(),
    });

    await db.insert('ai_model_data', {
      'model_name': 'BISINDO Hand Landmark',
      'model_version': '1.0.0',
      'model_type': 'hand_landmark',
      'model_path': 'assets/models/bisindo_hand_v1.tflite',
      'accuracy': 85.0,
      'total_training_samples': 3000,
      'total_gestures_supported': 26,
      'config_json': jsonEncode({
        'input_size': [224, 224],
        'num_landmarks': 21,
        'confidence_threshold': 0.65,
        'max_hands': 2,
      }),
      'is_active': 1,
      'last_trained_at': DateTime.now().toIso8601String(),
    });
  }

  /// Seed data dari file JSON (assets/data/bisindo_seed_data.json)
  /// Dipanggil setelah database dibuat untuk mengisi data awal
  Future<void> seedFromJson() async {
    final db = await database;

    try {
      // Baca file JSON dari assets
      final jsonString = await rootBundle.loadString(AppConstants.seedDataPath);
      final Map<String, dynamic> seedData = jsonDecode(jsonString);

      // Gunakan batch untuk performa lebih baik
      final batch = db.batch();

      // ─── Seed Categories ──────────────────────────────────────────────────
      if (seedData.containsKey('categories')) {
        final categories = seedData['categories'] as List<dynamic>;
        for (final category in categories) {
          batch.insert(
            'categories',
            {
              'name': category['name'],
              'description': category['description'],
              'icon_name': category['icon_name'],
              'color_hex': category['color_hex'],
              'sort_order': category['sort_order'] ?? 0,
              'is_active': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      // ─── Seed Gestures ────────────────────────────────────────────────────
      if (seedData.containsKey('gestures')) {
        final gestures = seedData['gestures'] as List<dynamic>;
        for (final gesture in gestures) {
          batch.insert(
            'gestures',
            {
              'name': gesture['name'],
              'description': gesture['description'],
              'category_id': gesture['category_id'],
              'difficulty': gesture['difficulty'] ?? 'beginner',
              'direction': gesture['direction'] ?? 'static',
              'hand_type': gesture['hand_type'] ?? 'both',
              'image_path': gesture['image_path'],
              'video_path': gesture['video_path'],
              'landmark_data': gesture['landmark_data'] != null
                  ? jsonEncode(gesture['landmark_data'])
                  : null,
              'is_active': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      // ─── Seed Vocabularies ────────────────────────────────────────────────
      if (seedData.containsKey('vocabularies')) {
        final vocabularies = seedData['vocabularies'] as List<dynamic>;
        for (final vocab in vocabularies) {
          batch.insert(
            'vocabularies',
            {
              'word': vocab['word'],
              'meaning': vocab['meaning'],
              'category_id': vocab['category_id'],
              'gesture_id': vocab['gesture_id'],
              'difficulty': vocab['difficulty'] ?? 'beginner',
              'usage_example': vocab['usage_example'],
              'pronunciation_guide': vocab['pronunciation_guide'],
              'is_active': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      // ─── Seed Translations ────────────────────────────────────────────────
      if (seedData.containsKey('translations')) {
        final translations = seedData['translations'] as List<dynamic>;
        for (final translation in translations) {
          batch.insert(
            'translations',
            {
              'source_text': translation['source_text'],
              'translated_text': translation['translated_text'],
              'source_language': translation['source_language'] ?? 'id',
              'target_language': translation['target_language'] ?? 'bisindo',
              'gesture_id': translation['gesture_id'],
              'confidence_score': translation['confidence_score'] ?? 0.0,
              'is_verified': translation['is_verified'] ?? 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }

      // Eksekusi semua batch sekaligus
      await batch.commit(noResult: true);

      debugPrint('[DatabaseHelper] Seed data berhasil dimuat dari JSON');
    } catch (e) {
      debugPrint('[DatabaseHelper] Error saat seed data: $e');
      // Tidak throw error - seed data opsional, app tetap bisa jalan
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CRUD Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Insert data ke tabel
  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Query semua data dari tabel
  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

  /// Query dengan kondisi
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Query by ID
  Future<Map<String, dynamic>?> queryById(String table, int id) async {
    final db = await database;
    final results = await db.query(table, where: 'id = ?', whereArgs: [id]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Update data
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  /// Delete data
  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Raw query untuk query kompleks
  Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// Hitung jumlah record di tabel
  Future<int> count(String table, {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    final result = await db.query(
      table,
      columns: ['COUNT(*) as count'],
      where: where,
      whereArgs: whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Cek apakah tabel sudah memiliki data
  Future<bool> hasData(String table) async {
    final c = await count(table);
    return c > 0;
  }

  /// Tutup koneksi database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  /// Reset database (untuk development/testing)
  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    await close();
    await deleteDatabase(path);
    _database = null;

    // Re-initialize
    await database;
    debugPrint('[DatabaseHelper] Database berhasil di-reset');
  }
}
