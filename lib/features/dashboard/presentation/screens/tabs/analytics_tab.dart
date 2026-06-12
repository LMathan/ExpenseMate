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

  void _exportAndShare(String type) async {
    setState(() => _isExporting = true);
    try {
      File file;
      String subject;
      if (type == 'PDF') {
        file = await _reportService.generatePdfReport();
        subject = 'My ExpenseMate Statement - PDF';
      } else if (type == 'Excel') {
        file = await _reportService.generateExcelReport();
        subject = 'My ExpenseMate Statement - Spreadsheet';
      } else {
        file = await _reportService.generateCsvReport();
        subject = 'My ExpenseMate Statement - CSV';
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

    for (var tx in txs) {
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

    final List<double> trendValues;
    final List<String> trendLabels;

    if (_timeRange == 'Weekly') {
      final now = DateTime.now();
      final currentWeekday = now.weekday;
      final startOfWeek = now.subtract(Duration(days: currentWeekday - 1));
      final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

      final List<double> weeklyRealValues = List.filled(7, 0.0);
      for (var tx in txs) {
        final txDateDay = DateTime(tx.date.year, tx.date.month, tx.date.day);
        final diffDays = txDateDay.difference(startOfWeekDay).inDays;
        if (diffDays >= 0 && diffDays < 7) {
          weeklyRealValues[diffDays] += tx.amount;
        }
      }
      trendValues = weeklyRealValues;
      trendLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    } else {
      final now = DateTime.now();
      final List<String> monthlyLabels = [];
      final List<double> monthlyRealValues = List.filled(6, 0.0);
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      for (int i = 5; i >= 0; i--) {
        final targetDate = DateTime(now.year, now.month - i, 1);
        monthlyLabels.add(monthNames[targetDate.month - 1]);
      }

      for (var tx in txs) {
        for (int i = 5; i >= 0; i--) {
          final targetMonthStart = DateTime(now.year, now.month - i, 1);
          final targetMonthEnd = DateTime(now.year, now.month - i + 1, 1).subtract(const Duration(seconds: 1));
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
                        Expanded(child: _buildExportButton('PDF', Icons.picture_as_pdf_rounded, Colors.redAccent, isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildExportButton('Excel', Icons.table_chart_rounded, Colors.green, isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildExportButton('CSV', Icons.notes_rounded, Colors.blue, isDark)),
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

  Widget _buildExportButton(String label, IconData icon, Color color, bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    return InkWell(
      onTap: () => _exportAndShare(label),
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
