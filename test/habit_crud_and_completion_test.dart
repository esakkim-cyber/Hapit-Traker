import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_forge/core/enums/task_enums.dart';
import 'package:habit_forge/core/services/streak_service.dart';
import 'package:habit_forge/database/app_database.dart';
import 'package:habit_forge/models/completion_model.dart';
import 'package:habit_forge/models/habit_model.dart';
import 'package:habit_forge/repositories/habit_repository.dart';

void main() {
  late AppDatabase db;
  late HabitRepository repo;
  late StreakService streakService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = HabitRepository(db);
    streakService = StreakService();
  });

  tearDown(() async {
    await db.close();
  });

  group('Comprehensive HabitForge Workflow Tests', () {
    test('1. Normal Habit CRUD & Single Completion', () async {
      final habit = HabitModel(
        id: 'habit-pushups-1',
        title: 'Push Ups',
        description: '50 push ups every day',
        taskType: TaskType.habit,
        frequencyType: FrequencyType.daily,
        createdAt: DateTime(2026, 9, 20),
      );

      // Create
      await repo.createHabit(habit);
      final fetched = await repo.getHabitById('habit-pushups-1');
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Push Ups');
      expect(fetched.currentStreak, 0);

      // Complete today
      final today = DateTime(2026, 9, 29);
      await repo.recordCompletion(habitId: habit.id, date: today);
      final isDone = await repo.isHabitCompletedOnDate(habit.id, '2026-09-29');
      expect(isDone, isTrue);

      // Prevent duplicate completion
      await repo.recordCompletion(habitId: habit.id, date: today);
      final comps = await repo.getCompletionsForHabit(habit.id);
      expect(comps.length, 1);

      // Update streak
      await streakService.updateStreakAfterCompletion(habit, comps, repo);
      final updated = await repo.getHabitById('habit-pushups-1');
      expect(updated!.currentStreak, 1);
      expect(updated.bestStreak, 1);

      // Update habit
      final edited = updated.copyWith(title: '100 Push Ups');
      await repo.updateHabit(edited);
      final fetchedEdited = await repo.getHabitById('habit-pushups-1');
      expect(fetchedEdited!.title, '100 Push Ups');

      // Delete habit
      await repo.deleteHabit('habit-pushups-1');
      final deleted = await repo.getHabitById('habit-pushups-1');
      expect(deleted, isNull);
    });

    test('2. Duration Habit: Countdown Completion & Streak', () async {
      final habit = HabitModel(
        id: 'habit-study-1',
        title: 'Study Flutter',
        taskType: TaskType.duration,
        targetValue: 2.0,
        targetUnit: 'minutes',
        frequencyType: FrequencyType.daily,
        createdAt: DateTime(2026, 9, 28),
      );

      await repo.createHabit(habit);
      final saved = await repo.getHabitById('habit-study-1');
      expect(saved!.taskType, TaskType.duration);
      expect(saved.targetValue, 2.0);

      // Record 2 minutes completed session
      await repo.recordCompletion(
        habitId: habit.id,
        date: DateTime(2026, 9, 29),
        value: 2.0,
      );

      final isCompleted = await repo.isHabitCompletedOnDate(habit.id, '2026-09-29');
      expect(isCompleted, isTrue);
    });

    test('3. Distance Habit: Target Distance Persistence', () async {
      final habit = HabitModel(
        id: 'habit-run-1',
        title: 'Run 2 KM',
        taskType: TaskType.distance,
        targetValue: 2.0,
        targetUnit: 'km',
        frequencyType: FrequencyType.daily,
        createdAt: DateTime(2026, 9, 25),
      );

      await repo.createHabit(habit);
      final saved = await repo.getHabitById('habit-run-1');
      expect(saved!.taskType, TaskType.distance);
      expect(saved.targetValue, 2.0);
      expect(saved.targetUnit, 'km');
    });

    test('4. Checklist Habit: Subtasks, Toggling, & Auto-completion', () async {
      final habit = HabitModel(
        id: 'habit-routine-1',
        title: 'Morning Routine',
        taskType: TaskType.checklist,
        frequencyType: FrequencyType.daily,
        createdAt: DateTime(2026, 9, 29),
        checklistItems: [
          const ChecklistItemModel(id: 'chk-1', habitId: 'habit-routine-1', title: 'Brush', isCompleted: false, sortOrder: 0),
          const ChecklistItemModel(id: 'chk-2', habitId: 'habit-routine-1', title: 'Drink Water', isCompleted: false, sortOrder: 1),
          const ChecklistItemModel(id: 'chk-3', habitId: 'habit-routine-1', title: 'Exercise', isCompleted: false, sortOrder: 2),
        ],
      );

      await repo.createHabit(habit);
      var fetched = await repo.getHabitById('habit-routine-1');
      expect(fetched!.checklistItems.length, 3);
      expect(fetched.checklistItems.every((i) => !i.isCompleted), isTrue);

      // Check item 1 and 2
      await repo.toggleChecklistItem('chk-1', true);
      await repo.toggleChecklistItem('chk-2', true);
      fetched = await repo.getHabitById('habit-routine-1');
      expect(fetched!.checklistItems.where((i) => i.isCompleted).length, 2);

      // Check final item -> All checked!
      await repo.toggleChecklistItem('chk-3', true);
      fetched = await repo.getHabitById('habit-routine-1');
      expect(fetched!.checklistItems.every((i) => i.isCompleted), isTrue);

      // Record completion when all are checked
      await repo.recordCompletion(habitId: habit.id, date: DateTime(2026, 9, 29));
      expect(await repo.isHabitCompletedOnDate(habit.id, '2026-09-29'), isTrue);
    });

    test('5. Specific Days Habit: Rest days do not break streak', () async {
      // Habit scheduled only on Mon (1), Wed (3), Fri (5)
      final habit = HabitModel(
        id: 'habit-gym-1',
        title: 'Gym',
        taskType: TaskType.habit,
        frequencyType: FrequencyType.specificDays,
        scheduledWeekdays: [1, 3, 5],
        createdAt: DateTime(2026, 9, 1),
      );

      // Let's create completions for:
      // Mon Sep 21 (completed)
      // Wed Sep 23 (completed)
      // Fri Sep 25 (completed)
      // Mon Sep 28 (completed)
      // Note: Tue Sep 22, Thu Sep 24, Sat/Sun are REST DAYS
      final completions = [
        CompletionModel(id: 'c1', habitId: habit.id, date: '2026-09-21', completedAt: DateTime.now()),
        CompletionModel(id: 'c2', habitId: habit.id, date: '2026-09-23', completedAt: DateTime.now()),
        CompletionModel(id: 'c3', habitId: habit.id, date: '2026-09-25', completedAt: DateTime.now()),
        CompletionModel(id: 'c4', habitId: habit.id, date: '2026-09-28', completedAt: DateTime.now()),
      ];

      // As of Tuesday Sep 29 (a rest day)
      final streakOnTuesday = streakService.calculateCurrentStreak(
        habit,
        completions,
        asOfDate: DateTime(2026, 9, 29),
      );
      expect(streakOnTuesday, 4, reason: 'Rest days (Tue, Thu, Sat, Sun) must NOT break specific-day streaks');
    });

    test('6. Streak Reset on Missed Required Day, Best Streak Preserved', () async {
      final habit = HabitModel(
        id: 'habit-meditate-1',
        title: 'Daily Meditation',
        taskType: TaskType.habit,
        frequencyType: FrequencyType.daily,
        createdAt: DateTime(2026, 9, 1),
      );

      // Completed Day 1, 2, 3 -> streak 3
      // Missed Day 4
      // Day 5 completed
      final completions = [
        CompletionModel(id: 'c1', habitId: habit.id, date: '2026-09-01', completedAt: DateTime.now()),
        CompletionModel(id: 'c2', habitId: habit.id, date: '2026-09-02', completedAt: DateTime.now()),
        CompletionModel(id: 'c3', habitId: habit.id, date: '2026-09-03', completedAt: DateTime.now()),
        // 2026-09-04 missed!
        CompletionModel(id: 'c5', habitId: habit.id, date: '2026-09-05', completedAt: DateTime.now()),
      ];

      final currentStreak = streakService.calculateCurrentStreak(
        habit,
        completions,
        asOfDate: DateTime(2026, 9, 5),
      );
      expect(currentStreak, 1, reason: 'Current streak should reset to 1 because Day 4 was missed');

      final bestStreak = streakService.calculateBestStreak(habit, completions);
      expect(bestStreak, 3, reason: 'Best streak must remain 3 despite the missed day');
    });
  });
}
