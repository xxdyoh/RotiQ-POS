import '../models/user.dart';
import '../models/cabang_model.dart';
import '../services/api_service.dart';

class SessionManager {
  static User? _currentUser;
  static String? _token;
  static Cabang? _currentCabang;
  static Map<int, Map<String, int>> _userPermissions = {};
  static Map<String, int> _menuNameToId = {};
  static Map<String, Map<String, int>> _userPermissionsByName = {};

  static Future<void> saveSession(String token, User user, Cabang cabang, {Map<String, dynamic>? permissions}) async {
    _currentUser = user;
    _token = token;
    _currentCabang = cabang; // Pastikan ini terisi

    print('Cabang saved: ${cabang.kode}'); // Tambahkan ini

    if (permissions != null) {
      _userPermissionsByName = {};
      permissions.forEach((menuName, value) {
        if (value is Map) {
          _userPermissionsByName[menuName] = {
            'insert': (value['insert'] as num?)?.toInt() ?? 0,
            'edit': (value['edit'] as num?)?.toInt() ?? 0,
            'delete': (value['delete'] as num?)?.toInt() ?? 0,
          };
        }
      });
    }

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

  static Map<int, Map<String, int>> getUserPermissions() {
    return _userPermissions;
  }

  static bool hasMenuAccess(int menuId) {
    final permissions = _userPermissions[menuId];
    if (permissions == null) return false;
    return (permissions['insert'] == 1 ||
        permissions['edit'] == 1 ||
        permissions['delete'] == 1);
  }

  static bool hasMenuAccessByName(String menuName) {
    final permissions = _userPermissionsByName[menuName];
    if (permissions == null) return false;
    return (permissions['insert'] == 1 ||
        permissions['edit'] == 1 ||
        permissions['delete'] == 1);
  }

  static bool canInsert(int menuId) {
    return _userPermissions[menuId]?['insert'] == 1;
  }

  static bool canEdit(int menuId) {
    return _userPermissions[menuId]?['edit'] == 1;
  }

  static bool canDelete(int menuId) {
    return _userPermissions[menuId]?['delete'] == 1;
  }

  static bool isLoggedIn() {
    return _currentUser != null && _token != null && _currentCabang != null;
  }

  static Future<void> logout() async {
    _currentUser = null;
    _token = null;
    _currentCabang = null;
    _userPermissions = {};
    _menuNameToId = {};
    ApiService.clearToken();
  }
}