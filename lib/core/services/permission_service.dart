import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestNotificationPermission(BuildContext? context) async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    if (result.isPermanentlyDenied && context != null && context.mounted) {
      _showSettingsDialog(
        context,
        title: 'Notification Permission Required',
        message: 'Enable notifications to receive habit reminders and morning wake-up alerts.',
      );
    }
    return result.isGranted;
  }

  static Future<bool> requestLocationPermission(BuildContext context) async {
    final status = await Permission.location.status;
    if (status.isGranted) return true;

    final result = await Permission.location.request();
    if (result.isPermanentlyDenied && context.mounted) {
      _showSettingsDialog(
        context,
        title: 'Location Permission Required',
        message: 'Location is required to track your running/walking distance in real time.',
      );
    }
    return result.isGranted;
  }

  static Future<bool> isLocationGranted() async {
    return await Permission.location.isGranted;
  }

  static void _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
