import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/task_enums.dart';
import '../../core/providers/app_providers.dart';
import '../../models/habit_model.dart';
import '../activity/gps_tracking_screen.dart';
import '../activity/timer_tracking_screen.dart';
import 'create_habit_sheet.dart';
import 'habit_detail_screen.dart';

class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  String _selectedFilter = 'All'; // All, Active, Completed Today, Paused
  final TextEditingController _searchController = TextEditingController();
  bool _isCompleting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final todayCompletionsAsync = ref.watch(todayCompletionsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final completedHabitIds = todayCompletionsAsync.maybeWhen(
      data: (comps) => comps.map((c) => c.habitId).toSet(),
      orElse: () => <String>{},
    );

    return Scaffold(
      appBar: AppBar(title: const Text('My Habits & Routines')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const CreateHabitSheet(),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Habit'),
      ),
      body: habitsAsync.when(
        data: (habits) {
          final query = _searchController.text.trim().toLowerCase();

          final filteredHabits = habits.where((h) {
            if (query.isNotEmpty && !h.title.toLowerCase().contains(query)) {
              return false;
            }
            if (_selectedFilter == 'Active') return h.isActive;
            if (_selectedFilter == 'Completed Today')
              return completedHabitIds.contains(h.id);
            if (_selectedFilter == 'Paused') return !h.isActive;
            return true;
          }).toList();

          return Column(
            children: [
              // Search & Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search habits...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: ['All', 'Active', 'Completed Today', 'Paused'].map((
                    filter,
                  ) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected)
                            setState(() => _selectedFilter = filter);
                        },
                        selectedColor: AppColors.primary.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? AppColors.primary : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Habits List
              Expanded(
                child: filteredHabits.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80, top: 8),
                        itemCount: filteredHabits.length,
                        itemBuilder: (context, index) {
                          final habit = filteredHabits[index];
                          final isCompleted = completedHabitIds.contains(
                            habit.id,
                          );
                          return _buildHabitCard(habit, isCompleted, isDark);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildHabitCard(HabitModel habit, bool isCompleted, bool isDark) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => HabitDetailScreen(habitId: habit.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(habit.colorValue).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconData(habit.iconName),
                      color: Color(habit.colorValue),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (habit.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            habit.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (habit.currentStreak > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: AppColors.accentAmber,
                            size: 16,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${habit.currentStreak}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accentAmber,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (isDark
                              ? AppColors.darkSurface
                              : AppColors.lightCardElevated),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        ),
                        child: Text(
                          habit.taskType.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        habit.frequencyType == FrequencyType.daily
                            ? 'Daily'
                            : 'Specific Days',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ),
                  _buildActionButton(habit, isCompleted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(HabitModel habit, bool isCompleted) {
    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentEmerald.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_rounded, color: AppColors.accentEmerald, size: 16),
            SizedBox(width: 4),
            Text(
              'Done',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accentEmerald,
              ),
            ),
          ],
        ),
      );
    }

    if (habit.taskType == TaskType.distance) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GpsTrackingScreen(habit: habit)),
          );
        },
        icon: const Icon(Icons.play_arrow_rounded, size: 16),
        label: const Text('Start Run'),
      );
    }

    if (habit.taskType == TaskType.duration) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TimerTrackingScreen(habit: habit),
            ),
          );
        },
        icon: const Icon(Icons.timer_rounded, size: 16),
        label: const Text('Start Timer'),
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      onPressed: () async {
        if (_isCompleting) return;
        _isCompleting = true;
        try {
          final repo = ref.read(habitRepositoryProvider);
          final streakService = ref.read(streakServiceProvider);
          final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final isAlreadyDone = await repo.isHabitCompletedOnDate(
            habit.id,
            todayStr,
          );
          if (!isAlreadyDone) {
            await repo.recordCompletion(
              habitId: habit.id,
              date: DateTime.now(),
            );
            final completions = await repo.getCompletionsForHabit(habit.id);
            await streakService.updateStreakAfterCompletion(
              habit,
              completions,
              repo,
            );
          }
        } finally {
          if (mounted) setState(() => _isCompleting = false);
        }
      },
      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
      label: const Text('Done'),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checklist_rounded,
              size: 64,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
            const SizedBox(height: 16),
            const Text(
              'No habits found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the "+ New Habit" button to forge your daily routines.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
