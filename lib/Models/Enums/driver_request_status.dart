// lib/models/enums/driver_request_status.dart
enum DriverRequestStatus {
  pending('pending'),
  accepted('accepted'),
  rejected('rejected'),
  completed('completed'),
  expired('expired');

  const DriverRequestStatus(this.value);
  final String value;

  static DriverRequestStatus fromString(String value) {
    return DriverRequestStatus.values.firstWhere(
          (status) => status.value == value,
      orElse: () => DriverRequestStatus.pending,
    );
  }
}