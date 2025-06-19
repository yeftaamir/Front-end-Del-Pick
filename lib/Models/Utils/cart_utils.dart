// lib/Services/Utils/cart_utils.dart
import 'package:del_pick/Models/Entities/store.dart';
import 'package:del_pick/Models/Responses/order_responses.dart';
import 'package:del_pick/Models/Enums/order_status.dart';
import 'package:del_pick/Common/global_style.dart';

class CartUtils {
  // Calculate cart totals
  static CartTotals calculateTotals(List<CartItem> cartItems) {
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final deliveryFee = calculateDeliveryFee(cartItems);
    final total = subtotal + deliveryFee;
    final totalItems = cartItems.fold(0, (sum, item) => sum + item.quantity);

    return CartTotals(
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      total: total,
      totalItems: totalItems,
    );
  }

  // Calculate delivery fee based on various factors
  static double calculateDeliveryFee(List<CartItem> cartItems) {
    const double baseFee = 5000; // Base delivery fee
    const double perItemFee = 1000; // Additional fee per item
    const double minimumOrder = 25000; // Minimum order for delivery

    final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    final totalItems = cartItems.fold(0, (sum, item) => sum + item.quantity);

    // If order is below minimum, add surcharge
    double fee = baseFee;
    if (subtotal < minimumOrder) {
      fee += 2000; // Low order surcharge
    }

    // Add per item fee
    fee += (totalItems * perItemFee);

    return fee;
  }

  // Calculate estimated delivery time
  static Duration estimateDeliveryTime({
    double? distance,
    int? totalItems,
    OrderStatus? currentStatus,
  }) {
    const Duration basePrepTime = Duration(minutes: 15);
    const Duration baseDeliveryTime = Duration(minutes: 20);

    Duration estimatedTime = basePrepTime + baseDeliveryTime;

    // Add time based on number of items
    if (totalItems != null && totalItems > 5) {
      estimatedTime += Duration(minutes: (totalItems - 5) * 2);
    }

    // Add time based on distance
    if (distance != null) {
      final int additionalMinutes = (distance * 3).round(); // 3 minutes per km
      estimatedTime += Duration(minutes: additionalMinutes);
    }

    // Adjust based on current status
    if (currentStatus != null) {
      switch (currentStatus) {
        case OrderStatus.confirmed:
          estimatedTime = basePrepTime + baseDeliveryTime;
          break;
        case OrderStatus.preparing:
          estimatedTime = const Duration(minutes: 10) + baseDeliveryTime;
          break;
        case OrderStatus.readyForPickup:
          estimatedTime = baseDeliveryTime;
          break;
        case OrderStatus.onDelivery:
          estimatedTime = Duration(minutes: distance != null ? (distance * 2).round() : 15);
          break;
        default:
          break;
      }
    }

    return estimatedTime;
  }

  // Validate cart items before order
  static CartValidationResult validateCart(List<CartItem> cartItems, Store store) {
    final List<String> errors = [];

    // Check if cart is empty
    if (cartItems.isEmpty) {
      errors.add('Keranjang kosong. Tambahkan item untuk melanjutkan.');
      return CartValidationResult(isValid: false, errors: errors);
    }

    // Check if store is open
    if (!isStoreOpen(store)) {
      errors.add('Toko sedang tutup. Silakan pesan saat toko buka.');
    }

    // Check individual items
    for (var item in cartItems) {
      if (!item.menuItem.isAvailable) {
        errors.add('${item.menuItem.name} tidak tersedia.');
      }

      if (item.quantity <= 0) {
        errors.add('Jumlah ${item.menuItem.name} tidak valid.');
      }

      if (item.quantity > 99) {
        errors.add('Maksimal 99 item untuk ${item.menuItem.name}.');
      }
    }

    // Check minimum order
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);
    const double minimumOrder = 10000;
    if (subtotal < minimumOrder) {
      errors.add('Minimum pemesanan ${GlobalStyle.formatRupiah(minimumOrder)}.');
    }

