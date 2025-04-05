// abstract class Env {
//   static const String baseUrl = String.fromEnvironment(
//       'BASE_URL',
//       // defaultValue: 'http://localhost:3000/api/v1'
//       defaultValue: 'https://delpick.fun/api/v1'
//   );
//
//   static const String env = String.fromEnvironment(
//       'ENV',
//       // defaultValue: 'dev'
//       defaultValue: 'prod'
//   );
// }
import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract class Env {
  static String? baseUrl = dotenv.env['BASE_URL'] ?? 'https://delpick.fun/api/v1';
  static String? socketUrl = dotenv.env['SOCKET_URL'] ?? 'https://delpick.fun';
  static String? mapboxAccessToken = dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
}
