import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _dateFormat = DateFormat(AppConstants.dateFormat);
  static final DateFormat _dateTimeFormat = DateFormat(AppConstants.dateTimeFormat);
  static final DateFormat _displayDateFormat = DateFormat(AppConstants.displayDateFormat);
  static final DateFormat _displayTimeFormat = DateFormat(AppConstants.displayTimeFormat);
  static final DateFormat _monthYearFormat = DateFormat(AppConstants.monthYearFormat);

  static String formatDate(DateTime date) => _dateFormat.format(date);

  static String formatDateTime(DateTime dateTime) => _dateTimeFormat.format(dateTime);

  static String formatDisplayDate(DateTime date) => _displayDateFormat.format(date);

  static String formatDisplayTime(DateTime time) => _displayTimeFormat.format(time);

  static String formatMonthYear(DateTime date) => _monthYearFormat.format(date);

  /// "15 Nov", with the year added when it is not this year.
  static String formatDayMonth(DateTime date) => DateFormat(
          date.year == DateTime.now().year ? 'd MMM' : 'd MMM y')
      .format(date);

  static DateTime parseDate(String dateStr) => _dateFormat.parse(dateStr);

  static DateTime parseDateTime(String dateTimeStr) => _dateTimeFormat.parse(dateTimeStr);

  static String getRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final difference = today.difference(targetDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference == -1) {
      return 'Tomorrow';
    } else if (difference > 0 && difference < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return formatDisplayDate(date);
    }
  }

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  static DateTime startOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  static DateTime endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0, 23, 59, 59, 999);
  }

  static DateTime startOfYear(DateTime date) {
    return DateTime(date.year, 1, 1);
  }

  static DateTime endOfYear(DateTime date) {
    return DateTime(date.year, 12, 31, 23, 59, 59, 999);
  }

  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }

  static DateTime endOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day + (7 - weekday), 23, 59, 59, 999);
  }

  static List<DateTime> getLast7Days() {
    final today = DateTime.now();
    return List.generate(7, (i) {
      return DateTime(today.year, today.month, today.day - (6 - i));
    });
  }

  static List<DateTime> getLast30Days() {
    final today = DateTime.now();
    return List.generate(30, (i) {
      return DateTime(today.year, today.month, today.day - (29 - i));
    });
  }

  static List<DateTime> getMonthsOfYear(int year) {
    return List.generate(12, (i) => DateTime(year, i + 1, 1));
  }

  static int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  static bool isSameYear(DateTime a, DateTime b) {
    return a.year == b.year;
  }

  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(date, yesterday);
  }

  static bool isThisMonth(DateTime date) {
    return isSameMonth(date, DateTime.now());
  }

  static bool isThisYear(DateTime date) {
    return isSameYear(date, DateTime.now());
  }

  static DateTime addMonths(DateTime date, int months) {
    final newMonth = date.month + months;
    final yearsToAdd = (newMonth - 1) ~/ 12;
    final month = ((newMonth - 1) % 12) + 1;
    final year = date.year + yearsToAdd;
    final daysInMonth = getDaysInMonth(year, month);
    final day = date.day > daysInMonth ? daysInMonth : date.day;
    return DateTime(year, month, day, date.hour, date.minute, date.second);
  }
}
