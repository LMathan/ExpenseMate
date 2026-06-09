import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/core/widgets/gradient_progress_bar.dart';
import 'package:espenseai/core/widgets/interactive_chart.dart';
import 'package:espenseai/core/services/sms_service.dart';
import 'package:espenseai/core/services/ocr_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/features/expense/presentation/screens/add_expense_screen.dart';
import 'package:espenseai/features/expense/presentation/screens/expense_history_screen.dart';

class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final SmsService _smsService = SmsService();
  final OcrService _ocrService = OcrService();
  Map<String, dynamic>? _pendingSmsTransaction;

  void _simulateIncomingSms() {
    const mockSms = "Alert: Debited Rs 450.00 at Swiggy on 09-06-2026. Avl Bal Rs.45,200.00";
    final parsed = _smsService.parseSms(mockSms);
    if (parsed != null) {
      setState(() {
        _pendingSmsTransaction = parsed;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Simulated bank SMS received! Check approval card.'),
          backgroundColor: AppColors.primaryPurple,
        ),
      );
    }
  }

  void _approveSmsTransaction() {
    if (_pendingSmsTransaction != null) {
      ref.read(transactionProvider.notifier).addTransaction(
            amount: _pendingSmsTransaction!['amount'] as double,
            category: _pendingSmsTransaction!['category'] as String,
            merchant: _pendingSmsTransaction!['merchant'] as String,
            notes: _pendingSmsTransaction!['notes'] as String,
            paymentMethod: _pendingSmsTransaction!['paymentMethod'] as String,
            date: DateTime.parse(_pendingSmsTransaction!['date']),
          );
      setState(() {
        _pendingSmsTransaction = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction approved & logged!'),
          backgroundColor: AppColors.emeraldGreen,
        ),
      );
    }
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
          MaterialPageRoute(
            builder: (context) => AddExpenseScreen(
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

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionProvider);
    final budget = ref.watch(budgetProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double currentMonthSpent = 0;
    final now = DateTime.now();
    for (var tx in txs) {
      if (tx.date.year == now.year && tx.date.month == now.month) {
        currentMonthSpent += tx.amount;
      }
    }

    final remaining = budget.monthlyIncome - currentMonthSpent;
    final progress = budget.monthlyIncome > 0 ? currentMonthSpent / budget.monthlyIncome : 0.0;
    final savings = remaining > 0 ? remaining : 0.0;

    final weeklyTrend = [1200.0, 4500.0, 1800.0, 950.0, 3200.0, 450.0, 2000.0];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.read(transactionProvider.notifier).loadTransactions();
            ref.read(budgetProvider.notifier).loadBudget();
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
                          height: 36,
                          width: 36,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ExpenseAI',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _simulateIncomingSms,
                          icon: const Icon(Icons.sms_rounded, color: AppColors.electricBlue),
                          tooltip: 'Simulate Bank SMS',
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                          ),
                          child: const CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150'),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good Morning,',
                      style: AppTextStyles.bodyMedium(isDark: isDark).copyWith(
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                    Text(
                      'Mathan',
                      style: AppTextStyles.heading2(isDark: isDark).copyWith(fontSize: 26),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                if (_pendingSmsTransaction != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.accentPink.withOpacity(0.5)),
                      color: AppColors.accentPink.withOpacity(0.12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.accentPink, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'SMS Expense Detected',
                              style: GoogleFonts.outfit(color: AppColors.accentPink, fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _pendingSmsTransaction = null),
                              child: const Icon(Icons.close, color: AppColors.textSecondaryDark, size: 18),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '₹${_pendingSmsTransaction!['amount']} debited to ${_pendingSmsTransaction!['merchant']}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Category: ${_pendingSmsTransaction!['category']} • ${_pendingSmsTransaction!['paymentMethod']}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryDark),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                final data = _pendingSmsTransaction!;
                                setState(() => _pendingSmsTransaction = null);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddExpenseScreen(
                                      preFilledAmount: data['amount'] as double,
                                      preFilledCategory: data['category'] as String,
                                      preFilledMerchant: data['merchant'] as String,
                                      preFilledNotes: data['notes'] as String,
                                    ),
                                  ),
                                );
                              },
                              child: const Text('Edit Details', style: TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: _approveSmsTransaction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentPink,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Approve & Add'),
                            ),
                          ],
                        )
                      ],
                    ),
                  )
                ],
                
                GlassCard(
                  gradientColors: isDark
                      ? [
                          AppColors.primaryPurple.withOpacity(0.25),
                          AppColors.electricBlue.withOpacity(0.05),
                        ]
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'REMAINING BALANCE',
                                style: AppTextStyles.caption(isDark: isDark).copyWith(
                                  letterSpacing: 1.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${remaining.toStringAsFixed(2)}',
                                style: AppTextStyles.heading1(isDark: isDark).copyWith(
                                  fontSize: 30,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.emeraldGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Savings: ₹${savings.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppColors.emeraldGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      GradientProgressBar(progress: progress),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Spent: ₹${currentMonthSpent.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall(isDark: isDark),
                          ),
                          Text(
                            'Budget: ₹${budget.monthlyIncome.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall(isDark: isDark),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _buildQuickAction(
                      icon: Icons.add_rounded,
                      label: 'Add Expense',
                      color: AppColors.primaryPurple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
                      ),
                    ),
                    _buildQuickAction(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Scan Receipt',
                      color: AppColors.electricBlue,
                      onTap: _triggerOcrScan,
                    ),
                    _buildQuickAction(
                      icon: Icons.history_edu_rounded,
                      label: 'All History',
                      color: AppColors.emeraldGreen,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ExpenseHistoryScreen()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'WEEKLY SPENDING',
                      style: AppTextStyles.caption(isDark: isDark).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textSecondaryDark),
                  ],
                ),
                const SizedBox(height: 12),
                GlassCard(
                  child: InteractiveChart(
                    type: ChartType.line,
                    data: const {},
                    trendData: weeklyTrend,
                    labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
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
                        MaterialPageRoute(builder: (context) => const ExpenseHistoryScreen()),
                      ),
                      child: const Text('View All', style: TextStyle(color: AppColors.electricBlue)),
                    ),
                  ],
                ),
                
                txs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No transactions recorded yet.', style: TextStyle(color: AppColors.textSecondaryDark))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: txs.length > 5 ? 5 : txs.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final tx = txs[index];
                          return _buildTransactionCard(tx, isDark);
                        },
                      ),
              ],
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
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        borderRadius: 16,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.15),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted')),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryPurple.withOpacity(0.12),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$formattedDate • ${tx.paymentMethod}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryDark),
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
