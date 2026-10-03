import '../core/enums/task_enums.dart';

class HabitModel {
  final String id;
  final String title;
  final String? description;
  final TaskType taskType;
  final FrequencyType frequencyType;
  final double? targetValue;
  final String? targetUnit;
  final String? reminderTime;
  final String? wakeTime;
  final bool isActive;
  final int colorValue;
  final String iconName;
  final int currentStreak;
  final int bestStreak;
  final DateTime createdAt;
  final List<int> scheduledWeekdays; // 1 = Monday, 7 = Sunday
  final List<ChecklistItemModel> checklistItems;

  const HabitModel({
    required this.id,
    required this.title,
    this.description,
    required this.taskType,
    required this.frequencyType,
    this.targetValue,
    this.targetUnit,
    this.reminderTime,
    this.wakeTime,
    this.isActive = true,
    this.colorValue = 0xFF6366F1,
    this.iconName = 'star',
    this.currentStreak = 0,
    this.bestStreak = 0,
    required this.createdAt,
    this.scheduledWeekdays = const [],
    this.checklistItems = const [],
  });

  bool isScheduledForWeekday(int weekday) {
    if (frequencyType == FrequencyType.daily) return true;
    return scheduledWeekdays.contains(weekday);
  }

  bool isScheduledForDate(DateTime date) {
    return isScheduledForWeekday(date.weekday);
  }

  bool get reminderEnabled => reminderTime != null && reminderTime!.isNotEmpty;

  HabitModel copyWith({
    String? id,
    String? title,
    String? description,
    TaskType? taskType,
    FrequencyType? frequencyType,
    double? targetValue,
    String? targetUnit,
    String? reminderTime,
    String? wakeTime,
    bool? isActive,
    int? colorValue,
    String? iconName,
    int? currentStreak,
    int? bestStreak,
    DateTime? createdAt,
    List<int>? scheduledWeekdays,
    List<ChecklistItemModel>? checklistItems,
  }) {
    return HabitModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      taskType: taskType ?? this.taskType,
      frequencyType: frequencyType ?? this.frequencyType,
      targetValue: targetValue ?? this.targetValue,
      targetUnit: targetUnit ?? this.targetUnit,
      reminderTime: reminderTime ?? this.reminderTime,
      wakeTime: wakeTime ?? this.wakeTime,
      isActive: isActive ?? this.isActive,
      colorValue: colorValue ?? this.colorValue,
      iconName: iconName ?? this.iconName,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      createdAt: createdAt ?? this.createdAt,
      scheduledWeekdays: scheduledWeekdays ?? this.scheduledWeekdays,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'taskType': taskType.name,
      'frequencyType': frequencyType.name,
      'targetValue': targetValue,
      'targetUnit': targetUnit,
      'reminderTime': reminderTime,
      'wakeTime': wakeTime,
      'isActive': isActive,
      'colorValue': colorValue,
      'iconName': iconName,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
      'createdAt': createdAt.toIso8601String(),
      'scheduledWeekdays': scheduledWeekdays,
      'checklistItems': checklistItems.map((e) => e.toJson()).toList(),
    };
  }

  factory HabitModel.fromJson(Map<String, dynamic> json) {
    return HabitModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      taskType: TaskType.fromString(json['taskType'] as String? ?? 'habit'),
      frequencyType: FrequencyType.fromString(json['frequencyType'] as String? ?? 'daily'),
      targetValue: (json['targetValue'] as num?)?.toDouble(),
      targetUnit: json['targetUnit'] as String?,
      reminderTime: json['reminderTime'] as String?,
      wakeTime: json['wakeTime'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      colorValue: json['colorValue'] as int? ?? 0xFF6366F1,
      iconName: json['iconName'] as String? ?? 'star',
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      scheduledWeekdays: (json['scheduledWeekdays'] as List<dynamic>?)?.map((e) => e as int).toList() ?? const [],
      checklistItems: (json['checklistItems'] as List<dynamic>?)
              ?.map((e) => ChecklistItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

class ChecklistItemModel {
  final String id;
  final String habitId;
  final String title;
  final bool isCompleted;
  final int sortOrder;

  const ChecklistItemModel({
    required this.id,
    required this.habitId,
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
  });

  ChecklistItemModel copyWith({
    String? id,
    String? habitId,
    String? title,
    bool? isCompleted,
    int? sortOrder,
  }) {
    return ChecklistItemModel(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habitId': habitId,
      'title': title,
      'isCompleted': isCompleted,
      'sortOrder': sortOrder,
    };
  }

  factory ChecklistItemModel.fromJson(Map<String, dynamic> json) {
    return ChecklistItemModel(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      title: json['title'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }
}
