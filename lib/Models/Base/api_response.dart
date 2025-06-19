// lib/models/Base/api_response.dart
class ApiResponse<T> {
  final int statusCode;
  final String message;
  final T? data;
  final String? error;

  ApiResponse({
    required this.statusCode,
    required this.message,
    this.data,
    this.error,
  });

  factory ApiResponse.fromJson(
      Map<String, dynamic> json,
      T Function(dynamic)? fromJsonT,
      ) {
    return ApiResponse<T>(
      statusCode: json['statusCode'] as int,
      message: json['message'] as String,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      error: json['error'] as String?,
    );
  }

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isError => !isSuccess;
}