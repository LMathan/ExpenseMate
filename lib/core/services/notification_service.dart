import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> scheduleReminders() async {
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
    const NotificationDetails dailyDetails = NotificationDetails(android: androidDailyDetails);
    
    await _localNotificationsPlugin.periodicallyShow(
      101,
      'Log your expenses! 📱',
      'Keep your budget on track by logging today\'s transactions.',
      RepeatInterval.daily,
      dailyDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );

    // 2. Weekly review reminder (Periodically scheduled every week)
    const AndroidNotificationDetails androidWeeklyDetails = AndroidNotificationDetails(
      'weekly_reminder_channel',
      'Weekly Reminders',
      channelDescription: 'Weekly reviews for saving progress and analytics',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails weeklyDetails = NotificationDetails(android: androidWeeklyDetails);

    await _localNotificationsPlugin.periodicallyShow(
      102,
      'Weekly Review 📊',
      'Let\'s see how much you saved this week! Open analytics to view.',
      RepeatInterval.weekly,
      weeklyDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showInstantNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'instant_notification_channel',
      'Instant Alerts',
      channelDescription: 'Real-time alert notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    
    await _localNotificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
