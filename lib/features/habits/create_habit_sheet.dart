import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/enums/task_enums.dart';
import '../../core/providers/app_providers.dart';
import '../../models/habit_model.dart';

class CreateHabitSheet extends ConsumerStatefulWidget {
  final HabitModel? initialHabit; // For edit mode

  const CreateHabitSheet({super.key, this.initialHabit});

  @override
  ConsumerState<CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends ConsumerState<CreateHabitSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _targetValueController;

  late TaskType _selectedType;
  late FrequencyType _selectedFrequency;
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5}; // Mon-Fri default
  String _targetUnit = 'km';
  TimeOfDay? _reminderTime;
  TimeOfDay? _wakeTime;
  bool _enableReminder = false;
  late int _selectedColor;
  late String _selectedIcon;

  bool _isSaving = false;
  bool _isSaveSuccess = false;
  String? _customValidationError;

  // Checklist items
  final List<TextEditingController> _checklistControllers = [];

  final List<String> _iconOptions = [
    'star',
    'fitness',
    'book',
    'directions_run',
    'water_drop',
    'bedtime',
    'alarm',
    'work',
    'code',
    'self_improvement',
  ];

  @override
  void initState() {
    super.initState();
    final h = widget.initialHabit;

    _titleController = TextEditingController(text: h?.title ?? '');
    _descController = TextEditingController(text: h?.description ?? '');
    _selectedType = h?.taskType ?? TaskType.habit;
    _selectedFrequency = h?.frequencyType ?? FrequencyType.daily;

    if (h != null && h.scheduledWeekdays.isNotEmpty) {
      _selectedWeekdays.clear();
      _selectedWeekdays.addAll(h.scheduledWeekdays);
    }

    _targetValueController = TextEditingController(
      text: h?.targetValue != null
          ? (h!.targetValue! == h.targetValue!.roundToDouble()
              ? h.targetValue!.toInt().toString()
              : h.targetValue!.toStringAsFixed(1))
          : (_selectedType == TaskType.distance ? '2.0' : '30'),
    );
    _targetUnit = h?.targetUnit ?? (_selectedType == TaskType.distance ? 'km' : 'minutes');

    if (h?.reminderTime != null && h!.reminderTime!.isNotEmpty) {
      final parts = h.reminderTime!.split(':');
      if (parts.length == 2) {
        _reminderTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
        _enableReminder = true;
      }
    }

    if (h?.wakeTime != null && h!.wakeTime!.isNotEmpty) {
      final parts = h.wakeTime!.split(':');
      if (parts.length == 2) {
        _wakeTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    } else {
      _wakeTime = const TimeOfDay(hour: 6, minute: 0);
    }

    _selectedColor = h?.colorValue ?? AppColors.primary.toARGB32();
    _selectedIcon = h?.iconName ?? 'star';

    if (h != null && h.checklistItems.isNotEmpty) {
      for (final item in h.checklistItems) {
        _checklistControllers.add(TextEditingController(text: item.title));
      }
    } else if (_selectedType == TaskType.checklist) {
      _checklistControllers.add(TextEditingController(text: 'Step 1'));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _targetValueController.dispose();
    for (final c in _checklistControllers) {
      c.dispose();
    }
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

  bool _validateCustomFields() {
    setState(() => _customValidationError = null);

    if (_selectedFrequency == FrequencyType.specificDays && _selectedWeekdays.isEmpty) {
      setState(() => _customValidationError = 'Please select at least one day.');
      return false;
    }

    if (_selectedType == TaskType.checklist) {
      final validItems = _checklistControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (validItems.isEmpty) {
        setState(() => _customValidationError = 'Please add at least one checklist item.');
        return false;
      }
    }

    if (_selectedType == TaskType.distance) {
      final val = double.tryParse(_targetValueController.text.trim());
      if (val == null || val <= 0) {
        setState(() => _customValidationError = 'Distance must be greater than 0.');
        return false;
      }
    }

    if (_selectedType == TaskType.duration) {
      final val = double.tryParse(_targetValueController.text.trim());
      if (val == null || val <= 0) {
        setState(() => _customValidationError = 'Duration must be greater than 0.');
        return false;
      }
    }

    return true;
  }

  Future<void> _saveHabit() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) return;
    if (!_validateCustomFields()) return;

    setState(() => _isSaving = true);

    try {
      final habitRepo = ref.read(habitRepositoryProvider);
      final notifService = ref.read(notificationServiceProvider);

      final habitId = widget.initialHabit?.id ?? const Uuid().v4();
      final double? targetVal = double.tryParse(_targetValueController.text.trim());

      String? reminderStr;
      if (_enableReminder && _reminderTime != null) {
        reminderStr =
            '${_reminderTime!.hour.toString().padLeft(2, '0')}:${_reminderTime!.minute.toString().padLeft(2, '0')}';
      }

      String? wakeStr;
      if (_selectedType == TaskType.wakeUp && _wakeTime != null) {
        wakeStr =
            '${_wakeTime!.hour.toString().padLeft(2, '0')}:${_wakeTime!.minute.toString().padLeft(2, '0')}';
      }

      final List<ChecklistItemModel> items = [];
      if (_selectedType == TaskType.checklist) {
        for (int i = 0; i < _checklistControllers.length; i++) {
          final text = _checklistControllers[i].text.trim();
          if (text.isNotEmpty) {
            items.add(ChecklistItemModel(
              id: const Uuid().v4(),
              habitId: habitId,
              title: text,
              isCompleted: false,
              sortOrder: i,
            ));
          }
        }
      }

      final habit = HabitModel(
        id: habitId,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        taskType: _selectedType,
        frequencyType: _selectedFrequency,
        targetValue: (_selectedType == TaskType.distance || _selectedType == TaskType.duration)
            ? targetVal
            : null,
        targetUnit: (_selectedType == TaskType.distance || _selectedType == TaskType.duration)
            ? _targetUnit
            : null,
        reminderTime: reminderStr,
        wakeTime: wakeStr,
        isActive: widget.initialHabit?.isActive ?? true,
        colorValue: _selectedColor,
        iconName: _selectedIcon,
        currentStreak: widget.initialHabit?.currentStreak ?? 0,
        bestStreak: widget.initialHabit?.bestStreak ?? 0,
        createdAt: widget.initialHabit?.createdAt ?? DateTime.now(),
        scheduledWeekdays: _selectedFrequency == FrequencyType.specificDays
            ? _selectedWeekdays.toList()
            : const [],
        checklistItems: items,
      );

      if (widget.initialHabit == null) {
        await habitRepo.createHabit(habit);
      } else {
        await habitRepo.updateHabit(habit);
      }

      // Schedule or Cancel Reminders via NotificationService
      try {
        if (_selectedType == TaskType.wakeUp && _wakeTime != null) {
          await notifService.scheduleWakeUpAlarm(
            habitId: habitId,
            hour: _wakeTime!.hour,
            minute: _wakeTime!.minute,
          );
        } else if (_enableReminder && _reminderTime != null) {
          await notifService.scheduleHabitReminder(
            habitId: habitId,
            title: habit.title,
            description: habit.description,
            hour: _reminderTime!.hour,
            minute: _reminderTime!.minute,
            frequencyType: habit.frequencyType,
            scheduledWeekdays: habit.scheduledWeekdays,
          );
        } else {
          await notifService.cancelHabitNotifications(habitId);
        }
      } catch (e) {
        if (kDebugMode) print('Notification scheduling warning: $e');
      }

      if (mounted) {
        setState(() => _isSaveSuccess = true);
        await Future.delayed(const Duration(milliseconds: 250));
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.initialHabit == null
                          ? (_enableReminder
                              ? '✓ Habit created (Reminder: ${DateFormat.jm().format(DateTime(2026, 1, 1, _reminderTime!.hour, _reminderTime!.minute))})'
                              : '✓ Habit created')
                          : '✓ Habit updated',
                    ),
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
    } catch (e) {
      if (kDebugMode) print('Save habit error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save habit. Please try again.'),
            backgroundColor: AppColors.accentRose,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialHabit == null ? 'Create Habit' : 'Edit Habit',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Form fields in SingleChildScrollView
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Inline Custom Error Message
                    if (_customValidationError != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.accentRose.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.accentRose.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.accentRose, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _customValidationError!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentRose,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Title Field
                    const Text('Title *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Read Book, Run 2 km, Morning Routine',
                        counterText: '',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a habit name.';
                        }
                        if (val.trim().length < 2) {
                          return 'Title must be at least 2 characters.';
                        }
                        if (val.trim().length > 100) {
                          return 'Title cannot exceed 100 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Description Field
                    const Text('Description (Optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLength: 250,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Read 20 pages every morning',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Habit Type Selector (Habit, Duration, Distance, Checklist, Wake Up)
                    const Text('Task Type', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TaskType.values.map((type) {
                        final isSelected = _selectedType == type;
                        return ChoiceChip(
                          label: Text(type.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedType = type;
                                if (type == TaskType.distance) {
                                  _targetUnit = 'km';
                                  _targetValueController.text = '2.0';
                                } else if (type == TaskType.duration) {
                                  _targetUnit = 'minutes';
                                  _targetValueController.text = '30';
                                } else if (type == TaskType.checklist && _checklistControllers.isEmpty) {
                                  _checklistControllers.add(TextEditingController(text: 'Step 1'));
                                }
                              });
                            }
                          },
                          selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Dynamic Configurations based on Type
                    if (_selectedType == TaskType.distance) ...[
                      const Text('Target Distance *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _targetValueController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: '2.0'),
                              validator: (val) {
                                final d = double.tryParse(val?.trim() ?? '');
                                if (d == null || d <= 0) return 'Distance must be > 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _targetUnit,
                            items: const [
                              DropdownMenuItem(value: 'km', child: Text('Kilometers (km)')),
                              DropdownMenuItem(value: 'miles', child: Text('Miles')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _targetUnit = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (_selectedType == TaskType.duration) ...[
                      const Text('Target Duration *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _targetValueController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: '30'),
                              validator: (val) {
                                final d = double.tryParse(val?.trim() ?? '');
                                if (d == null || d <= 0) return 'Duration must be > 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButton<String>(
                            value: _targetUnit,
                            items: const [
                              DropdownMenuItem(value: 'minutes', child: Text('Minutes')),
                              DropdownMenuItem(value: 'hours', child: Text('Hours')),
                              DropdownMenuItem(value: 'seconds', child: Text('Seconds (Dev/Test)')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _targetUnit = val);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (_selectedType == TaskType.wakeUp) ...[
                      const Text('Wake-up Time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        leading: const Icon(Icons.alarm_rounded, color: AppColors.accentOrange),
                        title: Text(
                          _wakeTime != null
                              ? DateFormat.jm().format(
                                  DateTime(2026, 1, 1, _wakeTime!.hour, _wakeTime!.minute))
                              : 'Set Wake-up Time',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _wakeTime ?? const TimeOfDay(hour: 6, minute: 0),
                          );
                          if (picked != null) setState(() => _wakeTime = picked);
                        },
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (_selectedType == TaskType.checklist) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Checklist Items *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _checklistControllers.add(TextEditingController());
                              });
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add Step'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._checklistControllers.asMap().entries.map((entry) {
                        final index = entry.key;
                        final controller = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: controller,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Step ${index + 1}',
                                    prefixIcon: const Icon(Icons.check_box_outline_blank_rounded, size: 20),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: AppColors.accentRose),
                                onPressed: () {
                                  setState(() {
                                    _checklistControllers.removeAt(index);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 18),
                    ],

                    // Frequency Selector
                    const Text('Frequency', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Daily')),
                            selected: _selectedFrequency == FrequencyType.daily,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedFrequency = FrequencyType.daily);
                            },
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Specific Days')),
                            selected: _selectedFrequency == FrequencyType.specificDays,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedFrequency = FrequencyType.specificDays);
                            },
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Specific Weekdays Chips
                    if (_selectedFrequency == FrequencyType.specificDays) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildWeekdayChip(1, 'M'),
                          _buildWeekdayChip(2, 'T'),
                          _buildWeekdayChip(3, 'W'),
                          _buildWeekdayChip(4, 'T'),
                          _buildWeekdayChip(5, 'F'),
                          _buildWeekdayChip(6, 'S'),
                          _buildWeekdayChip(7, 'S'),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Optional Daily Reminder Setting (For any task)
                    if (_selectedType != TaskType.wakeUp) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : AppColors.lightCardElevated,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 20),
                                    const SizedBox(width: 8),
                                    const Text('Reminder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  ],
                                ),
                                Switch(
                                  value: _enableReminder,
                                  onChanged: (val) async {
                                    if (val && _reminderTime == null) {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: const TimeOfDay(hour: 20, minute: 0),
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _reminderTime = picked;
                                          _enableReminder = true;
                                        });
                                      }
                                    } else {
                                      setState(() => _enableReminder = val);
                                    }
                                  },
                                ),
                              ],
                            ),
                            if (_enableReminder && _reminderTime != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '🔔 ${DateFormat.jm().format(DateTime(2026, 1, 1, _reminderTime!.hour, _reminderTime!.minute))}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                                  ),
                                  TextButton.icon(
                                    onPressed: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _reminderTime ?? const TimeOfDay(hour: 20, minute: 0),
                                      );
                                      if (picked != null) setState(() => _reminderTime = picked);
                                    },
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const Text('Change time'),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Text(
                                'No reminder',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Icon & Color Selection
                    const Text('Icon & Color', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _iconOptions.map((iconName) {
                          final isSelected = _selectedIcon == iconName;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => setState(() => _selectedIcon = iconName),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(_selectedColor).withValues(alpha: 0.2)
                                      : (isDark ? AppColors.darkCard : AppColors.lightCardElevated),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? Color(_selectedColor)
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Icon(
                                  _getIconData(iconName),
                                  color: isSelected ? Color(_selectedColor) : null,
                                  size: 22,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Color Palette
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: AppColors.habitColors.map((color) {
                        final isSelected = _selectedColor == color.toARGB32();
                        return InkWell(
                          onTap: () => setState(() => _selectedColor = color.toARGB32()),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Action Button Container (Always accessible)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveHabit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaveSuccess
                      ? AppColors.accentEmerald
                      : AppColors.primary,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text('Creating...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      )
                    : (_isSaveSuccess
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 8),
                              Text('Habit created ✓', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            ],
                          )
                        : Text(
                            widget.initialHabit == null ? 'CREATE HABIT' : 'SAVE CHANGES',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayChip(int weekday, String label) {
    final isSelected = _selectedWeekdays.contains(weekday);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedWeekdays.add(weekday);
          } else {
            if (_selectedWeekdays.length > 1) {
              _selectedWeekdays.remove(weekday);
            }
          }
        });
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    );
  }
}
