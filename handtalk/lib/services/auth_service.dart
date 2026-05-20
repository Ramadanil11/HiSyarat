/// HandTalk Authentication Service
/// Mengelola registrasi, login, session management, dan reset password
/// Keamanan: SHA-256 + salt per-user, session token, password reset

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../core/database_helper.dart';
import '../core/constants.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Model: UserModel
// ═══════════════════════════════════════════════════════════════════════════════

/// Model untuk data user
class UserModel {
  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final String salt;
  final String role;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    this.salt = '',
    required this.role,
    required this.createdAt,
  });

  /// Membuat UserModel dari Map (hasil query database)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: map['username'] as String? ?? map['full_name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      passwordHash: map['password_hash'] as String? ?? '',
      salt: map['salt'] as String? ?? '',
      role: map['role'] as String? ?? 'learner',
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Konversi UserModel ke Map untuk insert/update database
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'username': name,
      'full_name': name,
      'email': email,
      'password_hash': passwordHash,
      'salt': salt,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Membuat salinan UserModel dengan perubahan tertentu
  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? passwordHash,
    String? salt,
    String? role,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Model: SessionModel
// ═══════════════════════════════════════════════════════════════════════════════

/// Model untuk session login user
class SessionModel {
  final String token;
  final int userId;
  final DateTime createdAt;
  final DateTime expiresAt;

  SessionModel({
    required this.token,
    required this.userId,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

// ═══════════════════════════════════════════════════════════════════════════════
// Service: AuthService
// ═══════════════════════════════════════════════════════════════════════════════

/// Service autentikasi dengan keamanan yang ditingkatkan:
/// - Password hashing SHA-256 + random salt per-user
/// - Session token management dengan expiry
/// - Password reset via security code
class AuthService {
  final DatabaseHelper _db = DatabaseHelper();
  static const int _sessionDurationHours = 24;
  static const int _resetCodeLength = 6;

  // ─── In-memory session store (untuk local-only app) ───────────────────────
  static final Map<String, SessionModel> _sessions = {};
  static final Map<String, _ResetCode> _resetCodes = {};

  // ─── Salt Generation ──────────────────────────────────────────────────────

  /// Generate random salt (32 karakter hex)
  String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
    return saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  // ─── Hashing Password dengan Salt ─────────────────────────────────────────

  /// Hash password menggunakan SHA-256 + salt
  /// Format: SHA256(salt + password)
  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Hash password tanpa salt (backward compatibility untuk user lama)
  String _hashPasswordLegacy(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── Session Management ───────────────────────────────────────────────────

  /// Membuat session token baru untuk user
  String _createSession(int userId) {
    final token = const Uuid().v4();
    final now = DateTime.now();
    final session = SessionModel(
      token: token,
      userId: userId,
      createdAt: now,
      expiresAt: now.add(const Duration(hours: _sessionDurationHours)),
    );
    _sessions[token] = session;
    return token;
  }

  /// Validasi session token, return userId jika valid
  int? validateSession(String token) {
    final session = _sessions[token];
    if (session == null) return null;
    if (session.isExpired) {
      _sessions.remove(token);
      return null;
    }
    return session.userId;
  }

  /// Logout: hapus session token
  void logout(String token) {
    _sessions.remove(token);
  }

  /// Logout semua session user
  void logoutAll(int userId) {
    _sessions.removeWhere((_, session) => session.userId == userId);
  }

  // ─── Registrasi User Baru ─────────────────────────────────────────────────

  /// Mendaftarkan user baru ke database
  /// Mengembalikan UserModel jika berhasil, null jika gagal (email/username sudah ada)
  Future<UserModel?> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    try {
      // Validasi panjang username
      if (name.length < AppConstants.minUsernameLength ||
          name.length > AppConstants.maxUsernameLength) {
        return null;
      }

      // Validasi panjang password
      if (password.length < AppConstants.minPasswordLength) {
        return null;
      }

      // Validasi role
      if (!AppConstants.roles.contains(role)) {
        return null;
      }

      // Cek apakah email sudah terdaftar
      final existingEmail = await _db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );
      if (existingEmail.isNotEmpty) return null;

      // Cek apakah username sudah terdaftar
      final existingUsername = await _db.query(
        'users',
        where: 'username = ?',
        whereArgs: [name],
      );
      if (existingUsername.isNotEmpty) return null;

      // Generate salt dan hash password
      final salt = _generateSalt();
      final passwordHash = _hashPassword(password, salt);
      final now = DateTime.now();

      final user = UserModel(
        name: name,
        email: email,
        passwordHash: passwordHash,
        salt: salt,
        role: role,
        createdAt: now,
      );

      final id = await _db.insert('users', user.toMap());

      // Kembalikan user dengan ID yang baru dibuat
      return user.copyWith(id: id);
    } catch (e) {
      // Gagal registrasi (misal: constraint violation)
      return null;
    }
  }

  // ─── Login User ───────────────────────────────────────────────────────────

  /// Login user dengan email dan password
  /// Mengembalikan Map berisi UserModel dan session token jika berhasil
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      // Cari user berdasarkan email
      final results = await _db.query(
        'users',
        where: 'email = ? AND is_active = 1',
        whereArgs: [email],
      );

      if (results.isEmpty) return null;

      final userMap = results.first;
      final storedHash = userMap['password_hash'] as String? ?? '';
      final salt = userMap['salt'] as String? ?? '';

      // Verifikasi password
      String computedHash;
      if (salt.isNotEmpty) {
        // User baru: hash dengan salt
        computedHash = _hashPassword(password, salt);
      } else {
        // User lama (legacy): hash tanpa salt, lalu migrasi
        computedHash = _hashPasswordLegacy(password);
      }

      if (computedHash != storedHash) return null;

      final user = UserModel.fromMap(userMap);

      // Migrasi user lama ke salted hash
      if (salt.isEmpty && user.id != null) {
        final newSalt = _generateSalt();
        final newHash = _hashPassword(password, newSalt);
        await _db.update(
          'users',
          {'password_hash': newHash, 'salt': newSalt},
          where: 'id = ?',
          whereArgs: [user.id],
        );
      }

      // Buat session token
      final token = _createSession(user.id ?? 0);

      return {
        'user': user,
        'token': token,
      };
    } catch (e) {
      return null;
    }
  }

