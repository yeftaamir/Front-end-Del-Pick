// lib/services/user/profile_service.dart
import 'package:del_pick/Models/Extensions/menu_item_extensions.dart';

import '../../Models/Base/api_response.dart';
import '../../Models/Entities/user.dart';
import '../../Models/Exceptions/api_exception.dart';
import '../../Services/Auth/auth_service.dart';
import '../../Services/User/user_service.dart';
import '../../Services/Utils/auth_manager.dart';
import '../../Services/Utils/error_handler.dart';

class ProfileService {
  // Get user profile with fallback mechanism
  static Future<User?> getUserProfile() async {
    try {
      // First try to get from AuthManager current user
      final currentUser = AuthManager.currentUser;
      if (currentUser != null) {
        return currentUser;
      }

      // If not available, fetch from API
      final response = await UserService.getProfile();

      if (response.isSuccess && response.data != null) {
        // Update AuthManager with fresh data
        await AuthManager.updateCurrentUser(response.data!);
        return response.data;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProfileService.getUserProfile');
      rethrow;
    }
  }

  // Update user profile
  static Future<bool> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final response = await UserService.updateProfile(profileData);

      if (response.isSuccess && response.data != null) {
        // Update local user data
        await AuthManager.updateCurrentUser(response.data!);
        return true;
      } else {
        throw ApiException(
          message: response.message,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProfileService.updateUserProfile');
      rethrow;
    }
  }

  // Handle logout process
  static Future<void> handleLogout() async {
    try {
      // Call logout API
      await AuthService.logout();
    } catch (e) {
      // Log error but don't throw - we still want to clear local data
      ErrorHandler.logError(e, context: 'ProfileService.handleLogout');
    } finally {
      // Always clear local authentication data
      await AuthManager.clearAuthData();
    }
  }

  // Update profile image (if needed)
  static Future<bool> updateProfileImage(String base64Image) async {
    try {
      final profileData = {
        'avatar': base64Image,
      };

      return await updateUserProfile(profileData);
    } catch (e) {
      ErrorHandler.logError(e, context: 'ProfileService.updateProfileImage');
      rethrow;
    }
  }

  // Get user display information
  static Map<String, String> getUserDisplayInfo(User user) {
    return {
      'id': user.id.toString(),
      'name': user.name,
      'email': user.email,
      'phone': user.phone ?? 'Not provided',
      'role': user.roleDisplayName,
      'displayName': user.displayName,
    };
  }

  // Check if user data is complete
  static bool isUserDataComplete(User user) {
    return user.name.isNotEmpty &&
        user.email.isNotEmpty &&
        user.phone != null &&
        user.phone!.isNotEmpty;
  }
}