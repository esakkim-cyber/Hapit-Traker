import 'package:flutter/foundation.dart';

enum TaskType {
  habit,
  duration,
  distance,
  checklist,
  wakeUp;

  String get displayName {
    switch (this) {
      case TaskType.habit:
        return 'Habit';
      case TaskType.duration:
        return 'Duration';
      case TaskType.distance:
        return 'Distance';
      case TaskType.checklist:
        return 'Checklist';
      case TaskType.wakeUp:
        return 'Wake Up';
    }
  }

  String get actionLabel {
    switch (this) {
      case TaskType.habit:
      case TaskType.wakeUp:
      case TaskType.checklist:
        return 'Done';
      case TaskType.duration:
      case TaskType.distance:
        return 'Start';
    }
  }

  static TaskType fromString(String value) {
    if (value.toLowerCase() == 'reminder') {
      return TaskType.habit;
    }
    return TaskType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () {
        debugPrint(
          '[TaskEnums] Unknown TaskType value: $value, falling back to default',
        );
        return TaskType.habit;
      },
    );
  }
}

enum FrequencyType {
  daily,
  specificDays;

  String get displayName {
    switch (this) {
      case FrequencyType.daily:
        return 'Daily';
      case FrequencyType.specificDays:
        return 'Specific Days';
    }
  }

  static FrequencyType fromString(String value) {
    return FrequencyType.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () {
        debugPrint(
          '[TaskEnums] Unknown FrequencyType value: $value, falling back to default',
        );
        return FrequencyType.daily;
      },
    );
  }
}

enum ActivityStatus {
  idle,
  running,
  paused,
  completed,
  cancelled;

  static ActivityStatus fromString(String value) {
    return ActivityStatus.values.firstWhere(
      (e) => e.name.toLowerCase() == value.toLowerCase(),
      orElse: () {
        debugPrint(
          '[TaskEnums] Unknown ActivityStatus value: $value, falling back to default',
        );
        return ActivityStatus.idle;
      },
    );
  }
}
