class UserProfileModel {
  final String id;
  final String name;
  final int? age;
  final String? wakeTime;
  final String? sleepTime;
  final List<String> focusAreas;
  final bool onboardingCompleted;
  final DateTime createdAt;

  const UserProfileModel({
    required this.id,
    required this.name,
    this.age,
    this.wakeTime,
    this.sleepTime,
    this.focusAreas = const [],
    this.onboardingCompleted = false,
    required this.createdAt,
  });

  UserProfileModel copyWith({
    String? id,
    String? name,
    int? age,
    String? wakeTime,
    String? sleepTime,
    List<String>? focusAreas,
    bool? onboardingCompleted,
    DateTime? createdAt,
  }) {
    return UserProfileModel(
      id: id ?? this.id,
      name: name ?? this.name,
      age: age ?? this.age,
      wakeTime: wakeTime ?? this.wakeTime,
      sleepTime: sleepTime ?? this.sleepTime,
      focusAreas: focusAreas ?? this.focusAreas,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'wakeTime': wakeTime,
      'sleepTime': sleepTime,
      'focusAreas': focusAreas,
      'onboardingCompleted': onboardingCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int?,
      wakeTime: json['wakeTime'] as String?,
      sleepTime: json['sleepTime'] as String?,
      focusAreas: (json['focusAreas'] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
      onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
