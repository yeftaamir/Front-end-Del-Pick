class Customer {
  final String id;
  final String name;
  final String phoneNumber;
  final String email;
  final String? profileImageUrl;

  Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.email,
    this.profileImageUrl,
  });

  // Create a Customer from a JSON map
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      email: json['email'] ?? '',
      profileImageUrl: json['profile_image_url'],
    );
  }

  // Convert Customer to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone_number': phoneNumber,
      'email': email,
      'profile_image_url': profileImageUrl,
    };
  }

  // Create a copy of Customer with some fields replaced
  Customer copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? profileImageUrl,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }

  // Create an empty Customer
  factory Customer.empty() {
    return Customer(
      id: '',
      name: '',
      phoneNumber: '',
      email: '',
      profileImageUrl: null,
    );
  }
}