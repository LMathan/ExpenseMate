import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _iconController;
  late Animation<double> _iconFloat;

  final List<_OnboardSlide> _slides = const [
    _OnboardSlide(
      title: 'Track Every Expense\nEffortlessly',
      subtitle: 'Scan receipts with smart OCR, auto-track bank SMS, and log entries instantly.',
      gradientColors: [Color(0xFF6C63FF), Color(0xFF4A90E2)],
      icon: Icons.account_balance_wallet_rounded,
      accentColor: AppColors.electricBlue,
      tag: 'Smart Tracking',
    ),
    _OnboardSlide(
      title: 'Split & Settle\nInstantly',
      subtitle: 'Create groups, split bills with friends, and settle balances instantly via native UPI payments.',
      gradientColors: [Color(0xFF4A90E2), Color(0xFF00C896)],
      icon: Icons.handshake_rounded,
      accentColor: AppColors.emeraldGreen,
      tag: 'Split & Pay',
    ),
    _OnboardSlide(
      title: 'Save Smarter,\nSpend Better',
      subtitle: 'Create intelligent budgets, monitor subscriptions, and join savings challenges.',
      gradientColors: [Color(0xFFFF9F43), Color(0xFFFF6B9D)],
      icon: Icons.stars_rounded,
      accentColor: AppColors.accentPink,
      tag: 'Smart Savings',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _iconFloat = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgDark,
              slide.gradientColors[0].withValues(alpha: 0.15),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background shape
            Positioned(
              top: -size.height * 0.05,
              right: -size.width * 0.15,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slide.accentColor.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: size.height * 0.2,
              left: -size.width * 0.2,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: size.width * 0.5,
                height: size.width * 0.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slide.gradientColors[0].withValues(alpha: 0.05),
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Logo small
                        Row(
                          children: [
                            Image.asset('assets/images/logo.png', height: 38, fit: BoxFit.contain),
                            const SizedBox(width: 8),
                            Text(
                              'ExpenseMate',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: _finish,
                          child: Text(
                            'Skip',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondaryDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Page content
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (i) => setState(() => _currentPage = i),
                      itemCount: _slides.length,
                      itemBuilder: (context, index) {
                        final s = _slides[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Illustration card
                              AnimatedBuilder(
                                animation: _iconFloat,
                                builder: (_, child) => Transform.translate(
                                  offset: Offset(0, index == _currentPage ? _iconFloat.value : 0),
                                  child: child,
                                ),
                                child: Container(
                                  width: 220,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(36),
                                    gradient: LinearGradient(
                                      colors: s.gradientColors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: s.accentColor.withValues(alpha: 0.35),
                                        blurRadius: 40,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      // Tag chip
                                      Positioned(
                                        top: 16,
                                        right: 16,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            s.tag,
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Icon(s.icon, size: 90, color: Colors.white),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 48),

                              Text(
                                s.title,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                s.subtitle,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textSecondaryDark.withValues(alpha: 0.85),
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dot indicators
                        Row(
                          children: List.generate(_slides.length, (i) {
                            final isActive = i == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              height: 8,
                              width: isActive ? 28 : 8,
                              decoration: BoxDecoration(
                                color: isActive ? slide.accentColor : AppColors.borderDark,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),

                        // Next / Get Started
                        GestureDetector(
                          onTap: _onNext,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: slide.gradientColors),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: slide.accentColor.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
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
      ),
    );
  }
}

class _OnboardSlide {
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final IconData icon;
  final Color accentColor;
  final String tag;

  const _OnboardSlide({
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.icon,
    required this.accentColor,
    required this.tag,
  });
}
