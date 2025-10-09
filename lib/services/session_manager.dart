import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'dart:convert';

class SessionManager {
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _keyToken = 'token';
  static const String _keyUser = 'user';

  static User? _currentUser;

  // Save session setelah login
  static Future<void> saveSession(String token, User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsLoggedIn, true);
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(user.toJson()));
    _currentUser = user;
  }

  // Get current user
  static User? getCurrentUser() {
    return _currentUser;
  }

  // Load session saat app start
  static Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

    if (isLoggedIn) {
      final token = prefs.getString(_keyToken);
      final userJson = prefs.getString(_keyUser);

      if (token != null && userJson != null) {
        _currentUser = User.fromJson(jsonDecode(userJson));
        // Set token ke API service
        return true;
      }
    }
    return false;
  }

  // Get token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  // Check if logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsLoggedIn) ?? false;
  }

  // Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _currentUser = null;
  }
}