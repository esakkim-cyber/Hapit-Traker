import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/task_enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/location_service.dart';
import '../../models/activity_session_model.dart';
import '../../models/habit_model.dart';
import 'widgets/route_map_painter.dart';

class GpsTrackingScreen extends ConsumerStatefulWidget {
  final HabitModel habit;

  const GpsTrackingScreen({super.key, required this.habit});

  @override
  ConsumerState<GpsTrackingScreen> createState() => _GpsTrackingScreenState();
}

class _GpsTrackingScreenState extends ConsumerState<GpsTrackingScreen> {
  late final LocationService _locationService;
  late final String _sessionId;
  StreamSubscription<LocationTrackingData>? _trackingSub;

  double _currentDistanceKm = 0.0;
  double _currentSpeedKmh = 0.0;
  double _avgSpeedKmh = 0.0;
  int _durationSeconds = 0;
  List<GpsPointModel> _routePoints = [];
  bool _isWeakGps = false;
  String? _statusMessage;
  bool _isFinished = false;
  bool _hasTriggeredCompletion = false;

  double get targetKm => widget.habit.targetValue ?? 2.0;

  @override
  void initState() {
    super.initState();
    _locationService = ref.read(locationServiceProvider);
    _sessionId = const Uuid().v4();
    _startTracking();
  }

