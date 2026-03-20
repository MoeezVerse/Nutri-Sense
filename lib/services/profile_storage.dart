import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Persists [UserProfile] **per signed-in account** (email).
///
/// Previously a single global key caused new sign-ups to inherit another user's
/// profile on the same device, skipping Further Details / onboarding.
class ProfileStorage {
  /// Legacy single-profile key (pre per-account storage).
  static const _legacyKeyProfile = 'nutrisense_user_profile';

  /// Per-email profile: `nutrisense_user_profile_v3_<normalizedEmail>`
  static String _keyForEmail(String email) {
    final e = email.trim().toLowerCase();
    return 'nutrisense_user_profile_v3_$e';
  }

  /// Clears only the legacy global profile row. Call after **sign-up** so a new
  /// account does not inherit an old device-wide profile.
  static Future<void> clearLegacyGlobalProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyKeyProfile);
  }

  /// Loads profile for the current session without importing [AuthStorage]
  /// (avoids circular deps). Session key must match [AuthStorage._keySession].
  static Future<UserProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    const sessionKey = 'nutrisense_auth_session_v1';
    final rawSession = prefs.getString(sessionKey);
    if (rawSession == null || rawSession.isEmpty) return null;
    try {
      final decoded = jsonDecode(rawSession) as Map<String, dynamic>;
      final email = decoded['email'] as String? ?? '';
      if (email.isEmpty) return null;
      return loadForEmail(email);
    } catch (_) {
      return null;
    }
  }

  /// Loads profile for [email], migrating legacy global data once if needed.
  static Future<UserProfile?> loadForEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyForEmail(email);
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }

    // One-time migration from legacy global profile → this account.
    final legacy = prefs.getString(_legacyKeyProfile);
    if (legacy != null && legacy.isNotEmpty) {
      try {
        final profile = UserProfile.fromJson(jsonDecode(legacy) as Map<String, dynamic>);
        await prefs.setString(key, legacy);
        await prefs.remove(_legacyKeyProfile);
        return profile;
      } catch (_) {}
    }
    return null;
  }

  static Future<void> save(UserProfile profile, {required String accountEmail}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyForEmail(accountEmail);
    await prefs.setString(key, jsonEncode(profile.toJson()));
    // Prevent stale global row from confusing older app versions.
    await prefs.remove(_legacyKeyProfile);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyKeyProfile);
  }
}
