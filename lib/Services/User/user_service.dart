// lib/services/user/user_service.dart
import '../../Models/Base/api_response.dart';
import '../../Models/Entities/user.dart';
import '../Base/api_client.dart';

class UserService {
  static const String _baseEndpoint = '/users';

  // Get Profile
  static Future<ApiResponse<User>> getProfile() async {
    return await ApiClient.get<User>(
      '$_baseEndpoint/profile',
      fromJsonT: (data) => User.fromJson(data),
    );
  }

  // Update Profile
  static Future<ApiResponse<User>> updateProfile(Map<String, dynamic> profileData) async {
    return await ApiClient.put<User>(
      '$_baseEndpoint/profile',
      body: profileData,
      fromJsonT: (data) => User.fromJson(data),
    );
  }

  // Delete Profile
  static Future<ApiResponse<Map<String, dynamic>>> deleteProfile() async {
    return await ApiClient.delete<Map<String, dynamic>>(
      '$_baseEndpoint/profile',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Get Notifications
  static Future<ApiResponse<List<Map<String, dynamic>>>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    return await ApiClient.get<List<Map<String, dynamic>>>(
      '$_baseEndpoint/notifications',
      queryParams: queryParams,
      fromJsonT: (data) => List<Map<String, dynamic>>.from(data as List),
    );
  }

  // Mark Notification as Read
  static Future<ApiResponse<Map<String, dynamic>>> markNotificationAsRead(int notificationId) async {
    return await ApiClient.patch<Map<String, dynamic>>(
      '$_baseEndpoint/notifications/$notificationId/read',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Mark All Notifications as Read
  static Future<ApiResponse<Map<String, dynamic>>> markAllNotificationsAsRead() async {
    return await ApiClient.patch<Map<String, dynamic>>(
      '$_baseEndpoint/notifications/read-all',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Delete Notification
  static Future<ApiResponse<Map<String, dynamic>>> deleteNotification(int notificationId) async {
    return await ApiClient.delete<Map<String, dynamic>>(
      '$_baseEndpoint/notifications/$notificationId',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }
}