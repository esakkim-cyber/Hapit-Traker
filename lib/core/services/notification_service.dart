import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../enums/task_enums.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  String _currentTimeZone = 'UTC';

  // Versioned Channel IDs (guarantees clean, non-cached channel creation on Android with full sound & vibration)
  static const String reminderChannelId = 'habit_reminders_v4';
  static const String reminderChannelName = 'HabitForge Reminders';
  static const String reminderChannelDesc =
      'High-priority sound alerts for daily habit reminders';

  static const String alarmChannelId = 'wake_up_alarms_v4';
  static const String alarmChannelName = 'HabitForge Wake Up';
  static const String alarmChannelDesc =
      'Loud wake-up alarm notifications with vibration';

  static const String timerChannelId = 'timer_completion_v4';
  static const String timerChannelName = 'HabitForge Timers';
  static const String timerChannelDesc =
      'Completion sound alerts for countdown timers and GPS sessions';

  static const String trackingChannelId = 'live_tracking_v4';
  static const String trackingChannelName = 'Live Activity Tracking';
  static const String trackingChannelDesc =
      'Ongoing GPS and focus timer background status';

  // Vibration patterns (web-safe: plain List<int> avoids Int64List/dart:ffi web incompatibility)
  static final List<int> _reminderVibration = <int>[0, 500, 200, 500];
  static final List<int> _alarmVibration = <int>[0, 1000, 500, 1000, 500, 1000];

  bool get isInitialized => _isInitialized;
  String get currentTimeZoneName => _currentTimeZone;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[HabitForge] NotificationService: Initializing...');

      // 1. Initialize Timezone database
      tz.initializeTimeZones();

      // 2. Resolve and configure device local timezone
      try {
        final String detectedTimezone =
            await FlutterTimezone.getLocalTimezone();
        _currentTimeZone = detectedTimezone;
        try {
          tz.setLocalLocation(tz.getLocation(detectedTimezone));
          debugPrint(
            '[HabitForge] NotificationService: Device timezone configured -> $detectedTimezone',
          );
        } catch (tzError) {
          debugPrint(
            '[HabitForge] NotificationService: tz.getLocation failed for $detectedTimezone, using fallback: $tzError',
          );
          final fallbackLocation =
              tz.timeZoneDatabase.locations[detectedTimezone] ??
              tz.timeZoneDatabase.locations.values.first;
          tz.setLocalLocation(fallbackLocation);
        }
      } catch (e) {
        debugPrint(
          '[HabitForge] NotificationService: FlutterTimezone detection error -> $e',
        );
      }

      // 3. Platform Initialization Settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings darwinSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
            '[HabitForge] NotificationService: Notification tapped payload -> ${response.payload}',
          );
        },
      );

      // 4. Explicitly create Android Notification Channels with MAX importance, sound, and vibration
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          // Channel 1: Habit Reminders (HIGH/MAX importance, sound, vibration, lights, badge)
          await androidPlugin.createNotificationChannel(
            AndroidNotificationChannel(
              reminderChannelId,
              reminderChannelName,
              description: reminderChannelDesc,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              vibrationPattern: _reminderVibration,
              enableLights: true,
              showBadge: true,
              audioAttributesUsage: AudioAttributesUsage.notification,
            ),
          );

          // Channel 2: Wake-Up Alarms (MAX importance, alarm audio stream, long vibration, full-screen intent)
          await androidPlugin.createNotificationChannel(
            AndroidNotificationChannel(
              alarmChannelId,
              alarmChannelName,
              description: alarmChannelDesc,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              vibrationPattern: _alarmVibration,
              enableLights: true,
              showBadge: true,
              audioAttributesUsage: AudioAttributesUsage.alarm,
            ),
          );

          // Channel 3: Timers & Duration Completion
          await androidPlugin.createNotificationChannel(
            AndroidNotificationChannel(
              timerChannelId,
              timerChannelName,
              description: timerChannelDesc,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              vibrationPattern: _reminderVibration,
              showBadge: true,
              audioAttributesUsage: AudioAttributesUsage.notification,
            ),
          );

          // Channel 4: Live Activity Tracking (Low importance, silent ongoing)
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              trackingChannelId,
              trackingChannelName,
              description: trackingChannelDesc,
              importance: Importance.low,
              playSound: false,
              enableVibration: false,
              showBadge: false,
            ),
          );

          debugPrint(
            '[HabitForge] NotificationService: Android notification channels created successfully.',
          );
        }
      }

      _isInitialized = true;
      debugPrint(
        '[HabitForge] NotificationService: Initialization complete. Local time: ${tz.TZDateTime.now(tz.local)}',
      );
    } catch (e, stack) {
      debugPrint(
        '[HabitForge] NotificationService ERROR initializing notifications: $e\n$stack',
      );
    }
  }

  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        debugPrint(
          '[HabitForge] POST_NOTIFICATIONS permission request result: $granted',
        );
        return granted ?? false;
      }
    }
    return true;
  }

  Future<bool> checkPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final areEnabled = await androidPlugin.areNotificationsEnabled();
        return areEnabled ?? false;
      }
    }
    return true;
  }

  Future<bool> requestExactAlarmsPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestExactAlarmsPermission();
        debugPrint(
          '[HabitForge] Exact alarms permission request result: $granted',
        );
        return granted ?? false;
      }
    }
    return true;
  }

  Future<bool> checkExactAlarmPermissionStatus() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final granted = await androidPlugin.checkExactAlarmPermission();
        debugPrint(
          '[HabitForge] Exact alarm permission check result: $granted',
        );
        return granted ?? false;
      }
    }
    return true;
  }

  // Generate deterministic 32-bit positive integer notification ID
  static int getNotificationId(String habitId) {
    var hash = 0;
    for (var i = 0; i < habitId.length; i++) {
      hash = (hash * 31 + habitId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    return (hash % 1000000) + 1000;
  }

  // Schedule a habit reminder (supports DAILY and SPECIFIC_DAYS)
  Future<bool> scheduleHabitReminder({
    required String habitId,
    required String title,
    String? description,
    required int hour,
    required int minute,
    required FrequencyType frequencyType,
    List<int> scheduledWeekdays = const [],
  }) async {
    try {
      if (!_isInitialized) await initialize();

      // 1. Cancel previous notifications for this habit
      await cancelHabitNotifications(habitId);

      final baseId = getNotificationId(habitId);
      final notifTitle = 'HabitForge 🔔';
      final notifBody = description != null && description.isNotEmpty
          ? 'Time to complete $title — $description'
          : 'Time to complete $title';

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            reminderChannelId,
            reminderChannelName,
            channelDescription: reminderChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            vibrationPattern: _reminderVibration,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          );

      final now = tz.TZDateTime.now(tz.local);

      if (frequencyType == FrequencyType.daily || scheduledWeekdays.isEmpty) {
        // Daily Reminder
        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        );

        if (scheduledDate.isBefore(now) ||
            scheduledDate.isAtSameMomentAs(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        debugPrint(
          '[HabitForge] Scheduling DAILY reminder: "$title" (ID: $baseId) at $scheduledDate (local: $now)',
        );

        try {
          await _notificationsPlugin.zonedSchedule(
            baseId,
            notifTitle,
            notifBody,
            scheduledDate,
            NotificationDetails(android: androidDetails),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: '{"habitId": "$habitId", "type": "reminder"}',
          );
          debugPrint(
            '[HabitForge] ✓ Successfully scheduled daily reminder ID: $baseId with exactAllowWhileIdle',
          );
        } catch (exactError) {
          debugPrint(
            '[HabitForge] exactAllowWhileIdle fallback to inexact: $exactError',
          );
          await _notificationsPlugin.zonedSchedule(
            baseId,
            notifTitle,
            notifBody,
            scheduledDate,
            NotificationDetails(android: androidDetails),
            androidScheduleMode: AndroidScheduleMode.inexact,
            matchDateTimeComponents: DateTimeComponents.time,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: '{"habitId": "$habitId", "type": "reminder"}',
          );
          debugPrint(
            '[HabitForge] ✓ Successfully scheduled daily reminder ID: $baseId with inexact',
          );
        }
      } else {
        // Specific Weekdays Reminder (1=Monday ... 7=Sunday)
        for (final weekday in scheduledWeekdays) {
          final notifId = baseId + (weekday * 100000);
          var scheduledDate = tz.TZDateTime(
            tz.local,
            now.year,
            now.month,
            now.day,
            hour,
            minute,
          );

          // Find the next occurrence of this weekday
          while (scheduledDate.weekday != weekday ||
              scheduledDate.isBefore(now) ||
              scheduledDate.isAtSameMomentAs(now)) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          debugPrint(
            '[HabitForge] Scheduling WEEKDAY ($weekday) reminder: "$title" (ID: $notifId) at $scheduledDate',
          );

          try {
            await _notificationsPlugin.zonedSchedule(
              notifId,
              notifTitle,
              notifBody,
              scheduledDate,
              NotificationDetails(android: androidDetails),
              androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: '{"habitId": "$habitId", "type": "reminder"}',
            );
          } catch (exactError) {
            debugPrint(
              '[HabitForge] exact weekday fallback to inexact: $exactError',
            );
            await _notificationsPlugin.zonedSchedule(
              notifId,
              notifTitle,
              notifBody,
              scheduledDate,
              NotificationDetails(android: androidDetails),
              androidScheduleMode: AndroidScheduleMode.inexact,
              matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
              uiLocalNotificationDateInterpretation:
                  UILocalNotificationDateInterpretation.absoluteTime,
              payload: '{"habitId": "$habitId", "type": "reminder"}',
            );
          }
        }
      }

      return true;
    } catch (e, stack) {
      debugPrint('[HabitForge] ERROR in scheduleHabitReminder: $e\n$stack');
      return false;
    }
  }

  // Schedule Wake-Up Alarm notification (uses dedicated alarm channel, alarm audio stream, max priority)
  Future<bool> scheduleWakeUpAlarm({
    required String habitId,
    required int hour,
    required int minute,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      await cancelHabitNotifications(habitId);

      final notifId = getNotificationId(habitId);
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            alarmChannelId,
            alarmChannelName,
            channelDescription: alarmChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            fullScreenIntent: true,
            enableVibration: true,
            vibrationPattern: _alarmVibration,
            playSound: true,
            visibility: NotificationVisibility.public,
          );

      debugPrint(
        '[HabitForge] Scheduling WAKE UP alarm (ID: $notifId) at $scheduledDate (alarm channel with sound & vibration)',
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          notifId,
          '🌅 HabitForge Wake Up',
          'Good morning! Time to wake up and start your routine.',
          scheduledDate,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: '{"habitId": "$habitId", "type": "wakeUp"}',
        );
      } catch (exactError) {
        debugPrint(
          '[HabitForge] wakeUpAlarm exactAllowWhileIdle fallback to inexact: $exactError',
        );
        await _notificationsPlugin.zonedSchedule(
          notifId,
          '🌅 HabitForge Wake Up',
          'Good morning! Time to wake up and start your routine.',
          scheduledDate,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.time,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: '{"habitId": "$habitId", "type": "wakeUp"}',
        );
      }
      return true;
    } catch (e, stack) {
      debugPrint('[HabitForge] ERROR in scheduleWakeUpAlarm: $e\n$stack');
      return false;
    }
  }

  // Developer Test 1: Normal Notification with Sound (10 seconds from now)
  Future<bool> scheduleTestNotification10Seconds() async {
    try {
      if (!_isInitialized) await initialize();

      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(const Duration(seconds: 10));

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            reminderChannelId,
            reminderChannelName,
            channelDescription: reminderChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            vibrationPattern: _reminderVibration,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          );

      debugPrint(
        '[HabitForge] Scheduling 10-second test reminder (ID: 77777) at $scheduledDate',
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          77777,
          'HabitForge 🔔',
          'This is a test notification with sound and vibration.',
          scheduledDate,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('[HabitForge] 10s test notification fallback: $e');
        await _notificationsPlugin.zonedSchedule(
          77777,
          'HabitForge 🔔',
          'This is a test notification with sound and vibration.',
          scheduledDate,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      debugPrint(
        '[HabitForge] ✓ 10-second test notification scheduled successfully!',
      );
      return true;
    } catch (e, stack) {
      debugPrint(
        '[HabitForge] ERROR in scheduleTestNotification10Seconds: $e\n$stack',
      );
      return false;
    }
  }

  // Developer Test 2: Wake-Up Alarm with Audible Sound & Alarm Stream (15 seconds from now)
  Future<bool> scheduleTestWakeUpAlarm15Seconds() async {
    try {
      if (!_isInitialized) await initialize();

      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = now.add(const Duration(seconds: 15));

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            alarmChannelId,
            alarmChannelName,
            channelDescription: alarmChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            fullScreenIntent: true,
            enableVibration: true,
            vibrationPattern: _alarmVibration,
            playSound: true,
            visibility: NotificationVisibility.public,
          );

      debugPrint(
        '[HabitForge] Scheduling 15-second WAKE-UP ALARM test (ID: 88888) at $scheduledDate',
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          88888,
          '🌅 HabitForge Wake Up',
          'Good morning! Test wake-up alarm is ringing with sound.',
          scheduledDate,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint('[HabitForge] 15s wake-up alarm test fallback: $e');
        await _notificationsPlugin.zonedSchedule(
          88888,
          '🌅 HabitForge Wake Up',
          'Good morning! Test wake-up alarm is ringing with sound.',
          scheduledDate,
          NotificationDetails(android: androidDetails),
          androidScheduleMode: AndroidScheduleMode.inexact,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }

      debugPrint(
        '[HabitForge] ✓ 15-second wake-up alarm scheduled successfully!',
      );
      return true;
    } catch (e, stack) {
      debugPrint(
        '[HabitForge] ERROR in scheduleTestWakeUpAlarm15Seconds: $e\n$stack',
      );
      return false;
    }
  }

  // Developer Test 3: Instant Audible Notification
  Future<void> triggerImmediateSoundAndVibrationTest() async {
    try {
      if (!_isInitialized) await initialize();

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            reminderChannelId,
            reminderChannelName,
            channelDescription: reminderChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            vibrationPattern: _reminderVibration,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          );

      await _notificationsPlugin.show(
        99999,
        'HabitForge 🔔 Sound & Vibration Test',
        'If you hear sound and feel vibration, audio channels are working perfectly!',
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint(
        '[HabitForge] triggerImmediateSoundAndVibrationTest error: $e',
      );
    }
  }

  // Show Timer Completion Alert (Loud sound + vibration)
  Future<void> showTimerCompletionNotification({
    required String title,
    required String message,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            timerChannelId,
            timerChannelName,
            channelDescription: timerChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            vibrationPattern: _reminderVibration,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
            category: AndroidNotificationCategory.event,
            visibility: NotificationVisibility.public,
          );

      await _notificationsPlugin.show(
        9001,
        title,
        message,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('[HabitForge] showTimerCompletionNotification error: $e');
    }
  }

  // Show Distance Run/Walk Completion Alert (Loud sound + vibration)
  Future<void> showDistanceCompletionNotification({
    required String title,
    required String message,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            timerChannelId,
            timerChannelName,
            channelDescription: timerChannelDesc,
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            vibrationPattern: _reminderVibration,
            playSound: true,
            audioAttributesUsage: AudioAttributesUsage.notification,
            category: AndroidNotificationCategory.event,
            visibility: NotificationVisibility.public,
          );

      await _notificationsPlugin.show(
        9002,
        title,
        message,
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('[HabitForge] showDistanceCompletionNotification error: $e');
    }
  }

  // Show ongoing tracking notification (for live GPS & Timer countdown)
  Future<void> showTrackingNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    try {
      if (!_isInitialized) await initialize();

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            trackingChannelId,
            trackingChannelName,
            channelDescription: trackingChannelDesc,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            showWhen: false,
          );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('[HabitForge] showTrackingNotification error: $e');
    }
  }

  // Cancel all notifications for a specific habit
  Future<void> cancelHabitNotifications(String habitId) async {
    try {
      final baseId = getNotificationId(habitId);
      debugPrint(
        '[HabitForge] Cancelling habit notifications for $habitId (baseId: $baseId)',
      );
      await _notificationsPlugin.cancel(baseId);
      // Also cancel any weekday-specific slots (1..7)
      for (int day = 1; day <= 7; day++) {
        await _notificationsPlugin.cancel(baseId + (day * 100000));
      }
    } catch (e) {
      debugPrint('[HabitForge] cancelHabitNotifications error: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      debugPrint('[HabitForge] Cancelling notification ID: $id');
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('[HabitForge] cancelNotification error: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      debugPrint('[HabitForge] getPendingNotifications error: $e');
      return [];
    }
  }

  Future<void> cancelAll() async {
    try {
      debugPrint('[HabitForge] Cancelling all notifications');
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('[HabitForge] cancelAll error: $e');
    }
  }
}
