// lib/models/enums/delivery_status.dart
enum DeliveryStatus {
  pending('pending'),
  pickedUp('picked_up'),
  onWay('on_way'),
  delivered('delivered');

  const DeliveryStatus(this.value);
  final String value;

  static DeliveryStatus fromString(String value) {
    return DeliveryStatus.values.firstWhere(
          (status) => status.value == value,
      orElse: () => DeliveryStatus.pending,
    );
  }
}