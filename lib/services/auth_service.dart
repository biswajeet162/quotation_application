import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/user.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  bool _isAuthenticated = false;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  Future<bool> login(String email, String password) async {
    try {
      final user = await DatabaseHelper.instance.authenticateUser(email, password);
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<bool> resetPassword(String email, String oldPassword, String newPassword) async {
    try {
      final user = await DatabaseHelper.instance.getUserByEmail(email);
      if (user == null) {
        return false;
      }

      // Verify old password
      final authenticated = await DatabaseHelper.instance.authenticateUser(email, oldPassword);
      if (authenticated == null) {
        return false;
      }

      // Update password
      await DatabaseHelper.instance.updateUserPassword(user.id!, newPassword);
      
      // Update current user if it's the logged-in user
      if (_currentUser?.id == user.id) {
        _currentUser = await DatabaseHelper.instance.getUserByEmail(email);
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
}




