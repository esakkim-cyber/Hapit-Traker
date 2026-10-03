import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/task_enums.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/timer_service.dart';
import '../../models/activity_session_model.dart';
import '../../models/habit_model.dart';

class TimerTrackingScreen extends ConsumerStatefulWidget {
  final HabitModel habit;

  const TimerTrackingScreen({super.key, required this.habit});

  @override
  ConsumerState<TimerTrackingScreen> createState() =>
      _TimerTrackingScreenState();
}

class _TimerTrackingScreenState extends ConsumerState<TimerTrackingScreen> {
  final TimerService _timerService = TimerService();
  StreamSubscription<TimerState>? _timerSub;
  late final String _sessionId;

  int _targetSeconds = 0;
  int _elapsedSeconds = 0;
  int _remainingSeconds = 0;
  double _progress = 0.0;
  bool _isPaused = false;
  bool _isFinished = false;
  bool _hasTriggeredCompletion = false;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();

    final val = widget.habit.targetValue ?? 2.0;
    if (widget.habit.targetUnit == 'hours') {
      _targetSeconds = (val * 3600).round();
    } else if (widget.habit.targetUnit == 'seconds') {
      _targetSeconds = val.round();
    } else {
      _targetSeconds = (val * 60).round();
    }
    if (_targetSeconds <= 0) _targetSeconds = 120; // default 2 mins

    _timerSub = _timerService.stateStream.listen((state) {
      if (!mounted || _isFinished) return;

      setState(() {
        _elapsedSeconds = state.elapsedSeconds;
        _remainingSeconds = state.remainingSeconds;
        _progress = state.progress;
        _isPaused = state.isPaused;
      });

      // Update notification
      ref
          .read(notificationServiceProvider)
          .showTrackingNotification(
            id: 9998,
            title: 'HabitForge — ${widget.habit.title}',
            body:
                '${state.formattedRemaining} remaining (${(state.progress * 100).toInt()}%)',
          );

      if (state.isCompleted && !_hasTriggeredCompletion) {
        _hasTriggeredCompletion = true;
        _onGoalReached();
      }
    });

    _timerService.start(_targetSeconds);
  }

  Future<void> _onGoalReached() async {
    // Play completion sound & vibration notification
    ref
        .read(notificationServiceProvider)
        .showTimerCompletionNotification(
          title: '⏱ HabitForge Focus Session Completed!',
          message:
              'Great job! You finished your ${widget.habit.title} timer (${_formatDuration(_elapsedSeconds)}).',
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
                Icons.check_circle_rounded,
                color: AppColors.accentEmerald,
                size: 56,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '🎉 Task Completed!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.habit.title} session completed (${_formatDuration(_elapsedSeconds)})!',
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
      taskType: TaskType.duration,
      startTime: DateTime.now().subtract(Duration(seconds: _elapsedSeconds)),
      endTime: DateTime.now(),
      durationSeconds: _elapsedSeconds,
      distanceMeters: 0,
      averageSpeed: 0,
      maxSpeed: 0,
      status: isComplete ? ActivityStatus.completed : ActivityStatus.cancelled,
    );

    await activityRepo.saveSession(session);

    if (isComplete) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final isAlreadyDone = await habitRepo.isHabitCompletedOnDate(
        widget.habit.id,
        todayStr,
      );
      if (isAlreadyDone) {
        debugPrint(
          'Timer: completion already recorded for habit ${widget.habit.id} today, skipping',
        );
      } else {
        await habitRepo.recordCompletion(
          habitId: widget.habit.id,
          date: DateTime.now(),
          value: _elapsedSeconds / 60.0,
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
    _timerService.stop();
    ref.read(notificationServiceProvider).cancelNotification(9998);
    Navigator.of(context).pop();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final h = m ~/ 60;
    if (h > 0) {
      final remM = m % 60;
      return '${h.toString().padLeft(2, '0')}:${remM.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timerSub?.cancel();
    _timerService.dispose();
    ref.read(notificationServiceProvider).cancelNotification(9998);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            const Spacer(),

            // Circular Countdown Progress Indicator
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: _progress,
                      strokeWidth: 14,
                      backgroundColor: isDark
                          ? AppColors.darkCard
                          : AppColors.lightCardElevated,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDuration(_remainingSeconds),
                        style: const TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: ${_formatDuration(_targetSeconds)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Metrics Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      label: 'Elapsed',
                      value: _formatDuration(_elapsedSeconds),
                      icon: Icons.timer_outlined,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInfoCard(
                      label: 'Progress',
                      value: '${(_progress * 100).toInt()}%',
                      icon: Icons.donut_large_rounded,
                      color: AppColors.accentEmerald,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Controls
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_isPaused) {
                          _timerService.resume();
                        } else {
                          _timerService.pause();
                        }
                      },
                      icon: Icon(
                        _isPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                      ),
                      label: Text(_isPaused ? 'Resume' : 'Pause'),
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

  Widget _buildInfoCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCardElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showExitConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Stop Timer?'),
        content: Text(
          'You have completed ${_formatDuration(_elapsedSeconds)} of your ${_formatDuration(_targetSeconds)} target.',
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
              await _saveActivitySession(isComplete: _remainingSeconds <= 0);
              _finishAndExit();
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }
}
