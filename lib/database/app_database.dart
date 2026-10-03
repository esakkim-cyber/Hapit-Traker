import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  UserProfiles,
  Habits,
  HabitSchedules,
  Completions,
  ActivitySessions,
  GpsPoints,
  Reminders,
  ChecklistItems,
  ExpenseCategories,
  Expenses,
])
class AppDatabase extends _$AppDatabase {
  static AppDatabase? _instance;

  factory AppDatabase() {
    return _instance ??= AppDatabase._internal();
  }

  AppDatabase._internal() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  // SEC-001: SQLite stored plaintext unencrypted on device file system. To encrypt, configure SQLCipher via sqlcipher_flutter_libs and drift encrypted: true. Would require 4 native dependencies + user sign-off on dependencies.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          for (var v = from; v < to; v++) {
            switch (v) {
              case 1:
                break;
              default:
                throw Exception('Unknown migration v$v');
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'habit_forge_db.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }

  // Clear all data (for testing or "Delete All Data" feature)
  Future<void> clearAllData() async {
    await transaction(() async {
      // Child tables with FK references first
      // Expenses (FK -> ExpenseCategories)
      await delete(expenses).go();
      // GpsPoints (FK -> ActivitySessions)
      await delete(gpsPoints).go();
      // ActivitySessions (FK -> Habits)
      await delete(activitySessions).go();
      // ChecklistItems (FK -> Habits)
      await delete(checklistItems).go();
      // Reminders (FK -> Habits)
      await delete(reminders).go();
      // Completions (FK -> Habits)
      await delete(completions).go();
      // HabitSchedules (FK -> Habits)
      await delete(habitSchedules).go();
      // Habits (independent parent table)
      await delete(habits).go();
      // ExpenseCategories (independent parent table)
      await delete(expenseCategories).go();
      // UserProfiles (root table, last)
      await delete(userProfiles).go();
    });
  }
}
