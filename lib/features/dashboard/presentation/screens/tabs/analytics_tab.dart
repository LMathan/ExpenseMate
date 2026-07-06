import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/core/widgets/interactive_chart.dart';
import 'package:espenseai/core/services/report_service.dart';
import 'dart:io';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/core/utils/category_emoji_helper.dart';
import 'package:espenseai/core/widgets/vector_illustrations.dart';
import 'package:hive/hive.dart';
import 'package:espenseai/core/storage/hive_helper.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/features/dashboard/presentation/providers/dashboard_provider.dart';

class AnalyticsTab extends ConsumerStatefulWidget {
  const AnalyticsTab({super.key});

  @override
  ConsumerState<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<AnalyticsTab> {
  ChartType _selectedChartType = ChartType.pie;
  String _timeRange = 'Monthly';
  final ReportService _reportService = ReportService();
  bool _isExporting = false;

  void _exportAndShare(String type, DateTime selectedMonth) async {
    setState(() => _isExporting = true);
    try {
      File file;
      String subject;
      if (type == 'PDF') {
        file = await _reportService.generatePdfReport(selectedMonth: selectedMonth);
        subject = 'My ExpenseMate Statement (${DateFormat('MMMM yyyy').format(selectedMonth)}) - PDF';
      } else if (type == 'Excel') {
        file = await _reportService.generateExcelReport(selectedMonth: selectedMonth);
        subject = 'My ExpenseMate Statement (${DateFormat('MMMM yyyy').format(selectedMonth)}) - Spreadsheet';
      } else {
        file = await _reportService.generateCsvReport(selectedMonth: selectedMonth);
        subject = 'My ExpenseMate Statement (${DateFormat('MMMM yyyy').format(selectedMonth)}) - CSV';
      }
      await _reportService.shareReport(file, subject: subject);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e'), backgroundColor: AppColors.accentPink),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final txs = ref.watch(transactionProvider);
    final budget = ref.watch(budgetProvider);
    final selectedMonth = ref.watch(analyticsMonthProvider);
    final settingsBox = Hive.box(HiveHelper.settingsBox);

    final filteredTxs = txs.where((tx) => tx.date.year == selectedMonth.year && tx.date.month == selectedMonth.month).toList();

    double currentMonthSpent = 0;
    for (var tx in filteredTxs) {
      currentMonthSpent += tx.amount;
    }

    final currentMonthIncome = budget.monthlyIncome;
    final currentMonthSavings = currentMonthIncome - currentMonthSpent;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final dividerColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final Map<String, double> categorySums = {};
    final Map<String, double> merchantSums = {};
    double totalSpent = 0.0;
    final Map<String, double> dailySums = {};

    for (var tx in filteredTxs) {
      totalSpent += tx.amount;
      categorySums[tx.category] = (categorySums[tx.category] ?? 0.0) + tx.amount;
      merchantSums[tx.merchant] = (merchantSums[tx.merchant] ?? 0.0) + tx.amount;
      final dateKey = tx.date.toString().substring(0, 10);
      dailySums[dateKey] = (dailySums[dateKey] ?? 0.0) + tx.amount;
    }

    final sortedCategories = categorySums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    String mostExpensiveDay = 'N/A';
    double maxDailySpent = 0;
    dailySums.forEach((date, sum) {
      if (sum > maxDailySpent) {
        maxDailySpent = sum;
        mostExpensiveDay = date;
      }
    });

    final avgDailySpend = dailySums.isEmpty ? 0.0 : totalSpent / dailySums.length;

    // Last Month Savings Comparison
    final lastMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    final lastMonthTxs = txs.where((tx) => tx.date.year == lastMonth.year && tx.date.month == lastMonth.month).toList();
    double lastMonthSpent = 0;
    for (var tx in lastMonthTxs) {
      lastMonthSpent += tx.amount;
    }
    final lastMonthSavings = currentMonthIncome - lastMonthSpent;
    final double savingsDiffPercent;
    if (lastMonthSavings == 0) {
      savingsDiffPercent = currentMonthSavings > 0 ? 100.0 : 0.0;
    } else {
      savingsDiffPercent = ((currentMonthSavings - lastMonthSavings) / lastMonthSavings.abs() * 100);
    }

    final List<double> trendValues;
    final List<String> trendLabels;

    if (_timeRange == 'Weekly') {
      final now = DateTime.now();
      if (selectedMonth.year == now.year && selectedMonth.month == now.month) {
        final currentWeekday = now.weekday;
        final startOfWeek = now.subtract(Duration(days: currentWeekday - 1));
        final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

        final List<double> weeklyRealValues = List.filled(7, 0.0);
        for (var tx in filteredTxs) {
          final txDateDay = DateTime(tx.date.year, tx.date.month, tx.date.day);
          final diffDays = txDateDay.difference(startOfWeekDay).inDays;
          if (diffDays >= 0 && diffDays < 7) {
            weeklyRealValues[diffDays] += tx.amount;
          }
        }
        trendValues = weeklyRealValues;
        trendLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      } else {
        final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
        final int numWeeks = daysInMonth > 28 ? 5 : 4;
        final List<double> weeklyRealValues = List.filled(numWeeks, 0.0);
        for (var tx in filteredTxs) {
          final day = tx.date.day;
          if (day <= 7) {
            weeklyRealValues[0] += tx.amount;
          } else if (day <= 14) {
            weeklyRealValues[1] += tx.amount;
          } else if (day <= 21) {
            weeklyRealValues[2] += tx.amount;
          } else if (day <= 28) {
            weeklyRealValues[3] += tx.amount;
          } else if (numWeeks == 5) {
            weeklyRealValues[4] += tx.amount;
          }
        }
        trendValues = weeklyRealValues;
        trendLabels = numWeeks == 5 ? ['W1', 'W2', 'W3', 'W4', 'W5'] : ['W1', 'W2', 'W3', 'W4'];
      }
    } else {
      final List<String> monthlyLabels = [];
      final List<double> monthlyRealValues = List.filled(6, 0.0);
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      for (int i = 5; i >= 0; i--) {
        final targetDate = DateTime(selectedMonth.year, selectedMonth.month - i, 1);
        monthlyLabels.add(monthNames[targetDate.month - 1]);
      }

      for (var tx in txs) {
        for (int i = 5; i >= 0; i--) {
          final targetMonthStart = DateTime(selectedMonth.year, selectedMonth.month - i, 1);
          final targetMonthEnd = DateTime(selectedMonth.year, selectedMonth.month - i + 1, 1).subtract(const Duration(seconds: 1));
          if (tx.date.isAfter(targetMonthStart.subtract(const Duration(seconds: 1))) && 
              tx.date.isBefore(targetMonthEnd.add(const Duration(seconds: 1)))) {
            monthlyRealValues[5 - i] += tx.amount;
            break;
          }
        }
      }
      trendValues = monthlyRealValues;
      trendLabels = monthlyLabels;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: AppBackground(
        type: PageBg.analytics,
        child: SafeArea(
        child: _isExporting
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.primaryPurple),
                    const SizedBox(height: 16),
                    Text('Compiling report...', style: TextStyle(color: subColor)),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Analytics & Reports', style: AppTextStyles.heading2(isDark: isDark)),
                    const SizedBox(height: 16),
                    // Month Switcher
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: Icon(Icons.chevron_left_rounded, color: textColor),
                            onPressed: () {
                              ref.read(analyticsMonthProvider.notifier).state = DateTime(selectedMonth.year, selectedMonth.month - 1);
                            },
                          ),
                          Text(
                            DateFormat('MMMM yyyy').format(selectedMonth),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              color: selectedMonth.year == DateTime.now().year && selectedMonth.month == DateTime.now().month
                                  ? subColor.withOpacity(0.3)
                                  : textColor,
                            ),
                            onPressed: selectedMonth.year == DateTime.now().year && selectedMonth.month == DateTime.now().month
                                ? null
                                : () {
                                    ref.read(analyticsMonthProvider.notifier).state = DateTime(selectedMonth.year, selectedMonth.month + 1);
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Chart type pills
                    Row(
                      children: [
                        _buildTypePill(ChartType.pie, Icons.pie_chart_rounded, 'Pie', isDark),
                        const SizedBox(width: 8),
                        _buildTypePill(ChartType.line, Icons.show_chart_rounded, 'Line', isDark),
                        const SizedBox(width: 8),
                        _buildTypePill(ChartType.bar, Icons.bar_chart_rounded, 'Bar', isDark),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (_selectedChartType != ChartType.pie) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _buildRangeButton('Weekly', isDark),
                          const SizedBox(width: 8),
                          _buildRangeButton('Monthly', isDark),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: AppColors.emeraldGreen.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Income',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${currentMonthIncome.toStringAsFixed(0)}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.emeraldGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: dividerColor,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.arrow_upward_rounded,
                                      size: 12,
                                      color: AppColors.primaryPurple.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Spent',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${currentMonthSpent.toStringAsFixed(0)}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: dividerColor,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.savings_rounded,
                                      size: 12,
                                      color: AppColors.electricBlue.withValues(alpha: 0.8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Savings',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: subColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${currentMonthSavings.toStringAsFixed(0)}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.electricBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Savings Comparison Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (savingsDiffPercent >= 0 ? AppColors.emeraldGreen : AppColors.accentPink).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              savingsDiffPercent >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                              color: savingsDiffPercent >= 0 ? AppColors.emeraldGreen : AppColors.accentPink,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  savingsDiffPercent >= 0
                                      ? 'Savings Increased'
                                      : 'Savings Decreased',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  savingsDiffPercent >= 0
                                      ? '${savingsDiffPercent.abs().toStringAsFixed(1)}% more savings than ${DateFormat('MMMM').format(lastMonth)}'
                                      : '${savingsDiffPercent.abs().toStringAsFixed(1)}% less savings than ${DateFormat('MMMM').format(lastMonth)}',
                                  style: TextStyle(color: subColor, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (savingsDiffPercent >= 0 ? AppColors.emeraldGreen : AppColors.accentPink).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${savingsDiffPercent >= 0 ? '+' : ''}${savingsDiffPercent.toStringAsFixed(1)}%',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: savingsDiffPercent >= 0 ? AppColors.emeraldGreen : AppColors.accentPink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    GlassCard(
                      child: InteractiveChart(
                        type: _selectedChartType,
                        data: categorySums,
                        trendData: trendValues,
                        labels: trendLabels,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Stat cards
                    Row(
                      children: [
                        Expanded(
                          child: _StatMiniCard(
                            label: 'Avg Daily',
                            value: '₹${avgDailySpend.toStringAsFixed(0)}',
                            icon: Icons.trending_up_rounded,
                            color: AppColors.electricBlue,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatMiniCard(
                            label: 'Peak Day',
                            value: mostExpensiveDay == 'N/A' ? 'N/A' : mostExpensiveDay.substring(5),
                            icon: Icons.local_fire_department_rounded,
                            color: AppColors.accentOrange,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatMiniCard(
                            label: 'Categories',
                            value: '${sortedCategories.length}',
                            icon: Icons.category_rounded,
                            color: AppColors.primaryPurple,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Top Categories
                    Text(
                      'TOP CATEGORIES',
                      style: AppTextStyles.caption(isDark: isDark).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: sortedCategories.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text('No transactions logged yet.', style: TextStyle(color: subColor)),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: sortedCategories.length > 5 ? 5 : sortedCategories.length,
                              separatorBuilder: (_, __) => Divider(color: dividerColor, height: 1),
                              itemBuilder: (context, index) {
                                final entry = sortedCategories[index];
                                final pct = totalSpent > 0
                                    ? (entry.value / totalSpent * 100)
                                    : 0.0;
                                final pctStr = pct.toStringAsFixed(1);
                                final barColors = [
                                  AppColors.primaryPurple,
                                  AppColors.electricBlue,
                                  AppColors.emeraldGreen,
                                  AppColors.accentOrange,
                                  AppColors.accentPink,
                                ];
                                final barColor = barColors[index % barColors.length];

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: barColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              getCategoryEmoji(entry.key),
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              entry.key,
                                              style: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                                color: textColor,
                                              ),
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '₹${entry.value.toStringAsFixed(0)}',
                                                style: GoogleFonts.inter(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                  color: textColor,
                                                ),
                                              ),
                                              Text(
                                                '$pctStr%',
                                                style: TextStyle(color: subColor, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: pct / 100,
                                          minHeight: 5,
                                          backgroundColor: barColor.withValues(alpha: 0.1),
                                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 24),

                    // Export
                    Text(
                      'EXPORT STATEMENTS',
                      style: AppTextStyles.caption(isDark: isDark).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildExportButton('PDF', Icons.picture_as_pdf_rounded, Colors.redAccent, isDark, selectedMonth)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildExportButton('Excel', Icons.table_chart_rounded, Colors.green, isDark, selectedMonth)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildExportButton('CSV', Icons.notes_rounded, Colors.blue, isDark, selectedMonth)),
                      ],
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildTypePill(ChartType type, IconData icon, String text, bool isDark) {
    final isSelected = _selectedChartType == type;
    final inactiveColor = isDark ? AppColors.cardDark : Colors.white;
    final inactiveBorder = isDark ? AppColors.borderDark : AppColors.borderLight;
    final inactiveText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => setState(() => _selectedChartType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : inactiveColor,
          border: Border.all(
            color: isSelected ? Colors.transparent : inactiveBorder,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primaryPurple.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : inactiveText),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : inactiveText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeButton(String range, bool isDark) {
    final isSelected = _timeRange == range;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return GestureDetector(
      onTap: () => setState(() => _timeRange = range),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.primaryPurple : Colors.transparent,
          border: isSelected ? null : Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
        child: Text(
          range,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? Colors.white : subColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton(String label, IconData icon, Color color, bool isDark, DateTime selectedMonth) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    return InkWell(
      onTap: () => _exportAndShare(label, selectedMonth),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              'Share $label',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatMiniCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 10, color: subColor)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }
}
