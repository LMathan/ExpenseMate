import 'dart:ui';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/storage/hive_helper.dart';
import 'package:espenseai/core/services/biometric_service.dart';
import 'package:espenseai/core/services/firestore_sync_service.dart';
import 'package:espenseai/core/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:espenseai/core/utils/app_page_route.dart';
import 'package:espenseai/features/expense/presentation/screens/add_expense_screen.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'tabs/home_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/planner_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/ai_insights_tab.dart';
import 'create_group_screen.dart';
import 'package:espenseai/features/auth/presentation/providers/auth_provider.dart';
import 'package:espenseai/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:home_widget/home_widget.dart';
import 'package:espenseai/core/services/widget_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final BiometricService _bioService = BiometricService();
  bool _isLocked = false;
  late AnimationController _addBtnCtrl;
  late Animation<double> _addBtnScale;
  StreamSubscription? _groupsSubscription;
  StreamSubscription? _transactionsSubscription;
  StreamSubscription? _profileSubscription;
  StreamSubscription? _widgetLinkSubscription;
  StreamSubscription<QuerySnapshot>? _peerNotificationsSubscription;
  DateTime? _lastPressedAt;

  final List<Widget> _tabs = [
    const HomeTab(),
    const AnalyticsTab(),
    const PlannerTab(),
    const ProfileTab(),
    const AiInsightsTab(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _addBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _addBtnScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _addBtnCtrl, curve: Curves.easeOut),
    );
    _checkBiometricLock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeUser();
      _setupRealtimeSync();
      _setupNotifications();
      _initHomeWidget();
    });
  }

  void _initHomeWidget() {
    HomeWidget.setAppGroupId(WidgetService.appGroupId);
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) {
        _handleWidgetNavigation(uri);
      }
    });

    _widgetLinkSubscription = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _handleWidgetNavigation(uri);
      }
    });

    _listenAndSyncWidgets();
    WidgetService.updateWidgetData(ref);
  }

  void _handleWidgetNavigation(Uri uri) {
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    if (host == 'add_expense' || path == '/add_expense') {
      Navigator.push(
        context,
        AppPageRoute(
          page: const AddExpenseScreen(),
          type: RouteTransitionType.slideUp,
        ),
      );
    } else if (host == 'splits' || path == '/splits') {
      Navigator.push(
        context,
        AppPageRoute(
          page: const CreateGroupScreen(),
          type: RouteTransitionType.slideUp,
        ),
      );
    } else if (host == 'dashboard' || path == '/dashboard') {
      ref.read(dashboardIndexProvider.notifier).state = 0; // Go to Home Tab
    }
  }

  void _listenAndSyncWidgets() {
    ref.listenManual(transactionProvider, (previous, next) {
      WidgetService.updateWidgetData(ref);
    });
    ref.listenManual(budgetProvider, (previous, next) {
      WidgetService.updateWidgetData(ref);
    });
    ref.listenManual(groupsProvider, (previous, next) {
      WidgetService.updateWidgetData(ref);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _addBtnCtrl.dispose();
    _groupsSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _profileSubscription?.cancel();
    _widgetLinkSubscription?.cancel();
    _peerNotificationsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationStatusOnResume();
    }
  }

  void _checkNotificationStatusOnResume() async {
    final status = await Permission.notification.status;
    if (status.isGranted) {
      final notificationService = ref.read(notificationServiceProvider);
      await notificationService.scheduleReminders();
    }
  }

  void _setupNotifications() async {
    final notificationService = ref.read(notificationServiceProvider);
    await notificationService.init();

    final status = await Permission.notification.status;
    if (!status.isGranted) {
      if (mounted) {
        _showNotificationPermissionRationaleDialog(status);
      }
    } else {
      await notificationService.scheduleReminders();
    }
  }

  void _showNotificationPermissionRationaleDialog(PermissionStatus currentStatus) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPermanentlyDenied = currentStatus.isPermanentlyDenied;
    showAnimatedDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.primaryPurple,
              size: 36,
            ),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Stay on Track!',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isPermanentlyDenied
                  ? 'Notification permissions are disabled. Please enable them in settings to receive log reminders and transaction updates.'
                  : 'Allow notifications to receive daily reminders to log your expenses and timely alerts on your budget status.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    side: BorderSide(color: isDark ? AppColors.borderDark : Colors.grey[300]!),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Maybe Later'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (isPermanentlyDenied) {
                      await openAppSettings();
                    } else {
                      final isGranted = await ref.read(notificationServiceProvider).requestPermissions();
                      if (isGranted) {
                        await ref.read(notificationServiceProvider).scheduleReminders();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isPermanentlyDenied ? 'Open Settings' : 'Allow'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _setupRealtimeSync() {
    final box = Hive.box(HiveHelper.settingsBox);
    final isLoggedIn = box.get('is_logged_in', defaultValue: false) as bool;
    final isGuest = box.get('is_guest_mode', defaultValue: false) as bool;

    if (isLoggedIn && !isGuest) {
      final syncService = FirestoreSyncService();

      // Push all locally-known groups to every member's Firestore subcollection.
      // Fixes groups that were created before cross-user sync was active.
      syncService.backfillGroupsToAllMembers();

      _groupsSubscription = syncService.listenToGroups(() {
        if (mounted) {
          ref.read(groupsProvider.notifier).loadGroups();
        }
      });
      _transactionsSubscription = syncService.listenToTransactions(() {
        if (mounted) {
          ref.read(transactionProvider.notifier).loadTransactions();
        }
      });
      _profileSubscription = syncService.listenToUserProfile((data) {
        if (mounted) {
          final name = data['displayName'] as String? ?? 'User';
          final sBox = Hive.box(HiveHelper.settingsBox);
          final path = sBox.get('profile_picture_path') as String?;
          final url = sBox.get('profile_picture_url') as String?;
          ref.read(authProvider.notifier).updateProfileDetails(
            displayName: name,
            profilePicPath: path,
            profilePicUrl: url,
            clearPhoto: (url == null && path == null),
          );
        }
      });
      _listenForPeerNotifications();
    }
  }

  void _checkFirstTimeUser() {
    final box = Hive.box(HiveHelper.settingsBox);
    final isGuest = box.get('is_guest_mode', defaultValue: false) as bool;
    final isLoggedIn = box.get('is_logged_in', defaultValue: false) as bool;

    if (isLoggedIn && !isGuest) {
      final hasCompletedSetup = box.get('has_completed_profile_setup', defaultValue: false) as bool;
      if (!hasCompletedSetup) {
        _showOnboardingProfileSetup();
        return;
      }
    }

    final hasSeenTour = box.get('has_seen_intro_tour', defaultValue: false) as bool;
    if (!hasSeenTour) {
      _showWalkthroughDialog();
    }
  }

  void _listenForPeerNotifications() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _peerNotificationsSubscription?.cancel();
    _peerNotificationsSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('toUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            final docId = change.doc.id;
            final fromName = data['fromName'] as String? ?? 'A person';
            final amountNum = data['amount'] as num? ?? 0.0;
            final amount = amountNum.toDouble();
            final groupId = data['groupId'] as String? ?? '';
            final fromEmail = data['fromEmail'] as String? ?? '';
            
            // Trigger local push notification for the receiver
            try {
              NotificationService().showInstantNotification(
                'Payment Received Alert',
                '$fromName paid ₹${amount.toStringAsFixed(0)} to you. Check and update the settle status.',
              );
            } catch (e) {
              debugPrint('Error showing local notification: $e');
            }

            if (mounted) {
              _showPeerNotificationPopup(docId, fromName, fromEmail, amount, groupId);
            }
          }
        }
      }
    });
  }

  void _showPeerNotificationPopup(
    String docId,
    String fromName,
    String fromEmail,
    double amount,
    String groupId,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderCol.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: AppColors.primaryPurple,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Payment Received Notification',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '$fromName paid ₹${amount.toStringAsFixed(2)} to you. Check and update the settle status.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(docId)
                                .update({'status': 'dismissed'});
                          } catch (e) {
                            debugPrint('Error updating notification: $e');
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Dismiss',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          
                          // 1. Mark notification as confirmed
                          try {
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(docId)
                                .update({'status': 'confirmed'});
                          } catch (e) {
                            debugPrint('Error updating notification: $e');
                          }

                          // 2. Programmatically settle transaction in group
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null) {
                            final allTxs = ref.read(transactionProvider);
                            final myEmail = user.email?.trim().toLowerCase() ?? '';
                            final senderEmail = fromEmail.trim().toLowerCase();

                            final listTxs = allTxs.where((tx) =>
                              tx.groupId == groupId &&
                              !tx.isSettled &&
                              (
                                (tx.paidByEmail.trim().toLowerCase() == myEmail &&
                                 tx.splitWith.map((e) => e.trim().toLowerCase()).contains(senderEmail))
                                ||
                                (tx.paidByEmail.trim().toLowerCase() == senderEmail &&
                                 tx.splitWith.map((e) => e.trim().toLowerCase()).contains(myEmail))
                              )
                            ).toList();

                            for (var tx in listTxs) {
                              final list = List<String>.from(tx.settledWith);
                              if (!list.contains(senderEmail)) {
                                list.add(senderEmail);
                              }
                              if (!list.contains(myEmail)) {
                                list.add(myEmail);
                              }

                              final splitWithEmails = tx.splitWith.map((e) => e.trim().toLowerCase()).toList();
                              final allSettled = splitWithEmails.every((email) => list.contains(email));

                              final updated = tx.copyWith(
                                settledWith: list,
                                isSettled: allSettled ? true : tx.isSettled,
                              );
                              await ref.read(transactionProvider.notifier).editTransaction(updated);
                            }
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Settle status successfully updated!'),
                                backgroundColor: AppColors.emeraldGreen,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emeraldGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Settle',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showOnboardingProfileSetup() {
    showAnimatedDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const OnboardingProfileSetupDialog();
      },
    ).then((_) {
      _checkFirstTimeUser();
    });
  }

  void _showWalkthroughDialog() {
    showAnimatedDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bgDark.withOpacity(0.95),
                  AppColors.cardDark.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.electricBlue,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to ExpenseMate! ✨',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Let\'s take a quick tour of your new smart financial manager.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTourItem(
                        Icons.add_circle_outline_rounded,
                        AppColors.electricBlue,
                        'Log Expenses Instantly',
                        'Tap + to quickly add any expense with category, payment method & notes.',
                      ),
                      const SizedBox(height: 16),
                      _buildTourItem(
                        Icons.analytics_outlined,
                        AppColors.primaryPurple,
                        'Visual Analytics',
                        'See spending breakdowns by category with beautiful interactive charts.',
                      ),
                      const SizedBox(height: 16),
                      _buildTourItem(
                        Icons.call_split_rounded,
                        AppColors.emeraldGreen,
                        'Instant Bill Splitting',
                        'Search users dynamically in the database to split shared expenses.',
                      ),
                      const SizedBox(height: 16),
                      _buildTourItem(
                        Icons.calendar_today_rounded,
                        AppColors.accentOrange,
                        'Custom Billing Cycles',
                        'Set your own monthly budget reset date directly on the dashboard card.',
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            final box = Hive.box(HiveHelper.settingsBox);
                            box.put('has_seen_intro_tour', true);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Got it, Let\'s Start!',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTourItem(IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _checkBiometricLock() async {
    final box = Hive.box(HiveHelper.settingsBox);
    final isBiometricsEnabled = box.get('biometrics_enabled', defaultValue: false) as bool;
    if (!isBiometricsEnabled) return;

    final canAuth = await _bioService.canAuthenticate();
    if (canAuth) {
      setState(() {
        _isLocked = true;
      });
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    final success = await _bioService.authenticate();
    if (success) {
      setState(() {
        _isLocked = false;
      });
    }
  }

  void _onAddPressed() async {
    await _addBtnCtrl.forward();
    await _addBtnCtrl.reverse();
    if (mounted) {
      Navigator.push(
        context,
        AppPageRoute(
          page: const AddExpenseScreen(),
          type: RouteTransitionType.slideUp,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLocked) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 130,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'ExpenseMate Secure Vault',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text('Unlock using your biometrics credentials', style: TextStyle(color: AppColors.textSecondaryDark)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentIndex = ref.watch(dashboardIndexProvider);

    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        if (currentIndex != 0) {
          ref.read(dashboardIndexProvider.notifier).state = 0;
          setState(() {});
        }
      },
      child: Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: currentIndex == 0
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Row(
                children: [
                  Image.asset(
                    'assets/images/app_icon.png',
                    height: 40,
                    width: 40,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ExpenseMate',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
      body: Stack(
        children: [
          // Tab body with IndexedStack to keep tabs alive and eliminate lag
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 90.0),
              child: AnimatedIndexedStack(
                index: currentIndex,
                children: _tabs,
              ),
            ),
          ),

          // Bottom nav bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home', currentIndex),
                      _buildCreateGroupButton(isDark),
                      _buildAddButton(),
                      _buildNavItem(2, Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Planner', currentIndex),
                      _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile', currentIndex),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData filledIcon, IconData outlineIcon, String label, int currentIndex) {
    final isSelected = currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => ref.read(dashboardIndexProvider.notifier).state = index,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedScale(
                scale: isSelected ? 1.15 : 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(
                  isSelected ? filledIcon : outlineIcon,
                  color: isSelected ? AppColors.primaryPurple : unselectedColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryPurple : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _onAddPressed,
      child: AnimatedBuilder(
        animation: _addBtnScale,
        builder: (_, child) => Transform.scale(
          scale: _addBtnScale.value,
          child: child,
        ),
        child: Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withValues(alpha: 0.48),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateGroupButton(bool isDark) {
    final unselectedColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          AppPageRoute(
            page: const CreateGroupScreen(),
            type: RouteTransitionType.slideUp,
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              child: AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: Icon(
                  Icons.group_add_outlined,
                  color: unselectedColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'New Group',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: unselectedColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingProfileSetupDialog extends ConsumerStatefulWidget {
  const OnboardingProfileSetupDialog({super.key});

  @override
  ConsumerState<OnboardingProfileSetupDialog> createState() => _OnboardingProfileSetupDialogState();
}

class _OnboardingProfileSetupDialogState extends ConsumerState<OnboardingProfileSetupDialog> {
  final _controller = TextEditingController();
  final FirestoreSyncService _syncService = FirestoreSyncService();
  String? _imagePath;
  bool _isChecking = false;
  bool _isTaken = false;
  bool _isValidFormat = true;
  List<String> _suggestions = [];
  Timer? _debounce;
  String _selectedGender = 'male';

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final clean = val.trim();
    final validFormat = clean.isNotEmpty && RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean) && clean.length >= 3;
    setState(() {
      _isValidFormat = validFormat;
      _isTaken = false;
      _suggestions = [];
    });

    if (validFormat) {
      _debounce = Timer(const Duration(milliseconds: 600), () {
        _checkAvailability(clean);
      });
    }
  }

  Future<void> _checkAvailability(String username) async {
    setState(() {
      _isChecking = true;
    });
    
    final taken = await _syncService.isUsernameTaken(username);
    
    setState(() {
      _isTaken = taken;
      _isChecking = false;
      if (taken) {
        _suggestions = _generateSuggestions(username);
      }
    });
  }

  List<String> _generateSuggestions(String base) {
    final cleanBase = base.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
    final suggestions = <String>[];
    final random = DateTime.now().millisecond;
    suggestions.add('${cleanBase}_${100 + (random % 900)}');
    suggestions.add('${cleanBase}${10 + (random % 90)}');
    suggestions.add('${cleanBase}_${1000 + (random % 9000)}');
    return suggestions;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imagePath = picked.path;
      });
    }
  }

  void _submit() async {
    final username = _controller.text.trim();
    if (username.isEmpty || !_isValidFormat || _isTaken || _isChecking) return;

    final box = Hive.box(HiveHelper.settingsBox);
    await box.put('user_name', username);
    await box.put('user_gender', _selectedGender);
    await box.put('has_completed_profile_setup', true);

    final imagePath = _imagePath;
    if (imagePath != null) {
      await box.put('profile_picture_path', imagePath);
      // Immediately upload the profile picture to Firebase Storage and update Firestore/Hive url.
      await _syncService.syncProfilePicture(imagePath);
    }

    ref.read(authProvider.notifier).updateProfileDetails(
      displayName: username,
      profilePicPath: imagePath,
    );

    await _syncService.updateProfileName(
      username,
      hasCompletedSetup: true,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile setup completed! Welcome!'),
          backgroundColor: AppColors.emeraldGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.bgDark : Colors.white;
    final cardColor = isDark ? AppColors.cardDark : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final username = _controller.text.trim();
    final nameSeed = username.isNotEmpty ? username : 'ExpenseMate';
    final String seed = _selectedGender == 'female' 
        ? 'Willow_${nameSeed.replaceAll(' ', '')}' 
        : 'Oliver_${nameSeed.replaceAll(' ', '')}';
    final imageProvider = (_imagePath != null && File(_imagePath!).existsSync())
        ? FileImage(File(_imagePath!)) as ImageProvider
        : AssetImage(_selectedGender == 'female' ? 'assets/images/avatar_girl.png' : 'assets/images/avatar_boy.png') as ImageProvider;

    final canSave = _controller.text.trim().isNotEmpty && _isValidFormat && !_isTaken && !_isChecking;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Complete Your Profile ✨',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a unique username and optional profile photo to start splitting bills.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              
              Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundImage: imageProvider,
                    backgroundColor: cardColor,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryPurple,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _controller,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: textSecondary),
                  suffixIcon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue),
                          ),
                        )
                      : (_controller.text.trim().isEmpty
                          ? null
                          : (_isValidFormat && !_isTaken
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.emeraldGreen)
                              : const Icon(Icons.error_outline_rounded, color: AppColors.accentPink))),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                  ),
                ),
                onChanged: _onUsernameChanged,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGender = 'male'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedGender == 'male'
                              ? AppColors.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.12)
                              : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedGender == 'male' ? AppColors.primaryPurple : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.male_rounded,
                              color: _selectedGender == 'male' ? AppColors.primaryPurple : textColor.withValues(alpha: 0.6),
                              size: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Male',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: _selectedGender == 'male' ? FontWeight.bold : FontWeight.normal,
                                color: _selectedGender == 'male' ? AppColors.primaryPurple : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedGender = 'female'),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedGender == 'female'
                              ? AppColors.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.12)
                              : cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedGender == 'female' ? AppColors.primaryPurple : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.female_rounded,
                              color: _selectedGender == 'female' ? AppColors.primaryPurple : textColor.withValues(alpha: 0.6),
                              size: 24,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Female',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: _selectedGender == 'female' ? FontWeight.bold : FontWeight.normal,
                                color: _selectedGender == 'female' ? AppColors.primaryPurple : textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!_isValidFormat && _controller.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Must be at least 3 characters and alphanumeric only (no spaces/symbols)',
                    style: GoogleFonts.inter(color: AppColors.accentPink, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_isTaken) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Username already taken 🛑',
                    style: GoogleFonts.inter(color: AppColors.accentPink, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Suggestions:',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _suggestions.map((sug) {
                    return ActionChip(
                      label: Text(sug, style: const TextStyle(fontSize: 12)),
                      backgroundColor: cardColor,
                      labelStyle: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onPressed: () {
                        _controller.text = sug;
                        _onUsernameChanged(sug);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canSave ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    disabledBackgroundColor: AppColors.primaryPurple.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Get Started',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(widget.children.length, (i) {
        final isCurrent = i == widget.index;
        return FadeTransition(
          opacity: isCurrent ? _animation : const AlwaysStoppedAnimation(0.0),
          child: SlideTransition(
            position: isCurrent
                ? Tween<Offset>(
                    begin: const Offset(0.0, 0.025),
                    end: Offset.zero,
                  ).animate(_animation)
                : const AlwaysStoppedAnimation(Offset.zero),
            child: widget.children[i],
          ),
        );
      }),
    );
  }
}
