// lib/services/utils/error_handler.dart
import '../../Models/Exceptions/api_exception.dart';

class ErrorHandler {
  // Handle API errors
  static String handleApiError(ApiException error) {
    switch (error.statusCode) {
      case 400:
        return error.message.isNotEmpty
            ? error.message
            : 'Invalid request. Please check your input.';
      case 401:
        return 'You are not authorized. Please login again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return 'This resource already exists.';
      case 422:
        return error.message.isNotEmpty
            ? error.message
            : 'Validation failed. Please check your input.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service temporarily unavailable. Please try again later.';
      default:
        return error.message.isNotEmpty
            ? error.message
            : 'An unexpected error occurred. Please try again.';
    }
  }

  // Handle network errors
  static String handleNetworkError(NetworkException error) {
    return 'Network connection failed. Please check your internet connection and try again.';
  }

  // Handle validation errors
  static String handleValidationError(ValidationException error) {
    if (error.validationErrors != null && error.validationErrors!.isNotEmpty) {
      final firstError = error.validationErrors!.values.first.first;
      return firstError;
    }
    return error.message;
  }

  // Handle unauthorized errors
  static String handleUnauthorizedError(UnauthorizedException error) {
    return 'Your session has expired. Please login again.';
  }

  // Generic error handler
  static String handleError(dynamic error) {
    if (error is UnauthorizedException) {
      return handleUnauthorizedError(error);
    } else if (error is ValidationException) {
      return handleValidationError(error);
    } else if (error is NetworkException) {
      return handleNetworkError(error);
    } else if (error is ApiException) {
      return handleApiError(error);
    } else {
      return 'An unexpected error occurred: ${error.toString()}';
    }
  }

  // Show error message (can be customized based on your UI framework)
  static void showError(dynamic error, {Function(String)? onError}) {
    final message = handleError(error);

    if (onError != null) {
      onError(message);
    } else {
      print('Error: $message');
    }
  }

  // Log error for debugging
  static void logError(dynamic error, {String? context}) {
    final message = handleError(error);
    final logMessage = context != null
        ? '$context: $message'
        : message;

    print('ERROR LOG: $logMessage');

    // You can also send to crash reporting service here
    // Example: Crashlytics, Sentry, etc.
  }
}