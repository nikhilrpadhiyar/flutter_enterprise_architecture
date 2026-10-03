import 'package:intl/intl.dart';

/// Formatting of dates and sizes for display.
abstract final class AppFormatters {
  static const int _kilobyte = 1024;
  static const int _megabyte = 1024 * 1024;

  /// A short calendar date such as "Oct 5, 2026", in local time.
  static String date(DateTime value) =>
      DateFormat.yMMMd().format(value.toLocal());

  /// A short date and time, in local time.
  static String dateTime(DateTime value) =>
      DateFormat.yMMMd().add_jm().format(value.toLocal());

  /// A file size such as "20 KB" or "1.5 MB".
  static String fileSize(int bytes) {
    if (bytes >= _megabyte) {
      return '${(bytes / _megabyte).toStringAsFixed(1)} MB';
    }
    if (bytes >= _kilobyte) return '${(bytes / _kilobyte).round()} KB';
    return '$bytes B';
  }
}
