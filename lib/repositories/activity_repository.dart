import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../core/enums/task_enums.dart';
import '../database/app_database.dart';
import '../models/activity_session_model.dart';

class ActivityRepository {
  final AppDatabase _db;
  final Uuid _uuid = const Uuid();

  ActivityRepository(this._db);

  // Save new activity session
  Future<String> saveSession(ActivitySessionModel session) async {
    final sessionId = session.id.isNotEmpty ? session.id : _uuid.v4();

    await _db.into(_db.activitySessions).insert(
          ActivitySessionsCompanion.insert(
            id: sessionId,
            habitId: session.habitId,
            taskType: session.taskType.name,
            startTime: session.startTime,
            endTime: Value(session.endTime),
            durationSeconds: Value(session.durationSeconds),
            distanceMeters: Value(session.distanceMeters),
            averageSpeed: Value(session.averageSpeed),
            maxSpeed: Value(session.maxSpeed),
            status: Value(session.status.name),
          ),
        );

    return sessionId;
  }

  // Update existing session
  Future<void> updateSession(ActivitySessionModel session) async {
    await (_db.update(_db.activitySessions)..where((t) => t.id.equals(session.id))).write(
      ActivitySessionsCompanion(
        endTime: Value(session.endTime),
        durationSeconds: Value(session.durationSeconds),
        distanceMeters: Value(session.distanceMeters),
        averageSpeed: Value(session.averageSpeed),
        maxSpeed: Value(session.maxSpeed),
        status: Value(session.status.name),
      ),
    );
  }

  // Batch insert GPS points
  Future<void> saveGpsPoints(List<GpsPointModel> points) async {
    if (points.isEmpty) return;
    await _db.batch((batch) {
      batch.insertAll(
        _db.gpsPoints,
        points.map((p) => GpsPointsCompanion.insert(
              id: p.id.isNotEmpty ? p.id : _uuid.v4(),
              sessionId: p.sessionId,
              latitude: p.latitude,
              longitude: p.longitude,
              altitude: Value(p.altitude),
              accuracy: Value(p.accuracy),
              speed: Value(p.speed),
              timestamp: p.timestamp,
            )),
      );
    });
  }

  // Get all activity sessions
  Future<List<ActivitySessionModel>> getAllSessions() async {
    final rows = await (_db.select(_db.activitySessions)
          ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc)]))
        .get();

    return rows
        .map((r) => ActivitySessionModel(
              id: r.id,
              habitId: r.habitId,
              taskType: TaskType.fromString(r.taskType),
              startTime: r.startTime,
              endTime: r.endTime,
              durationSeconds: r.durationSeconds,
              distanceMeters: r.distanceMeters,
              averageSpeed: r.averageSpeed,
              maxSpeed: r.maxSpeed,
              status: ActivityStatus.fromString(r.status),
            ))
        .toList();
  }

  // Stream activity sessions
  Stream<List<ActivitySessionModel>> watchAllSessions() {
    return (_db.select(_db.activitySessions)
          ..orderBy([(t) => OrderingTerm(expression: t.startTime, mode: OrderingMode.desc)]))
        .watch()
        .map((rows) => rows
            .map((r) => ActivitySessionModel(
                  id: r.id,
                  habitId: r.habitId,
                  taskType: TaskType.fromString(r.taskType),
                  startTime: r.startTime,
                  endTime: r.endTime,
                  durationSeconds: r.durationSeconds,
                  distanceMeters: r.distanceMeters,
                  averageSpeed: r.averageSpeed,
                  maxSpeed: r.maxSpeed,
                  status: ActivityStatus.fromString(r.status),
                ))
            .toList());
  }

  // Get GPS points for a session
  Future<List<GpsPointModel>> getGpsPointsForSession(String sessionId) async {
    final rows = await (_db.select(_db.gpsPoints)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
        .get();

    return rows
        .map((r) => GpsPointModel(
              id: r.id,
              sessionId: r.sessionId,
              latitude: r.latitude,
              longitude: r.longitude,
              altitude: r.altitude,
              accuracy: r.accuracy,
              speed: r.speed,
              timestamp: r.timestamp,
            ))
        .toList();
  }
}
