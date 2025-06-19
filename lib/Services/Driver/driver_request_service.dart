// lib/services/driver/driver_request_service.dart
import '../../Models/Base/api_response.dart';
import '../../Models/Entities/driver_request.dart';
import '../../Models/Enums/driver_request_status.dart';
import '../../Models/Requests/driver_requests.dart';
import '../../Models/Utils/model_utils.dart';
import '../Base/api_client.dart';

class DriverRequestService {
  static const String _baseEndpoint = '/driver-requests';

  // Get Driver Requests
  static Future<ApiResponse<List<DriverRequest>>> getDriverRequests({
    int page = 1,
    int limit = 10,
    DriverRequestStatus? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (status != null) {
      queryParams['status'] = status.value;
    }

    return await ApiClient.get<List<DriverRequest>>(
      _baseEndpoint,
      queryParams: queryParams,
      fromJsonT: (data) {
        if (data is Map<String, dynamic> && data.containsKey('requests')) {
          return ModelUtils.parseList(data['requests'], (json) => DriverRequest.fromJson(json));
        } else if (data is List) {
          return ModelUtils.parseList(data, (json) => DriverRequest.fromJson(json));
        }
        return <DriverRequest>[];
      },
    );
  }

  // Get Driver Request Detail
  static Future<ApiResponse<DriverRequest>> getDriverRequestDetail(int requestId) async {
    return await ApiClient.get<DriverRequest>(
      '$_baseEndpoint/$requestId',
      fromJsonT: (data) => DriverRequest.fromJson(data),
    );
  }

  // Respond to Driver Request (Accept/Reject)
  static Future<ApiResponse<DriverRequest>> respondToDriverRequest(
      int requestId,
      String action, // 'accept' or 'reject'
      ) async {
    return await ApiClient.post<DriverRequest>(
      '$_baseEndpoint/$requestId/respond',
      body: {'action': action},
      fromJsonT: (data) => DriverRequest.fromJson(data),
    );
  }

  // Create Driver Request
  static Future<ApiResponse<DriverRequest>> createDriverRequest(
      CreateDriverRequestRequest request,
      ) async {
    return await ApiClient.post<DriverRequest>(
      _baseEndpoint,
      body: request.toJson(),
      fromJsonT: (data) => DriverRequest.fromJson(data),
    );
  }
}