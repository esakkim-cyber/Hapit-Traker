import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/task_enums.dart';
import '../../core/providers/app_providers.dart';
import '../../models/completion_model.dart';
import '../../models/habit_model.dart';
import '../activity/gps_tracking_screen.dart';
import '../activity/timer_tracking_screen.dart';
import 'create_habit_sheet.dart';

class HabitDetailScreen extends ConsumerStatefulWidget {
  final String habitId;

  const HabitDetailScreen({super.key, required this.habitId});

  @override
  ConsumerState<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends ConsumerState<HabitDetailScreen> {
  IconData _getIconData(String name) {
    switch (name) {
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'book':
        return Icons.menu_book_rounded;
      case 'directions_run':
        return Icons.directions_run_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'bedtime':
        return Icons.bedtime_rounded;
      case 'alarm':
        return Icons.alarm_rounded;
      case 'work':
        return Icons.work_outline_rounded;
      case 'code':
        return Icons.code_rounded;
      case 'self_improvement':
        return Icons.self_improvement_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final todayStr = ref.watch(todayDateStringProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return habitsAsync.when(
      data: (habits) {
        HabitModel? habit;
        for (final h in habits) {
          if (h.id == widget.habitId) {
            habit = h;
            break;
          }
        }

        if (habit == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Habit Not Found')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.accentRose),
                  const SizedBox(height: 16),
                  Text(
                    'This habit no longer exists.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(habit.title),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => CreateHabitSheet(initialHabit: habit),
                  );
                },
              ),
              PopupMenuButton<String>(
                onSelected: (val) async {
                  final habitRepo = ref.read(habitRepositoryProvider);
                  if (val == 'toggle') {
                    await habitRepo.toggleHabitActive(habit.id, !habit.isActive);
                  } else if (val == 'delete') {
                    _showDeleteConfirm(context, habit);
                  }
                },
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(habit.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(habit.isActive ? 'Pause Habit' : 'Resume Habit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, color: AppColors.accentRose, size: 20),
                        SizedBox(width: 8),
                        Text('Delete Habit', style: TextStyle(color: AppColors.accentRose)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card with 3D Depth
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(habit.colorValue),
                        Color(habit.colorValue).withValues(alpha: 0.75),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Color(habit.colorValue).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          _getIconData(habit.iconName),
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              habit.title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            if (habit.description != null && habit.description!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                habit.description!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                habit.taskType.displayName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Streak Cards Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Current Streak',
                        value: '${habit.currentStreak} days',
                        icon: Icons.local_fire_department_rounded,
                        color: AppColors.accentAmber,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Best Streak',
                        value: '${habit.bestStreak} days',
                        icon: Icons.emoji_events_rounded,
                        color: AppColors.accentEmerald,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Schedule Details Card
                Container(
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
                      const Text(
                        'Schedule & Reminders',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 18, color: Color(habit.colorValue)),
                          const SizedBox(width: 8),
                          Text(
                            habit.frequencyType == FrequencyType.daily
                                ? 'Repeats Daily'
                                : 'Repeats on specific weekdays',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      if (habit.frequencyType == FrequencyType.specificDays) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                            final isScheduled = habit.scheduledWeekdays.contains(day);
                            final dayName = ['M', 'T', 'W', 'T', 'F', 'S', 'S'][day - 1];
                            return Container(
                              margin: const EdgeInsets.only(right: 6),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isScheduled
                                    ? Color(habit.colorValue)
                                    : (isDark ? AppColors.darkSurface : AppColors.lightBorder),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  dayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isScheduled ? Colors.white : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            habit.reminderTime != null && habit.reminderTime!.isNotEmpty
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_outlined,
                            size: 18,
                            color: habit.reminderTime != null && habit.reminderTime!.isNotEmpty
                                ? AppColors.primary
                                : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            habit.reminderTime != null && habit.reminderTime!.isNotEmpty
                                ? '🔔 Reminder: ${habit.reminderTime}'
                                : 'No reminder',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: habit.reminderTime != null && habit.reminderTime!.isNotEmpty
                                  ? AppColors.primary
                                  : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Checklist Section (if checklist type)
                if (habit.taskType == TaskType.checklist && habit.checklistItems.isNotEmpty) ...[
                  Container(
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
                        const Text(
                          'Checklist Items',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        ...habit.checklistItems.map((item) {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.title,
                              style: TextStyle(
                                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                color: item.isCompleted ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted) : null,
                              ),
                            ),
                            value: item.isCompleted,
                            activeColor: Color(habit.colorValue),
                            onChanged: (val) async {
                              final repo = ref.read(habitRepositoryProvider);
                              await repo.toggleChecklistItem(item.id, val ?? false);
                            },
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Button (Done or Start)
                FutureBuilder<bool>(
                  future: ref.read(habitRepositoryProvider).isHabitCompletedOnDate(habit.id, todayStr),
                  builder: (context, snapshot) {
                    final isCompletedToday = snapshot.data ?? false;

                    if (isCompletedToday) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accentEmerald.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.accentEmerald),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald),
                            SizedBox(width: 8),
                            Text(
                              'Completed for Today! 🎉',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentEmerald,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    if (habit.taskType == TaskType.distance) {
                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GpsTrackingScreen(habit: habit),
                              ),
                            );
                          },
                          icon: const Icon(Icons.directions_run_rounded),
                          label: Text('START ${habit.targetValue?.toStringAsFixed(1) ?? '2.0'} KM RUN'),
                        ),
                      );
                    }

                    if (habit.taskType == TaskType.duration) {
                      return SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TimerTrackingScreen(habit: habit),
                              ),
                            );
                          },
                          icon: const Icon(Icons.timer_rounded),
                          label: Text('START ${habit.targetValue?.toInt() ?? 30} MIN TIMER'),
                        ),
                      );
                    }

                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(habit.colorValue),
                        ),
                        onPressed: () async {
                          final repo = ref.read(habitRepositoryProvider);
                          final streakService = ref.read(streakServiceProvider);

                          await repo.recordCompletion(
                            habitId: habit.id,
                            date: DateTime.now(),
                          );
                          final completions = await repo.getCompletionsForHabit(habit.id);
                          await streakService.updateStreakAfterCompletion(habit, completions, repo);
                          setState(() {});
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('MARK AS DONE FOR TODAY'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Recent Completion History
                const Text(
                  'Recent Activity History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                FutureBuilder<List<CompletionModel>>(
                  future: ref.read(habitRepositoryProvider).getCompletionsForHabit(habit.id),
                  builder: (context, snap) {
                    final completions = snap.data ?? [];
                    if (completions.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'No completions recorded yet. Complete today to start your streak!',
                            style: TextStyle(fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: completions.length > 7 ? 7 : completions.length,
                      itemBuilder: (context, index) {
                        final comp = completions[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: AppColors.accentEmerald, size: 20),
                                  const SizedBox(width: 10),
                                  Text(
                                    comp.date,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Text(
                                DateFormat.jm().format(comp.completedAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, HabitModel habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Habit?'),
        content: Text('Are you sure you want to delete "${habit.title}"? This will also cancel its scheduled reminders.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentRose),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final notifService = ref.read(notificationServiceProvider);
              final repo = ref.read(habitRepositoryProvider);

              // Cancel notification schedule
              await notifService.cancelHabitNotifications(habit.id);
              await repo.deleteHabit(habit.id);

              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Habit deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
