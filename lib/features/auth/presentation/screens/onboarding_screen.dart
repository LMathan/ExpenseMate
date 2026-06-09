import 'package:flutter/material.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'title': 'Track every expense effortlessly',
      'subtitle':
          'Scan receipts with smart OCR, auto-track bank SMS notifications, and log manual entries instantly.',
      'gradient': [AppColors.primaryPurple, AppColors.electricBlue],
      'icon': Icons.account_balance_wallet_rounded,
      'accent': AppColors.electricBlue,
    },
    {
      'title': 'AI-powered spending insights',
      'subtitle':
          'Chat with your AI financial advisor, discover savings opportunities, and understand your habits.',
      'gradient': [AppColors.electricBlue, AppColors.emeraldGreen],
      'icon': Icons.insights_rounded,
      'accent': AppColors.emeraldGreen,
    },
    {
      'title': 'Save smarter, spend better',
      'subtitle':
          'Create intelligent category budgets, monitor subscriptions, and participate in savings challenges.',
      'gradient': [AppColors.accentOrange, AppColors.accentPink],
      'icon': Icons.stars_rounded,
      'accent': AppColors.accentPink,
    },
  ];

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _slides[_currentPage]['accent'].withOpacity(0.15),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        'Skip',
                        style: AppTextStyles.bodyMedium(isDark: true).copyWith(
                          color: AppColors.textSecondaryDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (idx) {
                      setState(() {
                        _currentPage = idx;
                      });
                    },
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 240,
                              height: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: slide['gradient'],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: slide['accent'].withOpacity(0.3),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                slide['icon'],
                                size: 100,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 48),

                            Text(
                              slide['title'],
                              textAlign: TextAlign.center,
                              style: AppTextStyles.heading2(isDark: true)
                                  .copyWith(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 16),

                            Text(
                              slide['subtitle'],
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMedium(isDark: true)
                                  .copyWith(
                                    color: AppColors.textSecondaryDark
                                        .withValues(alpha: 0.8),
                                    height: 1.5,
                                  ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 24.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: List.generate(
                          _slides.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            height: 8,
                            width: i == _currentPage ? 24 : 8,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? _slides[_currentPage]['accent']
                                  : AppColors.borderDark,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      ElevatedButton(
                        onPressed: _onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _slides[_currentPage]['accent'],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: _slides[_currentPage]['accent']
                              .withOpacity(0.4),
                        ),
                        child: Text(
                          _currentPage == _slides.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