    return CartValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  // Check if store is currently open
  static bool isStoreOpen(Store store) {
    if (store.openTime == null || store.closeTime == null) {
      return true; // Assume open if no hours specified
    }

    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    try {
      final openParts = store.openTime!.split(':');
      final closeParts = store.closeTime!.split(':');

      final openMinutes = int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
      final closeMinutes = int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);

      if (openMinutes <= closeMinutes) {
        // Same day (e.g., 9:00 - 17:00)
        return currentMinutes >= openMinutes && currentMinutes <= closeMinutes;
      } else {
        // Crosses midnight (e.g., 22:00 - 06:00)
        return currentMinutes >= openMinutes || currentMinutes <= closeMinutes;
      }
    } catch (e) {
      return true; // Default to open if parsing fails
    }
  }

  // Format cart summary for sharing
  static String formatCartSummary(List<CartItem> cartItems, Store store) {
    final buffer = StringBuffer();
    buffer.writeln('Pesanan dari ${store.name}:');
    buffer.writeln();

    for (var item in cartItems) {
      buffer.writeln('• ${item.menuItem.name} x${item.quantity}');
      buffer.writeln('  ${GlobalStyle.formatRupiah(item.menuItem.price)} x ${item.quantity} = ${GlobalStyle.formatRupiah(item.totalPrice)}');
      if (item.notes != null && item.notes!.isNotEmpty) {
        buffer.writeln('  Catatan: ${item.notes}');
      }
      buffer.writeln();
    }

    final totals = calculateTotals(cartItems);
    buffer.writeln('Subtotal: ${GlobalStyle.formatRupiah(totals.subtotal)}');
    buffer.writeln('Biaya Pengiriman: ${GlobalStyle.formatRupiah(totals.deliveryFee)}');
    buffer.writeln('Total: ${GlobalStyle.formatRupiah(totals.total)}');

    return buffer.toString();
  }

  // Group cart items by category
  static Map<String, List<CartItem>> groupItemsByCategory(List<CartItem> cartItems) {
    final Map<String, List<CartItem>> grouped = {};

    for (var item in cartItems) {
      final category = item.menuItem.category;
      if (!grouped.containsKey(category)) {
        grouped[category] = [];
      }
      grouped[category]!.add(item);
    }

    return grouped;
  }

  // Get recommended items based on cart contents
  static List<String> getRecommendedCategories(List<CartItem> cartItems) {
    final categories = cartItems.map((item) => item.menuItem.category).toSet();
    final List<String> recommendations = [];

    // Add complementary categories
    if (categories.contains('Makanan Utama') && !categories.contains('Minuman')) {
      recommendations.add('Minuman');
    }

    if (categories.contains('Makanan') && !categories.contains('Cemilan')) {
      recommendations.add('Cemilan');
    }

    if (categories.contains('Minuman Panas') && !categories.contains('Makanan Penutup')) {
      recommendations.add('Makanan Penutup');
    }

    return recommendations;
  }

  // Calculate savings if any
  static double calculateSavings(List<CartItem> cartItems) {
    // This could be enhanced with actual promotion logic
    double savings = 0.0;

    // Example: Free delivery for orders above certain amount
    const double freeDeliveryThreshold = 50000;
    final subtotal = cartItems.fold(0.0, (sum, item) => sum + item.totalPrice);

    if (subtotal >= freeDeliveryThreshold) {
      savings += calculateDeliveryFee(cartItems);
    }

    return savings;
  }

  // Get payment method recommendations
  static List<String> getRecommendedPaymentMethods(double totalAmount) {
    final List<String> methods = [];

    // Always available
    methods.add('Tunai');

    // Digital payments for larger amounts
    if (totalAmount >= 20000) {
      methods.addAll(['GoPay', 'OVO', 'DANA', 'ShopeePay']);
    }

    // Bank transfer for very large amounts
    if (totalAmount >= 100000) {
      methods.add('Transfer Bank');
    }

    return methods;
  }
}

// Supporting classes
class CartTotals {
  final double subtotal;
  final double deliveryFee;
  final double total;
  final int totalItems;

  CartTotals({
    required this.subtotal,
    required this.deliveryFee,
    required this.total,
    required this.totalItems,
  });

  Map<String, dynamic> toMap() {
    return {
      'subtotal': subtotal,
      'deliveryFee': deliveryFee,
      'total': total,
      'totalItems': totalItems,
    };
  }
}

class CartValidationResult {
  final bool isValid;
  final List<String> errors;

  CartValidationResult({
    required this.isValid,
    required this.errors,
  });

  String get firstError => errors.isNotEmpty ? errors.first : '';
  String get allErrors => errors.join('\n');
}