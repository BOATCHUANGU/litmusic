import 'package:flutter/foundation.dart';
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
    notifyListeners();
    return null; // null means success
  }

  Future<String?> login(String username, String password) async {
    final user = await _db.loginUser(username.trim(), password);
    if (user == null) {
      return '用户名或密码错误';
    }
    _currentUser = user;
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
