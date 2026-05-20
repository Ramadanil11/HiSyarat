/// HandTalk - Home/Dashboard Page
/// Pattern: StatefulWidget + setState(), imperative navigation, SnackBar feedback
/// Bottom navigation with 4 tabs: Beranda, Terjemah, Riwayat, Profil

import 'package:flutter/material.dart';

import 'core/themes.dart';
import 'core/constants.dart';
import 'services/auth_service.dart';
import 'services/translation_service.dart';
import 'translate_page.dart';
import 'dictionary_page.dart';
import 'history_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final UserModel user;

  const HomePage({super.key, required this.user});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ─── State Variables ──────────────────────────────────────────────────────
  int _currentNavIndex = 0;
  bool _isLoadingStats = true;
  Map<String, dynamic> _stats = {};
  List<CategoryModel> _categories = [];

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ─── Data Loading ─────────────────────────────────────────────────────────

  Future<void> _loadDashboardData() async {
    setState(() => _isLoadingStats = true);

    try {
      final translationService = TranslationService();
      final userId = widget.user.id ?? 0;

      final stats = await translationService.getDashboardStats(userId);
      final categories = await translationService.getAllCategories();

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _categories = categories;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingStats = false);
      _showSnackBar('Gagal memuat data dashboard', isError: true);
    }
  }

  // ─── Navigation Handler ───────────────────────────────────────────────────

  void _onNavTap(int index) {
    if (index == 0) {
      setState(() => _currentNavIndex = 0);
      return;
    }

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TranslatePage(user: widget.user),
        ),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HistoryPage(user: widget.user),
        ),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfilePage(user: widget.user),
        ),
      );
    }
  }

  // ─── SnackBar Helper ──────────────────────────────────────────────────────

  void _showSnackBar(String message, {bool isError = false}) {
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
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildStatsGrid(),
              const SizedBox(height: 20),
              _buildCategoriesSection(),
              const SizedBox(height: 20),
              _buildInfoCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─── Header with Gradient ─────────────────────────────────────────────────

  Widget _buildHeader() {
    final roleSubtitle = _getRoleSubtitle();

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
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: greeting + icon
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, ${widget.user.name}!',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          roleSubtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.sign_language,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Quick action buttons
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.translate,
                      label: 'Terjemahkan',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TranslatePage(user: widget.user),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.menu_book_rounded,
                      label: 'Kamus BISINDO',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DictionaryPage(user: widget.user),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 20,
                    semanticLabel: label),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Statistics Grid ──────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    if (_isLoadingStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final statItems = [
      _StatItem(
        label: 'Gesture',
        value: '${_stats['totalGestures'] ?? 0}',
        unit: 'buah',
        icon: Icons.back_hand_outlined,
        color: AppColors.primary,
      ),
      _StatItem(
        label: 'Kosakata',
        value: '${_stats['totalVocabularies'] ?? 0}',
        unit: 'kata',
        icon: Icons.text_fields,
        color: AppColors.secondary,
      ),
      _StatItem(
        label: 'Kategori',
        value: '${_stats['totalCategories'] ?? 0}',
        unit: 'kategori',
        icon: Icons.category_outlined,
        color: AppColors.accent,
      ),
      _StatItem(
        label: 'Terjemahan',
        value: '${_stats['totalTranslations'] ?? 0}',
        unit: 'kali',
        icon: Icons.translate,
        color: AppColors.info,
      ),
      _StatItem(
        label: 'Sesi',
        value: '${_stats['totalSessions'] ?? 0}',
        unit: 'sesi',
        icon: Icons.timer_outlined,
        color: AppColors.success,
      ),
      _StatItem(
        label: 'Akurasi AI',
        value: '${(_stats['aiAccuracy'] as num?)?.toStringAsFixed(1) ?? '0.0'}',
        unit: '%',
        icon: Icons.psychology_outlined,
        color: AppColors.primaryDark,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistik',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: statItems.length,
            itemBuilder: (context, index) {
              return _buildStatCard(statItems[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Semantics(
      label: '${item.label}: ${item.value} ${item.unit}',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, color: item.color, size: 22,
                semanticLabel: item.label),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: item.color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Categories Section ───────────────────────────────────────────────────

  Widget _buildCategoriesSection() {
    if (_categories.isEmpty && !_isLoadingStats) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kategori BISINDO',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: _categories.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada kategori',
                      style: TextStyle(color: AppColors.textHint),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      return _buildCategoryChip(_categories[index], index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(CategoryModel category, int index) {
    final color = AppColors.categoryColors[index % AppColors.categoryColors.length];
    final iconData = _getCategoryIcon(category.iconName);

    return GestureDetector(
      onTap: () {
        // Navigate to Kamus BISINDO page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DictionaryPage(user: widget.user),
          ),
        );
      },
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              category.name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Info Card ────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryLight.withOpacity(0.15),
              AppColors.primary.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Tentang BISINDO',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'BISINDO (Bahasa Isyarat Indonesia) adalah bahasa isyarat alami '
              'yang digunakan oleh komunitas Tuli di Indonesia. Berbeda dengan '
              'SIBI yang mengikuti struktur bahasa Indonesia lisan, BISINDO '
              'memiliki tata bahasa dan struktur sendiri yang berkembang secara '
              'alami dalam komunitas Tuli.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bottom Navigation ────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentNavIndex,
      onTap: _onNavTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Beranda',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.translate_outlined),
          activeIcon: Icon(Icons.translate),
          label: 'Terjemah',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'Riwayat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _getRoleSubtitle() {
    switch (widget.user.role) {
      case 'learner':
        return 'Selamat belajar BISINDO! 🤟';
      case 'instructor':
        return 'Terima kasih telah mengajar! 🙌';
      case 'admin':
        return 'Panel Administrator';
      default:
        return AppConstants.appTagline;
    }
  }

  IconData _getCategoryIcon(String? iconName) {
    switch (iconName) {
      case 'greeting':
        return Icons.waving_hand;
      case 'family':
        return Icons.family_restroom;
      case 'food':
        return Icons.restaurant;
      case 'emotion':
        return Icons.emoji_emotions;
      case 'number':
        return Icons.pin;
      case 'color':
        return Icons.palette;
      case 'animal':
        return Icons.pets;
      case 'place':
        return Icons.place;
      case 'time':
        return Icons.access_time;
      case 'activity':
        return Icons.directions_run;
      default:
        return Icons.label_outline;
    }
  }
}

// ─── Helper Model ─────────────────────────────────────────────────────────────

class _StatItem {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });
}
