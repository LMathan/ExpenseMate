import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/storage/hive_helper.dart';
import 'package:espenseai/core/services/biometric_service.dart';
import 'package:espenseai/core/services/firestore_sync_service.dart';
import 'package:espenseai/core/utils/app_page_route.dart';
import 'package:espenseai/features/expense/presentation/screens/add_expense_screen.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'tabs/home_tab.dart';
import 'tabs/analytics_tab.dart';
import 'tabs/planner_tab.dart';
import 'tabs/profile_tab.dart';
import 'package:espenseai/features/auth/presentation/providers/auth_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final BiometricService _bioService = BiometricService();
  bool _isLocked = false;
  late AnimationController _addBtnCtrl;
  late Animation<double> _addBtnScale;
  StreamSubscription? _groupsSubscription;
  StreamSubscription? _transactionsSubscription;
  StreamSubscription? _profileSubscription;

  final List<Widget> _tabs = [
    const HomeTab(),
    const AnalyticsTab(),
    const PlannerTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _addBtnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _addBtnScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _addBtnCtrl, curve: Curves.easeOut),
    );
    _checkBiometricLock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstTimeUser();
      _setupRealtimeSync();
    });
  }

  @override
  void dispose() {
    _addBtnCtrl.dispose();
    _groupsSubscription?.cancel();
    _transactionsSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  void _setupRealtimeSync() {
    final box = Hive.box(HiveHelper.settingsBox);
    final isLoggedIn = box.get('is_logged_in', defaultValue: false) as bool;
    final isGuest = box.get('is_guest_mode', defaultValue: false) as bool;

    if (isLoggedIn && !isGuest) {
      final syncService = FirestoreSyncService();

      // Push all locally-known groups to every member's Firestore subcollection.
      // Fixes groups that were created before cross-user sync was active.
      syncService.backfillGroupsToAllMembers();

      _groupsSubscription = syncService.listenToGroups(() {
        if (mounted) {
          ref.read(groupsProvider.notifier).loadGroups();
        }
      });
      _transactionsSubscription = syncService.listenToTransactions(() {
        if (mounted) {
          ref.read(transactionProvider.notifier).loadTransactions();
        }
      });
      _profileSubscription = syncService.listenToUserProfile((data) {
        if (mounted) {
          final name = data['displayName'] as String? ?? 'User';
          final sBox = Hive.box(HiveHelper.settingsBox);
          final path = sBox.get('profile_picture_path') as String?;
          final url = sBox.get('profile_picture_url') as String?;
          ref.read(authProvider.notifier).updateProfileDetails(
            displayName: name,
            profilePicPath: path,
            profilePicUrl: url,
            clearPhoto: (url == null && path == null),
          );
        }
      });
    }
  }

  void _checkFirstTimeUser() {
    final box = Hive.box(HiveHelper.settingsBox);
    final isGuest = box.get('is_guest_mode', defaultValue: false) as bool;
    final isLoggedIn = box.get('is_logged_in', defaultValue: false) as bool;

    if (isLoggedIn && !isGuest) {
      final hasCompletedSetup = box.get('has_completed_profile_setup', defaultValue: false) as bool;
      if (!hasCompletedSetup) {
        _showOnboardingProfileSetup();
        return;
      }
    }

    final hasSeenTour = box.get('has_seen_intro_tour', defaultValue: false) as bool;
    if (!hasSeenTour) {
      _showWalkthroughDialog();
    }
  }

  void _showOnboardingProfileSetup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const OnboardingProfileSetupDialog();
      },
    ).then((_) {
      _checkFirstTimeUser();
    });
  }

  void _showWalkthroughDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.bgDark.withOpacity(0.95),
                  AppColors.cardDark.withOpacity(0.95),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.electricBlue,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Welcome to ExpenseMate! ✨',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Let\'s take a quick tour of your new smart financial manager.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildTourItem(
                        Icons.add_circle_outline_rounded,
                        AppColors.electricBlue,
                        'Log Expenses Instantly',
                        'Tap + to quickly add any expense with category, payment method & notes.',
                      ),
                      const SizedBox(height: 16),
                      _buildTourItem(
                        Icons.analytics_outlined,
                        AppColors.primaryPurple,
                        'Visual Analytics',
                        'See spending breakdowns by category with beautiful interactive charts.',
                      ),
                      const SizedBox(height: 16),
                      _buildTourItem(
                        Icons.call_split_rounded,
                        AppColors.emeraldGreen,
                        'Instant Bill Splitting',
                        'Search users dynamically in the database to split shared expenses.',
                      ),
                      const SizedBox(height: 16),
                      _buildTourItem(
                        Icons.calendar_today_rounded,
                        AppColors.accentOrange,
                        'Custom Billing Cycles',
                        'Set your own monthly budget reset date directly on the dashboard card.',
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            final box = Hive.box(HiveHelper.settingsBox);
                            box.put('has_seen_intro_tour', true);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'Got it, Let\'s Start!',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTourItem(IconData icon, Color color, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondaryDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _checkBiometricLock() async {
    final box = Hive.box(HiveHelper.settingsBox);
    final isBiometricsEnabled = box.get('biometrics_enabled', defaultValue: false) as bool;
    if (!isBiometricsEnabled) return;

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

  void _onAddPressed() async {
    await _addBtnCtrl.forward();
    await _addBtnCtrl.reverse();
    if (mounted) {
      Navigator.push(
        context,
        AppPageRoute(
          page: const AddExpenseScreen(),
          type: RouteTransitionType.slideUp,
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
                height: 130,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'ExpenseMate Secure Vault',
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
                    height: 40,
                    width: 40,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ExpenseMate',
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
          // Tab body with animated switcher
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 90.0),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(_currentIndex),
                  child: _tabs[_currentIndex],
                ),
              ),
            ),
          ),

          // Bottom nav bar
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.75)
                        : Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                      _buildNavItem(1, Icons.analytics_rounded, Icons.analytics_outlined, 'Charts'),
                      _buildAddButton(),
                      _buildNavItem(2, Icons.calendar_month_rounded, Icons.calendar_month_outlined, 'Planner'),
                      _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
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

  Widget _buildNavItem(int index, IconData filledIcon, IconData outlineIcon, String label) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryPurple.withValues(alpha: isDark ? 0.2 : 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? filledIcon : outlineIcon,
                color: isSelected ? AppColors.primaryPurple : unselectedColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primaryPurple : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: _onAddPressed,
      child: AnimatedBuilder(
        animation: _addBtnScale,
        builder: (_, child) => Transform.scale(
          scale: _addBtnScale.value,
          child: child,
        ),
        child: Container(
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withValues(alpha: 0.48),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class OnboardingProfileSetupDialog extends ConsumerStatefulWidget {
  const OnboardingProfileSetupDialog({super.key});

  @override
  ConsumerState<OnboardingProfileSetupDialog> createState() => _OnboardingProfileSetupDialogState();
}

class _OnboardingProfileSetupDialogState extends ConsumerState<OnboardingProfileSetupDialog> {
  final _controller = TextEditingController();
  final FirestoreSyncService _syncService = FirestoreSyncService();
  String? _imagePath;
  bool _isChecking = false;
  bool _isTaken = false;
  bool _isValidFormat = true;
  List<String> _suggestions = [];
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onUsernameChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final clean = val.trim();
    final validFormat = clean.isNotEmpty && RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean) && clean.length >= 3;
    setState(() {
      _isValidFormat = validFormat;
      _isTaken = false;
      _suggestions = [];
    });

    if (validFormat) {
      _debounce = Timer(const Duration(milliseconds: 600), () {
        _checkAvailability(clean);
      });
    }
  }

  Future<void> _checkAvailability(String username) async {
    setState(() {
      _isChecking = true;
    });
    
    final taken = await _syncService.isUsernameTaken(username);
    
    setState(() {
      _isTaken = taken;
      _isChecking = false;
      if (taken) {
        _suggestions = _generateSuggestions(username);
      }
    });
  }

  List<String> _generateSuggestions(String base) {
    final cleanBase = base.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
    final suggestions = <String>[];
    final random = DateTime.now().millisecond;
    suggestions.add('${cleanBase}_${100 + (random % 900)}');
    suggestions.add('${cleanBase}${10 + (random % 90)}');
    suggestions.add('${cleanBase}_${1000 + (random % 9000)}');
    return suggestions;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imagePath = picked.path;
      });
    }
  }

  void _submit() async {
    final username = _controller.text.trim();
    if (username.isEmpty || !_isValidFormat || _isTaken || _isChecking) return;

    final box = Hive.box(HiveHelper.settingsBox);
    await box.put('user_name', username);
    await box.put('has_completed_profile_setup', true);

    final imagePath = _imagePath;
    if (imagePath != null) {
      await box.put('profile_picture_path', imagePath);
      // Immediately upload the profile picture to Firebase Storage and update Firestore/Hive url.
      await _syncService.syncProfilePicture(imagePath);
    }

    ref.read(authProvider.notifier).updateProfileDetails(
      displayName: username,
      profilePicPath: imagePath,
    );

    await _syncService.updateProfileName(
      username,
      hasCompletedSetup: true,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile setup completed! Welcome!'),
          backgroundColor: AppColors.emeraldGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.bgDark : Colors.white;
    final cardColor = isDark ? AppColors.cardDark : Colors.grey[100];
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final imageProvider = (_imagePath != null && File(_imagePath!).existsSync())
        ? FileImage(File(_imagePath!)) as ImageProvider
        : const NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150');

    final canSave = _controller.text.trim().isNotEmpty && _isValidFormat && !_isTaken && !_isChecking;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Complete Your Profile ✨',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a unique username and optional profile photo to start splitting bills.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              
              Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundImage: imageProvider,
                    backgroundColor: cardColor,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryPurple,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _controller,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: textSecondary),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: textSecondary),
                  suffixIcon: _isChecking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue),
                          ),
                        )
                      : (_controller.text.trim().isEmpty
                          ? null
                          : (_isValidFormat && !_isTaken
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.emeraldGreen)
                              : const Icon(Icons.error_outline_rounded, color: AppColors.accentPink))),
                  filled: true,
                  fillColor: cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primaryPurple, width: 1.5),
                  ),
                ),
                onChanged: _onUsernameChanged,
              ),
              const SizedBox(height: 8),

              if (!_isValidFormat && _controller.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Must be at least 3 characters and alphanumeric only (no spaces/symbols)',
                    style: GoogleFonts.inter(color: AppColors.accentPink, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_isTaken) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    'Username already taken 🛑',
                    style: GoogleFonts.inter(color: AppColors.accentPink, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'Suggestions:',
                  style: GoogleFonts.inter(color: textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _suggestions.map((sug) {
                    return ActionChip(
                      label: Text(sug, style: const TextStyle(fontSize: 12)),
                      backgroundColor: cardColor,
                      labelStyle: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      onPressed: () {
                        _controller.text = sug;
                        _onUsernameChanged(sug);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canSave ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    disabledBackgroundColor: AppColors.primaryPurple.withOpacity(0.3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Get Started',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
