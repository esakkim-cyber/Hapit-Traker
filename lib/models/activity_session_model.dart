import '../core/enums/task_enums.dart';

class ActivitySessionModel {
  final String id;
  final String habitId;
  final TaskType taskType;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final double distanceMeters;
  final double averageSpeed; // km/h
  final double maxSpeed; // km/h
  final ActivityStatus status;

  const ActivitySessionModel({
    required this.id,
    required this.habitId,
    required this.taskType,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.distanceMeters = 0.0,
    this.averageSpeed = 0.0,
    this.maxSpeed = 0.0,
    this.status = ActivityStatus.running,
  });

  double get distanceKm => distanceMeters / 1000.0;

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    final h = m ~/ 60;
    if (h > 0) {
      final remM = m % 60;
      return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habitId': habitId,
      'taskType': taskType.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'durationSeconds': durationSeconds,
      'distanceMeters': distanceMeters,
      'averageSpeed': averageSpeed,
      'maxSpeed': maxSpeed,
      'status': status.name,
    };
  }

  factory ActivitySessionModel.fromJson(Map<String, dynamic> json) {
    return ActivitySessionModel(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      taskType: TaskType.fromString(json['taskType'] as String? ?? 'distance'),
      startTime: DateTime.tryParse(json['startTime'] as String? ?? '') ?? DateTime.now(),
      endTime: json['endTime'] != null ? DateTime.tryParse(json['endTime'] as String) : null,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0.0,
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble() ?? 0.0,
      maxSpeed: (json['maxSpeed'] as num?)?.toDouble() ?? 0.0,
      status: ActivityStatus.fromString(json['status'] as String? ?? 'completed'),
    );
  }
}

class GpsPointModel {
  final String id;
  final String sessionId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final DateTime timestamp;

  const GpsPointModel({
    required this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'speed': speed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory GpsPointModel.fromJson(Map<String, dynamic> json) {
    return GpsPointModel(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
