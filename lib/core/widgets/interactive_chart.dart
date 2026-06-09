import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

enum ChartType { line, bar, pie }

class InteractiveChart extends StatefulWidget {
  final ChartType type;
  final Map<String, double>
  data; // For Pie chart: {'Food': 500.0, 'Travel': 200.0...}
  final List<double>? trendData; // For Line/Bar chart: [120.0, 300.0, 450.0...]
  final List<String>? labels; // For Line/Bar chart labels: ['Mon', 'Tue'...]

  const InteractiveChart({
    super.key,
    required this.type,
    required this.data,
    this.trendData,
    this.labels,
  });

  @override
  State<InteractiveChart> createState() => _InteractiveChartState();
}

class _InteractiveChartState extends State<InteractiveChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (widget.type) {
      case ChartType.pie:
        return _buildPieChart(isDark);
      case ChartType.line:
        return _buildLineChart(isDark);
      case ChartType.bar:
        return _buildBarChart(isDark);
    }
  }

  Widget _buildPieChart(bool isDark) {
    final entries = widget.data.entries.toList();
    if (entries.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final total = entries
        .map((e) => e.value)
        .fold<double>(0, (sum, val) => sum + val);

    final List<Color> colors = [
      AppColors.primaryPurple,
      AppColors.electricBlue,
      AppColors.emeraldGreen,
      AppColors.accentOrange,
      AppColors.accentPink,
      Colors.cyan,
      Colors.indigo,
      Colors.teal,
    ];

    return Stack(
      alignment: Alignment.center,
      children: [
        AspectRatio(
          aspectRatio: 1.3,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 4,
              centerSpaceRadius: 50,
              sections: List.generate(entries.length, (i) {
                final isTouched = i == touchedIndex;
                final fontSize = isTouched ? 16.0 : 12.0;
                final radius = isTouched ? 65.0 : 55.0;
                final value = entries[i].value;
                final percentage = total > 0
                    ? (value / total * 100).toStringAsFixed(0)
                    : '0';

                return PieChartSectionData(
                  color: colors[i % colors.length],
                  value: value,
                  title: isTouched
                      ? '${entries[i].key}\n$percentage%'
                      : '$percentage%',
                  radius: radius,
                  titleStyle: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            Text(
              '₹${total.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLineChart(bool isDark) {
    final trend =
        widget.trendData ?? [100.0, 200.0, 150.0, 400.0, 300.0, 500.0, 450.0];
    final labelList = widget.labels ?? ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    final spots = List.generate(
      trend.length,
      (i) => FlSpot(i.toDouble(), trend[i]),
    );

    double maxVal = trend.fold(0.0, (max, val) => val > max ? val : max);
    if (maxVal == 0) maxVal = 100.0;

    return AspectRatio(
      aspectRatio: 1.8,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: isDark
                  ? AppColors.borderDark.withValues(alpha: 0.3)
                  : AppColors.borderLight.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < labelList.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        labelList[idx],
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (trend.length - 1).toDouble(),
          minY: 0,
          maxY: maxVal * 1.1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              gradient: const LinearGradient(
                colors: [AppColors.primaryPurple, AppColors.electricBlue],
              ),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryPurple.withValues(alpha: 0.35),
                    AppColors.electricBlue.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(bool isDark) {
    final trend =
        widget.trendData ?? [1000.0, 2000.0, 1500.0, 4000.0, 3000.0, 5000.0];
    final labelList =
        widget.labels ?? ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];

    double maxVal = trend.fold(0.0, (max, val) => val > max ? val : max);
    if (maxVal == 0) maxVal = 100.0;

    return AspectRatio(
      aspectRatio: 1.8,
      child: BarChart(
        BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < labelList.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        labelList[idx],
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(trend.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: trend[i],
                  gradient: const LinearGradient(
                    colors: [AppColors.electricBlue, AppColors.emeraldGreen],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxVal * 1.1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
