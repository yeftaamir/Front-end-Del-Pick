// lib/Services/service_manager.dart
import 'package:flutter/foundation.dart';
import 'Core/token_service.dart';
import 'auth_service.dart';
import 'customer_service.dart';
import 'driver_service.dart';
import 'image_service.dart';
import 'store_service.dart';
import 'order_service.dart';
import 'tracking_service.dart';
import 'driver_request_service.dart';
import 'user_service.dart';

class ServiceManager {
  static ServiceManager? _instance;
  static ServiceManager get instance => _instance ??= ServiceManager._();
  ServiceManager._();

  // Service initialization status
  bool _isInitialized = false;
  String? _currentUserRole;
  Map<String, dynamic>? _currentUserData;

  /// Initialize service manager
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;

      // Check authentication status
      final isAuthenticated = await TokenService.isAuthenticated();
      if (isAuthenticated) {
        _currentUserRole = await TokenService.getUserRole();
        _currentUserData = await TokenService.getUserData();
      }

      _isInitialized = true;
      print('ServiceManager initialized successfully');
    } catch (e) {
      print('ServiceManager initialization error: $e');
      throw Exception('Failed to initialize ServiceManager: $e');
    }
  }

  /// Get app authentication status
  Future<Map<String, dynamic>> getAppStatus() async {
    try {
      final isAuthenticated = await TokenService.isAuthenticated();
      final userRole = await TokenService.getUserRole();
      final userData = await TokenService.getUserData();

      return {
        'is_authenticated': isAuthenticated,
        'user_role': userRole,
        'user_data': userData,
        'has_valid_session': isAuthenticated && userRole != null,
      };
    } catch (e) {
      print('Get app status error: $e');
      return {
        'is_authenticated': false,
        'user_role': null,
        'user_data': null,
        'has_valid_session': false,
      };
    }
  }

  /// Navigate to role-based home screen
  String? navigateToRoleBasedHome(String? role) {
    switch (role?.toLowerCase()) {
      case 'customer':
        return '/customer/home';
      case 'driver':
        return '/driver/home';
      case 'store':
        return '/store/home';
      default:
        return '/login';
    }
  }

  /// Get role-specific services
  List<String> getRoleSpecificServices(String? role) {
    switch (role?.toLowerCase()) {
      case 'customer':
        return [
          'AuthService',
          'StoreService',
          'MenuItemService',
          'OrderService',
          'TrackingService',
          'UserService',
        ];
      case 'driver':
        return [
          'AuthService',
          'DriverService',
          'DriverRequestService',
          'OrderService',
          'TrackingService',
          'UserService',
        ];
      case 'store':
        return [
          'AuthService',
          'StoreService',
          'MenuItemService',
          'OrderService',
          'UserService',
        ];
      default:
        return ['AuthService'];
    }
  }

  /// Request all required permissions for the app
  Future<Map<String, bool>> requestAllPermissions() async {
    final permissions = <String, bool>{};

    try {
      // Location permission (for delivery tracking)
      permissions['location'] = await _requestLocationPermission();

      // Camera permission (for profile pictures)
      permissions['camera'] = await _requestCameraPermission();

      // Storage permission (for image uploads)
      permissions['storage'] = await _requestStoragePermission();

      // Notification permission (for order updates)
      permissions['notification'] = await _requestNotificationPermission();

      return permissions;
    } catch (e) {
      print('Request permissions error: $e');
      return permissions;
    }
  }

  /// Perform health check on all services
  Future<Map<String, bool>> performHealthCheck() async {
    final healthStatus = <String, bool>{};

    try {
      // Check authentication service
      healthStatus['auth'] = await _checkAuthServiceHealth();

      // Check API connectivity
      healthStatus['api'] = await _checkApiConnectivity();

      // Check local storage
      healthStatus['storage'] = await _checkLocalStorageHealth();

      // Check image service
      healthStatus['images'] = await _checkImageServiceHealth();

      return healthStatus;
    } catch (e) {
      print('Health check error: $e');
      return healthStatus;
    }
  }

  /// Clear all app data (logout + cleanup)
  Future<bool> clearAllAppData() async {
    try {
      // Logout user
      await AuthService.logout();

      // Clear service manager state
      _currentUserRole = null;
      _currentUserData = null;

      // Clear all local data
      await TokenService.clearAll();

      print('All app data cleared successfully');
      return true;
    } catch (e) {
      print('Clear app data error: $e');
      return false;
    }
  }

  /// Update user session data
  Future<void> updateUserSession(Map<String, dynamic> userData) async {
    try {
      _currentUserData = userData;
      _currentUserRole = userData['user']?['role'];

      await TokenService.saveUserData(userData);
      if (_currentUserRole != null) {
        await TokenService.saveUserRole(_currentUserRole!);
      }
    } catch (e) {
      print('Update user session error: $e');
    }
  }

  /// Get current user role
  String? getCurrentUserRole() => _currentUserRole;

  /// Get current user data
  Map<String, dynamic>? getCurrentUserData() => _currentUserData;

  /// Check if user has specific role
  bool hasRole(String role) => _currentUserRole?.toLowerCase() == role.toLowerCase();

  /// Check if service manager is initialized
  bool get isInitialized => _isInitialized;

  // PRIVATE HELPER METHODS

  Future<bool> _requestLocationPermission() async {
    // Implementation depends on permission_handler package
    // For now, return true as placeholder
    return true;
  }

  Future<bool> _requestCameraPermission() async {
    // Implementation depends on permission_handler package
    return true;
  }

  Future<bool> _requestStoragePermission() async {
    // Implementation depends on permission_handler package
    return true;
  }

  Future<bool> _requestNotificationPermission() async {
    // Implementation depends on permission_handler package
    return true;
  }

  Future<bool> _checkAuthServiceHealth() async {
    try {
      final isAuthenticated = await TokenService.isAuthenticated();
      return true; // If no exception, auth service is working
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkApiConnectivity() async {
    try {
      // Try to make a simple API call
      // For example, check health endpoint
      return true; // Placeholder
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkLocalStorageHealth() async {
    try {
      // Test storage read/write
      await TokenService.saveUserRole('test');
      final testRole = await TokenService.getUserRole();
      return testRole == 'test';
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkImageServiceHealth() async {
    try {
      // Test image URL processing
      final testUrl = ImageService.getImageUrl('test.jpg');
      return testUrl.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}