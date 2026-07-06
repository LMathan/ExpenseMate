import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import '../storage/hive_helper.dart';
import '../../features/expense/presentation/providers/expense_provider.dart';
import '../models/transaction_model.dart';
import '../models/group_model.dart';

class WidgetService {
  static const String appGroupId = 'group.com.mathan.espenseai';
  static const String androidWidgetProvider = 'com.example.espenseai.ExpenseWidgetProvider';

  static Future<void> updateWidgetData(WidgetRef ref) async {
    try {
      final txs = ref.read(transactionProvider);
      final budget = ref.read(budgetProvider);
      final groups = ref.read(groupsProvider);
      final settingsBox = Hive.box(HiveHelper.settingsBox);

      final resetDay = settingsBox.get('budget_reset_day', defaultValue: 1) as int;
      final cycleType = settingsBox.get('budget_cycle_type', defaultValue: 'monthly') as String;

      // 1. Calculate Cycle Start Date
      DateTime getCycleStartDate() {
        final now = DateTime.now();
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

      final cycleStart = getCycleStartDate();

      // 2. This Month Spend
      double currentMonthSpent = 0.0;
      for (var tx in txs) {
        if (tx.date.compareTo(cycleStart) >= 0) {
          currentMonthSpent += tx.amount;
        }
      }

      // 3. You Get and You Owe (Split totals)
      double totalOwed = 0.0;
      double totalToGet = 0.0;
      final settingsEmail = settingsBox.get('user_email', defaultValue: '') as String;
      if (settingsEmail.isNotEmpty) {
        final myEmail = settingsEmail.trim().toLowerCase();
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

            final settledEmails = tx.settledWith.map((e) => e.trim().toLowerCase()).toList();

            if (tx.splitShares != null && tx.splitShares!.isNotEmpty) {
              double payerCredit = 0.0;
              for (var email in splitWith) {
                if (settledEmails.contains(email)) continue;
                final share = tx.getSplitShareFor(email) ?? perHeadAmount;
                balances[email] = (balances[email] ?? 0.0) - share;
                payerCredit += share;
              }
              balances[payerEmail] = (balances[payerEmail] ?? 0.0) + payerCredit;
            } else {
              final activeSplitWith = splitWith.where((e) => !settledEmails.contains(e)).toList();
              final payerCredit = perHeadAmount * activeSplitWith.length;
              balances[payerEmail] = (balances[payerEmail] ?? 0.0) + payerCredit;
              for (var email in activeSplitWith) {
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

      // 4. Budget Left
      final budgetLeft = budget.monthlyIncome - currentMonthSpent;

      // 5. Today's Expenses Count
      final now = DateTime.now();
      int todayCount = 0;
      for (var tx in txs) {
        if (tx.date.year == now.year && tx.date.month == now.month && tx.date.day == now.day) {
          todayCount++;
        }
      }

      // 6. Top Category (Spend based)
      final Map<String, double> categorySums = {};
      for (var tx in txs) {
        if (tx.date.compareTo(cycleStart) >= 0) {
          categorySums[tx.category] = (categorySums[tx.category] ?? 0.0) + tx.amount;
        }
      }
      final sortedCategories = categorySums.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCategory = sortedCategories.isNotEmpty ? sortedCategories.first.key : 'None';

      final bool hasBudget = budget.monthlyIncome > 0;

      // Save Data to shared container
      await HomeWidget.setAppGroupId(appGroupId);
      
      final numberFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

      await HomeWidget.saveWidgetData('thisMonthSpend', numberFormat.format(currentMonthSpent));
      await HomeWidget.saveWidgetData('youGet', numberFormat.format(totalToGet));
      await HomeWidget.saveWidgetData('youOwe', numberFormat.format(totalOwed));
      await HomeWidget.saveWidgetData('budgetLeft', numberFormat.format(budgetLeft));
      await HomeWidget.saveWidgetData('expensesToday', todayCount.toString());
      await HomeWidget.saveWidgetData('topCategory', topCategory);
      await HomeWidget.saveWidgetData('monthName', DateFormat('MMMM').format(now));
      await HomeWidget.saveWidgetData('hasBudget', hasBudget);
      await HomeWidget.saveWidgetData('budgetLimit', numberFormat.format(budget.monthlyIncome));

      // Trigger Android Widget updates
      await HomeWidget.updateWidget(
        androidName: 'SmallWidgetProvider',
      );
      await HomeWidget.updateWidget(
        androidName: 'MediumWidgetProvider',
      );
      await HomeWidget.updateWidget(
        androidName: 'LargeWidgetProvider',
      );
    } catch (e) {
      print('Error updating widget data: $e');
    }
  }
}
