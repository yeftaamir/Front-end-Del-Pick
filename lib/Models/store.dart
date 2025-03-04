// File: lib/Models/store.dart
class StoreModel {
  final String name;
  final String address;
  final String openHours;
  final double distance; // in KM
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final String phoneNumber;
  final int productCount;
  final String description;

  StoreModel({
    required this.name,
    required this.address,
    required this.openHours,
    this.distance = 0.0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.imageUrl = 'assets/images/store_front.jpg',
    this.phoneNumber = '',
    this.productCount = 0,
    this.description = '',
  });

  String get formattedRating => '$rating dari 5';
  String get formattedProductCount => '$productCount Produk';
}