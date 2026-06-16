import 'package:flutter/material.dart';
import 'package:espenseai/core/utils/app_page_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/core/utils/category_emoji_helper.dart';
import 'package:espenseai/features/dashboard/presentation/screens/day_details_screen.dart';
import 'package:espenseai/core/widgets/vector_illustrations.dart';
import 'package:espenseai/core/models/subscription_model.dart';
import 'package:espenseai/core/models/bill_reminder_model.dart';

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

  void _showAddSubscriptionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String category = 'Entertainment';
    String cycle = 'Monthly';
    DateTime dueDate = DateTime.now();

    showAnimatedDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Subscription', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Subscription Name (e.g. Netflix)',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      items: ['Entertainment', 'Bills', 'Services', 'Education', 'Other']
                          .map((cat) => DropdownMenuItem(value: cat, child: Text('${getCategoryEmoji(cat)} $cat')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: cycle,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Billing Cycle',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                      items: ['Monthly', 'Yearly', 'Weekly']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => cycle = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Next Renewal: ', style: TextStyle(color: Colors.white)),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => dueDate = picked);
                            }
                          },
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(dueDate),
                            style: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (title.isNotEmpty && amount > 0) {
                      ref.read(subscriptionsProvider.notifier).addSubscription(
                            title: title,
                            amount: amount,
                            dueDate: dueDate,
                            billingCycle: cycle,
                            category: category,
                          );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subscription added successfully!'),
                          backgroundColor: AppColors.emeraldGreen,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditSubscriptionDialog(SubscriptionModel sub) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController(text: sub.title);
    final amountController = TextEditingController(text: sub.amount.toString());
    String category = sub.category;
    String cycle = sub.billingCycle;
    DateTime dueDate = sub.dueDate;

    showAnimatedDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Subscription', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Subscription Name (e.g. Netflix)',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      items: ['Entertainment', 'Bills', 'Services', 'Education', 'Other']
                          .map((cat) => DropdownMenuItem(value: cat, child: Text('${getCategoryEmoji(cat)} $cat')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: cycle,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Billing Cycle',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                      items: ['Monthly', 'Yearly', 'Weekly']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => cycle = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Next Renewal: ', style: TextStyle(color: Colors.white)),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => dueDate = picked);
                            }
                          },
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(dueDate),
                            style: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(subscriptionsProvider.notifier).deleteSubscription(sub.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Subscription deleted successfully.'),
                        backgroundColor: AppColors.accentPink,
                      ),
                    );
                  },
                  child: const Text('Delete', style: TextStyle(color: AppColors.accentPink)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (title.isNotEmpty && amount > 0) {
                      ref.read(subscriptionsProvider.notifier).editSubscription(
                            id: sub.id,
                            title: title,
                            amount: amount,
                            dueDate: dueDate,
                            billingCycle: cycle,
                            category: category,
                            reminderEnabled: sub.reminderEnabled,
                          );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subscription updated successfully!'),
                          backgroundColor: AppColors.emeraldGreen,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddBillDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String category = 'Bills';
    String recurrence = 'One-time';
    DateTime dueDate = DateTime.now();

    showAnimatedDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add Bill Reminder', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Bill Name (e.g. Rent, Gas)',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      items: ['Bills', 'Rent', 'EMI', 'Healthcare', 'Education', 'Other']
                          .map((cat) => DropdownMenuItem(value: cat, child: Text('${getCategoryEmoji(cat)} $cat')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: recurrence,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Recurrence',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                      items: ['One-time', 'Monthly', 'Yearly']
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => recurrence = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Due Date: ', style: TextStyle(color: Colors.white)),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => dueDate = picked);
                            }
                          },
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(dueDate),
                            style: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (title.isNotEmpty && amount > 0) {
                      ref.read(billsProvider.notifier).addBill(
                            title: title,
                            amount: amount,
                            dueDate: dueDate,
                            category: category,
                            recurrence: recurrence,
                          );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bill reminder added successfully!'),
                          backgroundColor: AppColors.emeraldGreen,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditBillDialog(BillReminderModel bill) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleController = TextEditingController(text: bill.title);
    final amountController = TextEditingController(text: bill.amount.toString());
    String category = bill.category;
    String recurrence = bill.recurrence;
    DateTime dueDate = bill.dueDate;

    showAnimatedDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.bgDark,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Bill Reminder', style: TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Bill Name (e.g. Rent, Gas)',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Amount (₹)',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: category,
                      dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: 'Category',
                        labelStyle: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      items: ['Bills', 'Rent', 'EMI', 'Healthcare', 'Education', 'Other']
                          .map((cat) => DropdownMenuItem(value: cat, child: Text('${getCategoryEmoji(cat)} $cat')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => category = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: recurrence,
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Recurrence',
                        labelStyle: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                      items: ['One-time', 'Monthly', 'Yearly']
                          .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => recurrence = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Due Date: ', style: TextStyle(color: Colors.white)),
                        TextButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: dueDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() => dueDate = picked);
                            }
                          },
                          child: Text(
                            DateFormat('MMM dd, yyyy').format(dueDate),
                            style: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ref.read(billsProvider.notifier).deleteBill(bill.id);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bill reminder deleted successfully.'),
                        backgroundColor: AppColors.accentPink,
                      ),
                    );
                  },
                  child: const Text('Delete', style: TextStyle(color: AppColors.accentPink)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondaryDark)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final amount = double.tryParse(amountController.text) ?? 0.0;
                    if (title.isNotEmpty && amount > 0) {
                      ref.read(billsProvider.notifier).editBill(
                            id: bill.id,
                            title: title,
                            amount: amount,
                            dueDate: dueDate,
                            category: category,
                            recurrence: recurrence,
                            isPaid: bill.isPaid,
                          );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bill reminder updated successfully!'),
                          backgroundColor: AppColors.emeraldGreen,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final subs = ref.watch(subscriptionsProvider);
    final bills = ref.watch(billsProvider);
    final txs = ref.watch(transactionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double subTotal = subs.fold(0.0, (sum, sub) => sum + sub.amount);

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: AppBackground(
        type: PageBg.planner,
        child: SafeArea(
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
                labelColor: isDark ? Colors.white : Colors.black87,
                unselectedLabelColor: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                              Text(
                                'Monthly Subscriptions:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    '₹${subTotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.accentPink,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: _showAddSubscriptionDialog,
                                    icon: const Icon(
                                      Icons.add_circle_outline_rounded,
                                      color: AppColors.electricBlue,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
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
                                    return GestureDetector(
                                       onTap: () => _showEditSubscriptionDialog(sub),
                                       child: GlassCard(
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
                                                     style: TextStyle(
                                                       fontWeight: FontWeight.bold,
                                                       color: isDark ? Colors.white : Colors.black87,
                                                     ),
                                                   ),
                                                   Text(
                                                     '${getCategoryEmoji(sub.category)} ${sub.category} • Renews on $renewal',
                                                     style: TextStyle(
                                                       fontSize: 11,
                                                       color: isDark
                                                           ? AppColors.textSecondaryDark
                                                           : AppColors.textSecondaryLight,
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
                                                   style: TextStyle(
                                                     fontWeight: FontWeight.bold,
                                                     color: isDark ? Colors.white : Colors.black87,
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
                                       ),
                                     );
                                  },
                                ),
                        ),
                      ],
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Bill Reminders:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              IconButton(
                                onPressed: _showAddBillDialog,
                                icon: const Icon(
                                  Icons.add_circle_outline_rounded,
                                  color: AppColors.electricBlue,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: bills.isEmpty
                              ? const Center(
                                  child: Text('No bills due.', style: TextStyle(color: AppColors.textSecondaryDark)),
                                )
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
                                             child: GestureDetector(
                                               onTap: () => _showEditBillDialog(bill),
                                               behavior: HitTestBehavior.opaque,
                                               child: Column(
                                                 crossAxisAlignment:
                                                     CrossAxisAlignment.start,
                                                 children: [
                                                   Text(
                                                     bill.title,
                                                     style: TextStyle(
                                                       fontWeight: FontWeight.bold,
                                                       color: isDark ? Colors.white : Colors.black87,
                                                       decoration: bill.isPaid
                                                           ? TextDecoration.lineThrough
                                                           : null,
                                                     ),
                                                   ),
                                                   Text(
                                                     '${getCategoryEmoji(bill.category)} ${bill.category} • Due by $due',
                                                     style: TextStyle(
                                                       fontSize: 11,
                                                       color: isDark
                                                           ? AppColors.textSecondaryDark
                                                           : AppColors.textSecondaryLight,
                                                     ),
                                                   ),
                                                 ],
                                               ),
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
      ),
    );
  }

  Widget _buildCalendarGrid(List<dynamic> txs, List<dynamic> bills) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final navIconColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final isToday = DateTime.now().year == year && DateTime.now().month == month;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    monthName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                  ),
                  if (isToday)
                    Text('Today: ${DateTime.now().day}', style: TextStyle(fontSize: 10, color: AppColors.primaryPurple)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _focusedMonth = DateTime(year, month - 1)),
                    icon: Icon(Icons.chevron_left_rounded, color: navIconColor),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    onPressed: () => setState(() => _focusedMonth = DateTime(year, month + 1)),
                    icon: Icon(Icons.chevron_right_rounded, color: navIconColor),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'].map((e) => Text(
              e,
              style: TextStyle(fontSize: 9, color: subColor, fontWeight: FontWeight.w600),
            )).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 4,
              childAspectRatio: 0.8,
            ),
            itemCount: daysInMonth,
            itemBuilder: (context, index) {
              final day = index + 1;
              final hasTx = dayHasExpense[day] ?? false;
              final hasBill = dayHasBill[day] ?? false;
              final cellDate = DateTime(year, month, day);
              final isToday2 = DateTime.now().year == year && DateTime.now().month == month && DateTime.now().day == day;
              final hasActivity = hasTx || hasBill;

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  AppPageRoute(page: DayDetailsScreen(date: cellDate), type: RouteTransitionType.slideRight),
                ),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: isToday2
                        ? AppColors.primaryPurple.withValues(alpha: isDark ? 0.3 : 0.15)
                        : hasActivity
                            ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white)
                            : Colors.transparent,
                    border: isToday2
                        ? Border.all(color: AppColors.primaryPurple, width: 1.5)
                        : hasActivity
                            ? Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.borderLight)
                            : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isToday2 ? FontWeight.w800 : FontWeight.w500,
                          color: isToday2 ? AppColors.primaryPurple : textColor,
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
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
