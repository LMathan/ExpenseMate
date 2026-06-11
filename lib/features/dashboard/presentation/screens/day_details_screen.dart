import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/models/transaction_model.dart';
import 'package:espenseai/core/utils/category_emoji_helper.dart';
import 'package:espenseai/core/utils/app_page_route.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/features/expense/presentation/screens/add_expense_screen.dart';
import 'package:espenseai/core/widgets/vector_illustrations.dart';
import 'package:espenseai/core/utils/transaction_permissions.dart';

class DayDetailsScreen extends ConsumerWidget {
  final DateTime date;

  const DayDetailsScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allTxs = ref.watch(transactionProvider);
    final allBills = ref.watch(billsProvider);

    final dayTxs = allTxs
        .where((tx) =>
            tx.date.year == date.year &&
            tx.date.month == date.month &&
            tx.date.day == date.day)
        .toList();

    final dayBills = allBills
        .where((b) =>
            b.dueDate.year == date.year &&
            b.dueDate.month == date.month &&
            b.dueDate.day == date.day)
        .toList();

    final totalSpent = dayTxs.fold<double>(0, (s, t) => s + t.amount);
    final totalBills = dayBills.fold<double>(0, (s, b) => s + b.amount);

    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: bgColor,
      body: AppBackground(
        type: PageBg.planner,
        child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.bgDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryPurple, AppColors.electricBlue],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat('EEEE').format(date),
                          style: GoogleFonts.outfit(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMMM dd, yyyy').format(date),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StatChip(
                                label: 'Spent',
                                value: '₹${totalSpent.toStringAsFixed(0)}',
                                color: AppColors.accentPink),
                            const SizedBox(width: 10),
                            _StatChip(
                                label: 'Bills',
                                value: '₹${totalBills.toStringAsFixed(0)}',
                                color: AppColors.accentOrange),
                            const SizedBox(width: 10),
                            _StatChip(
                                label: 'Transactions',
                                value: '${dayTxs.length}',
                                color: AppColors.emeraldGreen),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (dayTxs.isEmpty && dayBills.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_available_rounded,
                          size: 48, color: AppColors.primaryPurple),
                    ),
                    const SizedBox(height: 16),
                    Text('No Activity',
                        style: GoogleFonts.outfit(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('No transactions or bills for this date.',
                        style: TextStyle(color: textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (dayTxs.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Expenses',
                      count: dayTxs.length,
                      color: AppColors.accentPink,
                      icon: Icons.receipt_long_rounded,
                    ),
                    const SizedBox(height: 12),
                    ...dayTxs.asMap().entries.map((e) => _TransactionCard(
                          tx: e.value,
                          index: e.key,
                          isDark: isDark,
                          textColor: textColor,
                          textSecondary: textSecondary,
                          onEdit: () => Navigator.push(
                            context,
                            AppPageRoute(
                              page: AddExpenseScreen(
                                editTransaction: e.value,
                                preFilledAmount: e.value.amount,
                                preFilledCategory: e.value.category,
                                preFilledMerchant: e.value.merchant,
                                preFilledNotes: e.value.notes,
                              ),
                            ),
                          ),
                          onDelete: () => _confirmDelete(
                              context, ref, e.value, isDark, textColor,
                              textSecondary),
                          showActions: canEditTransaction(e.value, ref),
                        )),
                    const SizedBox(height: 24),
                  ],
                  if (dayBills.isNotEmpty) ...[
                    _SectionHeader(
                      title: 'Bills Due',
                      count: dayBills.length,
                      color: AppColors.accentOrange,
                      icon: Icons.notifications_active_rounded,
                    ),
                    const SizedBox(height: 12),
                    ...dayBills.map((b) => _BillCard(
                          bill: b,
                          isDark: isDark,
                          textColor: textColor,
                          textSecondary: textSecondary,
                        )),
                  ],
                ]),
              ),
            ),
        ],
      ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref,
      TransactionModel tx, bool isDark, Color textColor, Color textSecondary) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Transaction',
            style: TextStyle(
                color: textColor, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this transaction?',
            style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Transaction deleted'),
                  backgroundColor: AppColors.accentPink,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Stat Chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('$label: ',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  const _SectionHeader(
      {required this.title,
      required this.count,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Text('$count',
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ─── Transaction Card with Edit/Delete ───────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  final TransactionModel tx;
  final int index;
  final bool isDark;
  final Color textColor, textSecondary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showActions;

  const _TransactionCard({
    required this.tx,
    required this.index,
    required this.isDark,
    required this.textColor,
    required this.textSecondary,
    required this.onEdit,
    required this.onDelete,
    required this.showActions,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = getCategoryEmoji(tx.category);
    final title = tx.merchant.isNotEmpty ? tx.merchant : tx.category;
    final time = DateFormat('hh:mm a').format(tx.date);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + index * 60),
      curve: Curves.easeOut,
      builder: (_, v, child) =>
          Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey[200]!,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accentPink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.outfit(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _Chip(
                              label: tx.category,
                              color: AppColors.primaryPurple),
                          const SizedBox(width: 6),
                          Text(tx.paymentMethod,
                              style: TextStyle(
                                  color: textSecondary, fontSize: 10)),
                          const SizedBox(width: 4),
                          Text('• $time',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 10)),
                        ],
                      ),
                      if (tx.notes.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(tx.notes,
                            style: TextStyle(
                                color: textSecondary, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('-₹${tx.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppColors.accentPink,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
            if (showActions) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _ActionBtn(
                      label: 'Edit',
                      icon: Icons.edit_rounded,
                      color: AppColors.electricBlue,
                      onTap: onEdit),
                  const SizedBox(width: 8),
                  _ActionBtn(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      onTap: onDelete),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─── Bill Card ────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final dynamic bill;
  final bool isDark;
  final Color textColor, textSecondary;
  const _BillCard(
      {required this.bill,
      required this.isDark,
      required this.textColor,
      required this.textSecondary});

  @override
  Widget build(BuildContext context) {
    final emoji = getCategoryEmoji(bill.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bill.isPaid
              ? AppColors.emeraldGreen.withValues(alpha: 0.3)
              : AppColors.accentOrange.withValues(alpha: 0.3),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (bill.isPaid ? AppColors.emeraldGreen : AppColors.accentOrange)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.title,
                    style: GoogleFonts.outfit(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration:
                            bill.isPaid ? TextDecoration.lineThrough : null)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Chip(
                        label: bill.isPaid ? 'Paid' : 'Pending',
                        color: bill.isPaid
                            ? AppColors.emeraldGreen
                            : AppColors.accentOrange),
                    const SizedBox(width: 6),
                    Text(bill.category,
                        style:
                            TextStyle(color: textSecondary, fontSize: 10)),
                    if (bill.recurrence != null &&
                        bill.recurrence != 'One-time') ...[
                      const SizedBox(width: 6),
                      Text('• ${bill.recurrence}',
                          style:
                              TextStyle(color: textSecondary, fontSize: 10)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text('₹${bill.amount.toStringAsFixed(2)}',
              style: TextStyle(
                  color: bill.isPaid
                      ? AppColors.emeraldGreen
                      : AppColors.accentOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ],
      ),
    );
  }
}
