import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/providers/app_providers.dart';
import '../../models/completion_model.dart';
import '../../models/habit_model.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _currentMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );
  DateTime _selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  String? _selectedHabitId; // null = All habits

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final completionsAsync = ref.watch(allCompletionsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Habit Calendar')),
      body: habitsAsync.when(
        data: (habits) {
          return completionsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading: $e')),
            data: (completions) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Filter dropdown (All vs Specific Habit)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedHabitId,
                          isExpanded: true,
                          hint: const Text('All Habits'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text(
                                'All Habits',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            ...habits.map(
                              (h) => DropdownMenuItem<String?>(
                                value: h.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: Color(h.colorValue),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(h.title),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedHabitId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Month Navigation Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(_currentMonth),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded),
                              onPressed: _previousMonth,
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Calendar Grid Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkCard
                            : AppColors.lightCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Weekday Headers
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((
                              day,
                            ) {
                              return SizedBox(
                                width: 36,
                                child: Center(
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.lightTextMuted,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          _buildCalendarMonthGrid(habits, completions, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monthly Summary Stats
                    _buildMonthlySummaryStats(habits, completions, isDark),
                    const SizedBox(height: 16),

                    // Selected Date Details
                    _buildSelectedDateDetails(habits, completions, isDark),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildCalendarMonthGrid(
    List<HabitModel> allHabits,
    List<CompletionModel> allCompletions,
    bool isDark,
  ) {
    final activeHabits = _selectedHabitId != null
        ? allHabits.where((h) => h.id == _selectedHabitId).toList()
        : allHabits.where((h) => h.isActive).toList();

    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final firstDayWeekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday; // 1 = Mon

    final completionMap = <String, Set<String>>{};
    for (final c in allCompletions) {
      if (c.status == 'completed') {
        completionMap.putIfAbsent(c.date, () => {}).add(c.habitId);
      }
    }

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    List<Widget> rows = [];
    List<Widget> currentCells = [];

    // Leading empty slots
    for (int i = 1; i < firstDayWeekday; i++) {
      currentCells.add(const SizedBox(width: 36, height: 36));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final cellDate = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dateStr = DateFormat('yyyy-MM-dd').format(cellDate);

      final scheduled = activeHabits
          .where((h) => h.isScheduledForDate(cellDate))
          .toList();
      final completedSet = completionMap[dateStr] ?? {};

      Color statusColor;
      Color textColor = isDark
          ? AppColors.darkTextPrimary
          : AppColors.lightTextPrimary;

      if (scheduled.isEmpty) {
        // Rest Day
        statusColor = Colors.transparent;
      } else {
        final completedCount = scheduled
            .where((h) => completedSet.contains(h.id))
            .length;
        if (completedCount == scheduled.length) {
          // Fully completed
          statusColor = AppColors.accentEmerald;
          textColor = Colors.white;
        } else if (completedCount > 0) {
          // Partially completed
          statusColor = AppColors.accentAmber;
          textColor = Colors.white;
        } else if (cellDate.isBefore(today)) {
          // Missed in the past
          statusColor = AppColors.accentRose.withValues(alpha: 0.8);
          textColor = Colors.white;
        } else {
          // Pending for today or future
          statusColor = Colors.transparent;
        }
      }

      final isSelected =
          cellDate.year == _selectedDate.year &&
          cellDate.month == _selectedDate.month &&
          cellDate.day == _selectedDate.day;

      final isToday =
          cellDate.year == today.year &&
          cellDate.month == today.month &&
          cellDate.day == today.day;

      currentCells.add(
        InkWell(
          onTap: () {
            setState(() => _selectedDate = cellDate);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: AppColors.primaryLight, width: 2)
                  : (isToday
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : null),
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ),
          ),
        ),
      );

      if (currentCells.length == 7) {
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.from(currentCells),
            ),
          ),
        );
        currentCells.clear();
      }
    }

    if (currentCells.isNotEmpty) {
      while (currentCells.length < 7) {
        currentCells.add(const SizedBox(width: 36, height: 36));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.from(currentCells),
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildMonthlySummaryStats(
    List<HabitModel> allHabits,
    List<CompletionModel> allCompletions,
    bool isDark,
  ) {
    final activeHabits = _selectedHabitId != null
        ? allHabits.where((h) => h.id == _selectedHabitId).toList()
        : allHabits.where((h) => h.isActive).toList();

    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final completionMap = <String, Set<String>>{};
    for (final c in allCompletions) {
      if (c.status == 'completed') {
        completionMap.putIfAbsent(c.date, () => {}).add(c.habitId);
      }
    }

    int totalScheduledDays = 0;
    int totalCompletedDays = 0;

    for (int day = 1; day <= daysInMonth; day++) {
      final cellDate = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dateStr = DateFormat('yyyy-MM-dd').format(cellDate);
      final scheduled = activeHabits
          .where((h) => h.isScheduledForDate(cellDate))
          .toList();

      if (scheduled.isNotEmpty) {
        totalScheduledDays++;
        final completedSet = completionMap[dateStr] ?? {};
        final count = scheduled
            .where((h) => completedSet.contains(h.id))
            .length;
        if (count == scheduled.length) {
          totalCompletedDays++;
        }
      }
    }

    final int percentage = totalScheduledDays > 0
        ? ((totalCompletedDays / totalScheduledDays) * 100).round()
        : 0;

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
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            label: 'Scheduled Days',
            value: '$totalScheduledDays',
            icon: Icons.calendar_month_rounded,
            color: AppColors.secondary,
            isDark: isDark,
          ),
          _buildSummaryItem(
            label: 'Completed',
            value: '$totalCompletedDays',
            icon: Icons.check_circle_rounded,
            color: AppColors.accentEmerald,
            isDark: isDark,
          ),
          _buildSummaryItem(
            label: 'Completion',
            value: '$percentage%',
            icon: Icons.percent_rounded,
            color: AppColors.primaryLight,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDateDetails(
    List<HabitModel> allHabits,
    List<CompletionModel> allCompletions,
    bool isDark,
  ) {
    final activeHabits = _selectedHabitId != null
        ? allHabits.where((h) => h.id == _selectedHabitId).toList()
        : allHabits.where((h) => h.isActive).toList();

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final scheduledHabits = activeHabits
        .where((h) => h.isScheduledForDate(_selectedDate))
        .toList();
    final completedHabitIds = allCompletions
        .where((c) => c.date == dateStr && c.status == 'completed')
        .map((c) => c.habitId)
        .toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (scheduledHabits.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
            child: const Center(
              child: Text(
                'Rest Day — No habits scheduled for this day.',
                style: TextStyle(fontSize: 13),
              ),
            ),
          )
        else
          ...scheduledHabits.map((habit) {
            final isDone = completedHabitIds.contains(habit.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isDone
                        ? AppColors.accentEmerald
                        : AppColors.accentRose,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      habit.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  Text(
                    isDone ? 'Completed' : 'Missed / Pending',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDone
                          ? AppColors.accentEmerald
                          : AppColors.accentRose,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
