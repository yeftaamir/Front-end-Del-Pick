// lib/models/constants/api_constants.dart
class ApiConstants {
  static const String baseUrl = 'https://delpick.horas-code.my.id/api/v1';
  static const String devBaseUrl = 'http://localhost:6100/api/v1';

  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';

  // Store endpoints
  static const String stores = '/stores';

  // Menu endpoints
  static const String menu = '/menu';

  // Order endpoints
  static const String orders = '/orders';

  // Driver endpoints
  static const String drivers = '/drivers';
  static const String driverRequests = '/driver-requests';

  // Tracking endpoints
  static const String tracking = '/tracking';

  // Customers endpoints
  static const String customers = '/customers';
}