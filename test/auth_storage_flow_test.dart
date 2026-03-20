import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project/services/auth_storage.dart';

void main() {
  test('signUp -> signOut(clearSession) -> signIn works', () async {
    SharedPreferences.setMockInitialValues({});

    await AuthStorage.signUp(
      name: 'Test User',
      email: 'test@example.com',
      password: 'password123',
    );

    // Simulate sign out: should remove only session, not stored accounts.
    await AuthStorage.clearSession();

    final session = await AuthStorage.signIn(
      email: 'test@example.com',
      password: 'password123',
    );

    expect(session.email, 'test@example.com');
    expect(session.name, 'Test User');
  });

  test('password reset token updates sign-in password', () async {
    SharedPreferences.setMockInitialValues({});

    const email = 'reset@example.com';
    const password = 'old_password_123';
    const newPassword = 'new_password_123';

    await AuthStorage.signUp(
      name: 'Reset User',
      email: email,
      password: password,
    );

    // Request reset token (prototype returns token).
    final token = await AuthStorage.requestPasswordReset(email: email);

    // Reset password with token.
    await AuthStorage.resetPasswordWithToken(token: token, newPassword: newPassword);

    // Sign-in with old password should fail.
    expect(
      () => AuthStorage.signIn(email: email, password: password),
      throwsA(isA<AuthStorageException>()),
    );

    // Sign-in with new password should work.
    final session = await AuthStorage.signIn(email: email, password: newPassword);
    expect(session.email, email);
    expect(session.name, 'Reset User');
  });
}

