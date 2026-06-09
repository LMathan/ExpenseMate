import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';

class ExpenseHistoryScreen extends ConsumerStatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  ConsumerState<ExpenseHistoryScreen> createState() =>
      _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends ConsumerState<ExpenseHistoryScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  final String _selectedPaymentMethod = 'All';
  String _sortBy = 'Date (Newest)';

  final List<String> _categories = [
    'All',
    'Food',
    'Travel',
    'Shopping',
    'Entertainment',
    'Bills',
    'Healthcare',
    'Education',
    'Rent',
    'EMI',
    'Fuel',
    'Other',
  ];

  final List<String> _paymentMethods = [
    'All',
    'UPI',
    'Credit Card',
    'Debit Card',
    'NetBanking',
    'Cash',
  ];

  final List<String> _sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Amount (Highest)',
    'Amount (Lowest)',
  ];

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<dynamic> filtered = txs.where((tx) {
      final matchesSearch =
          tx.merchant.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          tx.notes.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'All' || tx.category == _selectedCategory;
      final matchesMethod =
          _selectedPaymentMethod == 'All' ||
          tx.paymentMethod == _selectedPaymentMethod;

      return matchesSearch && matchesCategory && matchesMethod;
    }).toList();

    if (_sortBy == 'Date (Newest)') {
      filtered.sort((a, b) => b.date.compareTo(a.date));
    } else if (_sortBy == 'Date (Oldest)') {
      filtered.sort((a, b) => a.date.compareTo(b.date));
    } else if (_sortBy == 'Amount (Highest)') {
      filtered.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortBy == 'Amount (Lowest)') {
      filtered.sort((a, b) => a.amount.compareTo(b.amount));
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          'Transactions Ledger',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 10,
              ),
              child: Column(
                children: [
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search merchant or description...',
                      hintStyle: const TextStyle(
                        color: AppColors.textSecondaryDark,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.electricBlue,
                      ),
                      filled: true,
                      fillColor: AppColors.cardDark.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              dropdownColor: AppColors.cardDark,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              items: _categories
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _sortBy,
                              isExpanded: true,
                              dropdownColor: AppColors.cardDark,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              items: _sortOptions
                                  .map(
                                    (o) => DropdownMenuItem(
                                      value: o,
                                      child: Text(o),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _sortBy = val);
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No matching transactions found.',
                        style: TextStyle(color: AppColors.textSecondaryDark),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        return _buildTransactionCard(tx, isDark);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(dynamic tx, bool isDark) {
    final Map<String, IconData> categoryIcons = {
      'Food': Icons.restaurant_rounded,
      'Travel': Icons.directions_car_rounded,
      'Shopping': Icons.shopping_bag_rounded,
      'Entertainment': Icons.videogame_asset_rounded,
      'Bills': Icons.receipt_long_rounded,
      'Healthcare': Icons.medical_services_rounded,
      'Education': Icons.school_rounded,
      'Rent': Icons.home_work_rounded,
      'EMI': Icons.credit_card_rounded,
      'Fuel': Icons.local_gas_station_rounded,
      'Other': Icons.category_rounded,
    };

    final IconData icon = categoryIcons[tx.category] ?? Icons.category_rounded;
    final String formattedDate = DateFormat('MMM dd, yyyy').format(tx.date);

    return Dismissible(
      key: Key(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction deleted')));
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryPurple, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.merchant.isEmpty ? tx.category : tx.merchant,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$formattedDate • ${tx.paymentMethod}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '-₹${tx.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.accentPink,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
