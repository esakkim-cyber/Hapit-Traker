import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/constants/app_colors.dart';
import '../../core/enums/task_enums.dart';
import '../../core/providers/app_providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _overallNotifGranted = false;
  bool _exactAlarmGranted = false;
  bool _isLoading = true;
  String _timeZoneName = 'Unknown';
  List<PendingNotificationRequest> _pendingNotifications = [];

  @override
  void initState() {
    super.initState();
    _refreshDiagnostics();
  }

  Future<void> _refreshDiagnostics() async {
    setState(() => _isLoading = true);
    final notifService = ref.read(notificationServiceProvider);
    final notificationPermissionStatus = await Permission.notification.status;
    final exactAlarmPermissionGranted = await notifService
        .checkExactAlarmPermissionStatus();
    final pending = await notifService.getPendingNotifications();
    final tz = notifService.currentTimeZoneName;

    if (mounted) {
      setState(() {
        _overallNotifGranted = notificationPermissionStatus.isGranted;
        _exactAlarmGranted = exactAlarmPermissionGranted;
        _pendingNotifications = pending;
        _timeZoneName = tz;
        _isLoading = false;
      });
    }
  }

  Future<void> _togglePermission() async {
    if (!_overallNotifGranted) {
      final notifService = ref.read(notificationServiceProvider);
      final granted = await notifService.requestPermission();
      await _refreshDiagnostics();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              granted
                  ? '✓ Notifications allowed'
                  : 'Notifications permission denied',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nowFormatted = DateFormat('yyyy-MM-dd hh:mm:ss a')
        .format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications & Alarms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Diagnostics',
            onPressed: _refreshDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Master Permission Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (_overallNotifGranted
                                        ? AppColors.accentEmerald
                                        : AppColors.accentAmber)
                                    .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _overallNotifGranted
                                ? Icons.notifications_active_rounded
                                : Icons.notifications_off_outlined,
                            color: _overallNotifGranted
                                ? AppColors.accentEmerald
                                : AppColors.accentAmber,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _overallNotifGranted
                                    ? 'Notifications Active'
                                    : 'Notifications Disabled',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _overallNotifGranted
                                    ? 'Reminders & alarms will ring on schedule'
                                    : 'Enable permission to receive sound alerts',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _overallNotifGranted,
                          onChanged: (_) => _togglePermission(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Notification Diagnostics Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkCardElevated
                          : AppColors.lightCardElevated,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.analytics_outlined,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Notification & Sound Diagnostics',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _overallNotifGranted
                                    ? AppColors.accentEmerald.withValues(
                                        alpha: 0.15,
                                      )
                                    : AppColors.accentRose.withValues(
                                        alpha: 0.15,
                                      ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _overallNotifGranted
                                    ? 'READY'
                                    : 'ACTION NEEDED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: _overallNotifGranted
                                      ? AppColors.accentEmerald
                                      : AppColors.accentRose,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildDiagRow(
                          'POST_NOTIFICATIONS',
                          _overallNotifGranted ? 'GRANTED ✓' : 'DENIED ✕',
                          _overallNotifGranted
                              ? AppColors.accentEmerald
                              : AppColors.accentRose,
                        ),
                        _buildDiagRow(
                          'Reminder Channel (Sound & Vibrate)',
                          'MAX IMPORTANCE ✓',
                          AppColors.accentEmerald,
                        ),
                        _buildDiagRow(
                          'Wake-Up Alarm Channel',
                          'MAX IMPORTANCE (ALARM STREAM) ✓',
                          AppColors.accentEmerald,
                        ),
                        _buildDiagRow(
                          'Exact Alarms Status',
                          _exactAlarmGranted ? 'ENABLED ✓' : 'SYSTEM DEFAULT',
                          AppColors.primary,
                        ),
                        _buildDiagRow(
                          'Device Timezone',
                          _timeZoneName,
                          AppColors.secondary,
                        ),
                        _buildDiagRow(
                          'Current Local Time',
                          nowFormatted,
                          isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                        _buildDiagRow(
                          'Pending Android Alarms',
                          '${_pendingNotifications.length} scheduled in OS',
                          _pendingNotifications.isNotEmpty
                              ? AppColors.accentEmerald
                              : AppColors.accentAmber,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Developer Testing Suite (Active in Debug Mode)
                  if (kDebugMode) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.developer_mode_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Audio & Background Alarm Test Suite',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Test heads-up banners, sound playback, and vibration when app is open, backgrounded, or phone is locked.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        backgroundColor: AppColors.primary,
                                      ),
                                      onPressed: () async {
                                        final notifService = ref.read(
                                          notificationServiceProvider,
                                        );
                                        final success = await notifService
                                            .scheduleTestNotification10Seconds();
                                        await _refreshDiagnostics();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    success
                                                        ? '✓ 10-second reminder scheduled! Lock phone to test sound & vibration.'
                                                        : 'Failed to schedule test notification',
                                                  ),
                                                  backgroundColor: success
                                                      ? AppColors.accentEmerald
                                                      : AppColors.accentRose,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.flash_on_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'TEST (10s)',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        backgroundColor: AppColors.accentAmber,
                                        foregroundColor: Colors.black,
                                      ),
                                      onPressed: () async {
                                        final notifService = ref.read(
                                          notificationServiceProvider,
                                        );
                                        final success = await notifService
                                            .scheduleTestWakeUpAlarm15Seconds();
                                        await _refreshDiagnostics();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    success
                                                        ? '🌅 15-second Wake-Up Alarm scheduled! (Audible Alarm Stream)'
                                                        : 'Failed to schedule wake up alarm',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.accentEmerald,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.alarm_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'WAKE UP (15s)',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final notifService = ref.read(
                                          notificationServiceProvider,
                                        );
                                        await notifService
                                            .triggerImmediateSoundAndVibrationTest();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '✓ Immediate Sound & Vibration triggered!',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.accentEmerald,
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.volume_up_rounded,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'TEST SOUND NOW',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        foregroundColor: AppColors.accentRose,
                                      ),
                                      onPressed: () async {
                                        final notifService = ref.read(
                                          notificationServiceProvider,
                                        );
                                        await notifService.cancelNotification(
                                          77777,
                                        );
                                        await notifService.cancelNotification(
                                          88888,
                                        );
                                        await notifService.cancelNotification(
                                          99999,
                                        );
                                        await _refreshDiagnostics();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    '✓ Test alarms cancelled.',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                ),
                                              );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.cancel_outlined,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'CANCEL TESTS',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Pending Android System Scheduled Alarms Inspector
                  if (_pendingNotifications.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_send_rounded,
                          size: 18,
                          color: AppColors.accentEmerald,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Active System Alarms (${_pendingNotifications.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _pendingNotifications.length,
                      itemBuilder: (context, index) {
                        final req = _pendingNotifications[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.accentEmerald.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.accentEmerald.withValues(
                                    alpha: 0.15,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.accentEmerald,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      req.title ?? 'Habit Alert',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (req.body != null)
                                      Text(
                                        req.body!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                'ID: ${req.id}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Upcoming Scheduled Habits from Database
                  const Text(
                    'Habits with Reminders Enabled',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),

                  habitsAsync.when(
                    data: (habits) {
                      final reminderHabits = habits
                          .where(
                            (h) =>
                                h.isActive &&
                                (h.reminderEnabled || h.wakeTime != null),
                          )
                          .toList();

                      if (reminderHabits.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkCard
                                : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : AppColors.lightBorder,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'No habit reminders scheduled yet.\nEnable reminders when creating or editing a habit.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: reminderHabits.length,
                        itemBuilder: (context, index) {
                          final h = reminderHabits[index];
                          final timeStr = h.wakeTime ?? h.reminderTime ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(h.colorValue)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.alarm_rounded,
                                    color: Color(h.colorValue),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        h.title,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        h.frequencyType == FrequencyType.daily
                                            ? 'Every day at $timeStr'
                                            : 'Scheduled days at $timeStr',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Text('Error loading reminders: $e'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDiagRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
