/// HandTalk Gamification Service
/// Mengelola streak, badge, progress tracking, dan leaderboard
/// Mendorong user untuk terus belajar BISINDO

import '../core/database_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Models
// ═══════════════════════════════════════════════════════════════════════════════

/// Badge yang bisa didapatkan user
class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String iconName;
  final int requiredValue;
  final String type; // 'translation', 'quiz', 'streak', 'learning'
  final bool isUnlocked;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.requiredValue,
    required this.type,
    this.isUnlocked = false,
  });

  BadgeModel copyWith({bool? isUnlocked}) {
    return BadgeModel(
      id: id,
      name: name,
      description: description,
      iconName: iconName,
      requiredValue: requiredValue,
      type: type,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

/// Progress belajar user
class UserProgress {
  final int totalTranslations;
  final int totalQuizAnswered;
  final int quizCorrect;
  final int currentStreak;
  final int longestStreak;
  final int lettersLearned;
  final int wordsLearned;
  final List<BadgeModel> badges;
  final DateTime? lastActiveDate;

  const UserProgress({
    this.totalTranslations = 0,
    this.totalQuizAnswered = 0,
    this.quizCorrect = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lettersLearned = 0,
    this.wordsLearned = 0,
    this.badges = const [],
    this.lastActiveDate,
  });

  double get quizAccuracy =>
      totalQuizAnswered > 0 ? (quizCorrect / totalQuizAnswered) * 100 : 0;

  int get totalBadgesUnlocked => badges.where((b) => b.isUnlocked).length;
}

/// Entry leaderboard
class LeaderboardEntry {
  final int rank;
  final String userName;
  final String role;
  final int score;
  final int badgeCount;

  const LeaderboardEntry({
    required this.rank,
    required this.userName,
    required this.role,
    required this.score,
    required this.badgeCount,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// Badge Definitions
// ═══════════════════════════════════════════════════════════════════════════════

/// Semua badge yang tersedia di aplikasi
class BadgeDefinitions {
  static const List<BadgeModel> all = [
    // Translation badges
    BadgeModel(
      id: 'first_translation',
      name: 'Penerjemah Pemula',
      description: 'Lakukan terjemahan pertama',
      iconName: 'translate',
      requiredValue: 1,
      type: 'translation',
    ),
    BadgeModel(
      id: 'translator_10',
      name: 'Penerjemah Aktif',
      description: 'Lakukan 10 terjemahan',
      iconName: 'translate',
      requiredValue: 10,
      type: 'translation',
    ),
    BadgeModel(
      id: 'translator_50',
      name: 'Penerjemah Handal',
      description: 'Lakukan 50 terjemahan',
      iconName: 'star',
      requiredValue: 50,
      type: 'translation',
    ),
    BadgeModel(
      id: 'translator_100',
      name: 'Master Penerjemah',
      description: 'Lakukan 100 terjemahan',
      iconName: 'emoji_events',
      requiredValue: 100,
      type: 'translation',
    ),

    // Quiz badges
    BadgeModel(
      id: 'quiz_first',
      name: 'Pelajar Baru',
      description: 'Jawab quiz pertama dengan benar',
      iconName: 'school',
      requiredValue: 1,
      type: 'quiz',
    ),
    BadgeModel(
      id: 'quiz_10',
      name: 'Pelajar Rajin',
      description: 'Jawab 10 quiz dengan benar',
      iconName: 'school',
      requiredValue: 10,
      type: 'quiz',
    ),
    BadgeModel(
      id: 'quiz_50',
      name: 'Pelajar Cerdas',
      description: 'Jawab 50 quiz dengan benar',
      iconName: 'psychology',
      requiredValue: 50,
      type: 'quiz',
    ),

    // Streak badges
    BadgeModel(
      id: 'streak_3',
      name: 'Konsisten',
      description: 'Streak 3 hari berturut-turut',
      iconName: 'local_fire_department',
      requiredValue: 3,
      type: 'streak',
    ),
    BadgeModel(
      id: 'streak_7',
      name: 'Semangat Membara',
      description: 'Streak 7 hari berturut-turut',
      iconName: 'local_fire_department',
      requiredValue: 7,
      type: 'streak',
    ),
    BadgeModel(
      id: 'streak_30',
      name: 'Tak Terbendung',
      description: 'Streak 30 hari berturut-turut',
      iconName: 'whatshot',
      requiredValue: 30,
      type: 'streak',
    ),

    // Learning badges
    BadgeModel(
      id: 'alphabet_half',
      name: 'Setengah Jalan',
      description: 'Pelajari 13 huruf BISINDO',
      iconName: 'abc',
      requiredValue: 13,
      type: 'learning',
    ),
    BadgeModel(
      id: 'alphabet_all',
      name: 'Master Alfabet',
      description: 'Pelajari semua 26 huruf BISINDO',
      iconName: 'military_tech',
      requiredValue: 26,
      type: 'learning',
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════════
// Service: GamificationService
// ═══════════════════════════════════════════════════════════════════════════════

class GamificationService {
  final DatabaseHelper _db = DatabaseHelper();

  // ─── Get User Progress ────────────────────────────────────────────────────

  /// Mendapatkan progress lengkap user
  Future<UserProgress> getUserProgress(int userId) async {
    try {
      // Total terjemahan
      final totalTranslations = await _db.count(
        'translation_history',
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // Quiz stats dari feedback (quiz answers stored as feedback)
      final totalQuizAnswered = await _db.count(
        'feedbacks',
        where: 'user_id = ? AND type = ?',
        whereArgs: [userId, 'translation'],
      );

      final quizCorrect = await _db.count(
        'feedbacks',
        where: 'user_id = ? AND type = ? AND rating >= 4',
        whereArgs: [userId, 'translation'],
      );

      // Streak calculation
      final streakData = await _calculateStreak(userId);

      // Letters learned (unique detected gestures)
      final lettersResult = await _db.rawQuery(
        'SELECT COUNT(DISTINCT detected_gesture_id) as count FROM translation_history WHERE user_id = ? AND detected_gesture_id IS NOT NULL',
        [userId],
      );
      final lettersLearned = lettersResult.isNotEmpty
          ? (lettersResult.first['count'] as int? ?? 0)
          : 0;

      // Words learned (unique translations)
      final wordsResult = await _db.rawQuery(
        'SELECT COUNT(DISTINCT input_data) as count FROM translation_history WHERE user_id = ? AND input_type = ?',
        [userId, 'text'],
      );
      final wordsLearned = wordsResult.isNotEmpty
          ? (wordsResult.first['count'] as int? ?? 0)
          : 0;

      // Calculate badges
      final badges = _calculateBadges(
        totalTranslations: totalTranslations,
        quizCorrect: quizCorrect,
        currentStreak: streakData['current'] as int,
        lettersLearned: lettersLearned,
      );

      return UserProgress(
        totalTranslations: totalTranslations,
        totalQuizAnswered: totalQuizAnswered,
        quizCorrect: quizCorrect,
        currentStreak: streakData['current'] as int,
        longestStreak: streakData['longest'] as int,
        lettersLearned: lettersLearned,
        wordsLearned: wordsLearned,
        badges: badges,
        lastActiveDate: streakData['lastActive'] as DateTime?,
      );
    } catch (e) {
      return const UserProgress();
    }
  }

  // ─── Streak Calculation ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> _calculateStreak(int userId) async {
    try {
      // Get all unique active dates
      final results = await _db.rawQuery(
        "SELECT DISTINCT DATE(created_at) as active_date FROM translation_history WHERE user_id = ? ORDER BY active_date DESC",
        [userId],
      );

      if (results.isEmpty) {
        return {'current': 0, 'longest': 0, 'lastActive': null};
      }

      final dates = results
          .map((r) => DateTime.tryParse(r['active_date'] as String? ?? ''))
          .where((d) => d != null)
          .cast<DateTime>()
          .toList();

      if (dates.isEmpty) {
        return {'current': 0, 'longest': 0, 'lastActive': null};
      }

      // Calculate current streak
      int currentStreak = 0;
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      for (int i = 0; i < dates.length; i++) {
        final expectedDate = todayDate.subtract(Duration(days: i));
        final dateOnly = DateTime(dates[i].year, dates[i].month, dates[i].day);

        if (dateOnly == expectedDate) {
          currentStreak++;
        } else if (i == 0 && dateOnly == todayDate.subtract(const Duration(days: 1))) {
          // Allow yesterday as start if not active today
          currentStreak++;
        } else {
          break;
        }
      }

      // Calculate longest streak
      int longestStreak = 0;
      int tempStreak = 1;

      for (int i = 1; i < dates.length; i++) {
        final diff = dates[i - 1].difference(dates[i]).inDays;
        if (diff == 1) {
          tempStreak++;
        } else {
          longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
          tempStreak = 1;
        }
      }
      longestStreak = tempStreak > longestStreak ? tempStreak : longestStreak;
      if (currentStreak > longestStreak) longestStreak = currentStreak;

      return {
        'current': currentStreak,
        'longest': longestStreak,
        'lastActive': dates.first,
      };
    } catch (e) {
      return {'current': 0, 'longest': 0, 'lastActive': null};
    }
  }

  // ─── Badge Calculation ────────────────────────────────────────────────────

  List<BadgeModel> _calculateBadges({
    required int totalTranslations,
    required int quizCorrect,
    required int currentStreak,
    required int lettersLearned,
  }) {
    return BadgeDefinitions.all.map((badge) {
      int currentValue;
      switch (badge.type) {
        case 'translation':
          currentValue = totalTranslations;
          break;
        case 'quiz':
          currentValue = quizCorrect;
          break;
        case 'streak':
          currentValue = currentStreak;
          break;
        case 'learning':
          currentValue = lettersLearned;
          break;
        default:
          currentValue = 0;
      }

      return badge.copyWith(isUnlocked: currentValue >= badge.requiredValue);
    }).toList();
  }

  // ─── Leaderboard ──────────────────────────────────────────────────────────

  /// Mendapatkan leaderboard berdasarkan total aktivitas
  Future<List<LeaderboardEntry>> getLeaderboard({int limit = 10}) async {
    try {
      final results = await _db.rawQuery('''
        SELECT 
          u.id,
          u.username,
          u.role,
          COUNT(th.id) as score,
          (SELECT COUNT(*) FROM feedbacks f WHERE f.user_id = u.id AND f.rating >= 4) as badge_score
        FROM users u
        LEFT JOIN translation_history th ON th.user_id = u.id
        WHERE u.is_active = 1
        GROUP BY u.id
        ORDER BY score DESC
        LIMIT ?
      ''', [limit]);

      final entries = <LeaderboardEntry>[];
      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        entries.add(LeaderboardEntry(
          rank: i + 1,
          userName: r['username'] as String? ?? 'Unknown',
          role: r['role'] as String? ?? 'learner',
          score: r['score'] as int? ?? 0,
          badgeCount: r['badge_score'] as int? ?? 0,
        ));
      }

      return entries;
    } catch (e) {
      return [];
    }
  }
}
