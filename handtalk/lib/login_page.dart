/// HandTalk - Login/Register Page
/// Pattern: StatefulWidget + setState(), imperative navigation, SnackBar feedback
/// Tabbed auth page: Masuk (Login) & Daftar (Register)

import 'package:flutter/material.dart';

import 'core/themes.dart';
import 'core/constants.dart';
import 'services/auth_service.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // ─── Tab Controller ─────────────────────────────────────────────────────────
  late TabController _tabController;

  // ─── Form Keys ──────────────────────────────────────────────────────────────
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // ─── Login Controllers ──────────────────────────────────────────────────────
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // ─── Register Controllers ───────────────────────────────────────────────────
  final _registerNameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();

  // ─── State Variables ────────────────────────────────────────────────────────
  bool _loginLoading = false;
  bool _registerLoading = false;
  bool _loginPasswordVisible = false;
  bool _registerPasswordVisible = false;
  bool _registerConfirmPasswordVisible = false;
  String _selectedRole = 'learner';

  // ─── Role Options ───────────────────────────────────────────────────────────
  final List<Map<String, String>> _roleOptions = [
    {'value': 'learner', 'label': 'Orang Dengar'},
    {'value': 'instructor', 'label': 'Teman Tuli'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  // ─── Login Handler ──────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _loginLoading = true);

    try {
      final authService = AuthService();
      final result = await authService.login(
        _loginEmailController.text.trim(),
        _loginPasswordController.text,
      );

      if (!mounted) return;

      if (result != null) {
        final user = result['user'] as UserModel;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomePage(user: user)),
        );
      } else {
        _showSnackBar('Email atau password salah', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan saat login', isError: true);
    } finally {
      if (mounted) {
        setState(() => _loginLoading = false);
      }
    }
  }

  // ─── Register Handler ───────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _registerLoading = true);

    try {
      final authService = AuthService();
      final user = await authService.register(
        _registerNameController.text.trim(),
        _registerEmailController.text.trim(),
        _registerPasswordController.text,
        _selectedRole,
      );

      if (!mounted) return;

      if (user != null) {
        _showSnackBar('Registrasi berhasil! Silakan masuk.', isError: false);

        // Clear register form
        _registerNameController.clear();
        _registerEmailController.clear();
        _registerPasswordController.clear();
        _registerConfirmPasswordController.clear();
        setState(() => _selectedRole = 'learner');

        // Switch to login tab
        _tabController.animateTo(0);
      } else {
        _showSnackBar(
          'Registrasi gagal. Email atau username sudah terdaftar.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan saat registrasi', isError: true);
    } finally {
      if (mounted) {
        setState(() => _registerLoading = false);
      }
    }
  }

  // ─── SnackBar Helper ────────────────────────────────────────────────────────

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Build Methods ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(),
                  _buildRegisterTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.sign_language,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            AppConstants.appName,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppConstants.appTagline,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Masuk'),
          Tab(text: 'Daftar'),
        ],
      ),
    );
  }

  // ─── Login Tab ──────────────────────────────────────────────────────────────

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _buildLoginEmailField(),
            const SizedBox(height: 16),
            _buildLoginPasswordField(),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _handleForgotPassword,
                child: const Text(
                  'Lupa Password?',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  // ─── Forgot Password Handler ────────────────────────────────────────────────

  Future<void> _handleForgotPassword() async {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    final newPasswordController = TextEditingController();

    // Step 1: Minta email
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lupa Password', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Masukkan email yang terdaftar untuk mendapatkan kode reset.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, emailController.text.trim()),
            child: const Text('Kirim Kode'),
          ),
        ],
      ),
    );

    if (email == null || email.isEmpty) return;

    // Request reset code
    final authService = AuthService();
    final code = await authService.requestPasswordReset(email);

    if (!mounted) return;

    if (code == null) {
      _showSnackBar('Email tidak ditemukan', isError: true);
      return;
    }

    // Step 2: Tampilkan kode dan minta password baru
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.info, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kode reset Anda: $code',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Masukkan Kode Reset',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password Baru',
                hintText: 'Minimal 6 karakter',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Password'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Proses reset
    final success = await authService.resetPassword(
      email,
      codeController.text.trim(),
      newPasswordController.text,
    );

    if (!mounted) return;

    if (success) {
      _showSnackBar('Password berhasil direset! Silakan login.', isError: false);
    } else {
      _showSnackBar('Gagal reset password. Kode salah atau password terlalu pendek.', isError: true);
    }
  }

  Widget _buildLoginEmailField() {
    return TextFormField(
      controller: _loginEmailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'Masukkan email Anda',
        prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Email tidak boleh kosong';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
          return 'Format email tidak valid';
        }
        return null;
      },
    );
  }

  Widget _buildLoginPasswordField() {
    return TextFormField(
      controller: _loginPasswordController,
      obscureText: !_loginPasswordVisible,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Masukkan password',
        prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _loginPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textSecondary,
          ),
          onPressed: () {
            setState(() => _loginPasswordVisible = !_loginPasswordVisible);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password tidak boleh kosong';
        }
        if (value.length < AppConstants.minPasswordLength) {
          return 'Password minimal ${AppConstants.minPasswordLength} karakter';
        }
        return null;
      },
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _loginLoading ? null : _handleLogin,
        child: _loginLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Masuk',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  // ─── Register Tab ───────────────────────────────────────────────────────────

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _buildRegisterNameField(),
            const SizedBox(height: 16),
            _buildRegisterEmailField(),
            const SizedBox(height: 16),
            _buildRegisterPasswordField(),
            const SizedBox(height: 16),
            _buildRegisterConfirmPasswordField(),
            const SizedBox(height: 20),
            _buildRoleSelector(),
            const SizedBox(height: 28),
            _buildRegisterButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterNameField() {
    return TextFormField(
      controller: _registerNameController,
      textInputAction: TextInputAction.next,
      textCapitalization: TextCapitalization.words,
      decoration: const InputDecoration(
        labelText: 'Nama',
        hintText: 'Masukkan nama Anda',
        prefixIcon: Icon(Icons.person_outlined, color: AppColors.primary),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Nama tidak boleh kosong';
        }
        if (value.trim().length < AppConstants.minUsernameLength) {
          return 'Nama minimal ${AppConstants.minUsernameLength} karakter';
        }
        if (value.trim().length > AppConstants.maxUsernameLength) {
          return 'Nama maksimal ${AppConstants.maxUsernameLength} karakter';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterEmailField() {
    return TextFormField(
      controller: _registerEmailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Email',
        hintText: 'Masukkan email Anda',
        prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Email tidak boleh kosong';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
          return 'Format email tidak valid';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterPasswordField() {
    return TextFormField(
      controller: _registerPasswordController,
      obscureText: !_registerPasswordVisible,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'Minimal ${AppConstants.minPasswordLength} karakter',
        prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _registerPasswordVisible ? Icons.visibility_off : Icons.visibility,
            color: AppColors.textSecondary,
          ),
          onPressed: () {
            setState(
                () => _registerPasswordVisible = !_registerPasswordVisible);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Password tidak boleh kosong';
        }
        if (value.length < AppConstants.minPasswordLength) {
          return 'Password minimal ${AppConstants.minPasswordLength} karakter';
        }
        return null;
      },
    );
  }

  Widget _buildRegisterConfirmPasswordField() {
    return TextFormField(
      controller: _registerConfirmPasswordController,
      obscureText: !_registerConfirmPasswordVisible,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: 'Konfirmasi Password',
        hintText: 'Ulangi password Anda',
        prefixIcon:
            const Icon(Icons.lock_reset_outlined, color: AppColors.primary),
        suffixIcon: IconButton(
          icon: Icon(
            _registerConfirmPasswordVisible
                ? Icons.visibility_off
                : Icons.visibility,
            color: AppColors.textSecondary,
          ),
          onPressed: () {
            setState(() => _registerConfirmPasswordVisible =
                !_registerConfirmPasswordVisible);
          },
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Konfirmasi password tidak boleh kosong';
        }
        if (value != _registerPasswordController.text) {
          return 'Password tidak cocok';
        }
        return null;
      },
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Saya adalah:',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: _roleOptions.map((role) {
            final isSelected = _selectedRole == role['value'];
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: role == _roleOptions.first ? 6 : 0,
                  left: role == _roleOptions.last ? 6 : 0,
                ),
                child: _buildRoleChip(
                  label: role['label']!,
                  value: role['value']!,
                  isSelected: isSelected,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRoleChip({
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        setState(() => _selectedRole = value);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.textHint,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              value == 'learner'
                  ? Icons.hearing_outlined
                  : Icons.accessibility_new_outlined,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _registerLoading ? null : _handleRegister,
        child: _registerLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Daftar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
