class DateUtilsHelper {
  /// Returns the start of the week for the given date.
  /// defaults to Monday as the start of the week.
  static DateTime getStartOfWeek(
    DateTime date, {
    int startDay = DateTime.sunday,
  }) {
    // Force Sunday start logic if startDay is Sunday (defacto standard now)
    if (startDay == DateTime.sunday) {
      // weekday is 1(Mon)...7(Sun).
      // 7 % 7 = 0 (Sunday -> 0 days ago)
      // 1 % 7 = 1 (Monday -> 1 day ago)
      int daysToSubtract = date.weekday % 7;
      final start = date.subtract(Duration(days: daysToSubtract));
      return DateTime(start.year, start.month, start.day);
    }

    // Fallback for other start days if ever needed (legacy logic)
    int diff = date.weekday - startDay;
    if (diff < 0) diff += 7;
    final start = date.subtract(Duration(days: diff));
    return DateTime(start.year, start.month, start.day);
  }

  /// Returns the end of the week for the given date.
  /// Returns the end of the week for the given date.
  /// Returns the end of the week for the given date.
  static DateTime getEndOfWeek(
    DateTime date, {
    int startDay = DateTime.sunday,
  }) {
    final start = getStartOfWeek(date, startDay: startDay);
    return start.add(const Duration(days: 6));
  }

  /// Returns the week number of the year based on a Sunday-start week.
  /// Week 1 is always Jan 1st - First Saturday.
  /// Week 2 starts on the first Sunday of the year.
  static int getWeekOfYear(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);

    // Find the first Sunday of the year
    int daysUntilSunday = DateTime.sunday - startOfYear.weekday;
    if (daysUntilSunday < 0) daysUntilSunday += 7;

    // Note: If Jan 1 IS Sunday, then daysUntilSunday is 0.
    // If Jan 1 is Sunday, Week 1 is valid (it's a full week starting Sunday).
    // The user requirement says "Jan 1 - Jan 3: Week 1 (Partial)" assuming Jan 1 is not Sunday?
    // User Example: Jan 1 (Thu) - Jan 3 (Sat) = Week 1. Jan 4 (Sun) = Week 2.
    // Logic:
    // If date is before the first Sunday, it's Week 1.
    // Otherwise, calculate weeks passed since first Sunday.

    final firstSunday = startOfYear.add(Duration(days: daysUntilSunday));

    // If the date is before the first Sunday, it's Week 1.
    if (date.isBefore(firstSunday)) {
      return 1;
    }

    // Calculate days since the first Sunday
    final difference = date.difference(firstSunday).inDays;

    // Week 2 starts on firstSunday (difference = 0 -> 0/7 = 0 -> 2 + 0 = 2)
    return 2 + (difference / 7).floor();
  }
}
