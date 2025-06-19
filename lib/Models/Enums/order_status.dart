// lib/models/enums/order_status.dart
enum OrderStatus {
  pending('pending'),
  confirmed('confirmed'),
  preparing('preparing'),
  readyForPickup('ready_for_pickup'),
  onDelivery('on_delivery'),
  delivered('delivered'),
  cancelled('cancelled');

  const OrderStatus(this.value);
  final String value;

  static OrderStatus fromString(String value) {
    return OrderStatus.values.firstWhere(
          (status) => status.value == value,
      orElse: () => OrderStatus.pending,
    );
  }
}
