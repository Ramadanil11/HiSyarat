/// HandTalk - Profile Page
/// Pattern: StatefulWidget + setState(), imperative navigation, SnackBar feedback
/// Menampilkan profil user, statistik feedback, info aplikasi, dan logout

import 'package:flutter/material.dart';

import 'core/themes.dart';
import 'core/constants.dart';
import 'services/auth_service.dart';
import 'services/feedback_service.dart';
import 'services/gamification_service.dart';
import 'login_page.dart';

class ProfilePage extends StatefulWidget {
  final UserModel user;

  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ─── State Variables ──────────────────────────────────────────────────────
  bool _isLoadingStats = true;
  int _correctCount = 0;
  int _incorrectCount = 0;
  double _accuracy = 0.0;
  UserProgress? _userProgress;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadFeedbackStats();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  Future<void> _loadFeedbackStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final feedbackService = FeedbackService();
      final gamificationService = GamificationService();
      final userId = widget.user.id ?? 0;

      final stats = await feedbackService.getFeedbackStats(userId);
      final progress = await gamificationService.getUserProgress(userId);

      if (!mounted) return;

      setState(() {
        _correctCount = stats['correct'] as int? ?? 0;
        _incorrectCount = stats['incorrect'] as int? ?? 0;
        _accuracy = (stats['accuracy'] as num?)?.toDouble() ?? 0.0;
        _userProgress = progress;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingStats = false);
      _showSnackBar('Gagal memuat statistik', isError: true);
    }
  }

  // ─── Logout Handler ───────────────────────────────────────────────────────

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar'),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // ─── SnackBar Helper ──────────────────────────────────────────────────────

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Keluar',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildFeedbackStatsSection(),
            const SizedBox(height: 16),
            _buildStreakAndProgressSection(),
            const SizedBox(height: 16),
            _buildBadgesSection(),
            const SizedBox(height: 16),
            _buildAppInfoSection(),
            const SizedBox(height: 16),
            _buildVariablesSummary(),
            const SizedBox(height: 24),
            _buildLogoutButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── Profile Header ───────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    final firstLetter = widget.user.name.isNotEmpty
        ? widget.user.name[0].toUpperCase()
        : '?';
    final roleBadge = _getRoleBadge(widget.user.role);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 3),
            ),
            child: Center(
              child: Text(
                firstLetter,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Name
          Text(
            widget.user.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          // Email
          Text(
            widget.user.email,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 12),
          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Text(
              roleBadge,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Feedback Statistics Section ──────────────────────────────────────────

  Widget _buildFeedbackStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistik Feedback',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _isLoadingStats
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildFeedbackStatItem(
                          icon: Icons.check_circle_outline,
                          value: '$_correctCount',
                          label: 'Benar',
                          color: AppColors.success,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.textHint.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _buildFeedbackStatItem(
                          icon: Icons.cancel_outlined,
                          value: '$_incorrectCount',
                          label: 'Salah',
                          color: AppColors.error,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: AppColors.textHint.withOpacity(0.3),
                      ),
                      Expanded(
                        child: _buildFeedbackStatItem(
                          icon: Icons.percent,
                          value: '${_accuracy.toStringAsFixed(1)}%',
                          label: 'Akurasi',
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildFeedbackStatItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ─── Streak & Progress Section ──────────────────────────────────────────

  Widget _buildStreakAndProgressSection() {
    if (_userProgress == null) return const SizedBox.shrink();

    final progress = _userProgress!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Belajar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Streak row
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: progress.currentStreak > 0
                            ? Colors.orange.withOpacity(0.15)
                            : AppColors.textHint.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_fire_department,
                        color: progress.currentStreak > 0
                            ? Colors.orange
                            : AppColors.textHint,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${progress.currentStreak} Hari Streak',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Terpanjang: ${progress.longestStreak} hari',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 16),
                // Stats grid
                Row(
                  children: [
                    Expanded(
                      child: _buildProgressStat(
                        icon: Icons.translate,
                        value: '${progress.totalTranslations}',
                        label: 'Terjemahan',
                        color: AppColors.primary,
                      ),
                    ),
                    Expanded(
                      child: _buildProgressStat(
                        icon: Icons.abc,
                        value: '${progress.lettersLearned}',
                        label: 'Huruf',
                        color: AppColors.info,
                      ),
                    ),
                    Expanded(
                      child: _buildProgressStat(
                        icon: Icons.quiz,
                        value: '${progress.quizCorrect}',
                        label: 'Quiz Benar',
                        color: AppColors.success,
                      ),
                    ),
                    Expanded(
                      child: _buildProgressStat(
                        icon: Icons.emoji_events,
                        value: '${progress.totalBadgesUnlocked}',
                        label: 'Badge',
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  // ─── Badges Section ───────────────────────────────────────────────────────

  Widget _buildBadgesSection() {
    if (_userProgress == null) return const SizedBox.shrink();

    final badges = _userProgress!.badges;
    final unlockedBadges = badges.where((b) => b.isUnlocked).toList();
    final lockedBadges = badges.where((b) => !b.isUnlocked).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Badge',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${unlockedBadges.length}/${badges.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Unlocked badges
          if (unlockedBadges.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: unlockedBadges.map((badge) {
                return _buildBadgeChip(badge, unlocked: true);
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          // Locked badges (dimmed)
          if (lockedBadges.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: lockedBadges.map((badge) {
                return _buildBadgeChip(badge, unlocked: false);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildBadgeChip(BadgeModel badge, {required bool unlocked}) {
    return Tooltip(
      message: '${badge.name}\n${badge.description}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: unlocked
              ? AppColors.secondary.withOpacity(0.12)
              : AppColors.textHint.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: unlocked
                ? AppColors.secondary.withOpacity(0.4)
                : AppColors.textHint.withOpacity(0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getBadgeIcon(badge.iconName),
              size: 14,
              color: unlocked ? AppColors.secondary : AppColors.textHint,
            ),
            const SizedBox(width: 4),
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: unlocked ? FontWeight.w600 : FontWeight.w400,
                color: unlocked ? AppColors.textPrimary : AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getBadgeIcon(String iconName) {
    switch (iconName) {
      case 'translate':
        return Icons.translate;
      case 'star':
        return Icons.star;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'school':
        return Icons.school;
      case 'psychology':
        return Icons.psychology;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'abc':
        return Icons.abc;
      case 'military_tech':
        return Icons.military_tech;
      default:
        return Icons.badge;
    }
  }

  // ─── App Info Section ─────────────────────────────────────────────────────

  Widget _buildAppInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Aplikasi',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  icon: Icons.apps,
                  label: 'Nama Aplikasi',
                  value: AppConstants.appName,
                ),
                _buildInfoDivider(),
                _buildInfoRow(
                  icon: Icons.palette_outlined,
                  label: 'Tema',
                  value: AppConstants.appTheme,
                ),
                _buildInfoDivider(),
                _buildInfoRow(
                  icon: Icons.description_outlined,
                  label: 'Deskripsi',
                  value: AppConstants.appDescription,
                ),
                _buildInfoDivider(),
                _buildInfoRow(
                  icon: Icons.sign_language,
                  label: 'Bahasa Isyarat',
                  value: 'BISINDO',
                ),
                _buildInfoDivider(),
                _buildInfoRow(
                  icon: Icons.info_outline,
                  label: 'Versi',
                  value: 'v${AppConstants.appVersion}',
                ),
                _buildInfoDivider(),
                _buildInfoRow(
                  icon: Icons.psychology_outlined,
                  label: 'Model AI',
                  value: 'MediaPipe Pose (${AppConstants.defaultAccuracy}%)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoDivider() {
    return Divider(
      height: 1,
      color: AppColors.textHint.withOpacity(0.2),
    );
  }

  // ─── 9 Variables Summary ──────────────────────────────────────────────────

  Widget _buildVariablesSummary() {
    final variables = [
      {'name': 'User', 'desc': 'Data pengguna', 'unit': 'record'},
      {'name': 'Gesture', 'desc': 'Gerakan isyarat', 'unit': 'buah'},
      {'name': 'Category', 'desc': 'Kategori gesture', 'unit': 'kategori'},
      {'name': 'Vocabulary', 'desc': 'Kosakata BISINDO', 'unit': 'kata'},
      {'name': 'Translation', 'desc': 'Data terjemahan', 'unit': 'record'},
      {'name': 'History', 'desc': 'Riwayat terjemahan', 'unit': 'log'},
      {'name': 'Feedback', 'desc': 'Umpan balik user', 'unit': 'entry'},
      {'name': 'AI Model', 'desc': 'Data model AI', 'unit': 'model'},
      {'name': 'Session', 'desc': 'Sesi pengguna', 'unit': 'sesi'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '9 Variabel Data',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: List.generate(variables.length, (index) {
                final variable = variables[index];
                final color = AppColors
                    .categoryColors[index % AppColors.categoryColors.length];
                return Column(
                  children: [
                    if (index > 0)
                      Divider(
                        height: 1,
                        color: AppColors.textHint.withOpacity(0.15),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  variable['name']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  variable['desc']!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              variable['unit']!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Logout Button ────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _handleLogout,
          icon: const Icon(Icons.logout, size: 20),
          label: const Text(
            'Keluar dari Akun',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _getRoleBadge(String role) {
    switch (role) {
      case 'learner':
        return 'Orang Dengar (Learner)';
      case 'instructor':
        return 'Teman Tuli (Instructor)';
      case 'admin':
        return 'Administrator';
      default:
        return role;
    }
  }
}
