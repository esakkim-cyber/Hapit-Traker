import 'package:intl/intl.dart';

import '../../models/completion_model.dart';
import '../../models/habit_model.dart';
import '../../repositories/habit_repository.dart';

class StreakService {
  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  /// Calculates the current streak for a given habit based on its completion history and schedule.
  /// - For Daily habits: Every day is required.
  /// - For Specific Days habits: Only scheduled weekdays are required; rest days do NOT break streak.
  int calculateCurrentStreak(
    HabitModel habit,
    List<CompletionModel> completions, {
    DateTime? asOfDate,
  }) {
    final referenceDate = asOfDate ?? DateTime.now();
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );
    final completionDates = completions
        .where((c) => c.habitId == habit.id && c.status == 'completed')
        .map((c) => c.date)
        .toSet();

    int streak = 0;
    DateTime checkDate = today;

    // Check if today is a scheduled day
    final bool isScheduledToday = habit.isScheduledForDate(checkDate);
    final bool isCompletedToday = completionDates.contains(
      formatDate(checkDate),
    );

    if (isScheduledToday && isCompletedToday) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else if (isScheduledToday && !isCompletedToday) {
      // Today is scheduled but not completed yet:
      // We look back to yesterday to see if the streak is still alive from previous days
      checkDate = checkDate.subtract(const Duration(days: 1));
    } else {
      // Today is a rest day: look back from yesterday
      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    // Now walk backwards day-by-day
    // Limit to 3650 days (10 years) max to prevent infinite loops
    int daysChecked = 0;
    while (daysChecked < 3650) {
      daysChecked++;
      final bool isScheduled = habit.isScheduledForDate(checkDate);

      if (isScheduled) {
        final dateStr = formatDate(checkDate);
        if (completionDates.contains(dateStr)) {
          streak++;
        } else {
          // A required scheduled day was missed -> streak ends
          break;
        }
      }
      // If it's not a scheduled day (rest day), streak is preserved and we continue looking back.

      // Stop if we have checked before habit creation date (minus 1 day for safety)
      final habitCreatedDay = DateTime(
        habit.createdAt.year,
        habit.createdAt.month,
        habit.createdAt.day,
      );
      if (checkDate.isBefore(habitCreatedDay)) {
        break;
      }

      checkDate = checkDate.subtract(const Duration(days: 1));
    }

    return streak;
  }

  /// Calculates the best streak ever achieved for this habit.
  int calculateBestStreak(HabitModel habit, List<CompletionModel> completions) {
    final completionDates = completions
        .where((c) => c.habitId == habit.id && c.status == 'completed')
        .map((c) => c.date)
        .toSet();

    if (completionDates.isEmpty) return 0;

    // Find earliest completion or habit creation date
    DateTime earliest = habit.createdAt;
    for (final dateStr in completionDates) {
      try {
        final parsed = DateFormat('yyyy-MM-dd').parse(dateStr);
        if (parsed.isBefore(earliest)) {
          earliest = parsed;
        }
      } catch (_) {}
    }

    final today = DateTime.now();
    DateTime current = DateTime(earliest.year, earliest.month, earliest.day);
    final end = DateTime(today.year, today.month, today.day);

    int maxStreak = 0;
    int currentRun = 0;

    while (!current.isAfter(end)) {
      final isScheduled = habit.isScheduledForDate(current);

      if (isScheduled) {
        final dateStr = formatDate(current);
        if (completionDates.contains(dateStr)) {
          currentRun++;
          if (currentRun > maxStreak) {
            maxStreak = currentRun;
          }
        } else {
          currentRun = 0;
        }
      }
      // Non-scheduled days do not reset currentRun

      current = current.add(const Duration(days: 1));
    }

    return maxStreak;
  }

  /// Recomputes and updates streak in database after any completion change
  Future<void> updateStreakAfterCompletion(
    HabitModel habit,
    List<CompletionModel> completions,
    HabitRepository repo,
  ) async {
    final current = calculateCurrentStreak(habit, completions);
    final best = calculateBestStreak(habit, completions);
    final finalBest = best;

    await repo.updateHabitStreaks(habit.id, current, finalBest);
  }

  /// Calculate daily progress fraction for today (e.g. 4/6 = 0.66)
  double calculateDailyProgress({
    required List<HabitModel> activeHabits,
    required List<CompletionModel> todayCompletions,
    required DateTime date,
  }) {
    final scheduledHabits = activeHabits
        .where((h) => h.isScheduledForDate(date))
        .toList();
    if (scheduledHabits.isEmpty) return 1.0;

    final completedHabitIds = todayCompletions
        .where((c) => c.status == 'completed')
        .map((c) => c.habitId)
        .toSet();

    int completedCount = 0;
    for (final h in scheduledHabits) {
      if (completedHabitIds.contains(h.id)) {
        completedCount++;
      }
    }

    return completedCount / scheduledHabits.length;
  }
}
