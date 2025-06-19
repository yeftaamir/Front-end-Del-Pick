// lib/models/enums/store_status.dart
enum StoreStatus {
  active('active'),
  inactive('inactive'),
  closed('closed');

  const StoreStatus(this.value);
  final String value;

  static StoreStatus fromString(String value) {
    return StoreStatus.values.firstWhere(
          (status) => status.value == value,
      orElse: () => StoreStatus.active,
    );
  }
}