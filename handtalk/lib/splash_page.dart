/// HandTalk - Splash Page
/// Pattern: StatefulWidget + setState(), imperative navigation
/// Animated splash screen dengan inisialisasi database

import 'package:flutter/material.dart';

import 'core/database_helper.dart';
import 'core/constants.dart';
import 'core/themes.dart';
import 'login_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  // ─── Animation Controller ───────────────────────────────────────────────────
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // ─── Setup Animations ───────────────────────────────────────────────────────

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();
  }

  // ─── Initialize App ─────────────────────────────────────────────────────────

  Future<void> _initializeApp() async {
    try {
      // Inisialisasi database
      final db = DatabaseHelper();
      await db.database;

      // Seed data jika belum ada
      final hasCategories = await db.hasData('categories');
      if (!hasCategories) {
        await db.seedFromJson();
      }

      // Tunggu minimal splash duration
      await Future.delayed(
        Duration(seconds: AppConstants.splashDuration),
      );

      // Navigasi ke LoginPage
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      // Tetap navigasi meskipun ada error
      await Future.delayed(
        Duration(seconds: AppConstants.splashDuration),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  // ─── Build Methods ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  _buildLogo(),
                  const SizedBox(height: 24),
                  _buildAppName(),
                  const SizedBox(height: 8),
                  _buildTagline(),
                  const SizedBox(height: 20),
                  _buildThemeBadge(),
                  const SizedBox(height: 12),
                  _buildDescription(),
                  const Spacer(flex: 2),
                  _buildLoadingSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/logo.png',
          width: 120,
          height: 120,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildAppName() {
    return const Text(
      AppConstants.appName,
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTagline() {
    return Text(
      AppConstants.appTagline,
      style: TextStyle(
        fontSize: 16,
        color: Colors.white.withOpacity(0.9),
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildThemeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        AppConstants.appTheme,
        style: TextStyle(
          fontSize: 13,
          color: Colors.white.withOpacity(0.95),
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDescription() {
    return Text(
      AppConstants.appDescription,
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withOpacity(0.7),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildLoadingSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withOpacity(0.9),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Memuat data BISINDO...',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
