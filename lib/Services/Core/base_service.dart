// lib/Services/core/base_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:del_pick/Services/Core/token_service.dart';
import 'package:http/http.dart' as http;
import 'api_constants.dart';

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

  /// Parse response body with improved error handling
  static Map<String, dynamic> parseResponse(http.Response response) {
    try {
      final body = response.body.trim();

      // Handle empty response
      if (body.isEmpty) {
        return {
          'message': 'Empty response',
          'data': null,
          'errors': null
        };
      }

      // Try to decode JSON
      final decodedJson = jsonDecode(body);

      // Handle different response types
      if (decodedJson is Map<String, dynamic>) {
        // Normal case - response is already a Map
        return _normalizeResponse(decodedJson);
      } else if (decodedJson is List) {
        // Response is an array - wrap it in a standard format
        return {
          'message': 'Success',
          'data': decodedJson,
          'errors': null
        };
      } else if (decodedJson is String) {
        // Response is a string - wrap it in a standard format
        return {
          'message': decodedJson,
          'data': null,
          'errors': null
        };
      } else {
        // Response is some other type - wrap it in a standard format
        return {
          'message': 'Success',
          'data': decodedJson,
          'errors': null
        };
      }
    } on FormatException catch (e) {
      // JSON parsing failed - treat as plain text
      return {
        'message': response.body.isNotEmpty ? response.body : 'Invalid response format',
        'data': null,
        'errors': 'JSON parsing failed: $e'
      };
    } catch (e) {
      // Other parsing errors
      return {
        'message': 'Failed to parse response',
        'data': null,
        'errors': e.toString()
      };
    }
  }

  /// Normalize response to ensure consistent format
  static Map<String, dynamic> _normalizeResponse(Map<String, dynamic> response) {
    return {
      'message': response['message'] ?? 'Success',
      'data': response['data'],
      'errors': response['errors'],
      // Preserve any additional fields
      ...response,
    };
  }

  /// Parse response with raw data access
  static dynamic parseResponseRaw(http.Response response) {
    try {
      final body = response.body.trim();

      if (body.isEmpty) {
        return null;
      }

      return jsonDecode(body);
    } catch (e) {
      return response.body;
    }
  }

  /// Handle API errors consistently
  static void handleApiError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return; // Success
    }

    try {
      final errorData = parseResponse(response);
      final message = errorData['message'] ??
          errorData['errors'] ??
          'Request failed';
      throw Exception(message);
    } catch (e) {
      // Fallback error messages
      switch (response.statusCode) {
        case 400:
          throw Exception('Bad request - Invalid input data');
        case 401:
          throw Exception('Unauthorized - Please login again');
        case 403:
          throw Exception('Forbidden - Access denied');
        case 404:
          throw Exception('Not found - Resource does not exist');
        case 422:
          throw Exception('Validation error - Please check your input');
        case 429:
          throw Exception('Too many requests - Please try again later');
        case 500:
          throw Exception('Internal server error - Please try again later');
        case 502:
          throw Exception('Bad gateway - Service temporarily unavailable');
        case 503:
          throw Exception('Service unavailable - Please try again later');
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

  /// Generic API call method with improved error handling
  static Future<Map<String, dynamic>> apiCall({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requiresAuth = true,
  }) async {
    late http.Response response;

    try {
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
    } catch (e) {
      // Log the error for debugging
      print('API Call Error: $e');
      print('Endpoint: $endpoint');
      print('Method: $method');
      if (body != null) print('Body: $body');

      rethrow;
    }
  }

  /// Debug method to log response details
  static void debugResponse(http.Response response) {
    print('=== DEBUG RESPONSE ===');
    print('Status Code: ${response.statusCode}');
    print('Headers: ${response.headers}');
    print('Body: ${response.body}');
    print('Body Length: ${response.body.length}');
    print('Body Type: ${response.body.runtimeType}');
    print('=====================');
  }
}