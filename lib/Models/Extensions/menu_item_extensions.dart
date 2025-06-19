// lib/models/extensions/menu_item_extensions.dart
import 'package:flutter/material.dart';

import '../Entities/menu_item.dart';
import '../Entities/user.dart';
import '../Enums/user_role.dart';

extension MenuItemExtensions on MenuItem {
  String get formattedPrice {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
  }

  bool get isAvailableForOrder {
    return isAvailable;
  }
}

// lib/models/extensions/user_extensions.dart
extension UserExtensions on User {
  String get displayName {
    return name.isNotEmpty ? name : email.split('@').first;
  }

  String get roleDisplayName {
    switch (role) {
      case UserRole.admin:
        return 'Administrator';
      case UserRole.customer:
        return 'Customer';
      case UserRole.store:
        return 'Store Owner';
      case UserRole.driver:
        return 'Driver';
    }
  }

  bool get isCustomer => role == UserRole.customer;
  bool get isDriver => role == UserRole.driver;
  bool get isStoreOwner => role == UserRole.store;
  bool get isAdmin => role == UserRole.admin;
}
