import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileNotifier extends StateNotifier<String> {
  UserProfileNotifier() : super('');

  Future<void> setName(String name) async {
    state = name.trim().isEmpty ? '' : name.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', state);
  }

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('user_name') ?? '';
  }

  String get displayName => state.isEmpty ? 'Pilgrim' : state;
}

final userNameProvider =
    StateNotifierProvider<UserProfileNotifier, String>((ref) => UserProfileNotifier());
