import 'package:flutter/material.dart';
import '../constants/colors.dart';

class GradientProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0+
  final double height;
  final List<Color>? gradientColors;

  const GradientProgressBar({
    super.key,
    required this.progress,
    this.height = 10.0,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final cappedProgress = progress.clamp(0.0, 1.0);
    final isExceeded = progress > 1.0;
    final isWarning = progress > 0.8 && progress <= 1.0;

    List<Color> colors =
        gradientColors ?? [AppColors.primaryPurple, AppColors.electricBlue];
    if (isExceeded) {
      colors = [AppColors.accentPink, Colors.redAccent];
    } else if (isWarning) {
      colors = [AppColors.accentOrange, Colors.orange];
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final progressWidth = totalWidth * cappedProgress;

        return Stack(
          children: [
            Container(
              height: height,
              width: totalWidth,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              height: height,
              width: progressWidth == 0 ? 0 : progressWidth,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
