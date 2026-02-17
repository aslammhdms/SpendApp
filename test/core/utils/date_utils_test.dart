import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/utils/date_utils.dart';

void main() {
  group('AppDateUtils', () {
    group('startOfDay / endOfDay', () {
      test('startOfDay strips time components', () {
        final date = DateTime(2024, 6, 15, 14, 30, 45, 123);
        final result = AppDateUtils.startOfDay(date);
        expect(result, DateTime(2024, 6, 15));
        expect(result.hour, 0);
        expect(result.minute, 0);
        expect(result.second, 0);
      });

      test('endOfDay sets time to 23:59:59.999', () {
        final date = DateTime(2024, 6, 15, 8, 0);
        final result = AppDateUtils.endOfDay(date);
        expect(result, DateTime(2024, 6, 15, 23, 59, 59, 999));
      });

      test('startOfDay on already midnight is identity', () {
        final date = DateTime(2024, 1, 1);
        expect(AppDateUtils.startOfDay(date), date);
      });
    });

    group('startOfMonth / endOfMonth', () {
      test('startOfMonth returns first day', () {
        final date = DateTime(2024, 6, 15);
        expect(AppDateUtils.startOfMonth(date), DateTime(2024, 6, 1));
      });

      test('endOfMonth for January returns Jan 31', () {
        final date = DateTime(2024, 1, 10);
        final result = AppDateUtils.endOfMonth(date);
        expect(result.day, 31);
        expect(result.month, 1);
      });

      test('endOfMonth for February leap year returns Feb 29', () {
        final date = DateTime(2024, 2, 10); // 2024 is a leap year
        final result = AppDateUtils.endOfMonth(date);
        expect(result.day, 29);
        expect(result.month, 2);
      });

      test('endOfMonth for February non-leap year returns Feb 28', () {
        final date = DateTime(2025, 2, 10);
        final result = AppDateUtils.endOfMonth(date);
        expect(result.day, 28);
        expect(result.month, 2);
      });

      test('endOfMonth for December returns Dec 31', () {
        final date = DateTime(2024, 12, 5);
        final result = AppDateUtils.endOfMonth(date);
        expect(result.day, 31);
        expect(result.month, 12);
      });

      test('endOfMonth for April returns Apr 30', () {
        final date = DateTime(2024, 4, 1);
        final result = AppDateUtils.endOfMonth(date);
        expect(result.day, 30);
      });
    });

    group('startOfWeek / endOfWeek (Monday-based)', () {
      test('Monday returns itself as startOfWeek', () {
        // 2024-01-15 is a Monday
        final monday = DateTime(2024, 1, 15);
        expect(monday.weekday, DateTime.monday);
        expect(AppDateUtils.startOfWeek(monday), DateTime(2024, 1, 15));
      });

      test('Wednesday goes back to Monday', () {
        // 2024-01-17 is a Wednesday
        final wednesday = DateTime(2024, 1, 17);
        expect(AppDateUtils.startOfWeek(wednesday), DateTime(2024, 1, 15));
      });

      test('Sunday goes to previous Monday', () {
        // 2024-01-21 is a Sunday
        final sunday = DateTime(2024, 1, 21);
        expect(AppDateUtils.startOfWeek(sunday), DateTime(2024, 1, 15));
      });

      test('endOfWeek from Wednesday goes to Sunday', () {
        final wednesday = DateTime(2024, 1, 17);
        final result = AppDateUtils.endOfWeek(wednesday);
        expect(result.day, 21);
        expect(result.hour, 23);
        expect(result.minute, 59);
      });

      test('startOfWeek crosses month boundary', () {
        // 2024-02-01 is a Thursday; Monday is Jan 29
        final thursday = DateTime(2024, 2, 1);
        expect(AppDateUtils.startOfWeek(thursday), DateTime(2024, 1, 29));
      });
    });

    group('startOfYear / endOfYear', () {
      test('startOfYear returns Jan 1', () {
        final date = DateTime(2024, 7, 15);
        expect(AppDateUtils.startOfYear(date), DateTime(2024, 1, 1));
      });

      test('endOfYear returns Dec 31 23:59:59.999', () {
        final date = DateTime(2024, 3, 1);
        final result = AppDateUtils.endOfYear(date);
        expect(result, DateTime(2024, 12, 31, 23, 59, 59, 999));
      });
    });

    group('isSameDay / isSameMonth / isSameYear', () {
      test('isSameDay true for same date different times', () {
        final a = DateTime(2024, 6, 15, 10, 30);
        final b = DateTime(2024, 6, 15, 22, 45);
        expect(AppDateUtils.isSameDay(a, b), isTrue);
      });

      test('isSameDay false for different days', () {
        final a = DateTime(2024, 6, 15);
        final b = DateTime(2024, 6, 16);
        expect(AppDateUtils.isSameDay(a, b), isFalse);
      });

      test('isSameMonth true for same month', () {
        final a = DateTime(2024, 6, 1);
        final b = DateTime(2024, 6, 30);
        expect(AppDateUtils.isSameMonth(a, b), isTrue);
      });

      test('isSameMonth false for different months', () {
        final a = DateTime(2024, 6, 1);
        final b = DateTime(2024, 7, 1);
        expect(AppDateUtils.isSameMonth(a, b), isFalse);
      });

      test('isSameYear true for same year', () {
        final a = DateTime(2024, 1, 1);
        final b = DateTime(2024, 12, 31);
        expect(AppDateUtils.isSameYear(a, b), isTrue);
      });

      test('isSameYear false for different years', () {
        final a = DateTime(2024, 12, 31);
        final b = DateTime(2025, 1, 1);
        expect(AppDateUtils.isSameYear(a, b), isFalse);
      });
    });

    group('isToday / isYesterday / isThisMonth / isThisYear', () {
      test('isToday returns true for today', () {
        expect(AppDateUtils.isToday(DateTime.now()), isTrue);
      });

      test('isToday returns false for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(AppDateUtils.isToday(yesterday), isFalse);
      });

      test('isYesterday returns true for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(AppDateUtils.isYesterday(yesterday), isTrue);
      });

      test('isYesterday returns false for today', () {
        expect(AppDateUtils.isYesterday(DateTime.now()), isFalse);
      });

      test('isThisMonth returns true for current month', () {
        expect(AppDateUtils.isThisMonth(DateTime.now()), isTrue);
      });

      test('isThisYear returns true for current year', () {
        expect(AppDateUtils.isThisYear(DateTime.now()), isTrue);
      });
    });

    group('getRelativeDate', () {
      test('returns Today for today', () {
        expect(AppDateUtils.getRelativeDate(DateTime.now()), 'Today');
      });

      test('returns Yesterday for yesterday', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(AppDateUtils.getRelativeDate(yesterday), 'Yesterday');
      });

      test('returns Tomorrow for tomorrow', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(AppDateUtils.getRelativeDate(tomorrow), 'Tomorrow');
      });

      test('returns day name for 3 days ago', () {
        final threeDaysAgo = DateTime.now().subtract(const Duration(days: 3));
        final result = AppDateUtils.getRelativeDate(threeDaysAgo);
        // Should be a day name like Monday, Tuesday, etc.
        final dayNames = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        expect(dayNames, contains(result));
      });

      test('returns formatted date for 8+ days ago', () {
        final longAgo = DateTime.now().subtract(const Duration(days: 10));
        final result = AppDateUtils.getRelativeDate(longAgo);
        // Should NOT be a day name
        expect(result, isNot('Today'));
        expect(result, isNot('Yesterday'));
        expect(result, isNot('Tomorrow'));
      });
    });

    group('addMonths', () {
      test('normal case: Jan to Feb', () {
        final date = DateTime(2024, 1, 15);
        expect(AppDateUtils.addMonths(date, 1), DateTime(2024, 2, 15));
      });

      test('cross-year: Dec + 1 = Jan next year', () {
        final date = DateTime(2024, 12, 10);
        expect(AppDateUtils.addMonths(date, 1), DateTime(2025, 1, 10));
      });

      test('Jan 31 + 1 month = Feb 29 (leap year)', () {
        final date = DateTime(2024, 1, 31);
        expect(AppDateUtils.addMonths(date, 1), DateTime(2024, 2, 29));
      });

      test('Jan 31 + 1 month = Feb 28 (non-leap year)', () {
        final date = DateTime(2025, 1, 31);
        expect(AppDateUtils.addMonths(date, 1), DateTime(2025, 2, 28));
      });

      test('add multiple months', () {
        final date = DateTime(2024, 1, 15);
        expect(AppDateUtils.addMonths(date, 6), DateTime(2024, 7, 15));
      });

      test('add 12 months = next year same month', () {
        final date = DateTime(2024, 3, 20);
        expect(AppDateUtils.addMonths(date, 12), DateTime(2025, 3, 20));
      });

      test('preserves time components', () {
        final date = DateTime(2024, 1, 15, 10, 30, 45);
        final result = AppDateUtils.addMonths(date, 1);
        expect(result.hour, 10);
        expect(result.minute, 30);
        expect(result.second, 45);
      });
    });

    group('getDaysInMonth', () {
      test('February 2024 (leap year) = 29', () {
        expect(AppDateUtils.getDaysInMonth(2024, 2), 29);
      });

      test('February 2025 (non-leap) = 28', () {
        expect(AppDateUtils.getDaysInMonth(2025, 2), 28);
      });

      test('January = 31', () {
        expect(AppDateUtils.getDaysInMonth(2024, 1), 31);
      });

      test('April = 30', () {
        expect(AppDateUtils.getDaysInMonth(2024, 4), 30);
      });

      test('December = 31', () {
        expect(AppDateUtils.getDaysInMonth(2024, 12), 31);
      });
    });

    group('getLast7Days', () {
      test('returns exactly 7 dates', () {
        final days = AppDateUtils.getLast7Days();
        expect(days.length, 7);
      });

      test('last element is today', () {
        final days = AppDateUtils.getLast7Days();
        final today = DateTime.now();
        expect(AppDateUtils.isSameDay(days.last, today), isTrue);
      });

      test('dates are in ascending order', () {
        final days = AppDateUtils.getLast7Days();
        for (int i = 1; i < days.length; i++) {
          expect(days[i].isAfter(days[i - 1]), isTrue);
        }
      });
    });

    group('getLast30Days', () {
      test('returns exactly 30 dates', () {
        final days = AppDateUtils.getLast30Days();
        expect(days.length, 30);
      });

      test('last element is today', () {
        final days = AppDateUtils.getLast30Days();
        final today = DateTime.now();
        expect(AppDateUtils.isSameDay(days.last, today), isTrue);
      });
    });

    group('getMonthsOfYear', () {
      test('returns 12 entries', () {
        final months = AppDateUtils.getMonthsOfYear(2024);
        expect(months.length, 12);
      });

      test('first month is January', () {
        final months = AppDateUtils.getMonthsOfYear(2024);
        expect(months.first.month, 1);
        expect(months.first.year, 2024);
      });

      test('last month is December', () {
        final months = AppDateUtils.getMonthsOfYear(2024);
        expect(months.last.month, 12);
      });

      test('all dates are first of month', () {
        final months = AppDateUtils.getMonthsOfYear(2024);
        for (final m in months) {
          expect(m.day, 1);
        }
      });
    });

    group('formatDate / parseDate roundtrip', () {
      test('formats and parses correctly', () {
        final date = DateTime(2024, 6, 15);
        final formatted = AppDateUtils.formatDate(date);
        final parsed = AppDateUtils.parseDate(formatted);
        expect(AppDateUtils.isSameDay(parsed, date), isTrue);
      });
    });
  });
}