  Future<void> _startTracking() async {
    final success = await _locationService.startTracking(_sessionId);
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not start GPS tracking. Please check permissions and GPS.',
            ),
            backgroundColor: AppColors.accentRose,
          ),
        );
      }
      return;
    }

    _trackingSub = _locationService.trackingStream.listen((data) {
      if (!mounted || _isFinished) return;

      setState(() {
        _currentDistanceKm = data.distanceKm;
        _currentSpeedKmh = data.currentSpeedKmh;
        _avgSpeedKmh = data.averageSpeedKmh;
        _durationSeconds = data.durationSeconds;
        _routePoints = data.routePoints;
        _isWeakGps = data.isWeakGps;
        _statusMessage = data.statusMessage;
      });

      // Update ongoing notification
      ref
          .read(notificationServiceProvider)
          .showTrackingNotification(
            id: 9999,
            title: 'HabitForge — ${widget.habit.title}',
            body:
                '${data.distanceKm.toStringAsFixed(2)} / ${targetKm.toStringAsFixed(2)} km (${_formatDuration(data.durationSeconds)})',
          );

      // Check auto completion
      if (_currentDistanceKm >= targetKm && !_hasTriggeredCompletion) {
        _hasTriggeredCompletion = true;
        _onGoalReached();
      }
    });
  }

  Future<void> _onGoalReached() async {
    _locationService.pauseTracking();

    // Play loud completion sound & vibration notification
    ref
        .read(notificationServiceProvider)
        .showDistanceCompletionNotification(
          title: '🏃 HabitForge Goal Reached!',
          message:
              'Awesome run! You completed ${widget.habit.title} (${_currentDistanceKm.toStringAsFixed(2)} km in ${_formatDuration(_durationSeconds)}).',
        );

    await _saveActivitySession(isComplete: true);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.accentEmerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.accentEmerald,
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '🎉 Goal Completed!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'You covered ${_currentDistanceKm.toStringAsFixed(2)} km in ${_formatDuration(_durationSeconds)}!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _finishAndExit();
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveActivitySession({required bool isComplete}) async {
    final activityRepo = ref.read(activityRepositoryProvider);
    final habitRepo = ref.read(habitRepositoryProvider);
    final streakService = ref.read(streakServiceProvider);

    final session = ActivitySessionModel(
      id: _sessionId,
      habitId: widget.habit.id,
      taskType: TaskType.distance,
      startTime: DateTime.now().subtract(Duration(seconds: _durationSeconds)),
      endTime: DateTime.now(),
      durationSeconds: _durationSeconds,
      distanceMeters: _currentDistanceKm * 1000.0,
      averageSpeed: _avgSpeedKmh,
      maxSpeed: _currentSpeedKmh > _avgSpeedKmh
          ? _currentSpeedKmh
          : _avgSpeedKmh,
      status: isComplete ? ActivityStatus.completed : ActivityStatus.cancelled,
    );

    await activityRepo.saveSession(session);
    await activityRepo.saveGpsPoints(_routePoints);

    if (isComplete) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final isAlreadyDone = await habitRepo.isHabitCompletedOnDate(
        widget.habit.id,
        todayStr,
      );
      if (isAlreadyDone) {
        debugPrint(
          'GPS: completion already recorded for habit ${widget.habit.id} today, skipping',
        );
      } else {
        await habitRepo.recordCompletion(
          habitId: widget.habit.id,
          date: DateTime.now(),
          value: _currentDistanceKm,
        );

        final completions = await habitRepo.getCompletionsForHabit(
          widget.habit.id,
        );
        await streakService.updateStreakAfterCompletion(
          widget.habit,
          completions,
          habitRepo,
        );
      }
    }
  }

  void _finishAndExit() {
    _isFinished = true;
    _locationService.stopTracking();
    ref.read(notificationServiceProvider).cancelNotification(9999);
    Navigator.of(context).pop();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _trackingSub?.cancel();
    _locationService.stopTracking();
    ref.read(notificationServiceProvider).cancelNotification(9999);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double progress = targetKm > 0
        ? (_currentDistanceKm / targetKm).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.habit.title),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _showExitConfirmDialog,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Debug-Only GPS Simulation Bar (Only renders in debug mode)
            if (kDebugMode) _buildDebugGpsBar(isDark),

            if (_statusMessage != null || _isWeakGps)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.accentAmber.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.accentAmber,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage ??
                            'GPS accuracy is low. Move to an open area.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Live Route Map Canvas
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkCard
                      : AppColors.lightCardElevated,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    CustomPaint(
                      painter: RouteMapPainter(
                        points: _routePoints,
                        isDark: isDark,
                      ),
                      child: const SizedBox.expand(),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark ? AppColors.darkSurface : Colors.white)
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color:
                                    _locationService.isTracking &&
                                        !_locationService.isPaused
                                    ? AppColors.accentEmerald
                                    : AppColors.accentAmber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _locationService.isPaused
                                  ? 'Paused'
                                  : (_isWeakGps ? 'Weak GPS' : 'Live GPS'),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Distance Progress Display
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Distance',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${_currentDistanceKm.toStringAsFixed(2)} / ${targetKm.toStringAsFixed(2)} km',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Metric Tiles Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Time',
                      value: _formatDuration(_durationSeconds),
                      icon: Icons.timer_outlined,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Speed',
                      value: '${_currentSpeedKmh.toStringAsFixed(1)} km/h',
                      icon: Icons.speed_rounded,
                      color: AppColors.accentEmerald,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Average',
                      value: '${_avgSpeedKmh.toStringAsFixed(1)} km/h',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.accentAmber,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Activity Control Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_locationService.isPaused) {
                          _locationService.resumeTracking();
                        } else {
                          _locationService.pauseTracking();
                        }
                        setState(() {});
                      },
                      icon: Icon(
                        _locationService.isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(
                        _locationService.isPaused ? 'Resume' : 'Pause',
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentRose,
                      ),
                      onPressed: _showExitConfirmDialog,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Stop'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugGpsBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bug_report_rounded,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 6),
          const Text(
            'GPS Sim:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const Spacer(),
          Wrap(
            spacing: 6,
            children: [0.5, 1.0, 1.5, 2.0].map((km) {
              return InkWell(
                onTap: () {
                  _locationService.simulateDistanceInDebug(km);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '+${km}km',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Activity?'),
        content: Text(
          'You have completed ${_currentDistanceKm.toStringAsFixed(2)} km of your ${targetKm.toStringAsFixed(2)} km target.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Going'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRose,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _saveActivitySession(
                isComplete: _currentDistanceKm >= targetKm,
              );
              _finishAndExit();
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}
