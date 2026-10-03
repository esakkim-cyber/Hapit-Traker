import 'package:flutter_test/flutter_test.dart';
import 'package:habit_forge/core/enums/task_enums.dart';
import 'package:habit_forge/models/activity_session_model.dart';
import 'package:habit_forge/models/habit_model.dart';
import 'package:habit_forge/models/user_profile_model.dart';

void main() {
  group('Data Model & Serialization Tests', () {
    test('HabitModel JSON serialization and deserialization', () {
      final habit = HabitModel(
        id: 'h_101',
        title: 'Run 5 km',
        description: 'Morning jog in the park',
        taskType: TaskType.distance,
        frequencyType: FrequencyType.specificDays,
        targetValue: 5.0,
        targetUnit: 'km',
        reminderTime: '06:30',
        colorValue: 0xFF10B981,
        iconName: 'directions_run',
        currentStreak: 4,
        bestStreak: 12,
        createdAt: DateTime(2026, 9, 1),
        scheduledWeekdays: [1, 3, 5],
        checklistItems: const [
          ChecklistItemModel(
            id: 'c1',
            habitId: 'h_101',
            title: 'Warmup stretches',
            isCompleted: true,
          ),
        ],
      );

      final json = habit.toJson();
      final fromJson = HabitModel.fromJson(json);

      expect(fromJson.id, equals('h_101'));
      expect(fromJson.title, equals('Run 5 km'));
      expect(fromJson.taskType, equals(TaskType.distance));
      expect(fromJson.targetValue, equals(5.0));
      expect(fromJson.scheduledWeekdays, equals([1, 3, 5]));
      expect(fromJson.checklistItems.length, equals(1));
      expect(fromJson.checklistItems.first.title, equals('Warmup stretches'));
    });

    test('UserProfileModel JSON serialization', () {
      final profile = UserProfileModel(
        id: 'user_1',
        name: 'Harijith',
        age: 24,
        wakeTime: '06:00',
        sleepTime: '22:30',
        focusAreas: const ['Fitness', 'Productivity'],
        onboardingCompleted: true,
        createdAt: DateTime(2026, 9, 29),
      );

      final json = profile.toJson();
      final fromJson = UserProfileModel.fromJson(json);

      expect(fromJson.name, equals('Harijith'));
      expect(fromJson.age, equals(24));
      expect(fromJson.focusAreas, contains('Fitness'));
      expect(fromJson.onboardingCompleted, isTrue);
    });

    test('ActivitySessionModel formatting & conversions', () {
      final session = ActivitySessionModel(
        id: 'sess_1',
        habitId: 'h_1',
        taskType: TaskType.distance,
        startTime: DateTime(2026, 9, 29, 7, 0),
        durationSeconds: 125, // 2 mins 5 secs
        distanceMeters: 2500, // 2.5 km
        averageSpeed: 12.0,
      );

      expect(session.distanceKm, equals(2.5));
      expect(session.formattedDuration, equals('02:05'));
    });
  });
}
