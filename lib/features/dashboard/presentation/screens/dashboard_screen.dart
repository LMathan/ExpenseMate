import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/services/biometric_service.dart';
import 'package:espenseai/core/services/voice_service.dart';
import 'package:espenseai/features/expense/presentation/screens/add_expense_screen.dart';
import 'tabs/home_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/ai_insights_tab.dart';
import 'tabs/planner_tab.dart';
import 'tabs/profile_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _currentIndex = 0;
  final BiometricService _bioService = BiometricService();
  final VoiceService _voiceService = VoiceService();
  bool _isLocked = false;
  bool _isListening = false;
  String _spokenText = '';

  final List<Widget> _tabs = [
    const HomeTab(),
    const AnalyticsTab(),
    const AiInsightsTab(),
    const PlannerTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _checkBiometricLock();
  }

  Future<void> _checkBiometricLock() async {
    final canAuth = await _bioService.canAuthenticate();
    if (canAuth) {
      setState(() {
        _isLocked = true;
      });
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    final success = await _bioService.authenticate();
    if (success) {
      setState(() {
        _isLocked = false;
      });
    }
  }

  void _triggerVoiceEntry() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() {
        _isListening = false;
      });
      if (_spokenText.isNotEmpty) {
        _processVoiceInput(_spokenText);
      }
    } else {
      final success = await _voiceService.initialize();
      if (success) {
        setState(() {
          _isListening = true;
          _spokenText = '';
        });
        await _voiceService.startListening(
          onResult: (text) {
            setState(() {
              _spokenText = text;
            });
          },
          onSoundLevelChanged: (_) {},
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    }
  }

  void _processVoiceInput(String text) {
    final data = _voiceService.parseVoiceCommand(text);
    if (data != null) {
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not understand: "$text". Try e.g. "spent 250 on food"'),
          backgroundColor: AppColors.accentPink,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLocked) {
      return Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 100,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'ExpenseAI Secure Vault',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text('Unlock using your biometrics credentials', style: TextStyle(color: AppColors.textSecondaryDark)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: _currentIndex == 0
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Row(
                children: [
                  Image.asset(
                    'assets/images/app_icon.png',
                    height: 32,
                    width: 32,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ExpenseAI',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 90.0),
              child: _tabs[_currentIndex],
            ),
          ),
          
          if (_isListening)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryPurple.withOpacity(0.2),
                          ),
                          child: const Icon(Icons.mic, size: 60, color: AppColors.accentPink),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Listening...',
                          style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32.0),
                          child: Text(
                            _spokenText.isEmpty ? 'Say something like "Spent 450 at Swiggy"' : '"$_spokenText"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16, color: AppColors.textSecondaryDark, fontStyle: FontStyle.italic),
                          ),
                        ),
                        const SizedBox(height: 48),
                        ElevatedButton(
                          onPressed: _triggerVoiceEntry,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text('Stop & Process'),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.black : Colors.white).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.08),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_rounded, 'Home'),
                      _buildNavItem(1, Icons.analytics_rounded, 'Charts'),
                      _buildMicButton(),
                      _buildNavItem(3, Icons.calendar_today_rounded, 'Planner'),
                      _buildNavItem(4, Icons.person_rounded, 'Settings'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final targetIndex = index;
    final isSelected = _currentIndex == targetIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = targetIndex;
        });
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected
                ? AppColors.primaryPurple
                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected
                  ? AppColors.primaryPurple
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    final isSelected = _currentIndex == 2;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = 2;
        });
      },
      onLongPress: _triggerVoiceEntry,
      child: Container(
        height: 52,
        width: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isSelected
              ? const LinearGradient(colors: [AppColors.accentPink, AppColors.accentOrange])
              : AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPurple.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: const Icon(
          Icons.mic,
          color: Colors.white,
          size: 26,
        ),
      ),
    );
  }
}
