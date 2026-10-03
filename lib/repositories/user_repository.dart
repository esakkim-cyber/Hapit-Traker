import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../models/user_profile_model.dart';
import 'activity_repository.dart';
import 'habit_repository.dart';

// SEC-008: Android AutoBackup (android:allowBackup=true default) backs up SP+SQLite unencrypted to Google Drive. To disable, set android:allowBackup=false in manifest; impacts Play Store restore UX - user sign-off required.
class UserRepository {
  final AppDatabase _db;
  final HabitRepository _habitRepo;
  static const String _onboardingKey = 'habit_forge_onboarding_completed';
  static const String _themeModeKey = 'habit_forge_theme_mode';

  UserRepository(this._db, this._habitRepo);

  Future<bool> isOnboardingCompleted() async {
    final profile = await getUserProfile();
    return profile?.onboardingCompleted ?? false;
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, completed);
  }

  Future<UserProfileModel?> getUserProfile() async {
    final row = await _db.select(_db.userProfiles).getSingleOrNull();
    if (row == null) return null;

    List<String> focusList = [];
    if (row.focusAreas != null && row.focusAreas!.isNotEmpty) {
      try {
        focusList = (jsonDecode(row.focusAreas!) as List<dynamic>)
            .map((e) => e.toString())
            .toList();
      } catch (_) {
        focusList = row.focusAreas!.split(',');
      }
    }

    return UserProfileModel(
      id: row.id,
      name: row.name,
      age: row.age,
      wakeTime: row.wakeTime,
      sleepTime: row.sleepTime,
      focusAreas: focusList,
      onboardingCompleted: row.onboardingCompleted,
      createdAt: row.createdAt,
    );
  }

  Future<void> saveUserProfile(UserProfileModel profile) async {
    final existing = await _db.select(_db.userProfiles).getSingleOrNull();
    final focusJson = jsonEncode(profile.focusAreas);

    if (existing == null) {
      await _db
          .into(_db.userProfiles)
          .insert(
            UserProfilesCompanion.insert(
              id: profile.id.isNotEmpty ? profile.id : const Uuid().v4(),
              name: profile.name,
              age: Value(profile.age),
              wakeTime: Value(profile.wakeTime),
              sleepTime: Value(profile.sleepTime),
              focusAreas: Value(focusJson),
              onboardingCompleted: Value(profile.onboardingCompleted),
              createdAt: Value(profile.createdAt),
            ),
          );
    } else {
      await (_db.update(
        _db.userProfiles,
      )..where((t) => t.id.equals(existing.id))).write(
        UserProfilesCompanion(
          name: Value(profile.name),
          age: Value(profile.age),
          wakeTime: Value(profile.wakeTime),
          sleepTime: Value(profile.sleepTime),
          focusAreas: Value(focusJson),
          onboardingCompleted: Value(profile.onboardingCompleted),
        ),
      );
    }
  }

  Future<String> getThemeMode() async {
    // SEC-004: SharedPreferences stores theme mode XML plaintext on Android. Use flutter_secure_storage for sensitive state; theme mode is UI-only so acceptable.
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeModeKey) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode);
  }

  // Export full user database as JSON string
  Future<String> exportAllDataAsJson() async {
    final profile = await getUserProfile();
    final habits = await _habitRepo.getAllHabits();
    final habitSchedulesRows = await _db.select(_db.habitSchedules).get();
    final completions = await _habitRepo.getAllCompletions();
    final checklistItemsRows = await _db.select(_db.checklistItems).get();
    final remindersRows = await _db.select(_db.reminders).get();

    final activityRepo = ActivityRepository(_db);
    final activitySessions = await activityRepo.getAllSessions();
    final gpsPointRows = await _db.select(_db.gpsPoints).get();
    final expenseCategoryRows = await _db.select(_db.expenseCategories).get();
    final expenseRows = await _db.select(_db.expenses).get();

    final habitScheduleToJson = (HabitSchedule s) => {
      'id': s.id,
      'habitId': s.habitId,
      'weekday': s.weekday,
    };
    final checklistItemToJson = (ChecklistItem c) => {
      'id': c.id,
      'habitId': c.habitId,
      'title': c.title,
      'isCompleted': c.isCompleted,
      'sortOrder': c.sortOrder,
    };
    final reminderToJson = (Reminder r) => {
      'id': r.id,
      'habitId': r.habitId,
      'time': r.time,
      'enabled': r.enabled,
      'message': r.message,
      'daysOfWeek': r.daysOfWeek,
    };
    final gpsPointToJson = (GpsPoint g) => {
      'id': g.id,
      'sessionId': g.sessionId,
      'latitude': g.latitude,
      'longitude': g.longitude,
      'altitude': g.altitude,
      'accuracy': g.accuracy,
      'speed': g.speed,
      'timestamp': g.timestamp.toIso8601String(),
    };
    final expenseCategoryToJson = (ExpenseCategory c) => {
      'id': c.id,
      'name': c.name,
      'iconIndex': c.iconIndex,
      'colorIndex': c.colorIndex,
      'isDefault': c.isDefault,
      'isIncome': c.isIncome,
    };
    final expenseToJson = (Expense e) => {
      'id': e.id,
      'categoryId': e.categoryId,
      'amount': e.amount,
      'description': e.description,
      'date': e.date,
      'createdAt': e.createdAt,
      'updatedAt': e.updatedAt,
    };

    final exportMap = {
      'app': 'HabitForge',
      'version': '1.0.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile?.toJson(),
      'habits': habits.map((h) => h.toJson()).toList(),
      'habitSchedules': habitSchedulesRows.map(habitScheduleToJson).toList(),
      'completions': completions.map((c) => c.toJson()).toList(),
      'checklistItems': checklistItemsRows.map(checklistItemToJson).toList(),
      'activitySessions': activitySessions.map((a) => a.toJson()).toList(),
      'gpsPoints': gpsPointRows.map(gpsPointToJson).toList(),
      'reminders': remindersRows.map(reminderToJson).toList(),
      'expenseCategories': expenseCategoryRows
          .map(expenseCategoryToJson)
          .toList(),
      'expenses': expenseRows.map(expenseToJson).toList(),
      '_note_reminders': 'This table reserved for v2; v1.0 rows empty',
    };

    return const JsonEncoder.withIndent('  ').convert(exportMap);
  }

  // Clear all data completely
  Future<void> deleteAllData() async {
    await _db.clearAllData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
