// lib/services/base/api_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../Models/Base/api_response.dart';
import '../../Models/Exceptions/api_exception.dart';

class ApiClient {
  static const String baseUrl = 'https://delpick.horas-code.my.id/api/v1';
  static const String devBaseUrl = 'http://localhost:6100/api/v1';

  static const Duration _timeout = Duration(seconds: 30);
  static String? _authToken;

  // Set base URL based on environment
  static String get currentBaseUrl {
    // You can change this based on your environment configuration
    const bool isDevelopment = bool.fromEnvironment('dart.vm.product') == false;
    return isDevelopment ? devBaseUrl : baseUrl;
  }

  // Set authentication token
  static void setAuthToken(String? token) {
    _authToken = token;
  }

  // Get authentication token
  static String? get authToken => _authToken;

  // Clear authentication token
  static void clearAuthToken() {
    _authToken = null;
  }

  // Build headers
  static Map<String, String> _buildHeaders({
    Map<String, String>? extraHeaders,
    bool requiresAuth = true,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth && _authToken != null) {
      headers['Authorization'] = 'Bearer $_authToken';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  // Build full URL
  static String _buildUrl(String endpoint) {
    return '$currentBaseUrl$endpoint';
  }

  // Handle HTTP response
  static Future<ApiResponse<T>> _handleResponse<T>(
      http.Response response,
      T Function(dynamic)? fromJsonT,
      ) async {
    try {
      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      final apiResponse = ApiResponse<T>.fromJson(jsonResponse, fromJsonT);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return apiResponse;
      } else {
        throw ApiException.fromResponse(apiResponse);
      }
    } catch (e) {
      if (e is ApiException) rethrow;

      // Handle specific HTTP status codes
      if (response.statusCode == 401) {
        throw UnauthorizedException();
      } else if (response.statusCode == 400) {
        throw ValidationException(message: 'Invalid request data');
      } else {
        throw ApiException(
          message: 'Request failed with status: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    }
  }

  // GET request
  static Future<ApiResponse<T>> get<T>(
      String endpoint, {
        Map<String, String>? queryParams,
        Map<String, String>? headers,
        bool requiresAuth = true,
        T Function(dynamic)? fromJsonT,
      }) async {
    try {
      String url = _buildUrl(endpoint);

      if (queryParams != null && queryParams.isNotEmpty) {
        final uri = Uri.parse(url);
        final newUri = uri.replace(queryParameters: {
          ...uri.queryParameters,
          ...queryParams,
        });
        url = newUri.toString();
      }

      final response = await http
          .get(
        Uri.parse(url),
        headers: _buildHeaders(
          extraHeaders: headers,
          requiresAuth: requiresAuth,
        ),
      )
          .timeout(_timeout);

      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on HttpException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  // POST request
  static Future<ApiResponse<T>> post<T>(
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
        bool requiresAuth = true,
        T Function(dynamic)? fromJsonT,
      }) async {
    try {
      final response = await http
          .post(
        Uri.parse(_buildUrl(endpoint)),
        headers: _buildHeaders(
          extraHeaders: headers,
          requiresAuth: requiresAuth,
        ),
        body: body != null ? json.encode(body) : null,
      )
          .timeout(_timeout);

      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on HttpException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  // PUT request
  static Future<ApiResponse<T>> put<T>(
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
        bool requiresAuth = true,
        T Function(dynamic)? fromJsonT,
      }) async {
    try {
      final response = await http
          .put(
        Uri.parse(_buildUrl(endpoint)),
        headers: _buildHeaders(
          extraHeaders: headers,
          requiresAuth: requiresAuth,
        ),
        body: body != null ? json.encode(body) : null,
      )
          .timeout(_timeout);

      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on HttpException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  // PATCH request
  static Future<ApiResponse<T>> patch<T>(
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? headers,
        bool requiresAuth = true,
        T Function(dynamic)? fromJsonT,
      }) async {
    try {
      final response = await http
          .patch(
        Uri.parse(_buildUrl(endpoint)),
        headers: _buildHeaders(
          extraHeaders: headers,
          requiresAuth: requiresAuth,
        ),
        body: body != null ? json.encode(body) : null,
      )
          .timeout(_timeout);

      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on HttpException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }

  // DELETE request
  static Future<ApiResponse<T>> delete<T>(
      String endpoint, {
        Map<String, String>? headers,
        bool requiresAuth = true,
        T Function(dynamic)? fromJsonT,
      }) async {
    try {
      final response = await http
          .delete(
        Uri.parse(_buildUrl(endpoint)),
        headers: _buildHeaders(
          extraHeaders: headers,
          requiresAuth: requiresAuth,
        ),
      )
          .timeout(_timeout);

      return _handleResponse<T>(response, fromJsonT);
    } on SocketException {
      throw NetworkException();
    } on HttpException {
      throw NetworkException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException(message: e.toString());
    }
  }
}
