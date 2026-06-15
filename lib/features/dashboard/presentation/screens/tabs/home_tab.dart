import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/services/notification_service.dart';
import 'package:espenseai/core/widgets/vector_illustrations.dart';
// AppBackground, PageBg, StaggeredListItem exported from vector_illustrations
import 'package:espenseai/core/services/ocr_service.dart';
import 'package:espenseai/core/services/firestore_sync_service.dart';
import 'package:espenseai/core/utils/app_page_route.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:espenseai/core/storage/hive_helper.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/features/expense/presentation/screens/add_expense_screen.dart';
import 'package:espenseai/features/expense/presentation/screens/expense_history_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:espenseai/core/models/group_model.dart';
import 'package:espenseai/core/utils/transaction_permissions.dart';
import 'package:espenseai/features/auth/presentation/providers/auth_provider.dart';
import '../group_details_screen.dart';
import '../create_group_screen.dart';
import '../owe_details_screen.dart';
import '../to_get_details_screen.dart';
import '../../providers/dashboard_provider.dart';
import 'profile_tab.dart';
import 'package:espenseai/core/utils/category_emoji_helper.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final OcrService _ocrService = OcrService();

  void _showCreateGroupSheet() {
    Navigator.push(
      context,
      AppPageRoute(page: const CreateGroupScreen()),
    );
  }

  void _showEditBudgetDialog(BuildContext context) {
    final budget = ref.read(budgetProvider);
    final txs = ref.read(transactionProvider);
    final settingsBox = Hive.box(HiveHelper.settingsBox);
    final resetDay = settingsBox.get('budget_reset_day', defaultValue: 1) as int;
    final cycleType = settingsBox.get('budget_cycle_type', defaultValue: 'monthly') as String;

    final controller = TextEditingController(text: budget.monthlyIncome.toStringAsFixed(0));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bgColor = isDark ? AppColors.cardDark : Colors.white;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String tempCycleType = cycleType;
        int tempResetDay = resetDay;
        if (tempCycleType == 'weekly' && tempResetDay > 7) {
          tempResetDay = 1;
        }

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            // Compute spent in this cycle based on current state
            final DateTime cycleStart;
            if (tempCycleType == 'weekly') {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              int daysToSubtract = today.weekday - tempResetDay;
              if (daysToSubtract < 0) {
                daysToSubtract += 7;
              }
              cycleStart = today.subtract(Duration(days: daysToSubtract));
            } else {
              DateTime now = DateTime.now();
              int month = now.month, year = now.year;
              int daysInMonth = DateTime(year, month + 1, 0).day;
              int targetDay = tempResetDay > daysInMonth ? daysInMonth : tempResetDay;
              cycleStart = now.day >= targetDay
                  ? DateTime(year, month, targetDay)
                  : DateTime(year, month == 1 ? 12 : month - 1, targetDay);
            }

            double spent = 0;
            for (var tx in txs) {
              if (tx.date.compareTo(cycleStart) >= 0) spent += tx.amount;
            }

            final currentAmount = double.tryParse(controller.text) ?? budget.monthlyIncome;
            final remaining = currentAmount - spent;
            final progress = currentAmount > 0 ? (spent / currentAmount).clamp(0.0, 1.0) : 0.0;
            final progressColor = progress > 0.85
                ? AppColors.accentPink
                : progress > 0.6
                    ? AppColors.accentOrange
                    : AppColors.emeraldGreen;

            final List<String> weekdays = [
              'Monday',
              'Tuesday',
              'Wednesday',
              'Thursday',
              'Friday',
              'Saturday',
              'Sunday'
            ];

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(dialogContext).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      offset: const Offset(0, -8),
                    )
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primaryPurple, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Configure Budget",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                        tempCycleType == 'weekly'
                                            ? "Resets weekly on ${weekdays[tempResetDay - 1]}"
                                            : "Resets monthly on Day $tempResetDay",
                                        style: TextStyle(fontSize: 11, color: subColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Stats row
                            Row(
                              children: [
                                Expanded(child: _BudgetStatBox(label: 'Spent', value: '₹${spent.toStringAsFixed(0)}', color: AppColors.accentPink, isDark: isDark)),
                                const SizedBox(width: 10),
                                Expanded(child: _BudgetStatBox(label: 'Remaining', value: '₹${remaining.toStringAsFixed(0)}', color: AppColors.emeraldGreen, isDark: isDark)),
                                const SizedBox(width: 10),
                                Expanded(child: _BudgetStatBox(label: 'Limit', value: '₹${currentAmount.toStringAsFixed(0)}', color: AppColors.electricBlue, isDark: isDark)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: progressColor.withValues(alpha: 0.12),
                                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(progress * 100).toStringAsFixed(1)}% used',
                              style: TextStyle(color: progressColor, fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.end,
                            ),

                            const SizedBox(height: 20),
                            Text('BUDGET LIMIT AMOUNT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: subColor, letterSpacing: 1)),
                            const SizedBox(height: 10),

                            // Input
                            TextField(
                              controller: controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                              onChanged: (val) {
                                setDialogState(() {});
                              },
                              decoration: InputDecoration(
                                prefixText: '₹  ',
                                prefixStyle: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                                hintText: '0',
                                hintStyle: TextStyle(color: subColor),
                                filled: true,
                                fillColor: isDark ? AppColors.bgDark : AppColors.bgLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Weekly vs Monthly cycle toggle dropdowns
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('CYCLE TYPE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: subColor, letterSpacing: 1)),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.bgDark : AppColors.bgLight,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: tempCycleType,
                                            dropdownColor: bgColor,
                                            isExpanded: true,
                                            style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                                            items: const [
                                              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                            ],
                                            onChanged: (val) {
                                              if (val != null) {
                                                setDialogState(() {
                                                  tempCycleType = val;
                                                  if (tempCycleType == 'weekly') {
                                                    tempResetDay = 1; // Default to Monday
                                                  } else {
                                                    tempResetDay = 1; // Default to 1st of month
                                                  }
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tempCycleType == 'weekly' ? 'RESET DAY' : 'RESET DATE',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: subColor, letterSpacing: 1),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.bgDark : AppColors.bgLight,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int>(
                                            value: tempResetDay,
                                            dropdownColor: bgColor,
                                            isExpanded: true,
                                            style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
                                            items: tempCycleType == 'weekly'
                                                ? List.generate(7, (i) => i + 1)
                                                    .map((d) => DropdownMenuItem(
                                                          value: d,
                                                          child: Text(weekdays[d - 1]),
                                                        ))
                                                    .toList()
                                                : List.generate(31, (i) => i + 1)
                                                    .map((d) => DropdownMenuItem(
                                                          value: d,
                                                          child: Text('Day $d'),
                                                        ))
                                                    .toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setDialogState(() {
                                                  tempResetDay = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 28),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: subColor,
                                      side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: AppColors.primaryGradient,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final income = double.tryParse(controller.text) ?? 0.0;
                                        if (income > 0) {
                                          ref.read(budgetProvider.notifier).updateIncome(income);
                                          await settingsBox.put('budget_cycle_type', tempCycleType);
                                          await settingsBox.put('budget_reset_day', tempResetDay);
                                          
                                          if (context.mounted) {
                                            setState(() {}); // Rebuild home tab with new budget options!
                                            Navigator.pop(dialogContext);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Budget cycle settings saved!'), backgroundColor: AppColors.emeraldGreen),
                                            );
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                      child: const Text('Save Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showResetDayDialog() {
    final settingsBox = Hive.box(HiveHelper.settingsBox);
    final currentDay = settingsBox.get('budget_reset_day', defaultValue: 1) as int;
    int selected = currentDay;
    
    showAnimatedDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Custom Reset Date', style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select the day of the month when your budget resets and monthly spending starts calculation:',
                    style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Day of month: ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      DropdownButton<int>(
                        value: selected,
                        dropdownColor: AppColors.cardDark,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        items: List.generate(31, (index) => index + 1)
                            .map((d) => DropdownMenuItem(
                                  value: d,
                                  child: Text('  $d  '),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selected = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await settingsBox.put('budget_reset_day', selected);
                    if (mounted) {
                      setState(() {});
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Budget cycle reset day set to Day $selected!'),
                          backgroundColor: AppColors.emeraldGreen,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _triggerOcrScan() async {
    final image = await _ocrService.pickImage(Theme.of(context).platform == TargetPlatform.android 
        ? ImageSource.camera 
        : ImageSource.gallery);
    if (image != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt uploaded. Scanning items...')),
      );
      final ocrResult = await _ocrService.scanReceipt(File(image.path));
      if (mounted) {
        Navigator.push(
          context,
          AppPageRoute(
            page: AddExpenseScreen(
              preFilledAmount: ocrResult['amount'] as double,
              preFilledCategory: ocrResult['category'] as String,
              preFilledMerchant: ocrResult['merchant'] as String,
              preFilledNotes: ocrResult['notes'] as String,
            ),
          ),
        );
      }
    }
  }

  Widget _buildSolidCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
    double borderRadius = 24,
    List<Color>? gradientColors,
    bool hasShadow = true,
    Color? customBg,
    Border? customBorder,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: customBg ?? (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.circular(borderRadius),
        border: customBorder ?? Border.all(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.06) 
              : AppColors.borderLight,
          width: 1.0,
        ),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
        gradient: gradientColors != null
            ? LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionProvider);
    final groups = ref.watch(groupsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsBox = Hive.box(HiveHelper.settingsBox);
    final userName = settingsBox.get('user_name', defaultValue: 'User') as String;
    final resetDay = settingsBox.get('budget_reset_day', defaultValue: 1) as int;

    final String cycleType = settingsBox.get('budget_cycle_type', defaultValue: 'monthly') as String;

    DateTime getCycleStartDate() {
      final now = DateTime.now();
      if (cycleType == 'weekly') {
        final today = DateTime(now.year, now.month, now.day);
        int daysToSubtract = today.weekday - resetDay;
        if (daysToSubtract < 0) {
          daysToSubtract += 7;
        }
        return today.subtract(Duration(days: daysToSubtract));
      } else {
        // Monthly
        int year = now.year;
        int month = now.month;
        int daysInMonth = DateTime(year, month + 1, 0).day;
        int targetDay = resetDay > daysInMonth ? daysInMonth : resetDay;
        
        if (now.day >= targetDay) {
          return DateTime(year, month, targetDay);
        } else {
          int prevMonth = month - 1;
          int prevYear = year;
          if (prevMonth == 0) {
            prevMonth = 12;
            prevYear = year - 1;
          }
          int daysInPrevMonth = DateTime(prevYear, prevMonth + 1, 0).day;
          int prevTargetDay = resetDay > daysInPrevMonth ? daysInPrevMonth : resetDay;
          return DateTime(prevYear, prevMonth, prevTargetDay);
        }
      }
    }

    final cycleStart = getCycleStartDate();

    double currentMonthSpent = 0;
    for (var tx in txs) {
      if (tx.date.compareTo(cycleStart) >= 0) {
        currentMonthSpent += tx.amount;
      }
    }

    final now = DateTime.now();
    double todaySpent = 0;
    for (var tx in txs) {
      if (tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day) {
        todaySpent += tx.amount;
      }
    }

    final authState = ref.watch(authProvider);
    final currentEmail = authState.email ?? '';
    double totalOwed = 0.0;
    double totalToGet = 0.0;

    if (currentEmail.isNotEmpty) {
      final myEmail = currentEmail.trim().toLowerCase();
      for (var group in groups) {
        final groupTxs = txs.where((tx) => tx.groupId == group.id).toList();
        final Map<String, double> balances = {};
        for (var tx in groupTxs) {
          if (tx.isSettled) continue;
          final payerEmail = tx.paidByEmail.trim().toLowerCase();
          final splitWith = tx.splitWith.map((e) => e.trim().toLowerCase()).toList();
          final totalSplitCount = splitWith.length + 1;
          if (totalSplitCount <= 1) continue;

          final perHeadAmount = tx.totalAmount > 0 
              ? tx.totalAmount / totalSplitCount 
              : tx.amount;

          if (tx.splitShares != null && tx.splitShares!.isNotEmpty) {
            double payerCredit = 0.0;
            for (var email in splitWith) {
              final share = tx.splitShares![email] ?? perHeadAmount;
              balances[email] = (balances[email] ?? 0.0) - share;
              payerCredit += share;
            }
            balances[payerEmail] = (balances[payerEmail] ?? 0.0) + payerCredit;
          } else {
            final payerCredit = perHeadAmount * splitWith.length;
            balances[payerEmail] = (balances[payerEmail] ?? 0.0) + payerCredit;
            for (var email in splitWith) {
              balances[email] = (balances[email] ?? 0.0) - perHeadAmount;
            }
          }
        }

        final myBalance = balances[myEmail] ?? 0.0;
        if (myBalance < -0.01) {
          totalOwed += -myBalance;
        } else if (myBalance > 0.01) {
          totalToGet += myBalance;
        }
      }
    }
    
    final Map<String, double> categorySpending = {};
    for (var tx in txs) {
      if (tx.date.compareTo(cycleStart) >= 0) {
        categorySpending[tx.category] = (categorySpending[tx.category] ?? 0.0) + tx.amount;
      }
    }
    final sortedCategories = categorySpending.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final hour = DateTime.now().hour;
    final String greeting;
    if (hour < 12) {
      greeting = 'Good Morning ☀️,';
    } else if (hour < 17) {
      greeting = 'Good Afternoon 🌤️,';
    } else {
      greeting = 'Good Evening 🌙,';
    }

    final String? profilePicPath = authState.profilePicPath;
    final String? profilePicUrl = authState.profilePicUrl;
    final ImageProvider imageProvider;
    if (profilePicPath != null && profilePicPath.startsWith('data:image')) {
      final base64String = profilePicPath.split('base64,').last;
      imageProvider = MemoryImage(base64Decode(base64String));
    } else if (profilePicPath != null && !profilePicPath.startsWith('http') && File(profilePicPath).existsSync()) {
      imageProvider = FileImage(File(profilePicPath));
    } else if (profilePicPath != null && profilePicPath.startsWith('http')) {
      imageProvider = NetworkImage(profilePicPath);
    } else if (profilePicUrl != null && profilePicUrl.startsWith('data:image')) {
      final base64String = profilePicUrl.split('base64,').last;
      imageProvider = MemoryImage(base64Decode(base64String));
    } else if (profilePicUrl != null) {
      imageProvider = NetworkImage(profilePicUrl);
    } else {
      final String gender = settingsBox.get('user_gender', defaultValue: 'male') as String;
      imageProvider = AssetImage(gender == 'female' ? 'assets/images/avatar_girl.png' : 'assets/images/avatar_boy.png');
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: AppBackground(
        type: PageBg.home,
        child: SafeArea(
          child: RefreshIndicator(
          onRefresh: () async {
            final syncService = FirestoreSyncService();
            await syncService.syncCloudToLocal();
            ref.read(transactionProvider.notifier).loadTransactions();
            ref.read(groupsProvider.notifier).loadGroups();
            ref.read(budgetProvider.notifier).loadBudget();
            ref.read(goalsProvider.notifier).loadGoals();
            ref.read(subscriptionsProvider.notifier).loadSubscriptions();
            ref.read(billsProvider.notifier).loadBills();
            ref.read(challengesProvider.notifier).loadChallenges();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Image.asset(
                          'assets/images/app_icon.png',
                          height: 44,
                          width: 44,
                        ),
                        const SizedBox(width: 8),
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
                    BouncyGestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        AppPageRoute(
                          page: const ProfileTab(showBackButton: true),
                          type: RouteTransitionType.slideRight,
                        ),
                      ),
                      child: Hero(
                        tag: 'profile_avatar',
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: CircleAvatar(
                            radius: 20,
                            backgroundImage: imageProvider,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: AppTextStyles.bodyMedium(isDark: isDark).copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                        Text(
                          userName,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () => _showEditBudgetDialog(context),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: AppColors.primaryPurple),
                      label: Text(
                        'Add Budget',
                        style: GoogleFonts.inter(
                          color: AppColors.primaryPurple,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                Row(
                  children: [
                    // Box 1: Today's Spend
                    Expanded(
                      child: BouncyGestureDetector(
                        onTap: () => ref.read(dashboardIndexProvider.notifier).state = 1,
                        child: _buildSolidCard(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.electricBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                                ),
                                child: const Icon(
                                  Icons.today_rounded,
                                  color: AppColors.electricBlue,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Today',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '₹${todaySpent.toStringAsFixed(0)}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Box 2: This Month's Spend
                    Expanded(
                      child: BouncyGestureDetector(
                        onTap: () => ref.read(dashboardIndexProvider.notifier).state = 1,
                        child: _buildSolidCard(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.primaryPurple.withValues(alpha: isDark ? 0.15 : 0.08),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppColors.primaryPurple,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'This Month',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '₹${currentMonthSpent.toStringAsFixed(0)}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Box 3: You Owe
                    Expanded(
                      child: BouncyGestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          AppPageRoute(
                            page: const OweDetailsScreen(),
                            type: RouteTransitionType.slideRight,
                          ),
                        ),
                        child: _buildSolidCard(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                                ),
                                child: const Icon(
                                  Icons.money_off_rounded,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You Owe',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '₹${totalOwed.toStringAsFixed(0)}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Box 4: To Get
                    Expanded(
                      child: BouncyGestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          AppPageRoute(
                            page: const ToGetDetailsScreen(),
                            type: RouteTransitionType.slideRight,
                          ),
                        ),
                        child: _buildSolidCard(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.emeraldGreen.withValues(alpha: isDark ? 0.15 : 0.08),
                                ),
                                child: const Icon(
                                  Icons.attach_money_rounded,
                                  color: AppColors.emeraldGreen,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'To Get',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '₹${totalToGet.toStringAsFixed(0)}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emeraldGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                Text(
                  'QUICK ACTIONS',
                  style: AppTextStyles.caption(isDark: isDark).copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.add_rounded,
                        label: 'Add Expense',
                        color: AppColors.primaryPurple,
                        onTap: () => Navigator.push(
                          context,
                          AppPageRoute(page: const AddExpenseScreen()),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan Receipt',
                        color: AppColors.electricBlue,
                        onTap: _triggerOcrScan,
                      ),
                    ),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.analytics_rounded,
                        label: 'Charts',
                        color: AppColors.accentOrange,
                        onTap: () => ref.read(dashboardIndexProvider.notifier).state = 1,
                      ),
                    ),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.history_edu_rounded,
                        label: 'History',
                        color: AppColors.emeraldGreen,
                        onTap: () => Navigator.push(
                          context,
                          AppPageRoute(page: const ExpenseHistoryScreen(), type: RouteTransitionType.slideRight),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'YOUR GROUPS',
                      style: AppTextStyles.caption(isDark: isDark).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showCreateGroupSheet,
                      icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primaryPurple),
                      label: const Text(
                        'Create Group',
                        style: TextStyle(
                          color: AppColors.primaryPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                groups.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: Text(
                            'No groups found. Create a group to split expenses!',
                            style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13),
                          ),
                        ),
                      )
                    : SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: groups.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final group = groups[index];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                AppPageRoute(
                                  page: GroupDetailsScreen(
                                    groupId: group.id,
                                    initialGroup: group,
                                  ),
                                  type: RouteTransitionType.slideRight,
                                ),
                              ),
                              child: SizedBox(
                                width: 144,
                                child: _buildSolidCard(
                                  padding: const EdgeInsets.all(12),
                                  borderRadius: 20,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primaryPurple.withValues(alpha: isDark ? 0.15 : 0.08),
                                            ),
                                            child: const Icon(
                                              Icons.group_rounded,
                                              color: AppColors.primaryPurple,
                                              size: 16,
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 14,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            group.name,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${group.memberNames.length} members',
                                            style: GoogleFonts.inter(
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              fontSize: 10.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOP SPENDING CATEGORIES',
                      style: AppTextStyles.caption(isDark: isDark).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSolidCard(
                  padding: const EdgeInsets.all(16.0),
                  child: sortedCategories.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.pie_chart_outline_rounded,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    size: 32),
                                const SizedBox(height: 8),
                                Text(
                                  'No spending in the current cycle yet.',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: sortedCategories.take(3).map((entry) {
                            final cat = entry.key;
                            final amt = entry.value;
                            final pct = currentMonthSpent > 0 ? amt / currentMonthSpent : 0.0;
                            
                            final barColors = [
                              AppColors.primaryPurple,
                              AppColors.electricBlue,
                              AppColors.emeraldGreen,
                              AppColors.accentOrange,
                              AppColors.accentPink,
                            ];
                            
                            final idx = sortedCategories.indexOf(entry);
                            final barColor = barColors[idx % barColors.length];

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(getCategoryEmoji(cat),
                                          style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          cat,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '₹${amt.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '(${(pct * 100).toStringAsFixed(0)}%)',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: pct,
                                      backgroundColor: isDark
                                          ? Colors.white.withOpacity(0.06)
                                          : Colors.black.withOpacity(0.04),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        barColor,
                                      ),
                                      minHeight: 6,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'RECENT TRANSACTIONS',
                      style: AppTextStyles.caption(isDark: isDark).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        AppPageRoute(page: const ExpenseHistoryScreen(), type: RouteTransitionType.slideRight),
                      ),
                      child: const Text('View All', style: TextStyle(color: AppColors.electricBlue)),
                    ),
                  ],
                ),
                
                txs.isEmpty
                    ? _buildSolidCard(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text(
                            'No transactions recorded yet.',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      )
                    : _buildSolidCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: txs.length > 5 ? 5 : txs.length,
                          separatorBuilder: (_, __) => Divider(
                            color: isDark ? Colors.white.withOpacity(0.06) : AppColors.borderLight,
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            final tx = txs[index];
                            return StaggeredListItem(
                              index: index,
                              child: _buildTransactionCard(tx, isDark),
                            );
                          },
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BouncyGestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: isDark ? 0.15 : 0.08),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: isDark ? 0.1 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(dynamic tx, bool isDark) {
    final String formattedDate = DateFormat('MMM dd, hh:mm a').format(tx.date);
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryPurple.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(getCategoryEmoji(tx.category), style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.merchant.isEmpty ? tx.category : tx.merchant,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: isDark ? 0.15 : 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tx.category, style: TextStyle(color: AppColors.primaryPurple, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    Text(formattedDate, style: TextStyle(fontSize: 10, color: subColor)),
                  ],
                ),
                if (tx.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(tx.notes, style: TextStyle(fontSize: 10, color: subColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-₹${tx.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentPink, fontSize: 14),
              ),
              if (canEditTransaction(tx, ref)) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        AppPageRoute(
                          page: AddExpenseScreen(
                            editTransaction: tx,
                            preFilledAmount: tx.amount,
                            preFilledCategory: tx.category,
                            preFilledMerchant: tx.merchant,
                            preFilledNotes: tx.notes,
                          ),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.electricBlue.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, color: AppColors.electricBlue, size: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        showAnimatedDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: Text('Delete Transaction', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            content: Text('Are you sure you want to delete this transaction?', style: TextStyle(color: subColor)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: subColor))),
                              ElevatedButton(
                                onPressed: () {
                                  ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Transaction deleted'), backgroundColor: AppColors.accentPink),
                                  );
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 13),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Budget stat helper widget
class _BudgetStatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _BudgetStatBox({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.1 : 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: subColor)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: textColor), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class CreateGroupSheet extends ConsumerStatefulWidget {
  const CreateGroupSheet({super.key});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedFriends = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final FirestoreSyncService _syncService = FirestoreSyncService();

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    final results = await _syncService.searchUsersByName(query);
    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _submitGroup() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name'), backgroundColor: AppColors.accentPink),
      );
      return;
    }
    if (_selectedFriends.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one friend'), backgroundColor: AppColors.accentPink),
      );
      return;
    }

    // Add current user to the members
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentUserName = Hive.box(HiveHelper.settingsBox).get('user_name', defaultValue: 'You') as String;
    
    final allMembers = [
      {
        'uid': currentUser?.uid ?? 'local_user',
        'displayName': currentUserName,
        'email': currentUser?.email ?? '',
      },
      ..._selectedFriends,
    ];

    // De-duplicate members by UID
    final seenUids = <String>{};
    final uniqueMembers = <Map<String, dynamic>>[];
    for (var m in allMembers) {
      final uid = m['uid'] as String;
      if (seenUids.add(uid)) {
        uniqueMembers.add(m);
      }
    }

    ref.read(groupsProvider.notifier).addGroup(name, uniqueMembers);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group created successfully!'), backgroundColor: AppColors.emeraldGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create New Group',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'MEMBERS',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.electricBlue, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            _selectedFriends.isEmpty
                ? const Text('Add friends below to join this group', style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 13))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedFriends.map((m) {
                      return Chip(
                        label: Text(m['displayName'] ?? m['email']),
                        backgroundColor: AppColors.primaryPurple.withOpacity(0.2),
                        labelStyle: const TextStyle(color: Colors.white),
                        deleteIcon: const Icon(Icons.cancel, size: 16, color: Colors.white54),
                        onDeleted: () {
                          setState(() {
                            _selectedFriends.remove(m);
                          });
                        },
                      );
                    }).toList(),
                  ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Search user by name...',
                labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondaryDark),
                suffixIcon: _isSearching
                    ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue)))
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: _searchUsers,
            ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final res = _searchResults[index];
                    final isAlreadyAdded = _selectedFriends.any((m) => m['uid'] == res['uid']);
                    return ListTile(
                      leading: Builder(
                        builder: (context) {
                          final photoUrl = res['photoUrl'] as String?;
                          final gender = res['user_gender'] as String? ?? 'male';
                          if (photoUrl != null && photoUrl.startsWith('data:image')) {
                            try {
                              final base64String = photoUrl.split('base64,').last;
                              return CircleAvatar(
                                radius: 20,
                                backgroundImage: MemoryImage(base64Decode(base64String)),
                                backgroundColor: Colors.transparent,
                              );
                            } catch (_) {}
                          } else if (photoUrl != null && photoUrl.startsWith('http')) {
                            return CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(photoUrl),
                              backgroundColor: Colors.transparent,
                            );
                          }
                          return CircleAvatar(
                            radius: 20,
                            backgroundImage: AssetImage(gender == 'female' ? 'assets/images/avatar_girl.png' : 'assets/images/avatar_boy.png'),
                            backgroundColor: Colors.transparent,
                          );
                        },
                      ),
                      title: Text(res['displayName'] ?? '', style: const TextStyle(color: Colors.white)),
                      subtitle: Text(res['email'] ?? '', style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
                      trailing: isAlreadyAdded
                          ? const Icon(Icons.check_circle, color: AppColors.emeraldGreen)
                          : const Icon(Icons.add_circle_outline, color: AppColors.electricBlue),
                      onTap: isAlreadyAdded
                          ? null
                          : () {
                              setState(() {
                                _selectedFriends.add(res);
                                _searchController.clear();
                                _searchResults = [];
                              });
                            },
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class AddGroupExpenseSheet extends ConsumerStatefulWidget {
  final GroupModel group;
  const AddGroupExpenseSheet({super.key, required this.group});

  @override
  ConsumerState<AddGroupExpenseSheet> createState() => _AddGroupExpenseSheetState();
}

class _AddGroupExpenseSheetState extends ConsumerState<AddGroupExpenseSheet> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _category = 'Other';
  String _paymentMethod = 'UPI';
  
  late String _whoPaidUid;
  late String _whoPaidName;
  
  String _splitType = 'Equally';
  Map<String, double> _unequalShares = {};
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    _whoPaidUid = currentUser?.uid ?? widget.group.memberUids.first;
    
    final idx = widget.group.memberUids.indexOf(_whoPaidUid);
    if (idx != -1) {
      _whoPaidName = widget.group.memberNames[idx];
    } else {
      _whoPaidName = widget.group.memberNames.first;
      _whoPaidUid = widget.group.memberUids.first;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _showErrorDialog(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showAnimatedDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.accentPink, size: 28),
            const SizedBox(width: 10),
            Text(
              'Validation Error',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'OK',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUnequalSplitDialog() {
    final totalAmount = double.tryParse(_amountController.text) ?? 0.0;
    if (totalAmount <= 0) {
      _showErrorDialog('Please enter a total amount first');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final memberCount = widget.group.memberUids.length;
    final controllers = <String, TextEditingController>{};
    for (int i = 0; i < memberCount; i++) {
      final uid = widget.group.memberUids[i];
      final currentShare =
          _unequalShares[uid] ?? (totalAmount / memberCount);
      controllers[uid] =
          TextEditingController(text: currentShare.toStringAsFixed(2));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setSheetState) {
            double currentSum = 0.0;
            controllers.forEach((_, c) {
              currentSum += double.tryParse(c.text) ?? 0.0;
            });
            final remaining = totalAmount - currentSum;
            final balanced = remaining.abs() < 0.01;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 14),
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.call_split_rounded,
                            color: AppColors.primaryPurple, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Custom Split  ₹${totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontFamily: 'Outfit',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (balanced
                                    ? AppColors.emeraldGreen
                                    : AppColors.accentOrange)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            balanced
                                ? 'Balanced ✓'
                                : (remaining > 0
                                    ? '+₹${remaining.toStringAsFixed(2)}'
                                    : '-₹${(-remaining).toStringAsFixed(2)}'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: balanced
                                  ? AppColors.emeraldGreen
                                  : AppColors.accentOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  // Member rows
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      itemCount: memberCount,
                      itemBuilder: (_, index) {
                        final uid = widget.group.memberUids[index];
                        final name = widget.group.memberNames[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  gradient: AppColors.primaryGradient,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  name.isNotEmpty
                                      ? name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Text(name,
                                    style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: controllers[uid],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    prefixText: '₹ ',
                                    prefixStyle: TextStyle(
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.black45,
                                        fontSize: 13),
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 8),
                                    filled: true,
                                    fillColor: AppColors.primaryPurple
                                        .withValues(alpha: 0.06),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  onChanged: (_) => setSheetState(() {}),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  // Action buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              double sum = 0.0;
                              final tempShares = <String, double>{};
                              controllers.forEach((key, c) {
                                final val =
                                    double.tryParse(c.text) ?? 0.0;
                                sum += val;
                                tempShares[key] = val;
                              });
                              if ((sum - totalAmount).abs() > 0.05) {
                                _showErrorDialog(
                                  'Total configured (₹${sum.toStringAsFixed(2)}) does not match the total amount (₹${totalAmount.toStringAsFixed(2)})'
                                );
                                return;
                              }
                              setState(() => _unequalShares = tempShares);
                              Navigator.pop(ctx);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Confirm',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _submitGroupExpense() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final desc = _descController.text.trim();

    if (amount <= 0) {
      _showErrorDialog('Please enter a valid amount');
      return;
    }
    if (desc.isEmpty) {
      _showErrorDialog('Please enter a description');
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    final myUid = currentUser?.uid ?? 'local_user';
    double myShare = 0.0;

    if (_splitType == 'Equally') {
      myShare = amount / widget.group.memberUids.length;
    } else {
      if (_unequalShares.isEmpty) {
        _showErrorDialog('Please configure unequal shares first');
        return;
      }
      myShare = _unequalShares[myUid] ?? 0.0;
    }

    Map<String, double>? splitShares;
    if (_splitType == 'Unequally') {
      splitShares = {};
      _unequalShares.forEach((uid, val) {
        final idx = widget.group.memberUids.indexOf(uid);
        if (idx != -1) {
          final email = widget.group.memberEmails[idx];
          splitShares![email] = val;
        }
      });
    }

    final otherEmails = widget.group.memberEmails.where((e) => e != currentUser?.email).toList();
    final payerIndex = widget.group.memberUids.indexOf(_whoPaidUid);
    final paidByEmail = payerIndex != -1 ? widget.group.memberEmails[payerIndex] : currentUser?.email ?? '';

    ref.read(transactionProvider.notifier).addTransaction(
      amount: myShare,
      category: _category,
      merchant: desc.startsWith('Split:') ? desc : 'Split: $desc (${widget.group.name})',
      notes: 'Total: ₹$amount. Paid by $_whoPaidName. Split $_splitType in group ${widget.group.name}.',
      paymentMethod: _paymentMethod,
      date: _selectedDate,
      splitWith: otherEmails,
      isSettled: false,
      paidByEmail: paidByEmail,
      totalAmount: amount,
      groupId: widget.group.id,
      splitShares: splitShares,
    );

    // Trigger notification
    if (paidByEmail == (currentUser?.email ?? '')) {
      final othersOwe = amount - myShare;
      ref.read(notificationServiceProvider).showInstantNotification(
        'New Split Added 💸',
        'You paid ₹${amount.toStringAsFixed(0)} in "${widget.group.name}" for $_category. Others owe you ₹${othersOwe.toStringAsFixed(0)}.',
      );
    } else {
      ref.read(notificationServiceProvider).showInstantNotification(
        'New Split in ${widget.group.name} 💸',
        'You need to pay ₹${myShare.toStringAsFixed(0)} in split for $_category.',
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Split added successfully! Your share: ₹${myShare.toStringAsFixed(2)}'),
        backgroundColor: AppColors.emeraldGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Expense to ${widget.group.name}',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
              decoration: InputDecoration(
                labelText: 'Total Amount (₹)',
                labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                filled: true,
                fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: (val) {
                setState(() {
                  _unequalShares.clear();
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
              decoration: InputDecoration(
                labelText: 'Description / Merchant',
                labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                filled: true,
                fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      filled: true,
                      fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: ['Food', 'Travel', 'Shopping', 'Entertainment', 'Bills', 'Healthcare', 'Education', 'Rent', 'EMI', 'Fuel', 'Other']
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(
                                '${getCategoryEmoji(cat)} $cat',
                                style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _category = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                    decoration: InputDecoration(
                      labelText: 'Payment Method',
                      labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      filled: true,
                      fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    items: [
                      {'name': 'UPI', 'emoji': '📱'},
                      {'name': 'Card', 'emoji': '💳'},
                      {'name': 'Cash', 'emoji': '💵'},
                      {'name': 'Net Banking', 'emoji': '🏦'},
                    ]
                        .map((pm) => DropdownMenuItem(
                              value: pm['name']!,
                              child: Row(
                                children: [
                                  Text(pm['emoji']!, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    pm['name']!,
                                    style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _paymentMethod = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _whoPaidUid,
              dropdownColor: isDark ? AppColors.cardDark : Colors.white,
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
              decoration: InputDecoration(
                labelText: 'Who Paid?',
                labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                filled: true,
                fillColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              items: (() {
                final seen = <String>{};
                final list = <DropdownMenuItem<String>>[];
                for (int i = 0; i < widget.group.memberUids.length; i++) {
                  final uid = widget.group.memberUids[i];
                  final name = widget.group.memberNames[i];
                  if (seen.add(uid)) {
                    list.add(DropdownMenuItem(
                      value: uid,
                      child: Text(
                        name,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                      ),
                    ));
                  }
                }
                return list;
              })(),
              onChanged: (val) {
                if (val != null) {
                  final idx = widget.group.memberUids.indexOf(val);
                  setState(() {
                    _whoPaidUid = val;
                    _whoPaidName = widget.group.memberNames[idx];
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: isDark
                            ? const ColorScheme.dark(
                                primary: AppColors.primaryPurple,
                                onPrimary: Colors.white,
                                surface: AppColors.cardDark,
                                onSurface: Colors.white,
                              )
                            : const ColorScheme.light(
                                primary: AppColors.primaryPurple,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black87,
                              ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Date',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.edit_calendar_rounded,
                      color: AppColors.primaryPurple,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SPLIT OPTIONS',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.electricBlue, letterSpacing: 1),
                ),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(
                        'Equally',
                        style: TextStyle(
                          color: _splitType == 'Equally'
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: _splitType == 'Equally',
                      selectedColor: AppColors.primaryPurple,
                      backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _splitType = 'Equally';
                            _unequalShares.clear();
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(
                        'Unequally',
                        style: TextStyle(
                          color: _splitType == 'Unequally'
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: _splitType == 'Unequally',
                      selectedColor: AppColors.primaryPurple,
                      backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _splitType = 'Unequally';
                          });
                          _showUnequalSplitDialog();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            // ── Live split preview ───────────────────────────────────────
            Builder(builder: (_) {
              final total = double.tryParse(_amountController.text) ?? 0.0;
              if (total <= 0) return const SizedBox.shrink();
              final memberCount = widget.group.memberUids.length;
              final isEqual = _splitType == 'Equally';

              return AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.primaryPurple.withValues(alpha: 0.14)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.splitscreen_rounded,
                            color: AppColors.primaryPurple, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          isEqual ? 'Equal split preview' : 'Custom split',
                          style: const TextStyle(
                              color: AppColors.primaryPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                        if (!isEqual && _unequalShares.isNotEmpty) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: _showUnequalSplitDialog,
                            child: const Text('Edit',
                                style: TextStyle(
                                    color: AppColors.electricBlue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...widget.group.memberUids.asMap().entries.map((e) {
                      final name = widget.group.memberNames[e.key];
                      final uid = e.value;
                      double share;
                      if (isEqual) {
                        share = total / memberCount;
                      } else {
                        share = _unequalShares[uid] ?? (total / memberCount);
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(name,
                                  style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                      fontSize: 12)),
                            ),
                            Text(
                              '₹${share.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  color: AppColors.primaryPurple,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (!isEqual && _unequalShares.isEmpty) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _showUnequalSplitDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.tune_rounded,
                                  color: AppColors.primaryPurple, size: 14),
                              SizedBox(width: 6),
                              Text('Set custom shares',
                                  style: TextStyle(
                                      color: AppColors.primaryPurple,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submitGroupExpense,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Add Group Expense', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class BouncyGestureDetector extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BouncyGestureDetector({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<BouncyGestureDetector> createState() => _BouncyGestureDetectorState();
}

class _BouncyGestureDetectorState extends State<BouncyGestureDetector>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
