// lib/models/extensions/store_extensions.dart
import 'package:flutter/material.dart';

import '../Entities/store.dart';
import '../Enums/store_status.dart';

extension StoreExtensions on Store {
  bool get isOpen {
    if (status != StoreStatus.active) return false;
    if (openTime == null || closeTime == null) return true;

    final now = TimeOfDay.now();
    final open = TimeOfDay(
      hour: int.parse(openTime!.split(':')[0]),
      minute: int.parse(openTime!.split(':')[1]),
    );
    final close = TimeOfDay(
      hour: int.parse(closeTime!.split(':')[0]),
      minute: int.parse(closeTime!.split(':')[1]),
    );

    return _isTimeInRange(now, open, close);
  }

  bool _isTimeInRange(TimeOfDay current, TimeOfDay start, TimeOfDay end) {
    final currentMinutes = current.hour * 60 + current.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      // Same day (e.g., 9:00 - 17:00)
      return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
    } else {
      // Crosses midnight (e.g., 22:00 - 06:00)
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }
  }

  String get formattedDistance {
    if (distance == null) return '';

    if (distance! < 1) {
      return '${(distance! * 1000).toInt()} m';
    } else {
      return '${distance!.toStringAsFixed(1)} km';
    }
  }

  String get formattedRating {
    if (rating == null) return 'No rating';
    return rating!.toStringAsFixed(1);
  }

  String get statusDisplayName {
    switch (status) {
      case StoreStatus.active:
        return isOpen ? 'Open' : 'Closed';
      case StoreStatus.inactive:
        return 'Temporarily Closed';
      case StoreStatus.closed:
        return 'Permanently Closed';
    }
  }
}