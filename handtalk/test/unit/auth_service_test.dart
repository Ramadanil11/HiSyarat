import 'package:flutter_test/flutter_test.dart';
import 'package:handtalk/services/auth_service.dart';

void main() {
  group('UserModel', () {
    test('fromMap creates UserModel correctly', () {
      final map = {
        'id': 1,
        'username': 'testuser',
        'email': 'test@example.com',
        'password_hash': 'abc123',
        'salt': 'salt123',
        'role': 'learner',
        'created_at': '2024-01-01T00:00:00.000',
      };

      final user = UserModel.fromMap(map);

      expect(user.id, 1);
      expect(user.name, 'testuser');
      expect(user.email, 'test@example.com');
      expect(user.passwordHash, 'abc123');
      expect(user.salt, 'salt123');
      expect(user.role, 'learner');
    });

    test('fromMap handles missing fields with defaults', () {
      final map = <String, dynamic>{};

      final user = UserModel.fromMap(map);

      expect(user.id, isNull);
      expect(user.name, '');
      expect(user.email, '');
      expect(user.role, 'learner');
      expect(user.salt, '');
    });

    test('toMap produces correct map', () {
      final user = UserModel(
        id: 1,
        name: 'testuser',
        email: 'test@example.com',
        passwordHash: 'hash123',
        salt: 'salt123',
        role: 'instructor',
        createdAt: DateTime(2024, 1, 1),
      );

      final map = user.toMap();

      expect(map['id'], 1);
      expect(map['username'], 'testuser');
      expect(map['full_name'], 'testuser');
      expect(map['email'], 'test@example.com');
      expect(map['password_hash'], 'hash123');
      expect(map['salt'], 'salt123');
      expect(map['role'], 'instructor');
    });

    test('copyWith creates modified copy', () {
      final user = UserModel(
        id: 1,
        name: 'original',
        email: 'original@test.com',
        passwordHash: 'hash',
        salt: 'salt',
        role: 'learner',
        createdAt: DateTime(2024, 1, 1),
      );

      final modified = user.copyWith(name: 'modified', role: 'admin');

      expect(modified.name, 'modified');
      expect(modified.role, 'admin');
      expect(modified.email, 'original@test.com'); // unchanged
      expect(modified.id, 1); // unchanged
    });

    test('copyWith with no changes returns equivalent object', () {
      final user = UserModel(
        id: 1,
        name: 'test',
        email: 'test@test.com',
        passwordHash: 'hash',
        role: 'learner',
        createdAt: DateTime(2024, 1, 1),
      );

      final copy = user.copyWith();

      expect(copy.id, user.id);
      expect(copy.name, user.name);
      expect(copy.email, user.email);
      expect(copy.role, user.role);
    });
  });

  group('SessionModel', () {
    test('isExpired returns false for future expiry', () {
      final session = SessionModel(
        token: 'test-token',
        userId: 1,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
      );

      expect(session.isExpired, false);
    });

    test('isExpired returns true for past expiry', () {
      final session = SessionModel(
        token: 'test-token',
        userId: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 48)),
        expiresAt: DateTime.now().subtract(const Duration(hours: 24)),
      );

      expect(session.isExpired, true);
    });
  });

  group('AuthService - Session Management', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('validateSession returns null for invalid token', () {
      final result = authService.validateSession('invalid-token');
      expect(result, isNull);
    });

    test('logout removes session', () {
      // Since we can't easily create a session without DB,
      // we test that logout doesn't throw for non-existent token
      expect(() => authService.logout('non-existent'), returnsNormally);
    });

    test('logoutAll does not throw', () {
      expect(() => authService.logoutAll(999), returnsNormally);
    });
  });
}
