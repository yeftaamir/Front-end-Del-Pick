// lib/services/core/base_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_constants.dart';
import 'token_service.dart';

abstract class BaseService {
  // Common error handling
  static void handleErrorResponse(http.Response response) {
    try {
      final Map<String, dynamic> errorData = json.decode(response.body);
      final message = errorData['message'] ?? 'Unknown error occurred';
      final statusCode = response.statusCode;

      switch (statusCode) {
        case 400:
          throw BadRequestException(message);
        case 401:
          throw UnauthorizedException(message);
        case 403:
          throw ForbiddenException(message);
        case 404:
          throw NotFoundException(message);
        case 422:
          throw ValidationException(message, errorData['errors']);
        case 429:
          throw RateLimitException(message);
        case 500:
          throw ServerException(message);
        default:
          throw ApiException(message, statusCode);
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Failed to parse error response', response.statusCode);
    }
  }

  // Parse response body safely
  static Map<String, dynamic> parseResponseBody(String body) {
    try {
      return json.decode(body) as Map<String, dynamic>;
    } catch (e) {
      throw ApiException('Invalid JSON response');
    }
  }

  // Make authenticated HTTP requests
  static Future<http.Response> makeRequest(
      String method,
      String endpoint, {
        Map<String, dynamic>? body,
        Map<String, String>? additionalHeaders,
        bool requiresAuth = true,
      }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    Map<String, String> headers = ApiConstants.defaultHeaders;

    if (requiresAuth) {
      headers = await TokenService.getAuthHeaders();
    }

    if (additionalHeaders != null) {
      headers.addAll(additionalHeaders);
    }

    final encodedBody = body != null ? json.encode(body) : null;

    try {
      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers)
              .timeout(ApiConstants.requestTimeout);
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: encodedBody)
              .timeout(ApiConstants.requestTimeout);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: encodedBody)
              .timeout(ApiConstants.requestTimeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers)
              .timeout(ApiConstants.requestTimeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method');
      }

      return response;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw NetworkException('Network error: ${e.toString()}');
    }
  }

  // Helper for GET requests
  static Future<Map<String, dynamic>> get(
      String endpoint, {
        Map<String, String>? queryParams,
        bool requiresAuth = true,
      }) async {
    String url = endpoint;
    if (queryParams != null && queryParams.isNotEmpty) {
      final query = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url += '?$query';
    }

    final response = await makeRequest('GET', url, requiresAuth: requiresAuth);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parseResponseBody(response.body);
    } else {
      handleErrorResponse(response);
      return {};
    }
  }

  // Helper for POST requests
  static Future<Map<String, dynamic>> post(
      String endpoint,
      Map<String, dynamic> body, {
        bool requiresAuth = true,
      }) async {
    final response = await makeRequest('POST', endpoint,
        body: body, requiresAuth: requiresAuth);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parseResponseBody(response.body);
    } else {
      handleErrorResponse(response);
      return {};
    }
  }

  // Helper for PUT requests
  static Future<Map<String, dynamic>> put(
      String endpoint,
      Map<String, dynamic> body, {
        bool requiresAuth = true,
      }) async {
    final response = await makeRequest('PUT', endpoint,
        body: body, requiresAuth: requiresAuth);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parseResponseBody(response.body);
    } else {
      handleErrorResponse(response);
      return {};
    }
  }

  // Helper for DELETE requests
  static Future<Map<String, dynamic>> delete(
      String endpoint, {
        bool requiresAuth = true,
      }) async {
    final response = await makeRequest('DELETE', endpoint, requiresAuth: requiresAuth);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parseResponseBody(response.body);
    } else {
      handleErrorResponse(response);
      return {};
    }
  }
}

// Custom Exception Classes
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => 'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class BadRequestException extends ApiException {
  BadRequestException(String message) : super(message, 400);
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message, 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException(String message) : super(message, 403);
}

class NotFoundException extends ApiException {
  NotFoundException(String message) : super(message, 404);
}

class ValidationException extends ApiException {
  final Map<String, dynamic>? errors;

  ValidationException(String message, this.errors) : super(message, 422);
}

class RateLimitException extends ApiException {
  RateLimitException(String message) : super(message, 429);
}

class ServerException extends ApiException {
  ServerException(String message) : super(message, 500);
}