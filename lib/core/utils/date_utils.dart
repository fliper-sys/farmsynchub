import 'package:intl/intl.dart';

/// Utility functions for date formatting and manipulation.
abstract final class DateUtils {
  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');

  /// Formats a DateTime to "Mon DD, YYYY" format.
  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  /// Formats a DateTime to "HH:mm" format.
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }

  /// Formats a DateTime to "Mon DD, YYYY HH:mm" format.
  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }

  /// Gets the time of day greeting based on current hour.
  static String getTimeOfDayGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }

  /// Calculates the number of days between two dates.
  static int daysBetween(DateTime from, DateTime to) {
    return to.difference(from).inDays;
  }

  /// Checks if a date is today.
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  /// Checks if a date is yesterday.
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
           date.month == yesterday.month &&
           date.day == yesterday.day;
  }

  /// Gets the start of the current month.
  static DateTime getStartOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  /// Gets the end of the current month.
  static DateTime getEndOfMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 0);
  }
}