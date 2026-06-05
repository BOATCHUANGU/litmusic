import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/database_helper.dart';

class AuthProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper();
  User? _currentUser;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  String? get currentUserId => _currentUser?.id;

  Future<String?> register(String username, String password) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      return '用户名和密码不能为空';
    }
    if (password.length < 3) {
      return '密码至少3位';
    }
    final success = await _db.registerUser(username.trim(), password);
    if (!success) {
      return '用户名已存在';
    }
    _currentUser = User(id: username.trim(), username: username.trim(), password: '');
    await _saveSession(username.trim());
    notifyListeners();
    return null; // null means success
  }

  Future<String?> login(String username, String password) async {
    final user = await _db.loginUser(username.trim(), password);
    if (user == null) {
      return '用户名或密码错误';
    }
    _currentUser = user;
    await _saveSession(username.trim());
    notifyListeners();
    return null;
  }

  /// Auto-login by username — no password check (trusts locally-stored session).
  /// Returns true if the user still exists in DB.
  Future<bool> autoLogin(String username) async {
    final user = await _db.getUserByUsername(username);
    if (user == null) {
      await _clearSession();
      return false;
    }
    _currentUser = user;
    notifyListeners();
    return true;
  }

  /// Try to restore the last session from SharedPreferences.
  /// Returns true if successful, false if no saved session.
  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('last_username');
    if (savedUsername == null || savedUsername.isEmpty) {
      return false;
    }
    return await autoLogin(savedUsername);
  }

  Future<void> logout() async {
    _currentUser = null;
    await _clearSession();
    notifyListeners();
  }

  Future<void> _saveSession(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_username', username);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_username');
  }
}
