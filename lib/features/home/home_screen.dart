import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/task_enums.dart';
import '../../core/providers/app_providers.dart';
import '../../models/habit_model.dart';
import '../activity/gps_tracking_screen.dart';
import '../activity/timer_tracking_screen.dart';
import '../habits/create_habit_sheet.dart';
import '../habits/habit_detail_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _taskFilter = 'All'; // All, Pending, Completed

  String _getGreeting(String? name) {
    final hour = DateTime.now().hour;
    String timeGreeting = 'Good morning';
    if (hour >= 12 && hour < 17) {
      timeGreeting = 'Good afternoon';
    } else if (hour >= 17 || hour < 5) {
      timeGreeting = 'Good evening';
    }
    final userName = (name != null && name.isNotEmpty) ? name : 'Friend';
    return '$timeGreeting, $userName 👋';
  }

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

  Future<void> _completeHabit(HabitModel habit) async {
    final repo = ref.read(habitRepositoryProvider);
    final streakService = ref.read(streakServiceProvider);

    final isAlreadyDone = await repo.isHabitCompletedOnDate(
      habit.id,
      DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    if (isAlreadyDone) return; // Prevent duplicate completion

    await repo.recordCompletion(
      habitId: habit.id,
      date: DateTime.now(),
    );

    final completions = await repo.getCompletionsForHabit(habit.id);
    await streakService.updateStreakAfterCompletion(habit, completions, repo);

    final updatedHabit = await repo.getHabitById(habit.id);
    final streak = updatedHabit?.currentStreak ?? (habit.currentStreak + 1);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('✓ Completed! 🔥 $streak day streak'),
              ),
            ],
          ),
          backgroundColor: AppColors.accentEmerald,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final userProfileAsync = ref.watch(userProfileProvider);
    final todayCompletionsAsync = ref.watch(todayCompletionsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userName = userProfileAsync.maybeWhen(
      data: (profile) => profile?.name,
      orElse: () => 'Friend',
    );

    final completedHabitIds = todayCompletionsAsync.maybeWhen(
      data: (comps) => comps.where((c) => c.status == 'completed').map((c) => c.habitId).toSet(),
      orElse: () => <String>{},
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(userName),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('EEEE, MMMM d').format(DateTime.now()),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const CreateHabitSheet(),
          );
        },
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: habitsAsync.when(
        data: (habits) {
          final now = DateTime.now();
          final activeHabits = habits.where((h) => h.isActive).toList();
          final todayHabits = activeHabits.where((h) => h.isScheduledForDate(now)).toList();

          final int totalScheduledToday = todayHabits.length;
          final int completedCount = todayHabits.where((h) => completedHabitIds.contains(h.id)).length;
          final double progressFraction = totalScheduledToday > 0
              ? (completedCount / totalScheduledToday).clamp(0.0, 1.0)
              : 0.0;

          int maxActiveStreak = 0;
          for (final h in activeHabits) {
            if (h.currentStreak > maxActiveStreak) {
              maxActiveStreak = h.currentStreak;
            }
          }

          final filteredTodayHabits = todayHabits.where((h) {
            final isDone = completedHabitIds.contains(h.id);
            if (_taskFilter == 'Pending') return !isDone;
            if (_taskFilter == 'Completed') return isDone;
            return true;
          }).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 80, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Today's Progress 3D Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Today's Progress",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: AppColors.accentAmber,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$maxActiveStreak ${maxActiveStreak == 1 ? 'day' : 'days'} streak',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$completedCount / $totalScheduledToday',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'tasks completed',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressFraction,
                          minHeight: 10,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

                // Upcoming Reminders Quick Bar
                _buildTodayRemindersBar(todayHabits, isDark),

                const SizedBox(height: 12),

                // Tasks Header & Filter Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Tasks",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Row(
                        children: ['All', 'Pending', 'Completed'].map((filter) {
                          final isSelected = _taskFilter == filter;
                          return Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: InkWell(
                              onTap: () => setState(() => _taskFilter = filter),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  filter,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Tasks List
                if (filteredTodayHabits.isEmpty)
                  _buildEmptyTasksState(todayHabits.isEmpty, isDark)
                else
                  ...filteredTodayHabits.map((habit) {
                    final isCompleted = completedHabitIds.contains(habit.id);
                    return _buildTodayTaskCard(habit, isCompleted, isDark);
                  }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildTodayRemindersBar(List<HabitModel> todayHabits, bool isDark) {
    final reminderHabits = todayHabits
        .where((h) => (h.reminderTime != null && h.reminderTime!.isNotEmpty) || h.taskType == TaskType.wakeUp)
        .toList();

    if (reminderHabits.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: AppColors.secondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: reminderHabits.map((h) {
                  final timeStr = h.taskType == TaskType.wakeUp ? h.wakeTime : h.reminderTime;
                  return Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Text(
                      '🔔 ${h.title} at $timeStr',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayTaskCard(HabitModel habit, bool isCompleted, bool isDark) {
    final hasReminder = (habit.reminderTime != null && habit.reminderTime!.isNotEmpty) ||
        (habit.taskType == TaskType.wakeUp && habit.wakeTime != null && habit.wakeTime!.isNotEmpty);
    final reminderDisplay = habit.taskType == TaskType.wakeUp
        ? (habit.wakeTime != null ? '🔔 ${habit.wakeTime}' : 'No alarm')
        : (habit.reminderTime != null && habit.reminderTime!.isNotEmpty
            ? '🔔 ${habit.reminderTime}'
            : 'No reminder');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCardElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? AppColors.accentEmerald.withValues(alpha: 0.3)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HabitDetailScreen(habitId: habit.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(habit.colorValue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _getIconData(habit.iconName),
                      color: Color(habit.colorValue),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted
                                ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                                : null,
                          ),
                        ),
                        if (habit.description != null && habit.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            habit.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // Reminder Indicator
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: hasReminder
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : (isDark ? AppColors.darkSurface : AppColors.lightBorder.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                reminderDisplay,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: hasReminder ? FontWeight.w700 : FontWeight.w500,
                                  color: hasReminder
                                      ? AppColors.primary
                                      : (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                                ),
                              ),
                            ),
                            if (habit.currentStreak > 0) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.local_fire_department_rounded, size: 14, color: AppColors.accentAmber),
                              Text(
                                '${habit.currentStreak}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentAmber,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildTaskActionButton(habit, isCompleted),
                ],
              ),

              if (habit.taskType == TaskType.checklist && habit.checklistItems.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 6),
                ...habit.checklistItems.map((item) {
                  return InkWell(
                    onTap: () async {
                      final repo = ref.read(habitRepositoryProvider);
                      await repo.toggleChecklistItem(item.id, !item.isCompleted);

                      final updatedHabit = await repo.getHabitById(habit.id);
                      if (updatedHabit != null &&
                          updatedHabit.checklistItems.isNotEmpty &&
                          updatedHabit.checklistItems.every((i) => i.isCompleted)) {
                        await _completeHabit(habit);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            item.isCompleted
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: item.isCompleted ? Color(habit.colorValue) : AppColors.darkTextMuted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                                color: item.isCompleted
                                    ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskActionButton(HabitModel habit, bool isCompleted) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentEmerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_rounded, color: AppColors.accentEmerald, size: 16),
            SizedBox(width: 4),
            Text(
              'DONE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.accentEmerald),
            ),
          ],
        ),
      );
    }

    if (habit.taskType == TaskType.distance) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GpsTrackingScreen(habit: habit),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow_rounded, size: 16),
        label: const Text('START'),
      );
    }

    if (habit.taskType == TaskType.duration) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TimerTrackingScreen(habit: habit),
            ),
          );
        },
        icon: const Icon(Icons.timer_rounded, size: 16),
        label: const Text('START'),
      );
    }

    if (habit.taskType == TaskType.checklist) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HabitDetailScreen(habitId: habit.id),
            ),
          );
        },
        icon: const Icon(Icons.checklist_rounded, size: 14),
        label: const Text('OPEN'),
      );
    }

    // Normal Habit or Wake Up Task
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () => _completeHabit(habit),
      child: const Text('DONE'),
    );
  }

  Widget _buildEmptyTasksState(bool noHabitsAtAll, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              noHabitsAtAll ? Icons.add_task_rounded : Icons.task_alt_rounded,
              size: 64,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
            const SizedBox(height: 16),
            Text(
              noHabitsAtAll ? 'No habits yet!' : 'All caught up for today! 🎉',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              noHabitsAtAll
                  ? 'Tap the + button below to forge your first habit.'
                  : 'You completed all your scheduled habits for today.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
