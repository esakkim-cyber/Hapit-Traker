import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/task_enums.dart';
import '../../core/providers/app_providers.dart';
import '../../models/activity_session_model.dart';
import '../../models/habit_model.dart';
import 'gps_tracking_screen.dart';
import 'timer_tracking_screen.dart';
import 'widgets/route_map_painter.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(activitySessionsStreamProvider);
    final habitsAsync = ref.watch(habitsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity & Sessions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Start Launchers Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quick Start Activity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickStartButton(
                          context: context,
                          title: 'GPS Run / Walk',
                          subtitle: 'Live distance & map',
                          icon: Icons.directions_run_rounded,
                          color: AppColors.accentEmerald,
                          onTap: () {
                            _launchGpsActivity(context, habitsAsync.asData?.value ?? []);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildQuickStartButton(
                          context: context,
                          title: 'Focus Timer',
                          subtitle: 'Duration countdown',
                          icon: Icons.timer_rounded,
                          color: AppColors.primary,
                          onTap: () {
                            _launchDurationActivity(context, habitsAsync.asData?.value ?? []);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Activity History Header
            const Text(
              'Activity History',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            // History List
            sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 48,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No activity sessions yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Start a GPS run or focus timer above to log your sessions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _buildSessionCard(context, ref, session, isDark);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    WidgetRef ref,
    ActivitySessionModel session,
    bool isDark,
  ) {
    final isDistance = session.taskType == TaskType.distance;
    final formattedDate = DateFormat('MMM d, yyyy • h:mm a').format(session.startTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isDistance ? AppColors.accentEmerald : AppColors.primary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDistance ? Icons.directions_run_rounded : Icons.timer_rounded,
                  color: isDistance ? AppColors.accentEmerald : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDistance ? 'Running / Walking' : 'Focus Session',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (session.status == ActivityStatus.completed
                          ? AppColors.accentEmerald
                          : AppColors.accentRose)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.status == ActivityStatus.completed ? 'Completed' : 'Cancelled',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: session.status == ActivityStatus.completed
                        ? AppColors.accentEmerald
                        : AppColors.accentRose,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (isDistance) ...[
                _buildSessionMetric(
                  label: 'Distance',
                  value: '${session.distanceKm.toStringAsFixed(2)} km',
                  isDark: isDark,
                ),
                _buildSessionMetric(
                  label: 'Avg Speed',
                  value: '${session.averageSpeed.toStringAsFixed(1)} km/h',
                  isDark: isDark,
                ),
              ],
              _buildSessionMetric(
                label: 'Duration',
                value: session.formattedDuration,
                isDark: isDark,
              ),
              if (isDistance)
                IconButton(
                  icon: const Icon(Icons.map_outlined, size: 20),
                  onPressed: () {
                    _showRouteDetailsModal(context, ref, session);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionMetric({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  void _showRouteDetailsModal(
    BuildContext context,
    WidgetRef ref,
    ActivitySessionModel session,
  ) async {
    final points = await ref.read(activityRepositoryProvider).getGpsPointsForSession(session.id);
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recorded Route Map',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCardElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(
                painter: RouteMapPainter(
                  points: points,
                  isDark: isDark,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSessionMetric(
                  label: 'Distance',
                  value: '${session.distanceKm.toStringAsFixed(2)} km',
                  isDark: isDark,
                ),
                _buildSessionMetric(
                  label: 'Duration',
                  value: session.formattedDuration,
                  isDark: isDark,
                ),
                _buildSessionMetric(
                  label: 'GPS Points',
                  value: '${points.length} coords',
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _launchGpsActivity(BuildContext context, List<HabitModel> habits) {
    final distanceHabits = habits.where((h) => h.taskType == TaskType.distance).toList();

    HabitModel selectedHabit;
    if (distanceHabits.isNotEmpty) {
      selectedHabit = distanceHabits.first;
    } else {
      selectedHabit = HabitModel(
        id: 'free_run',
        title: 'Free Run',
        taskType: TaskType.distance,
        frequencyType: FrequencyType.daily,
        targetValue: 2.0,
        targetUnit: 'km',
        createdAt: DateTime.now(),
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GpsTrackingScreen(habit: selectedHabit),
      ),
    );
  }

  void _launchDurationActivity(BuildContext context, List<HabitModel> habits) {
    final durationHabits = habits.where((h) => h.taskType == TaskType.duration).toList();

    HabitModel selectedHabit;
    if (durationHabits.isNotEmpty) {
      selectedHabit = durationHabits.first;
    } else {
      selectedHabit = HabitModel(
        id: 'free_timer',
        title: 'Focus Study',
        taskType: TaskType.duration,
        frequencyType: FrequencyType.daily,
        targetValue: 25.0,
        targetUnit: 'minutes',
        createdAt: DateTime.now(),
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TimerTrackingScreen(habit: selectedHabit),
      ),
    );
  }
}
