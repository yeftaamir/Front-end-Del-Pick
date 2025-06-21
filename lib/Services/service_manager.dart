// lib/services/service_manager.dart
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'Core/token_service.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'notification_service.dart';

class ServiceManager {
  static bool _isInitialized = false;

  // Initialize all services
  static Future<void> initialize() async {
    try {
      if (_isInitialized) {
        debugPrint('ServiceManager already initialized');
        return;
      }

      debugPrint('Initializing ServiceManager...');

      // Initialize notification service
      await NotificationService.initialize();

      // Request location permissions
      await LocationService.requestLocationPermission();

      // Check if user is already authenticated
      final isAuthenticated = await TokenService.isAuthenticated();

      if (isAuthenticated) {
        debugPrint('User is authenticated, refreshing user data...');
        try {
          await AuthService.refreshUserData();
        } catch (e) {
          debugPrint('Failed to refresh user data: $e');
          // Clear invalid token
          await TokenService.clearAll();
        }
      }

      _isInitialized = true;
      debugPrint('ServiceManager initialized successfully');
    } catch (e) {
      debugPrint('ServiceManager initialization error: $e');
    }
  }

  // Check authentication status
  static Future<bool> isAuthenticated() async {
    return await TokenService.isAuthenticated();
  }

  // Get current user role
  static Future<String?> getCurrentUserRole() async {
    return await TokenService.getUserRole();
  }

  // Get current user ID
  static Future<String?> getCurrentUserId() async {
    return await TokenService.getUserId();
  }

  // Check if current user has specific role
  static Future<bool> hasRole(List<String> roles) async {
    return await TokenService.hasRole(roles);
  }

  // Clear all user data (logout)
  static Future<void> clearUserData() async {
    await TokenService.clearAll();
    _isInitialized = false;
  }

  // Get authentication headers for manual API calls
  static Future<Map<String, String>> getAuthHeaders() async {
    return await TokenService.getAuthHeaders();
  }

  // Get current user location
  static Future<Position?> getCurrentLocation() async {
    return await LocationService.getCurrentLocation();
  }

  // Check app permissions
  static Future<Map<String, bool>> checkPermissions() async {
    try {
      final hasLocation = await LocationService.hasLocationPermission();

      return {
        'location': hasLocation,
        'notifications': true, // Assume granted for now
      };
    } catch (e) {
      debugPrint('Check permissions error: $e');
      return {
        'location': false,
        'notifications': false,
      };
    }
  }

  // Request all necessary permissions
  static Future<void> requestAllPermissions() async {
    try {
      await LocationService.requestLocationPermission();
      // Add other permission requests as needed
    } catch (e) {
      debugPrint('Request all permissions error: $e');
    }
  }

  // Get app status
  static Future<Map<String, dynamic>> getAppStatus() async {
    try {
      final isAuth = await isAuthenticated();
      final userRole = await getCurrentUserRole();
      final permissions = await checkPermissions();

      return {
        'is_authenticated': isAuth,
        'user_role': userRole,
        'permissions': permissions,
        'is_initialized': _isInitialized,
      };
    } catch (e) {
      debugPrint('Get app status error: $e');
      return {
        'is_authenticated': false,
        'user_role': null,
        'permissions': {},
        'is_initialized': false,
      };
    }
  }
}