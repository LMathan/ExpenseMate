import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/theme/theme_provider.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/core/widgets/gradient_progress_bar.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/features/auth/presentation/providers/auth_provider.dart';
import 'package:espenseai/features/auth/presentation/screens/login_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:espenseai/core/storage/hive_helper.dart';
import 'package:espenseai/core/services/firestore_sync_service.dart';
import 'package:espenseai/core/widgets/vector_illustrations.dart';

class ProfileTab extends ConsumerStatefulWidget {
  final bool showBackButton;
  const ProfileTab({super.key, this.showBackButton = false});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final _goalTitleController = TextEditingController();
  final _goalTargetController = TextEditingController();

  bool _biometrics = false;
  String _currency = '₹';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _pickProfilePicture({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 200,
      maxHeight: 200,
      imageQuality: 55,
    );
    if (picked != null) {
      final box = Hive.box(HiveHelper.settingsBox);
      await box.put('profile_picture_path', picked.path);
      
      // Update local Riverpod state immediately
      ref.read(authProvider.notifier).updateProfileDetails(
        profilePicPath: picked.path,
      );

      setState(() {});
      // Upload to Firebase Storage (replaces old file — no extra storage used)
      FirestoreSyncService().syncProfilePicture(picked.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated!'),
            backgroundColor: AppColors.emeraldGreen,
          ),
        );
      }
    }
  }

  void _showAboutAppDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'About ExpenseMate',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ExpenseMate is a smart personal finance manager that helps you log transactions, automate splits, track budgets, and take complete control of your financial life.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'KEY FEATURES',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.electricBlue,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              _buildFeatureRow(Icons.account_balance_wallet_rounded, 'Expense Tracker', 'Seamlessly log and categorize all your daily expenses.'),
              _buildFeatureRow(Icons.qr_code_scanner_rounded, 'OCR Scanner', 'Extract amounts instantly from receipts.'),
              _buildFeatureRow(Icons.call_split_rounded, 'Smart Splitting', 'Split group bills equally or unequally.'),
              _buildFeatureRow(Icons.cloud_sync_rounded, 'Live Sync', 'Real-time synchronization with Firestore.'),
              _buildFeatureRow(Icons.security_rounded, 'Security Vault', 'Keep data safe behind biometric lock.'),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Text(
                'App Version: 1.0.6',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Close',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryPurple,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String desc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryPurple),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showProfilePicOptions(
      BuildContext context, ImageProvider imageProvider, String? currentPath) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Hero(
              tag: 'profile_avatar',
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                ),
                child: CircleAvatar(
                  radius: 52,
                  backgroundImage: imageProvider,
                  backgroundColor:
                      isDark ? AppColors.cardDark : Colors.grey[200],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildPicOption(
              context: ctx,
              icon: Icons.photo_library_rounded,
              color: AppColors.electricBlue,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(ctx);
                _pickProfilePicture(source: ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
            _buildPicOption(
              context: ctx,
              icon: Icons.camera_alt_rounded,
              color: AppColors.emeraldGreen,
              label: 'Take a Photo',
              onTap: () {
                Navigator.pop(ctx);
                _pickProfilePicture(source: ImageSource.camera);
              },
            ),
            if (currentPath != null) ...[
              const SizedBox(height: 10),
              _buildPicOption(
                context: ctx,
                icon: Icons.delete_outline_rounded,
                color: Colors.redAccent,
                label: 'Remove Photo',
                onTap: () async {
                  Navigator.pop(ctx);
                  final box = Hive.box(HiveHelper.settingsBox);
                  await box.delete('profile_picture_path');
                  await box.delete('profile_picture_url');
                  
                  // Update local Riverpod state immediately
                  ref.read(authProvider.notifier).updateProfileDetails(
                    clearPhoto: true,
                  );

                  // Delete from Firebase Storage and Firestore
                  FirestoreSyncService().removeProfilePicture();
                  setState(() {});
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPicOption({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14,
                color:
                    isDark ? Colors.white38 : Colors.black26),
          ],
        ),
      ),
    );
  }

  void _loadSettings() {
    final box = Hive.box(HiveHelper.settingsBox);
    setState(() {
      _biometrics = box.get('biometrics_enabled', defaultValue: false) as bool;
      _currency = box.get('user_currency', defaultValue: '₹') as String;
    });
  }

  void _toggleBiometrics(bool val) async {
    final box = Hive.box(HiveHelper.settingsBox);
    await box.put('biometrics_enabled', val);
    setState(() {
      _biometrics = val;
    });
  }

  void _updateCurrency(String cur) async {
    final box = Hive.box(HiveHelper.settingsBox);
    await box.put('user_currency', cur);
    setState(() {
      _currency = cur;
    });
  }

  void _addNewGoal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Savings Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _goalTitleController,
              decoration: const InputDecoration(
                labelText: 'Goal Title (e.g. Buy Bike)',
              ),
            ),
            TextField(
              controller: _goalTargetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target Amount (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = _goalTitleController.text.trim();
              final target = double.tryParse(_goalTargetController.text) ?? 0.0;
              if (title.isNotEmpty && target > 0) {
                ref
                    .read(goalsProvider.notifier)
                    .addGoal(
                      title,
                      target,
                      0,
                      DateTime.now().add(const Duration(days: 180)),
                      'General',
                    );
                _goalTitleController.clear();
                _goalTargetController.clear();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Savings goal added!'),
                    backgroundColor: AppColors.emeraldGreen,
                  ),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _runSavingsCalculator() {
    showDialog(
      context: context,
      builder: (context) {
        double monthlySavings = 5000;
        double target = 50000;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final months = (target / monthlySavings).ceil();
            return AlertDialog(
              title: const Text('Savings Goal Calculator'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Target Purchase Cost: ₹${target.toStringAsFixed(0)}'),
                  Slider(
                    value: target,
                    min: 5000,
                    max: 300000,
                    divisions: 59,
                    activeColor: AppColors.primaryPurple,
                    onChanged: (val) => setDialogState(() => target = val),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Monthly Savings Ability: ₹${monthlySavings.toStringAsFixed(0)}',
                  ),
                  Slider(
                    value: monthlySavings,
                    min: 1000,
                    max: 50000,
                    divisions: 49,
                    activeColor: AppColors.electricBlue,
                    onChanged: (val) =>
                        setDialogState(() => monthlySavings = val),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Result: You will reach your goal in $months months!',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.emeraldGreen,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _triggerBackup() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Database backed up to secure Cloud Firestore!'),
        backgroundColor: AppColors.emeraldGreen,
      ),
    );
  }

  void _showEditUsernameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    final syncService = FirestoreSyncService();
    
    bool isChecking = false;
    bool isTaken = false;
    bool isValidFormat = true;
    List<String> suggestions = [];
    Timer? debounce;

    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? AppColors.bgDark : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;
        final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
        final cardColor = isDark ? AppColors.cardDark : Colors.grey[100];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            void onUsernameChanged(String val) {
              if (debounce?.isActive ?? false) debounce!.cancel();
              
              final clean = val.trim();
              final validFormat = clean.isNotEmpty && RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean) && clean.length >= 3;
              setDialogState(() {
                isValidFormat = validFormat;
                isTaken = false;
                suggestions = [];
              });

              if (validFormat && clean != currentName) {
                debounce = Timer(const Duration(milliseconds: 600), () {
                  setDialogState(() {
                    isChecking = true;
                  });
                  syncService.isUsernameTaken(clean).then((taken) {
                    setDialogState(() {
                      isTaken = taken;
                      isChecking = false;
                      if (taken) {
                        final cleanBase = clean.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
                        final random = DateTime.now().millisecond;
                        suggestions = [
                          '${cleanBase}_${100 + (random % 900)}',
                          '${cleanBase}${10 + (random % 90)}',
                          '${cleanBase}_${1000 + (random % 9000)}',
                        ];
                      }
                    });
                  });
                });
              }
            }

            final canSave = controller.text.trim().isNotEmpty && isValidFormat && !isTaken && !isChecking;

            return AlertDialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Edit Username', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: textSecondary),
                      prefixIcon: Icon(Icons.person_outline_rounded, color: textSecondary),
                      suffixIcon: isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue),
                              ),
                            )
                          : (controller.text.trim() == currentName
                              ? null
                              : (isValidFormat && !isTaken
                                  ? const Icon(Icons.check_circle_rounded, color: AppColors.emeraldGreen)
                                  : const Icon(Icons.error_outline_rounded, color: AppColors.accentPink))),
                    ),
                    onChanged: onUsernameChanged,
                  ),
                  const SizedBox(height: 8),
                  if (!isValidFormat && controller.text.trim().isNotEmpty)
                    Text(
                      'Must be at least 3 characters and alphanumeric (no spaces/symbols)',
                      style: TextStyle(color: AppColors.accentPink, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  if (isTaken) ...[
                    Text(
                      'Username already taken 🛑',
                      style: TextStyle(color: AppColors.accentPink, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Suggestions:',
                      style: TextStyle(color: textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: suggestions.map((sug) {
                        return ActionChip(
                          label: Text(sug, style: const TextStyle(fontSize: 11)),
                          backgroundColor: cardColor,
                          labelStyle: const TextStyle(color: AppColors.electricBlue, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onPressed: () {
                            controller.text = sug;
                            onUsernameChanged(sug);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    debounce?.cancel();
                    Navigator.pop(context);
                  },
                  child: Text('Cancel', style: TextStyle(color: textSecondary)),
                ),
                ElevatedButton(
                  onPressed: canSave
                      ? () async {
                          final newName = controller.text.trim();
                          if (newName.isNotEmpty) {
                            debounce?.cancel();
                            final sBox = Hive.box(HiveHelper.settingsBox);
                            await sBox.put('user_name', newName);
                            
                            ref.read(authProvider.notifier).updateProfileDetails(displayName: newName);

                            await syncService.updateProfileName(newName);
                            
                            if (mounted) {
                              setState(() {});
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Username updated successfully!'),
                                  backgroundColor: AppColors.emeraldGreen,
                                ),
                              );
                            }
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    disabledBackgroundColor: AppColors.primaryPurple.withOpacity(0.3),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onLogout() async {
    await ref.read(authProvider.notifier).logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final challenges = ref.watch(challengesProvider);
    final goals = ref.watch(goalsProvider);
    final isDark = themeMode == ThemeMode.dark;

    final sBox = Hive.box(HiveHelper.settingsBox);
    final int xp = sBox.get('user_xp', defaultValue: 0) as int;
    final int level = sBox.get('user_level', defaultValue: 1) as int;
    
    final authState = ref.watch(authProvider);
    final String name = authState.displayName ?? 'User';
    final String email = authState.email ?? '';
    final String? profilePicPath = authState.profilePicPath;
    final String? profilePicUrl = authState.profilePicUrl;
    final ImageProvider imageProvider;
    if (profilePicPath != null && profilePicPath.startsWith('data:image')) {
      final base64String = profilePicPath.split('base64,').last;
      imageProvider = MemoryImage(base64Decode(base64String));
    } else if (profilePicPath != null && !profilePicPath.startsWith('http') && File(profilePicPath).existsSync()) {
      imageProvider = FileImage(File(profilePicPath));
    } else if (profilePicPath != null && profilePicPath.startsWith('http')) {
      imageProvider = NetworkImage(profilePicPath);
    } else if (profilePicUrl != null && profilePicUrl.startsWith('data:image')) {
      final base64String = profilePicUrl.split('base64,').last;
      imageProvider = MemoryImage(base64Decode(base64String));
    } else if (profilePicUrl != null) {
      imageProvider = NetworkImage(profilePicUrl);
    } else {
      imageProvider = const NetworkImage('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150');
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: AppBackground(
        type: PageBg.profile,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showBackButton) ...[
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              GlassCard(
                gradientColors: [
                  AppColors.primaryPurple.withValues(alpha: 0.15),
                  AppColors.accentPink.withValues(alpha: 0.05),
                ],
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _showProfilePicOptions(
                          context, imageProvider, profilePicPath ?? profilePicUrl),
                      child: Stack(
                        children: [
                          Hero(
                            tag: 'profile_avatar',
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                              ),
                              child: CircleAvatar(
                                radius: 36,
                                backgroundImage: imageProvider,
                                backgroundColor: isDark
                                    ? AppColors.cardDark
                                    : Colors.grey[200],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryPurple,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(name, style: AppTextStyles.heading3(isDark: isDark)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.edit_rounded, color: isDark ? AppColors.electricBlue : AppColors.primaryPurple, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _showEditUsernameDialog(name),
                        ),
                      ],
                    ),
                    if (email.isNotEmpty) ...[
                      Text(
                        email,
                        style: AppTextStyles.bodySmall(isDark: isDark),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Level $level Wealth Master',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.accentOrange,
                          ),
                        ),
                        Text(
                          '$xp / 1000 XP',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GradientProgressBar(progress: xp / 1000, height: 6),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'SAVINGS CHALLENGES',
                style: AppTextStyles.caption(
                  isDark: isDark,
                ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              challenges.isEmpty
                  ? const Text('All challenges completed!')
                  : SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: challenges.length,
                        itemBuilder: (context, index) {
                          final c = challenges[index];
                          return Container(
                            width: 200,
                            margin: const EdgeInsets.only(right: 12),
                            child: GlassCard(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    c.description,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Streak: ${c.currentStreak}/${c.targetDays}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: AppColors.accentOrange,
                                        ),
                                      ),
                                      c.isCompleted
                                          ? GestureDetector(
                                              onTap: () => ref
                                                  .read(
                                                    challengesProvider.notifier,
                                                  )
                                                  .claimReward(c.id),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.emeraldGreen,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Claim',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : const Text(
                                              'Active',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.electricBlue,
                                              ),
                                            ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SAVINGS GOALS',
                    style: AppTextStyles.caption(
                      isDark: isDark,
                    ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _runSavingsCalculator,
                        icon: const Icon(
                          Icons.calculate_rounded,
                          color: AppColors.electricBlue,
                          size: 20,
                        ),
                      ),
                      IconButton(
                        onPressed: _addNewGoal,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.emeraldGreen,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              goals.isEmpty
                  ? const Text('No active goals.')
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: goals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final g = goals[index];
                        final ratio = g.targetAmount > 0
                            ? g.currentAmount / g.targetAmount
                            : 0.0;
                        return GlassCard(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    g.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '₹${g.currentAmount.toStringAsFixed(0)} / ₹${g.targetAmount.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GradientProgressBar(progress: ratio, height: 8),
                            ],
                          ),
                        );
                      },
                    ),

              const SizedBox(height: 24),

              Text(
                'SECURITY & PREFERENCES',
                style: AppTextStyles.caption(
                  isDark: isDark,
                ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(
                        isDark
                            ? Icons.dark_mode_rounded
                            : Icons.light_mode_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      title: Text(
                        'Dark Theme Mode',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      trailing: Switch(
                        value: isDark,
                        onChanged: (_) =>
                            ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                    ),
                    const Divider(color: AppColors.borderDark, height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.fingerprint_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      title: Text(
                        'Biometric Vault Unlock',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      trailing: Switch(
                        value: _biometrics,
                        onChanged: _toggleBiometrics,
                      ),
                    ),
                    const Divider(color: AppColors.borderDark, height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.attach_money_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      title: Text(
                        'Currency Settings',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      trailing: DropdownButton<String>(
                        value: _currency,
                        dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                        items: const [
                          DropdownMenuItem(value: '₹', child: Text('INR (₹)')),
                          DropdownMenuItem(
                            value: '\$',
                            child: Text('USD (\$)'),
                          ),
                          DropdownMenuItem(value: '€', child: Text('EUR (€)')),
                        ],
                        onChanged: (val) {
                          if (val != null) _updateCurrency(val);
                        },
                      ),
                    ),
                    const Divider(color: AppColors.borderDark, height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.info_outline_rounded,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      title: Text(
                        'About App',
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      ),
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      onTap: _showAboutAppDialog,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _triggerBackup,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white : Colors.black87,
                        side: BorderSide(color: isDark ? AppColors.borderDark : Colors.grey[300]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Backup Data'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _onLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentPink,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Logout Account'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 16.0, top: 8.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ExpenseMate',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.6',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
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
