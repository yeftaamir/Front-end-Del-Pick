// File: lib/Models/store.dart
class StoreModel {
  final int id;
  final int? userId;
  final String name;
  final String address;
  final String description;
  final String openHours;
  final double distance;
  final double rating;
  final int reviewCount;
  final String imageUrl;
  final String phoneNumber;
  final int productCount;
  final double? latitude;
  final double? longitude;

  StoreModel({
    required this.name,
    required this.address,
    required this.openHours,
    this.distance = 0.0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.imageUrl = '',
    this.phoneNumber = '',
    this.productCount = 0,
    this.description = '',
    this.id = 0,
    this.userId,
    this.latitude,
    this.longitude,
  });

  factory StoreModel.fromJson(Map<String, dynamic> json) {
    // Handle different field naming between FE and BE
    final openHours = json['open_hours'] ??
        (json['openTime'] != null && json['closeTime'] != null
            ? '${json['openTime']} - ${json['closeTime']}'
            : '');

    return StoreModel(
      id: json['id'] ?? 0,
      userId: json['userId'] ?? json['user_id'],
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      openHours: openHours,
      distance: (json['distance'] != null) ? double.tryParse(json['distance'].toString()) ?? 0.0 : 0.0,
      rating: (json['rating'] != null) ? double.tryParse(json['rating'].toString()) ?? 0.0 : 0.0,
      reviewCount: json['review_count'] ?? json['reviewCount'] ?? 0,
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      phoneNumber: json['phone_number'] ?? json['phone'] ?? '',
      productCount: json['product_count'] ?? json['totalProducts'] ?? 0,
      description: json['description'] ?? '',
      latitude: (json['latitude'] != null) ? double.tryParse(json['latitude'].toString()) : null,
      longitude: (json['longitude'] != null) ? double.tryParse(json['longitude'].toString()) : null,
    );
  }

  // This is the method that needed to be defined
  Map<String, dynamic> toJson() {
    // Split openHours to get open and close times
    final openTimeParts = openHours.split('-');
    final openTime = openTimeParts.isNotEmpty ? openTimeParts[0].trim() : '';
    final closeTime = openTimeParts.length > 1 ? openTimeParts[1].trim() : '';

    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'address': address,
      'description': description,
      'open_time': openTime,
      'close_time': closeTime,
      'rating': rating,
      'total_products': productCount,
      'image_url': imageUrl,
      'phone': phoneNumber,
      'review_count': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
    };
  }

  String get formattedRating => '$rating dari 5';
  String get formattedProductCount => '$productCount Produk';
}

class Store {
  int id;
  int userId;
  String name;
  String address;
  String description;
  String openTime;
  String closeTime;
  dynamic rating;
  dynamic totalProducts;
  String imageUrl;
  String phone;
  dynamic reviewCount;
  double latitude;
  double longitude;
  double distance;
  String email; // Add this field

  Store({
    required this.id,
    this.userId = 0,
    required this.name,
    required this.address,
    this.description = '',
    required this.openTime,
    required this.closeTime,
    required this.rating,
    this.totalProducts,
    required this.imageUrl,
    required this.phone,
    this.reviewCount,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.distance = 0.0,
    this.email = '', // Initialize it
  });

  // Update fromJson method to include email
  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? json['userId'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      description: json['description'] ?? '',
      openTime: json['open_time'] ?? json['openTime'] ?? '',
      closeTime: json['close_time'] ?? json['closeTime'] ?? '',
      rating: json['rating'] ?? 0.0,
      totalProducts: json['total_products'] ?? json['totalProducts'] ?? 0,
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? json['image'] ?? '',
      phone: json['phone'] ?? json['phone_number'] ?? '',
      reviewCount: json['review_count'] ?? json['reviewCount'] ?? 0,
      latitude: (json['latitude'] != null) ? double.tryParse(json['latitude'].toString()) ?? 0.0 : 0.0,
      longitude: (json['longitude'] != null) ? double.tryParse(json['longitude'].toString()) ?? 0.0 : 0.0,
      distance: (json['distance'] != null) ? double.tryParse(json['distance'].toString()) ?? 0.0 : 0.0,
      email: json['email'] ?? '', // Get email if available
    );
  }

  // Update toJson method to include email
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'address': address,
      'description': description,
      'open_time': openTime,
      'close_time': closeTime,
      'rating': rating,
      'total_products': totalProducts,
      'image_url': imageUrl,
      'phone': phone,
      'review_count': reviewCount,
      'latitude': latitude,
      'longitude': longitude,
      'distance': distance,
      'email': email,
    };
  }
}