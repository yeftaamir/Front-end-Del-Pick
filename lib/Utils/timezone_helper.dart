import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

class TimezoneHelper {
  static const String wibTimezoneName = 'Asia/Jakarta';

  /// Get WIB location
  static tz.Location get wibLocation => tz.getLocation(wibTimezoneName);

  /// Get current WIB DateTime
  static tz.TZDateTime nowWIB() {
    return tz.TZDateTime.now(wibLocation);
  }

  /// Convert UTC DateTime to WIB
  static tz.TZDateTime utcToWIB(DateTime utcDateTime) {
    // Pastikan input adalah UTC
    final utcTZ = utcDateTime.isUtc
        ? tz.TZDateTime.from(utcDateTime, tz.UTC)
        : tz.TZDateTime.from(utcDateTime.toUtc(), tz.UTC);
    return tz.TZDateTime.from(utcTZ, wibLocation);
  }

  /// Convert WIB to UTC (for API calls)
  static tz.TZDateTime wibToUTC(tz.TZDateTime wibDateTime) {
    return tz.TZDateTime.from(wibDateTime, tz.UTC);
  }

  /// Parse ISO string to WIB DateTime
  static tz.TZDateTime parseToWIB(String isoString) {
    try {
      // Parse ISO string dan pastikan sebagai UTC
      final utcDateTime = DateTime.parse(isoString);
      final utcDateTimeCorrect =
          utcDateTime.isUtc ? utcDateTime : utcDateTime.toUtc();
      return utcToWIB(utcDateTimeCorrect);
    } catch (e) {
      print('Error parsing date string: $isoString - $e');
      // Fallback ke waktu sekarang jika parsing gagal
      return nowWIB();
    }
  }

  /// Parse nullable ISO string to WIB DateTime
  static tz.TZDateTime? parseToWIBNullable(String? isoString) {
    if (isoString == null || isoString.isEmpty) return null;
    try {
      return parseToWIB(isoString);
    } catch (e) {
      print('Error parsing nullable date string: $isoString - $e');
      return null;
    }
  }

  /// Format WIB DateTime to readable string
  static String formatWIB(tz.TZDateTime wibDateTime,
      {String pattern = 'dd MMM yyyy, HH:mm'}) {
    try {
      final formatter = DateFormat(pattern, 'id_ID');
      return formatter.format(wibDateTime);
    } catch (e) {
      print('Error formatting date: $e');
      return wibDateTime.toString();
    }
  }

  /// Format WIB DateTime untuk tampilan lengkap
  static String formatWIBFull(tz.TZDateTime wibDateTime) {
    try {
      final formatter = DateFormat('EEEE, dd MMMM yyyy - HH:mm', 'id_ID');
      return '${formatter.format(wibDateTime)} WIB';
    } catch (e) {
      print('Error formatting full date: $e');
      return '${wibDateTime.toString()} WIB';
    }
  }

  /// Format untuk waktu saja (HH:mm)
  static String formatTimeOnly(tz.TZDateTime wibDateTime) {
    try {
      final formatter = DateFormat('HH:mm', 'id_ID');
      return formatter.format(wibDateTime);
    } catch (e) {
      print('Error formatting time: $e');
      return wibDateTime.toString().split(' ')[1].substring(0, 5);
    }
  }

  /// Format untuk tanggal saja (dd MMM yyyy)
  static String formatDateOnly(tz.TZDateTime wibDateTime) {
    try {
      final formatter = DateFormat('dd MMM yyyy', 'id_ID');
      return formatter.format(wibDateTime);
    } catch (e) {
      print('Error formatting date only: $e');
      return wibDateTime.toString().split(' ')[0];
    }
  }

  /// Check if given time is today in WIB
  static bool isToday(tz.TZDateTime dateTime) {
    final now = nowWIB();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  /// Check if given time is yesterday in WIB
  static bool isYesterday(tz.TZDateTime dateTime) {
    final yesterday = nowWIB().subtract(const Duration(days: 1));
    return dateTime.year == yesterday.year &&
        dateTime.month == yesterday.month &&
        dateTime.day == yesterday.day;
  }

  /// Get time difference in minutes from now
  static int getMinutesFromNow(tz.TZDateTime dateTime) {
    final now = nowWIB();
    return dateTime.difference(now).inMinutes;
  }

  /// Get time difference in hours from now
  static int getHoursFromNow(tz.TZDateTime dateTime) {
    final now = nowWIB();
    return dateTime.difference(now).inHours;
  }

  /// Format relative time (e.g., "2 jam lalu", "dalam 30 menit")
  static String formatRelativeTime(tz.TZDateTime dateTime) {
    final now = nowWIB();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      // Past time
      final absDifference = difference.abs();
      if (absDifference.inDays > 7) {
        return formatDateOnly(dateTime);
      } else if (absDifference.inDays > 0) {
        return '${absDifference.inDays} hari lalu';
      } else if (absDifference.inHours > 0) {
        return '${absDifference.inHours} jam lalu';
      } else if (absDifference.inMinutes > 0) {
        return '${absDifference.inMinutes} menit lalu';
      } else {
        return 'Baru saja';
      }
    } else {
      // Future time
      if (difference.inDays > 7) {
        return formatDateOnly(dateTime);
      } else if (difference.inDays > 0) {
        return 'dalam ${difference.inDays} hari';
      } else if (difference.inHours > 0) {
        return 'dalam ${difference.inHours} jam';
      } else if (difference.inMinutes > 0) {
        return 'dalam ${difference.inMinutes} menit';
      } else {
        return 'Sekarang';
      }
    }
  }

  /// Convert TZDateTime to ISO string untuk API
  static String toISOString(tz.TZDateTime dateTime) {
    return dateTime.toUtc().toIso8601String();
  }

  /// Format untuk order status time display
  static String formatOrderTime(tz.TZDateTime? dateTime) {
    if (dateTime == null) return 'Belum tersedia';

    if (isToday(dateTime)) {
      return 'Hari ini, ${formatTimeOnly(dateTime)} WIB';
    } else if (isYesterday(dateTime)) {
      return 'Kemarin, ${formatTimeOnly(dateTime)} WIB';
    } else {
      return formatWIBFull(dateTime);
    }
  }

  /// Get duration between two times
  static String getDurationString(tz.TZDateTime start, tz.TZDateTime end) {
    final duration = end.difference(start);

    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      return minutes > 0 ? '${hours}j ${minutes}m' : '${hours}j';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
