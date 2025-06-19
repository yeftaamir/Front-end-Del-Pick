// lib/models/extensions/driver_extensions.dart
import 'package:permission_handler/permission_handler.dart';

import '../Entities/driver.dart';
import '../Enums/driver_status.dart';

extension DriverExtensions on Driver {
  String get statusDisplayName {
    switch (status) {
      case DriverStatus.active:
        return 'Available';
      case DriverStatus.inactive:
        return 'Offline';
      case DriverStatus.busy:
        return 'Busy';
    }
  }

  String get formattedRating {
    return rating.toStringAsFixed(1);
  }

  bool get isAvailable {
    return status == DriverStatus.active;
  }

  String get reviewsText {
    if (reviewsCount == 0) return 'No reviews';
    if (reviewsCount == 1) return '1 review';
    return '$reviewsCount reviews';
  }
}
