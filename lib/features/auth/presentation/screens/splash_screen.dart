import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/features/auth/presentation/providers/auth_provider.dart';
import 'onboarding_screen.dart';
import 'package:espenseai/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:espenseai/core/services/update_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _particleController;
  late AnimationController _textController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowPulse;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _particleController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _textController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );
    _glowPulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeInOut),
    );
    _textSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.0, 0.7, curve: Curves.easeIn)),
    );
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: const Interval(0.4, 1.0, curve: Curves.easeIn)),
    );

    _logoController.forward().then((_) {
      _textController.forward();
    });

    _checkRedirect();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _particleController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _checkRedirect() async {
    await Future.delayed(const Duration(milliseconds: 3000));
    if (!mounted) return;

    // Check for available OTA updates (Android only)
    await UpdateService.checkAndPromptUpdate(context);
    if (!mounted) return;

    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.authenticated || authState.status == AuthStatus.guest) {
      Navigator.pushReplacement(context, _fadeRoute(const DashboardScreen()));
    } else {
      Navigator.pushReplacement(context, _fadeRoute(const OnboardingScreen()));
    }
  }

  PageRoute _fadeRoute(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 600),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0618),
              Color(0xFF0F172A),
              Color(0xFF0D1B3E),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Animated ambient orbs
            AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                size: size,
                painter: _AmbientOrbsPainter(_particleController.value),
              ),
            ),

            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Glow ring + logo
                  AnimatedBuilder(
                    animation: Listenable.merge([_logoController, _particleController]),
                    builder: (_, __) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer glow ring
                              Container(
                                width: 230,
                                height: 230,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryPurple.withValues(
                                        alpha: 0.15 + 0.1 * _glowPulse.value,
                                      ),
                                      blurRadius: 60 + 20 * _glowPulse.value,
                                      spreadRadius: 20,
                                    ),
                                    BoxShadow(
                                      color: AppColors.electricBlue.withValues(
                                        alpha: 0.1 + 0.08 * _glowPulse.value,
                                      ),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                              // Logo — transparent background container
                              Image.asset(
                                'assets/images/logo.png',
                                width: 190,
                                height: 190,
                                fit: BoxFit.contain,
                                // No container with background — shows logo transparently
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // App name + tagline
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (_, __) {
                      return Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Column(
                          children: [
                            Opacity(
                              opacity: _textOpacity.value,
                              child: ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Colors.white, Color(0xFFB8A5FF)],
                                ).createShader(bounds),
                                child: Text(
                                  'ExpenseMate',
                                  style: GoogleFonts.outfit(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Opacity(
                              opacity: _taglineOpacity.value,
                              child: Text(
                                'Track Smarter. Save Better.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: AppColors.textSecondaryDark.withValues(alpha: 0.85),
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom loading dots
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (_, __) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final phase = (_particleController.value + i * 0.33) % 1.0;
                    final opacity = (math.sin(phase * math.pi * 2) + 1) / 2;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryPurple.withValues(alpha: 0.3 + 0.7 * opacity),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientOrbsPainter extends CustomPainter {
  final double t;
  _AmbientOrbsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _OrbConfig(0.15, 0.15, 180, AppColors.primaryPurple, 0.0),
      _OrbConfig(0.85, 0.2, 140, AppColors.electricBlue, 0.3),
      _OrbConfig(0.1, 0.75, 120, AppColors.emeraldGreen, 0.6),
      _OrbConfig(0.8, 0.8, 160, AppColors.accentPink, 0.15),
    ];

    for (final orb in orbs) {
      final phase = (t + orb.phase) % 1.0;
      final drift = math.sin(phase * math.pi * 2) * 18;
      final cx = size.width * orb.xFrac;
      final cy = size.height * orb.yFrac + drift;
      final alpha = 0.04 + 0.02 * math.sin(phase * math.pi * 2);

      canvas.drawCircle(
        Offset(cx, cy),
        orb.radius,
        Paint()
          ..color = orb.color.withValues(alpha: alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientOrbsPainter old) => old.t != t;
}

class _OrbConfig {
  final double xFrac, yFrac, radius, phase;
  final Color color;
  const _OrbConfig(this.xFrac, this.yFrac, this.radius, this.color, this.phase);
}
