import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math' as math;
import '../models/subscription_model.dart';
import '../models/bill_reminder_model.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> init() async {
    // 0. Initialize Timezone data
    tz.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('NotificationService: Local timezone initialized to $timeZoneName');
    } catch (e) {
      debugPrint('NotificationService: Error initializing timezone in init(): $e');
    }

    // 1. Initialize local notifications
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
      debugPrint('NotificationService: Local notifications initialized successfully.');
    } catch (e) {
      debugPrint('NotificationService: Error initializing local notifications: $e');
    }

    // 2. Initialize Firebase Cloud Messaging (FCM)
    try {
      // Register top-level background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request FCM permissions (primarily for iOS)
      final NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('FCM Permission authorization status: ${settings.authorizationStatus}');

      // Retrieve and print FCM token to console
      final String? token = await _firebaseMessaging.getToken();
      debugPrint('================= FCM TOKEN =================');
      debugPrint(token ?? 'Could not retrieve FCM token');
      debugPrint('=============================================');

      // Update token in Firestore if authenticated
      await updateFcmTokenInFirestore();

      // Listen for token refreshes
      _firebaseMessaging.onTokenRefresh.listen((refreshedToken) async {
        debugPrint('FCM Token refreshed: $refreshedToken');
        await updateFcmTokenInFirestore();
      });

      // Setup foreground messaging listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM: Foreground message received: ${message.messageId}');
        final notification = message.notification;
        final data = message.data;
        if (notification != null) {
          showInstantNotification(
            notification.title ?? 'Notification',
            notification.body ?? '',
          );
        } else if (data.containsKey('title') && data.containsKey('body')) {
          showInstantNotification(
            data['title']!,
            data['body']!,
          );
        }
      });

      // Handle notification clicks when the app is in the background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM: App opened from background via notification: ${message.messageId}');
      });

      // Handle notification click when the app is opened from a terminated state
      final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM: App opened from terminated state via notification: ${initialMessage.messageId}');
      }

      debugPrint('NotificationService: FCM initialized successfully.');
    } catch (e) {
      debugPrint('NotificationService: Error initializing FCM: $e');
    }

    // 3. Schedule funny notifications automatically on start
    await scheduleFunnyRandomNotifications();
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
      // Cancel daily (101) and weekly (102) reminders specifically, instead of cancelAll()
      await _localNotificationsPlugin.cancel(101);
      await _localNotificationsPlugin.cancel(102);

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
      // Also schedule funny notifications on refresh
      await scheduleFunnyRandomNotifications();
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

  Future<void> scheduleNotificationForDue({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);
      
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'due_reminders_channel',
        'Due Reminders',
        channelDescription: 'Reminders for bills and subscriptions due soon',
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
      
      await _localNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('NotificationService: Scheduled notification for $scheduledDate with ID $id');
    } catch (e) {
      debugPrint('NotificationService: Error scheduling notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _localNotificationsPlugin.cancel(id);
      debugPrint('NotificationService: Cancelled notification with ID $id');
    } catch (e) {
      debugPrint('NotificationService: Error cancelling notification $id: $e');
    }
  }

  Future<void> scheduleSubscriptionReminder(SubscriptionModel sub) async {
    final int notifId = sub.id.hashCode & 0x7FFFFFFF;
    await cancelNotification(notifId); // Cancel existing first to prevent duplicate
    
    if (!sub.reminderEnabled) return;
    
    // Schedule exactly 3 days before due date, at 9:00 AM local time
    final notificationTime = DateTime(
      sub.dueDate.year,
      sub.dueDate.month,
      sub.dueDate.day,
      9, 0, 0,
    ).subtract(const Duration(days: 3));
    
    if (notificationTime.isAfter(DateTime.now())) {
      await scheduleNotificationForDue(
        id: notifId,
        title: 'Subscription Renewal: ${sub.title} 💳',
        body: 'Your subscription of ₹${sub.amount.toStringAsFixed(0)} is renewing in 3 days.',
        scheduledDate: notificationTime,
      );
    }
  }

  Future<void> cancelSubscriptionReminder(String subId) async {
    final int notifId = subId.hashCode & 0x7FFFFFFF;
    await cancelNotification(notifId);
  }

  Future<void> scheduleBillReminder(BillReminderModel bill) async {
    final int notifId = bill.id.hashCode & 0x7FFFFFFF;
    await cancelNotification(notifId); // Cancel existing first to prevent duplicate
    
    if (bill.isPaid) return;
    
    // Schedule exactly 3 days before due date, at 9:00 AM local time
    final notificationTime = DateTime(
      bill.dueDate.year,
      bill.dueDate.month,
      bill.dueDate.day,
      9, 0, 0,
    ).subtract(const Duration(days: 3));
    
    if (notificationTime.isAfter(DateTime.now())) {
      await scheduleNotificationForDue(
        id: notifId,
        title: 'Bill Due: ${bill.title} ⚠️',
        body: 'Your bill of ₹${bill.amount.toStringAsFixed(0)} is due in 3 days.',
        scheduledDate: notificationTime,
      );
    }
  }

  Future<void> cancelBillReminder(String billId) async {
    final int notifId = billId.hashCode & 0x7FFFFFFF;
    await cancelNotification(notifId);
  }

  static const List<String> _funnyMessages = [
    "My wallet is like an onion. Opening it makes me cry. 🧅💸",
    "I'm not bad with money, but my bank app just sent me a budgeting tutorial link. 📱😅",
    "Savings account status: currently accepting donations. 🥺💰",
    "Do I need this? No. Am I buying it? Absolutely. 🛍️🛒",
    "Just checked my balance. I have enough money for the rest of my life... if I die tomorrow. ⚰️💵",
    "I want to save money, but the internet has too many cool things! 🛍️🦄",
    "My favorite exercise is running out of money. 🏃‍♂️💨",
    "Card declined. Time to use my charm... or wash some dishes. 🍽️😭",
    "Another day, another dollar... spent on coffee I could make at home. ☕🤷‍♂️",
    "Me looking at bank account: 'Who spent all my money?' Looking in mirror: 'Oh.' 🪞🤡",
    "I put the 'spend' in 'spending all my savings'. 💸🏆",
    "Savings? I thought you said 'Starbucks savings'. ☕💸",
    "My savings account is just a layover between paycheck and Amazon. 📦📉",
    "I have a budget. It's called 'I hope there is money in my account'. 🤞🤑",
    "Dear wallet, I am so sorry for what I did to you today. 💔💳",
    "Money can't buy happiness, but it can buy tacos, and that's basically the same thing. 🌮✨"
  ];

  static const List<String> _funnyTitles = [
    "Budget Police! 🚨",
    "Expense Check! 💸",
    "Money Thoughts 🧠",
    "Hey Big Spender! 😎",
    "Wallet Alert 💳",
    "Financial Advice 📈"
  ];

  Future<void> scheduleFunnyRandomNotifications() async {
    try {
      final math.Random random = math.Random();
      
      // Cancel any previously scheduled funny notifications (IDs 200 to 221)
      for (int id = 200; id <= 221; id++) {
        await cancelNotification(id);
      }
      
      final now = DateTime.now();
      
      // Schedule 3 random notifications per day for the next 7 days
      for (int day = 0; day < 7; day++) {
        // morning: between 9:00 and 12:00
        final hour1 = 9 + random.nextInt(3); 
        final min1 = random.nextInt(60);
        
        // afternoon: between 13:00 and 17:00
        final hour2 = 13 + random.nextInt(4);
        final min2 = random.nextInt(60);
        
        // evening: between 18:00 and 21:00
        final hour3 = 18 + random.nextInt(3);
        final min3 = random.nextInt(60);
        
        final times = [
          {'hour': hour1, 'minute': min1},
          {'hour': hour2, 'minute': min2},
          {'hour': hour3, 'minute': min3},
        ];
        
        for (int i = 0; i < 3; i++) {
          final targetDate = DateTime(
            now.year,
            now.month,
            now.day + day,
            times[i]['hour']!,
            times[i]['minute']!,
          );
          
          if (targetDate.isAfter(now)) {
            final title = _funnyTitles[random.nextInt(_funnyTitles.length)];
            final body = _funnyMessages[random.nextInt(_funnyMessages.length)];
            final int notifId = 200 + (day * 3) + i;
            
            await scheduleNotificationForDue(
              id: notifId,
              title: title,
              body: body,
              scheduledDate: targetDate,
            );
          }
        }
      }
      debugPrint('NotificationService: Successfully scheduled 7 days of funny random alerts.');
    } catch (e) {
      debugPrint('NotificationService: Error scheduling funny notifications: $e');
    }
  }

  Future<void> updateFcmTokenInFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
          debugPrint('NotificationService: FCM token updated in Firestore for user: ${user.uid}');
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error updating FCM token in Firestore: $e');
    }
  }

  Future<void> removeFcmTokenFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': FieldValue.delete()});
        debugPrint('NotificationService: FCM token removed from Firestore for user: ${user.uid}');
      }
    } catch (e) {
      debugPrint('NotificationService: Error removing FCM token from Firestore: $e');
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
