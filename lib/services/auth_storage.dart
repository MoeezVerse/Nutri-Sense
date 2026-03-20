import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

class AuthStorageException implements Exception {
  AuthStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _AuthAccount {
  final String name;
  final String email;
  final String passwordHash;
  final String salt;
  final int createdAtMs;

  _AuthAccount({
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.createdAtMs,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'salt': salt,
        'createdAtMs': createdAtMs,
      };

  static _AuthAccount fromJson(Map<String, dynamic> json) {
    return _AuthAccount(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
      salt: json['salt'] as String? ?? '',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class AuthStorage {
  static const String _keyAccounts = 'nutrisense_auth_accounts_v1';
  static const String _keySession = 'nutrisense_auth_session_v1';
  static const String _keyPasswordResetTokens = 'nutrisense_auth_password_reset_tokens_v1';

  static Future<AuthSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final email = decoded['email'] as String? ?? '';
      final name = decoded['name'] as String? ?? '';
      if (email.isEmpty || name.isEmpty) return null;
      return AuthSession(email: email, name: name);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySession);
  }

  static String _normalizeEmail(String email) => email.trim().toLowerCase();

  static String _hashPassword({
    required String password,
    required String salt,
  }) {
    final input = '$salt:$password';
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  static String _randomSalt() {
    // Not cryptographically required for this prototype since we already hash the password,
    // but Random is still used to avoid identical hashes for identical passwords.
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static Future<List<_AuthAccount>> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyAccounts);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => _AuthAccount.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAccounts(List<_AuthAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = accounts.map((a) => a.toJson()).toList();
    await prefs.setString(_keyAccounts, jsonEncode(payload));
  }

  static Future<AuthSession> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw AuthStorageException('Email is required.');
    }
    if (name.trim().isEmpty) {
      throw AuthStorageException('Name is required.');
    }

    final accounts = await _loadAccounts();
    final alreadyExists = accounts.any((a) => _normalizeEmail(a.email) == normalizedEmail);
    if (alreadyExists) {
      throw AuthStorageException('An account with this email already exists.');
    }

    final salt = _randomSalt();
    final hash = _hashPassword(password: password, salt: salt);
    final account = _AuthAccount(
      name: name.trim(),
      email: normalizedEmail,
      passwordHash: hash,
      salt: salt,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    accounts.add(account);
    await _saveAccounts(accounts);

    final session = AuthSession(email: normalizedEmail, name: account.name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keySession,
      jsonEncode({'email': session.email, 'name': session.name}),
    );
    return session;
  }

  static Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw AuthStorageException('Email is required.');
    }

    final accounts = await _loadAccounts();
    final account = accounts.where((a) => _normalizeEmail(a.email) == normalizedEmail).toList();
    if (account.isEmpty) {
      throw AuthStorageException('No account found for this email.');
    }
    final found = account.first;

    final hash = _hashPassword(password: password, salt: found.salt);
    if (hash != found.passwordHash) {
      throw AuthStorageException('Incorrect password.');
    }

    final session = AuthSession(email: normalizedEmail, name: found.name);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keySession,
      jsonEncode({'email': session.email, 'name': session.name}),
    );
    return session;
  }

  /// Requests a password reset token for the given email.
  ///
  /// Security note (prototype): this implementation stores reset tokens locally
  /// (SharedPreferences) and returns the token so the UI can simulate clicking the
  /// email link. In production, you would send the token via a secure email link.
  static Future<String> requestPasswordReset({required String email}) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail.isEmpty) {
      throw AuthStorageException('Email is required.');
    }

    final tokens = await _loadPasswordResetTokens();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Remove expired tokens before adding a new one.
    tokens.removeWhere((t) => t.expiresAtMs <= nowMs);

    final rawToken = _generateResetToken();
    final tokenHash = _hashResetToken(rawToken);
    final expiresAtMs = nowMs + (1000 * 60 * 30); // 30 minutes

    tokens.add(
      _PasswordResetToken(
        tokenHash: tokenHash,
        email: normalizedEmail,
        expiresAtMs: expiresAtMs,
        createdAtMs: nowMs,
      ),
    );

    await _savePasswordResetTokens(tokens);
    return rawToken;
  }

  /// Resets the password for a valid (not expired) reset token.
  ///
  /// If the token is valid but the account doesn't exist, this is treated as a
  /// success path to avoid revealing whether the email exists in the system.
  static Future<void> resetPasswordWithToken({
    required String token,
    required String newPassword,
  }) async {
    final rawToken = token.trim();
    if (rawToken.isEmpty) {
      throw AuthStorageException('Invalid or expired reset link.');
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final tokenHash = _hashResetToken(rawToken);
    final tokens = await _loadPasswordResetTokens();

    final match = tokens.where((t) => t.tokenHash == tokenHash).toList();
    if (match.isEmpty) {
      throw AuthStorageException('Invalid or expired reset link.');
    }

    final t = match.first;
    if (t.expiresAtMs <= nowMs) {
      // Expired: remove it and fail.
      await _savePasswordResetTokens(tokens.where((x) => x.tokenHash != tokenHash).toList());
      throw AuthStorageException('Invalid or expired reset link.');
    }

    // Always remove the token after use.
    await _savePasswordResetTokens(tokens.where((x) => x.tokenHash != tokenHash).toList());

    final accounts = await _loadAccounts();
    final idx = accounts.indexWhere((a) => _normalizeEmail(a.email) == t.email);
    if (idx < 0) {
      // Do nothing, but treat as success to avoid enumeration.
      return;
    }

    final account = accounts[idx];
    final salt = _randomSalt();
    final hash = _hashPassword(password: newPassword, salt: salt);
    accounts[idx] = _AuthAccount(
      name: account.name,
      email: account.email,
      passwordHash: hash,
      salt: salt,
      createdAtMs: account.createdAtMs,
    );
    await _saveAccounts(accounts);
  }

  static String _generateResetToken() {
    // High-entropy token for the reset flow.
    final r = Random.secure();
    final bytes = List<int>.generate(32, (_) => r.nextInt(256));
    return base64UrlEncode(bytes);
  }

  static String _hashResetToken(String token) {
    final bytes = utf8.encode(token);
    return sha256.convert(bytes).toString();
  }

  static Future<List<_PasswordResetToken>> _loadPasswordResetTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPasswordResetTokens);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => _PasswordResetToken.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _savePasswordResetTokens(List<_PasswordResetToken> tokens) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = tokens.map((t) => t.toJson()).toList();
    await prefs.setString(_keyPasswordResetTokens, jsonEncode(payload));
  }
}

class _PasswordResetToken {
  final String tokenHash;
  final String email;
  final int expiresAtMs;
  final int createdAtMs;

  const _PasswordResetToken({
    required this.tokenHash,
    required this.email,
    required this.expiresAtMs,
    required this.createdAtMs,
  });

  Map<String, dynamic> toJson() => {
        'tokenHash': tokenHash,
        'email': email,
        'expiresAtMs': expiresAtMs,
        'createdAtMs': createdAtMs,
      };

  static _PasswordResetToken fromJson(Map<String, dynamic> json) {
    return _PasswordResetToken(
      tokenHash: json['tokenHash'] as String? ?? '',
      email: json['email'] as String? ?? '',
      expiresAtMs: (json['expiresAtMs'] as num?)?.toInt() ?? 0,
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

