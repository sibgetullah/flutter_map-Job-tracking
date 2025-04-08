import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String _keyUserId = 'userId';
  static const String _keyUsername = 'username';
  static const String _keyRole = 'role';
  static const String _keyIsLoggedIn = 'isLoggedIn';

  // Kullanıcı giriş yaptığında bilgileri kaydet
  static Future<void> saveUserSession(int userId, String username, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUserId, userId);
    await prefs.setString(_keyUsername, username);
    await prefs.setString(_keyRole, role);
    await prefs.setBool(_keyIsLoggedIn, true);
  }

  // Kullanıcı oturum bilgilerini getir
  static Future<Map<String, dynamic>> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_keyUserId);
    final username = prefs.getString(_keyUsername);
    final role = prefs.getString(_keyRole);
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;

    return {
      'userId': userId,
      'username': username,
      'role': role,
      'isLoggedIn': isLoggedIn,
    };
  }

  // Kullanıcı çıkış yaptığında bilgileri sil
  static Future<void> clearUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyRole);
    await prefs.setBool(_keyIsLoggedIn, false);
  }
}