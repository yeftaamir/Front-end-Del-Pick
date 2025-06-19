// lib/models/requests/driver_requests.dart
class CreateDriverRequestRequest {
  final int orderId;

  CreateDriverRequestRequest({
    required this.orderId,
  });

  Map<String, dynamic> toJson() {
    return {
      'orderId': orderId,
    };
  }
}