// lib/services/utils/auth_manager.dart
import 'package:del_pick/Models/Extensions/menu_item_extensions.dart';
import 'package:del_pick/Services/Utils/storage_service.dart';

import '../../Models/Entities/user.dart';
import '../../Models/Enums/user_role.dart';
import '../Base/api_client.dart';

class AuthManager {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';
  static const String _isLoggedInKey = 'is_logged_in';

  static User? _currentUser;
  static String? _currentToken;

  // Initialize auth manager
  static Future<void> init() async {
    await StorageService.init();
    await _loadAuthData();
  }

  // Load auth data from storage
  static Future<void> _loadAuthData() async {
    _currentToken = StorageService.getString(_tokenKey);
    final userJson = StorageService.getObject(_userKey);

    if (_currentToken != null && userJson != null) {
      _currentUser = User.fromJson(userJson);
      ApiClient.setAuthToken(_currentToken);
    }
  }

  // Save auth data
  static Future<void> saveAuthData(String token, User user) async {
    _currentToken = token;
    _currentUser = user;

    await Future.wait([
      StorageService.saveString(_tokenKey, token),
      StorageService.saveObject(_userKey, user.toJson()),
      StorageService.saveBool(_isLoggedInKey, true),
    ]);

    ApiClient.setAuthToken(token);
  }

  // Clear auth data
  static Future<void> clearAuthData() async {
    _currentToken = null;
    _currentUser = null;

    await Future.wait([
      StorageService.remove(_tokenKey),
      StorageService.remove(_userKey),
      StorageService.saveBool(_isLoggedInKey, false),
    ]);

    ApiClient.clearAuthToken();
  }

  // Get current user
  static User? get currentUser => _currentUser;

  // Get current token
  static String? get currentToken => _currentToken;

  // Check if user is logged in
  static bool get isLoggedIn => _currentToken != null && _currentUser != null;

  // Check if user has specific role
  static bool hasRole(UserRole role) {
    return _currentUser?.role == role;
  }

  // Update current user
  static Future<void> updateCurrentUser(User user) async {
    _currentUser = user;
    await StorageService.saveObject(_userKey, user.toJson());
  }

  // Get user display name
  static String get userDisplayName {
    return _currentUser?.displayName ?? 'Unknown User';
  }

  // Check if token is expired (basic check)
  static bool isTokenExpired() {
    // This is a basic implementation
    // In a real app, you would decode the JWT and check the expiration
    if (_currentToken == null) return true;

    // For now, we'll assume token is valid if it exists
    // You can implement JWT decoding here
    return false;
  }

  // Refresh token if needed
  static Future<bool> refreshTokenIfNeeded() async {
    if (isTokenExpired()) {
      // Implement token refresh logic here
      // For now, we'll just clear the auth data
      await clearAuthData();
      return false;
    }
    return true;
  }
}