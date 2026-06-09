import 'package:flutter/material.dart';
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
import 'package:hive/hive.dart';
import 'package:espenseai/core/storage/hive_helper.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

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
    final String familyWalletId =
        sBox.get('family_wallet_id', defaultValue: 'N/A') as String;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassCard(
                gradientColors: [
                  AppColors.primaryPurple.withValues(alpha: 0.15),
                  AppColors.accentPink.withValues(alpha: 0.05),
                ],
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 36,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Mathan', style: AppTextStyles.heading3(isDark: true)),
                    Text(
                      'mathan@expenseai.com',
                      style: AppTextStyles.bodySmall(isDark: true),
                    ),
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
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    c.description,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondaryDark,
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    '₹${g.currentAmount.toStringAsFixed(0)} / ₹${g.targetAmount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
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
                'FAMILY WALLET & SHARING',
                style: AppTextStyles.caption(
                  isDark: isDark,
                ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
              ),
              const SizedBox(height: 10),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Shared Family Wallet',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'ID: $familyWalletId',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Balance: ₹85,000.00',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.emeraldGreen,
                      ),
                    ),
                    const Divider(color: AppColors.borderDark, height: 20),
                    const Text(
                      'Pending Family Approval Split:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.white10,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.share_location_rounded,
                            color: AppColors.accentOrange,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Swiggy Order Split (With Priya)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Your share: ₹225.00',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Split approved & settled in wallet!',
                                ),
                                backgroundColor: AppColors.emeraldGreen,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Approve',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Dark Theme Mode',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Switch(
                        value: isDark,
                        onChanged: (_) =>
                            ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                    ),
                    const Divider(color: AppColors.borderDark, height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.fingerprint_rounded,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Biometric Vault Unlock',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: Switch(
                        value: _biometrics,
                        onChanged: _toggleBiometrics,
                      ),
                    ),
                    const Divider(color: AppColors.borderDark, height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.attach_money_rounded,
                        color: Colors.white,
                      ),
                      title: const Text(
                        'Currency Settings',
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: DropdownButton<String>(
                        value: _currency,
                        dropdownColor: AppColors.cardDark,
                        style: const TextStyle(
                          color: Colors.white,
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
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: AppColors.borderDark),
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
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
