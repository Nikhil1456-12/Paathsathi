// lib/services/profile_service.dart
//
// Single read/gate point for the user's on-device profile. It does NOT invent a
// new storage scheme — it reads exactly what the existing register/login flow
// already writes (SharedPreferences for non-secret fields, Keystore-backed
// secure storage for the password hash). This keeps the app's existing, working
// onboarding intact and just gives other features one clean place to ask
// "who is the user, and have they finished onboarding?".

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's non-secret profile.
class UserProfile {
  final String name;
  final String phone;
  final bool loggedIn;
  final bool onboardingDone;

  const UserProfile({
    required this.name,
    required this.phone,
    required this.loggedIn,
    required this.onboardingDone,
  });

  bool get isComplete => loggedIn && onboardingDone;
}

class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  // Keys already used by the existing register/login flow.
  static const _kName = 'user_name';
  static const _kPhone = 'user_phone';
  static const _kLoggedIn = 'is_logged_in';
  static const _kOnboardingDone = 'onboarding_done';

  // Secure storage for the credential hash (matches register_screen.dart).
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _kPassHash = 'pathsaathi_pass_hash';
  static const _salt = 'pathsaathi_v1_salt';

  /// Read the current profile (safe defaults if nothing stored yet).
  Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    return UserProfile(
      name: prefs.getString(_kName) ?? '',
      phone: prefs.getString(_kPhone) ?? '',
      loggedIn: prefs.getBool(_kLoggedIn) ?? false,
      onboardingDone: prefs.getBool(_kOnboardingDone) ?? false,
    );
  }

  /// Where the splash screen should route based on real profile state.
  ///  • not logged in            → /login
  ///  • logged in, onboarding not done → /language (resume onboarding)
  ///  • fully set up             → /home
  Future<String> initialRoute() async {
    final p = await load();
    if (!p.loggedIn) return '/login';
    if (!p.onboardingDone) return '/language';
    return '/home';
  }

  /// Mark onboarding complete (called at the end of the setup chain).
  Future<void> markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingDone, true);
  }

  /// Salted SHA-256 hash — identical scheme to register_screen.dart.
  static String _hash(String password) =>
      sha256.convert(utf8.encode('$_salt::$password')).toString();

  /// Verify a password/PIN for a returning user against the stored hash.
  /// Returns false if no credential is stored.
  Future<bool> verifyPassword(String password) async {
    final stored = await _secure.read(key: _kPassHash);
    if (stored == null || stored.isEmpty) return false;
    return _hash(password) == stored;
  }

  Future<bool> hasCredential() async {
    final stored = await _secure.read(key: _kPassHash);
    return stored != null && stored.isNotEmpty;
  }
}
