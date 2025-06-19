// lib/services/auth/auth_service.dart
import '../../Models/Base/api_response.dart';
import '../../Models/Entities/user.dart';
import '../../Models/Requests/auth_requests.dart';
import '../../Models/Responses/auth_responses.dart';
import '../Base/api_client.dart';

class AuthService {
  static const String _baseEndpoint = '/auth';

  // Login
  static Future<ApiResponse<LoginResponse>> login(LoginRequest request) async {
    return await ApiClient.post<LoginResponse>(
      '$_baseEndpoint/login',
      body: request.toJson(),
      requiresAuth: false,
      fromJsonT: (data) => LoginResponse.fromJson(data),
    );
  }

  // Logout
  static Future<ApiResponse<Map<String, dynamic>>> logout() async {
    return await ApiClient.post<Map<String, dynamic>>(
      '$_baseEndpoint/logout',
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

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

  // Forgot Password
  static Future<ApiResponse<Map<String, dynamic>>> forgotPassword(String email) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '$_baseEndpoint/forgot-password',
      body: {'email': email},
      requiresAuth: false,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Reset Password
  static Future<ApiResponse<Map<String, dynamic>>> resetPassword({
    required String token,
    required String password,
  }) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '$_baseEndpoint/reset-password',
      body: {
        'token': token,
        'password': password,
      },
      requiresAuth: false,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Verify Email
  static Future<ApiResponse<Map<String, dynamic>>> verifyEmail(String token) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '$_baseEndpoint/verify-email/$token',
      requiresAuth: false,
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }

  // Resend Verification
  static Future<ApiResponse<Map<String, dynamic>>> resendVerification(String email) async {
    return await ApiClient.post<Map<String, dynamic>>(
      '$_baseEndpoint/resend-verification',
      body: {'email': email},
      fromJsonT: (data) => data as Map<String, dynamic>,
    );
  }
}
