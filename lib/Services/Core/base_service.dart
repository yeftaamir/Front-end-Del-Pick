
// lib/Services/core/base_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_constants.dart';
import 'token_service.dart';

class BaseService {
  /// Get authorization headers with token
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await TokenService.getToken();
    final headers = Map<String, String>.from(ApiConstants.headers);

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// GET request with automatic token management
  static Future<http.Response> get(
      String endpoint, {
        Map<String, String>? queryParams,
        bool requiresAuth = true,
      }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final headers = requiresAuth
          ? await getAuthHeaders()
          : ApiConstants.headers;

      final response = await http.get(uri, headers: headers)
          .timeout(ApiConstants.requestTimeout);

      await _handleUnauthorized(response);
      return response;
    } on SocketException {
      throw Exception('No internet connection');
    } on HttpException {
      throw Exception('HTTP error occurred');
    } catch (e) {
      throw Exception('Request failed: $e');
    }
  }

  /// POST request with automatic token management
  static Future<http.Response> post(
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? queryParams,
        bool requiresAuth = true,
      }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final headers = requiresAuth
          ? await getAuthHeaders()
          : ApiConstants.headers;

      final response = await http.post(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(ApiConstants.requestTimeout);

      await _handleUnauthorized(response);
      return response;
    } on SocketException {
      throw Exception('No internet connection');
    } on HttpException {
      throw Exception('HTTP error occurred');
    } catch (e) {
      throw Exception('Request failed: $e');
    }
  }

  /// PUT request with automatic token management
  static Future<http.Response> put(
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? queryParams,
        bool requiresAuth = true,
      }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final headers = requiresAuth
          ? await getAuthHeaders()
          : ApiConstants.headers;

      final response = await http.put(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(ApiConstants.requestTimeout);

      await _handleUnauthorized(response);
      return response;
    } on SocketException {
      throw Exception('No internet connection');
    } on HttpException {
      throw Exception('HTTP error occurred');
    } catch (e) {
      throw Exception('Request failed: $e');
    }
  }

  /// PATCH request with automatic token management
  static Future<http.Response> patch(
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? queryParams,
        bool requiresAuth = true,
      }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final headers = requiresAuth
          ? await getAuthHeaders()
          : ApiConstants.headers;

      final response = await http.patch(
        uri,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(ApiConstants.requestTimeout);

      await _handleUnauthorized(response);
      return response;
    } on SocketException {
      throw Exception('No internet connection');
    } on HttpException {
      throw Exception('HTTP error occurred');
    } catch (e) {
      throw Exception('Request failed: $e');
    }
  }

  /// DELETE request with automatic token management
  static Future<http.Response> delete(
      String endpoint, {
        Map<String, String>? queryParams,
        bool requiresAuth = true,
      }) async {
    try {
      final uri = _buildUri(endpoint, queryParams);
      final headers = requiresAuth
          ? await getAuthHeaders()
          : ApiConstants.headers;

      final response = await http.delete(uri, headers: headers)
          .timeout(ApiConstants.requestTimeout);

      await _handleUnauthorized(response);
      return response;
    } on SocketException {
      throw Exception('No internet connection');
    } on HttpException {
      throw Exception('HTTP error occurred');
    } catch (e) {
      throw Exception('Request failed: $e');
    }
  }

  /// Parse response body with error handling
  static Map<String, dynamic> parseResponse(http.Response response) {
    try {
      final body = response.body;
      if (body.isEmpty) {
        return {};
      }
      return jsonDecode(body);
    } catch (e) {
      throw Exception('Failed to parse response: $e');
    }
  }

  /// Handle API errors consistently
  static void handleApiError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return; // Success
    }

    try {
      final errorData = parseResponse(response);
      final message = errorData['message'] ?? 'Request failed';
      throw Exception(message);
    } catch (e) {
      switch (response.statusCode) {
        case 400:
          throw Exception('Bad request');
        case 401:
          throw Exception('Unauthorized');
        case 403:
          throw Exception('Forbidden');
        case 404:
          throw Exception('Not found');
        case 500:
          throw Exception('Internal server error');
        default:
          throw Exception('Request failed with status ${response.statusCode}');
      }
    }
  }

  /// Build URI with query parameters
  static Uri _buildUri(String endpoint, Map<String, String>? queryParams) {
    final url = '${ApiConstants.baseUrl}$endpoint';
    final uri = Uri.parse(url);

    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams);
    }

    return uri;
  }

  /// Handle unauthorized responses by clearing tokens
  static Future<void> _handleUnauthorized(http.Response response) async {
    if (response.statusCode == 401) {
      await TokenService.clearAll();
    }
  }

  /// Generic API call method
  static Future<Map<String, dynamic>> apiCall({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    late http.Response response;

    switch (method.toUpperCase()) {
      case 'GET':
        response = await get(endpoint, queryParams: queryParams, requiresAuth: requiresAuth);
        break;
      case 'POST':
        response = await post(endpoint, body: body, queryParams: queryParams, requiresAuth: requiresAuth);
        break;
      case 'PUT':
        response = await put(endpoint, body: body, queryParams: queryParams, requiresAuth: requiresAuth);
        break;
      case 'PATCH':
        response = await patch(endpoint, body: body, queryParams: queryParams, requiresAuth: requiresAuth);
        break;
      case 'DELETE':
        response = await delete(endpoint, queryParams: queryParams, requiresAuth: requiresAuth);
        break;
      default:
        throw Exception('Unsupported HTTP method: $method');
    }

    handleApiError(response);
    return parseResponse(response);
  }
}