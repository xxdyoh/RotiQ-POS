import '../models/user.dart';
import '../models/cabang_model.dart';
import '../services/api_service.dart';

class SessionManager {
  static User? _currentUser;
  static String? _token;
  static Cabang? _currentCabang;

  static Future<void> saveSession(String token, User user, Cabang cabang) async {
    _currentUser = user;
    _token = token;
    _currentCabang = cabang;

    ApiService.setToken(token);
    ApiService.setCurrentCabang(cabang);
  }

  static Future<bool> loadSession() async {
    return false;
  }

  static User? getCurrentUser() {
    return _currentUser;
  }

  static Cabang? getCurrentCabang() {
    return _currentCabang;
  }

  static String? getToken() {
    return _token;
  }

  static bool isLoggedIn() {
    return _currentUser != null && _token != null && _currentCabang != null;
  }

  static Future<void> logout() async {
    _currentUser = null;
    _token = null;
    _currentCabang = null;
    ApiService.clearToken();
  }
}