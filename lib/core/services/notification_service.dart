import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/launcher_icon');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await _localNotificationsPlugin.initialize(
        initializationSettings,
      );
      debugPrint('NotificationService initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing NotificationService: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      if (Platform.isIOS) {
        final bool? result = await _localNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            );
        return result ?? false;
      } else if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        return status.isGranted;
      }
    } catch (e) {
      debugPrint('Error requesting notifications permission: $e');
    }
    return false;
  }

  Future<void> scheduleReminders() async {
    try {
      // Cancel any existing reminders to prevent duplicates
      await _localNotificationsPlugin.cancelAll();

      // 1. Daily logging reminder (Periodically scheduled every day)
      const AndroidNotificationDetails androidDailyDetails = AndroidNotificationDetails(
        'daily_reminder_channel',
        'Daily Reminders',
        channelDescription: 'Reminders to log daily expenses and keep budgets updated',
        importance: Importance.max,
        priority: Priority.high,
      );
      const DarwinNotificationDetails iosDailyDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const NotificationDetails dailyDetails = NotificationDetails(
        android: androidDailyDetails,
        iOS: iosDailyDetails,
      );
      
      await _localNotificationsPlugin.periodicallyShow(
        101,
        'Log your expenses! 📱',
        'Keep your budget on track by logging today\'s transactions.',
        RepeatInterval.daily,
        dailyDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      // 2. Weekly review reminder (Periodically scheduled every week)
      const AndroidNotificationDetails androidWeeklyDetails = AndroidNotificationDetails(
        'weekly_reminder_channel',
        'Weekly Reminders',
        channelDescription: 'Weekly reviews for saving progress and analytics',
        importance: Importance.max,
        priority: Priority.high,
      );
      const DarwinNotificationDetails iosWeeklyDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const NotificationDetails weeklyDetails = NotificationDetails(
        android: androidWeeklyDetails,
        iOS: iosWeeklyDetails,
      );

      await _localNotificationsPlugin.periodicallyShow(
        102,
        'Weekly Review 📊',
        'Let\'s see how much you saved this week! Open analytics to view.',
        RepeatInterval.weekly,
        weeklyDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('Periodic notification reminders scheduled successfully.');
    } catch (e) {
      debugPrint('Error scheduling notification reminders: $e');
    }
  }

  Future<void> showInstantNotification(String title, String body) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'instant_notification_channel',
        'Instant Alerts',
        channelDescription: 'Real-time alert notifications',
        importance: Importance.max,
        priority: Priority.high,
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _localNotificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        details,
      );
      debugPrint('Instant notification pushed: "$title" - "$body"');
    } catch (e) {
      debugPrint('Error showing instant notification: $e');
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
