class Driver {
  final String id;
  final String name;
  final double rating;
  final String phoneNumber;
  final String vehicleNumber;
  final String email;
  final String? profileImageUrl;

  Driver({
    required this.id,
    required this.name,
    required this.rating,
    required this.phoneNumber,
    required this.vehicleNumber,
    required this.email,
    this.profileImageUrl,
  });

  // Factory constructor to create a Driver from JSON data
  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rating: (json['rating'] as num? ?? 0.0).toDouble(),
      phoneNumber: json['phone_number'] as String? ?? '',
      vehicleNumber: json['vehicle_number'] as String? ?? '',
      email: json['email'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String?,
    );
  }

  // Convert Driver instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'rating': rating,
      'phone_number': phoneNumber,
      'vehicle_number': vehicleNumber,
      'email': email,
      'profile_image_url': profileImageUrl,
    };
  }

  // Create a copy of this Driver with the given field values changed
  Driver copyWith({
    String? id,
    String? name,
    double? rating,
    String? phoneNumber,
    String? vehicleNumber,
    String? email,
    String? profileImageUrl,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      rating: rating ?? this.rating,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  // Sample driver for testing purposes
  static Driver sample() {
    return Driver(
      id: '1',
      name: 'M. Hermawan',
      rating: 4.8,
      phoneNumber: '+62 8132635487',
      vehicleNumber: 'BB 1234 ABC',
      email: 'hermawan@gmail.com',
      profileImageUrl: null,
    );
  }
}