  // ─── Password Reset ───────────────────────────────────────────────────────

  /// Generate kode reset password (6 digit)
  /// Dalam app lokal, kode ditampilkan langsung ke user
  /// Return kode reset jika email ditemukan, null jika tidak
  Future<String?> requestPasswordReset(String email) async {
    try {
      final results = await _db.query(
        'users',
        where: 'email = ? AND is_active = 1',
        whereArgs: [email],
      );

      if (results.isEmpty) return null;

      // Generate 6-digit reset code
      final random = Random.secure();
      final code = List.generate(
        _resetCodeLength,
        (_) => random.nextInt(10),
      ).join();

      // Simpan kode reset (berlaku 15 menit)
      _resetCodes[email] = _ResetCode(
        code: code,
        expiresAt: DateTime.now().add(const Duration(minutes: 15)),
      );

      return code;
    } catch (e) {
      return null;
    }
  }

  /// Verifikasi kode reset dan ubah password
  /// Return true jika berhasil
  Future<bool> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      // Validasi password baru
      if (newPassword.length < AppConstants.minPasswordLength) return false;

      // Cek kode reset
      final resetCode = _resetCodes[email];
      if (resetCode == null) return false;
      if (resetCode.code != code) return false;
      if (DateTime.now().isAfter(resetCode.expiresAt)) {
        _resetCodes.remove(email);
        return false;
      }

      // Generate salt baru dan hash password baru
      final newSalt = _generateSalt();
      final newHash = _hashPassword(newPassword, newSalt);

      // Update password di database
      final updated = await _db.update(
        'users',
        {
          'password_hash': newHash,
          'salt': newSalt,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'email = ? AND is_active = 1',
        whereArgs: [email],
      );

      if (updated > 0) {
        // Hapus kode reset yang sudah dipakai
        _resetCodes.remove(email);

        // Logout semua session user
        final userResults = await _db.query(
          'users',
          where: 'email = ?',
          whereArgs: [email],
        );
        if (userResults.isNotEmpty) {
          final userId = userResults.first['id'] as int? ?? 0;
          logoutAll(userId);
        }

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // ─── Change Password (saat sudah login) ───────────────────────────────────

  /// Ubah password user yang sudah login
  /// Memerlukan password lama untuk verifikasi
  Future<bool> changePassword(
    int userId,
    String oldPassword,
    String newPassword,
  ) async {
    try {
      if (newPassword.length < AppConstants.minPasswordLength) return false;

      // Ambil data user
      final userMap = await _db.queryById('users', userId);
      if (userMap == null) return false;

      final storedHash = userMap['password_hash'] as String? ?? '';
      final salt = userMap['salt'] as String? ?? '';

      // Verifikasi password lama
      String computedHash;
      if (salt.isNotEmpty) {
        computedHash = _hashPassword(oldPassword, salt);
      } else {
        computedHash = _hashPasswordLegacy(oldPassword);
      }

      if (computedHash != storedHash) return false;

      // Generate salt baru dan hash password baru
      final newSalt = _generateSalt();
      final newHash = _hashPassword(newPassword, newSalt);

      await _db.update(
        'users',
        {
          'password_hash': newHash,
          'salt': newSalt,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // ─── Ambil User Berdasarkan ID ────────────────────────────────────────────

  /// Mendapatkan data user berdasarkan ID
  Future<UserModel?> getUserById(int id) async {
    try {
      final result = await _db.queryById('users', id);
      if (result == null) return null;
      return UserModel.fromMap(result);
    } catch (e) {
      return null;
    }
  }

  // ─── Hitung Total User ────────────────────────────────────────────────────

  /// Mendapatkan jumlah total user yang terdaftar
  Future<int> getTotalUserCount() async {
    try {
      return await _db.count('users');
    } catch (e) {
      return 0;
    }
  }
}

// ─── Internal Helper ──────────────────────────────────────────────────────────

class _ResetCode {
  final String code;
  final DateTime expiresAt;

  _ResetCode({required this.code, required this.expiresAt});
}
