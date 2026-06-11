import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/utils/category_emoji_helper.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/features/expense/presentation/screens/add_expense_screen.dart';
import 'package:espenseai/core/utils/transaction_permissions.dart';

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  ConsumerState<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _sortBy = 'Date (Newest)';

  final List<String> _categories = [
    'All', 'Food', 'Travel', 'Shopping', 'Entertainment',
    'Bills', 'Healthcare', 'Education', 'Rent', 'EMI', 'Fuel', 'Other',
  ];

  final List<String> _sortOptions = [
    'Date (Newest)', 'Date (Oldest)', 'Amount (Highest)', 'Amount (Lowest)',
  ];

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    List<dynamic> filtered = txs.where((tx) {
      final matchesSearch =
          tx.merchant.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.notes.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || tx.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    if (_sortBy == 'Date (Newest)') {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortBy == 'Date (Oldest)') {
      filtered.sort((a, b) => a.date.compareTo(b.date));
    } else if (_sortBy == 'Amount (Highest)') {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    } else {
      filtered.sort((a, b) => a.amount.compareTo(b.amount));
    }

    final totalFiltered = filtered.fold<double>(0, (s, tx) => s + tx.amount);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Transaction History',
          style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search + filter bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                children: [
                  TextField(
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search merchant, notes, category...',
                      hintStyle: TextStyle(color: subColor, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.electricBlue, size: 20),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.electricBlue, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              dropdownColor: cardBg,
                              icon: Icon(Icons.expand_more_rounded, color: subColor, size: 18),
                              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                              items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) { if (val != null) setState(() => _selectedCategory = val); },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              isExpanded: true,
                              dropdownColor: cardBg,
                              icon: Icon(Icons.expand_more_rounded, color: subColor, size: 18),
                              style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
                              items: _sortOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                              onChanged: (val) { if (val != null) setState(() => _sortBy = val); },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Summary row
            if (filtered.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${filtered.length} transactions',
                        style: const TextStyle(color: AppColors.primaryPurple, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accentPink.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Total: ₹${totalFiltered.toStringAsFixed(2)}',
                        style: const TextStyle(color: AppColors.accentPink, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 56, color: subColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No transactions found.', style: TextStyle(color: subColor, fontSize: 14)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _buildCard(filtered[index], isDark, textColor, subColor),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(dynamic tx, bool isDark, Color textColor, Color subColor) {
    final String formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(tx.date);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
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
                child: Text(getCategoryEmoji(tx.category), style: const TextStyle(fontSize: 20)),
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
                    Text(formattedDate, style: TextStyle(fontSize: 11, color: subColor)),
                  ],
                ),
              ),
              Text(
                '-₹${tx.amount.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.accentPink, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Details row
          Row(
            children: [
              _DetailChip(label: tx.category, color: AppColors.primaryPurple),
              const SizedBox(width: 6),
              _DetailChip(label: tx.paymentMethod, color: AppColors.electricBlue),
              if (tx.isRecurring) ...[
                const SizedBox(width: 6),
                _DetailChip(label: 'Recurring', color: AppColors.accentOrange),
              ],
            ],
          ),

          if (tx.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.notes_rounded, size: 12, color: subColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tx.notes,
                    style: TextStyle(fontSize: 11, color: subColor),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          if (canEditTransaction(tx, ref)) ...[
            const SizedBox(height: 10),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionBtn(
                  label: 'Edit',
                  icon: Icons.edit_rounded,
                  color: AppColors.electricBlue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddExpenseScreen(
                        editTransaction: tx,
                        preFilledAmount: tx.amount,
                        preFilledCategory: tx.category,
                        preFilledMerchant: tx.merchant,
                        preFilledNotes: tx.notes,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ActionBtn(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  onTap: () {
                    final isDarkLocal = Theme.of(context).brightness == Brightness.dark;
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: isDarkLocal ? AppColors.cardDark : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text('Delete Transaction',
                            style: TextStyle(color: isDarkLocal ? Colors.white : AppColors.textPrimaryLight, fontWeight: FontWeight.bold)),
                        content: Text('Delete this transaction permanently?',
                            style: TextStyle(color: isDarkLocal ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
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
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final Color color;
  const _DetailChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});

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
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
