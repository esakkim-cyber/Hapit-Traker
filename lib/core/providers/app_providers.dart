import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../database/app_database.dart';
import '../../models/activity_session_model.dart';
import '../../models/completion_model.dart';
import '../../models/expense_model.dart';
import '../../models/habit_model.dart';
import '../../models/user_profile_model.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/expense_repository.dart';
import '../../repositories/habit_repository.dart';
import '../../repositories/user_repository.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/streak_service.dart';

// Database Provider
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

// Repositories
final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HabitRepository(db);
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final habitRepo = ref.watch(habitRepositoryProvider);
  return UserRepository(db, habitRepo);
});

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ActivityRepository(db);
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = ExpenseRepository(db);
  Future.microtask(() => repo.seedDefaultCategoriesIfEmpty());
  return repo;
});

final expenseCategoriesStreamProvider =
    StreamProvider<List<ExpenseCategoryModel>>((ref) {
      final repo = ref.watch(expenseRepositoryProvider);
      return repo.watchAllCategories();
    });

// Services
final streakServiceProvider = Provider<StreakService>((ref) {
  return StreakService();
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

// Habits Stream
final habitsStreamProvider = StreamProvider<List<HabitModel>>((ref) {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.watchAllHabits();
});

// Today's date string YYYY-MM-DD — auto-refreshes at midnight
final todayDateStringProvider = StreamProvider<String>((ref) {
  final controller = StreamController<String>();
  Timer? timer;

  String currentDate() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  void emitDate() {
    final dateStr = currentDate();
    if (!controller.isClosed) {
      controller.add(dateStr);
    }
  }

  Duration durationUntilNextMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  void scheduleNextMidnight() {
    final delay = durationUntilNextMidnight();
    timer?.cancel();
    timer = Timer(delay, () {
      emitDate();
      schedulePeriodicCheck();
    });
  }

  void schedulePeriodicCheck() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      emitDate();
      final now = DateTime.now();
      if (now.hour == 0 && now.minute <= 1) {
        scheduleNextMidnight();
      }
    });
  }

  emitDate();
  scheduleNextMidnight();

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream.distinct();
});

// All Completions Stream (for Calendar, cross-tab reactivity)
final allCompletionsStreamProvider = StreamProvider<List<CompletionModel>>((
  ref,
) {
  final repo = ref.watch(habitRepositoryProvider);
  return repo.watchAllCompletions();
});

// Today's Completions Stream
final todayCompletionsStreamProvider = StreamProvider<List<CompletionModel>>((
  ref,
) {
  final repo = ref.watch(habitRepositoryProvider);
  final todayStr = ref
      .watch(todayDateStringProvider)
      .maybeWhen(
        data: (str) => str,
        orElse: () => DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
  return repo.watchCompletionsForDate(todayStr);
});

// Activity Sessions Stream
final activitySessionsStreamProvider =
    StreamProvider<List<ActivitySessionModel>>((ref) {
      final repo = ref.watch(activityRepositoryProvider);
      return repo.watchAllSessions();
    });

// User Profile Notifier / State
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfileModel?>> {
  final UserRepository _repo;

  UserProfileNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final profile = await _repo.getUserProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> saveProfile(UserProfileModel profile) async {
    await _repo.saveUserProfile(profile);
    state = AsyncValue.data(profile);
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfileModel?>>((
      ref,
    ) {
      final repo = ref.watch(userRepositoryProvider);
      return UserProfileNotifier(repo);
    });

// Theme Mode Notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final UserRepository _repo;

  ThemeModeNotifier(this._repo) : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _repo.getThemeMode();
    switch (mode) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    String modeStr = 'system';
    if (mode == ThemeMode.light) modeStr = 'light';
    if (mode == ThemeMode.dark) modeStr = 'dark';
    await _repo.setThemeMode(modeStr);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  final repo = ref.watch(userRepositoryProvider);
  return ThemeModeNotifier(repo);
});

final systemDefaultsEnsuredProvider = FutureProvider<void>((ref) async {
  final habitRepo = ref.watch(habitRepositoryProvider);
  await habitRepo.ensureSystemHabitsExist();
  final expenseRepo = ref.watch(expenseRepositoryProvider);
  await expenseRepo.seedDefaultCategoriesIfEmpty();
});
