// lib/models/exceptions/api_exception.dart
import '../Base/api_response.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? error;

  ApiException({
    required this.message,
    this.statusCode,
    this.error,
  });

  factory ApiException.fromResponse(ApiResponse response) {
    return ApiException(
      message: response.message,
      statusCode: response.statusCode,
      error: response.error,
    );
  }

  @override
  String toString() {
    return 'ApiException: $message (Status: $statusCode)';
  }
}

class NetworkException extends ApiException {
  NetworkException({String? message})
      : super(message: message ?? 'Network connection failed');
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({String? message})
      : super(
    message: message ?? 'Unauthorized access',
    statusCode: 401,
  );
}

class ValidationException extends ApiException {
  final Map<String, List<String>>? validationErrors;

  ValidationException({
    String? message,
    this.validationErrors,
  }) : super(
    message: message ?? 'Validation failed',
    statusCode: 400,
  );
}
