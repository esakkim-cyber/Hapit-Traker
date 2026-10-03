import 'package:flutter_test/flutter_test.dart';
import 'package:habit_forge/core/enums/task_enums.dart';
import 'package:habit_forge/core/services/streak_service.dart';
import 'package:habit_forge/models/completion_model.dart';
import 'package:habit_forge/models/habit_model.dart';

void main() {
  group('StreakService Tests', () {
    late StreakService streakService;

    setUp(() {
      streakService = StreakService();
    });

    test('Daily Habit: Consecutive completed days increment current streak', () {
      final habit = HabitModel(
        id: 'habit_1',
        title: 'Drink Water',
        taskType: TaskType.habit,
        frequencyType: FrequencyType.daily,
        createdAt: DateTime(2026, 9, 20),
      );

      final completions = [
        CompletionModel(
          id: '1',
          habitId: 'habit_1',
          date: '2026-09-27',
          completedAt: DateTime(2026, 9, 27, 10, 0),
        ),
        CompletionModel(
          id: '2',
          habitId: 'habit_1',
          date: '2026-09-28',
          completedAt: DateTime(2026, 9, 28, 10, 0),
        ),
        CompletionModel(
          id: '3',
          habitId: 'habit_1',
          date: '2026-09-29',
          completedAt: DateTime(2026, 9, 29, 10, 0),
        ),
      ];

      final currentStreak = streakService.calculateCurrentStreak(
        habit,
        completions,
        asOfDate: DateTime(2026, 9, 29),
      );

      expect(currentStreak, equals(3));
    });

    test('Daily Habit: Missed required day breaks current streak but preserves best streak', () {
      final habit = HabitModel(
        id: 'habit_1',
        title: 'Read Book',
        taskType: TaskType.habit,
        frequencyType: FrequencyType.daily,
        bestStreak: 5,
        createdAt: DateTime(2026, 9, 1),
      );

      // Completed Sept 20, 21, 22. Missed Sept 23, 24.
      final completions = [
        CompletionModel(
          id: '1',
          habitId: 'habit_1',
          date: '2026-09-20',
          completedAt: DateTime(2026, 9, 20),
        ),
        CompletionModel(
          id: '2',
          habitId: 'habit_1',
          date: '2026-09-21',
          completedAt: DateTime(2026, 9, 21),
        ),
        CompletionModel(
          id: '3',
          habitId: 'habit_1',
          date: '2026-09-22',
          completedAt: DateTime(2026, 9, 22),
        ),
      ];

      final currentStreak = streakService.calculateCurrentStreak(
        habit,
        completions,
        asOfDate: DateTime(2026, 9, 25),
      );

      final bestStreak = streakService.calculateBestStreak(habit, completions);

      expect(currentStreak, equals(0));
      expect(bestStreak, equals(5)); // Preserves best streak
    });

    test('Specific Days Habit: Mon, Wed, Fri habit - rest days (Tue, Thu) do NOT break streak', () {
      final habit = HabitModel(
        id: 'habit_gym',
        title: 'Gym Workout',
        taskType: TaskType.habit,
        frequencyType: FrequencyType.specificDays,
        scheduledWeekdays: [1, 3, 5], // Mon=1, Wed=3, Fri=5
        createdAt: DateTime(2026, 9, 20),
      );

      // Sept 21 (Mon) - completed
      // Sept 22 (Tue) - Rest Day
      // Sept 23 (Wed) - completed
      // Sept 24 (Thu) - Rest Day
      // Sept 25 (Fri) - completed
      final completions = [
        CompletionModel(
          id: '1',
          habitId: 'habit_gym',
          date: '2026-09-21',
          completedAt: DateTime(2026, 9, 21),
        ),
        CompletionModel(
          id: '2',
          habitId: 'habit_gym',
          date: '2026-09-23',
          completedAt: DateTime(2026, 9, 23),
        ),
        CompletionModel(
          id: '3',
          habitId: 'habit_gym',
          date: '2026-09-25',
          completedAt: DateTime(2026, 9, 25),
        ),
      ];

      final currentStreak = streakService.calculateCurrentStreak(
        habit,
        completions,
        asOfDate: DateTime(2026, 9, 25),
      );

      expect(currentStreak, equals(3));
    });

    test('Daily Progress Calculation', () {
      final habit1 = HabitModel(
        id: 'h1',
        title: 'Water',
        taskType: TaskType.habit,
        frequencyType: FrequencyType.daily,
        createdAt: DateTime(2026, 9, 1),
      );
      final habit2 = HabitModel(
        id: 'h2',
        title: 'Reading',
        taskType: TaskType.habit,
        frequencyType: FrequencyType.daily,
        createdAt: DateTime(2026, 9, 1),
      );

      final todayCompletions = [
        CompletionModel(
          id: 'c1',
          habitId: 'h1',
          date: '2026-09-29',
          completedAt: DateTime.now(),
        ),
      ];

      final progress = streakService.calculateDailyProgress(
        activeHabits: [habit1, habit2],
        todayCompletions: todayCompletions,
        date: DateTime(2026, 9, 29),
      );

      expect(progress, equals(0.5)); // 1 of 2 completed
    });
  });
}
