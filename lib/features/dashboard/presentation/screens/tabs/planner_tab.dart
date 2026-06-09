import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';

class PlannerTab extends ConsumerStatefulWidget {
  const PlannerTab({super.key});

  @override
  ConsumerState<PlannerTab> createState() => _PlannerTabState();
}

class _PlannerTabState extends ConsumerState<PlannerTab>
    with SingleTickerProviderStateMixin {
  late TabController _plannerTabController;
  DateTime _focusedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _plannerTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _plannerTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subscriptionsProvider);
    final bills = ref.watch(billsProvider);
    final txs = ref.watch(transactionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double subTotal = subs.fold(0.0, (sum, sub) => sum + sub.amount);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Planner & Calendar',
                style: AppTextStyles.heading2(isDark: isDark),
              ),
              const SizedBox(height: 16),

              _buildCalendarGrid(txs, bills),
              const SizedBox(height: 20),

              TabBar(
                controller: _plannerTabController,
                indicatorColor: AppColors.primaryPurple,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondaryDark,
                tabs: const [
                  Tab(text: 'Subscriptions'),
                  Tab(text: 'Bill Reminders'),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: TabBarView(
                  controller: _plannerTabController,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(16),
                          gradientColors: [
                            AppColors.primaryPurple.withValues(alpha: 0.15),
                            AppColors.electricBlue.withValues(alpha: 0.05),
                          ],
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Monthly Subscriptions:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '₹${subTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.accentPink,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: subs.isEmpty
                              ? const Center(
                                  child: Text('No subscriptions found.'),
                                )
                              : ListView.separated(
                                  itemCount: subs.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final sub = subs[index];
                                    final renewal = DateFormat(
                                      'MMM dd',
                                    ).format(sub.dueDate);
                                    return GlassCard(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.electricBlue
                                                  .withValues(alpha: 0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.sync_rounded,
                                              color: AppColors.electricBlue,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  sub.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                Text(
                                                  'Renews on $renewal',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors
                                                        .textSecondaryDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '₹${sub.amount.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () => ref
                                                    .read(
                                                      subscriptionsProvider
                                                          .notifier,
                                                    )
                                                    .toggleReminder(sub.id),
                                                child: Icon(
                                                  sub.reminderEnabled
                                                      ? Icons
                                                            .notifications_active
                                                      : Icons.notifications_off,
                                                  size: 16,
                                                  color: sub.reminderEnabled
                                                      ? AppColors.accentOrange
                                                      : AppColors
                                                            .textSecondaryDark,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),

                    bills.isEmpty
                        ? const Center(child: Text('No bills due.'))
                        : ListView.separated(
                            itemCount: bills.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final bill = bills[index];
                              final due = DateFormat(
                                'MMM dd, yyyy',
                              ).format(bill.dueDate);
                              return GlassCard(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: bill.isPaid,
                                      activeColor: AppColors.emeraldGreen,
                                      onChanged: (_) => ref
                                          .read(billsProvider.notifier)
                                          .togglePaid(bill.id),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            bill.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              decoration: bill.isPaid
                                                  ? TextDecoration.lineThrough
                                                  : null,
                                            ),
                                          ),
                                          Text(
                                            'Due by $due',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color:
                                                  AppColors.textSecondaryDark,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₹${bill.amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: bill.isPaid
                                            ? AppColors.emeraldGreen
                                            : AppColors.accentOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(List<dynamic> txs, List<dynamic> bills) {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final monthName = DateFormat('MMMM yyyy').format(_focusedMonth);

    final Map<int, bool> dayHasExpense = {};
    final Map<int, bool> dayHasBill = {};

    for (var tx in txs) {
      if (tx.date.year == year && tx.date.month == month) {
        dayHasExpense[tx.date.day] = true;
      }
    }
    for (var bill in bills) {
      if (bill.dueDate.year == year &&
          bill.dueDate.month == month &&
          !bill.isPaid) {
        dayHasBill[bill.dueDate.day] = true;
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(
                      () => _focusedMonth = DateTime(year, month - 1),
                    ),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () => setState(
                      () => _focusedMonth = DateTime(year, month + 1),
                    ),
                    icon: const Icon(Icons.chevron_right, color: Colors.white),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (e) => Text(
                    e,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final day = index + 1;
              final hasTx = dayHasExpense[day] ?? false;
              final hasBill = dayHasBill[day] ?? false;

              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withValues(alpha: 0.03),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasTx)
                          const CircleAvatar(
                            radius: 2,
                            backgroundColor: AppColors.accentPink,
                          ),
                        if (hasTx && hasBill) const SizedBox(width: 2),
                        if (hasBill)
                          const CircleAvatar(
                            radius: 2,
                            backgroundColor: AppColors.accentOrange,
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
