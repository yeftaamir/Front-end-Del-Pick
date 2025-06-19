// lib/models/enums/driver_status.dart
enum DriverStatus {
  active('active'),
  inactive('inactive'),
  busy('busy');

  const DriverStatus(this.value);
  final String value;

  static DriverStatus fromString(String value) {
    return DriverStatus.values.firstWhere(
          (status) => status.value == value,
      orElse: () => DriverStatus.active,
    );
  }
}