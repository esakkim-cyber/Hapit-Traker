import 'package:drift/drift.dart';

// User Profiles Table
class UserProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get age => integer().nullable()();
  TextColumn get wakeTime => text().nullable()();
  TextColumn get sleepTime => text().nullable()();
  TextColumn get focusAreas => text().nullable()();
  BoolColumn get onboardingCompleted =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// Habits Table
class Habits extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get taskType => text()(); // TaskType enum string
  TextColumn get frequencyType => text()(); // FrequencyType enum string
  RealColumn get targetValue => real().nullable()();
  TextColumn get targetUnit => text().nullable()();
  TextColumn get reminderTime => text().nullable()();
  TextColumn get wakeTime => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF6366F1))();
  TextColumn get iconName => text().withDefault(const Constant('star'))();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get bestStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// Habit Schedules Table (e.g., Monday = 1, Sunday = 7)
// FK habitId -> habits.id enforced at app level via habit_repository.deleteHabit cascade
class HabitSchedules extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  IntColumn get weekday => integer()(); // 1 = Monday, ..., 7 = Sunday

  @override
  Set<Column> get primaryKey => {id};
}

// Completions Table
class Completions extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  TextColumn get date => text()(); // YYYY-MM-DD
  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();
  RealColumn get value => real().nullable()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Activity Sessions Table (for GPS runs and Duration timers)
class ActivitySessions extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  TextColumn get taskType => text()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  RealColumn get distanceMeters => real().withDefault(const Constant(0.0))();
  RealColumn get averageSpeed => real().withDefault(const Constant(0.0))();
  RealColumn get maxSpeed => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('running'))();

  @override
  Set<Column> get primaryKey => {id};
}

// GPS Points Table (persisted route coordinates)
class GpsPoints extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  RealColumn get altitude => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  RealColumn get speed => real().nullable()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// Reminders Table
// Reserved for v2 local in-app reminder rows; v1.0 NotificationService talks to OS directly, this table is unused in v1.0
class Reminders extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  TextColumn get time => text()(); // HH:mm
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get message => text().nullable()();
  TextColumn get daysOfWeek =>
      text().nullable()(); // comma-separated ints "1,2,3"

  @override
  Set<Column> get primaryKey => {id};
}

// Checklist Items Table
class ChecklistItems extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// Expense Categories Table
class ExpenseCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get iconIndex => integer().withDefault(const Constant(0))();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

// Expenses Table
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  RealColumn get amount => real()();
  TextColumn get description => text().nullable()();
  TextColumn get date => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}
