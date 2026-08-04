import 'package:hive_flutter/hive_flutter.dart';

class HiveHelper {
  static const String settingsBox = 'settings';
  static const String transactionsBox = 'transactions';
  static const String budgetsBox = 'budgets';
  static const String goalsBox = 'goals';
  static const String subscriptionsBox = 'subscriptions';
  static const String billsBox = 'bills';
  static const String challengesBox = 'challenges';
  static const String groupsBox = 'groups';

  static Future<void> init() async {
    await Hive.initFlutter();
    
    // Open boxes
    final sSettings = await Hive.openBox(settingsBox);
    final tBox = await Hive.openBox(transactionsBox);
    final bBox = await Hive.openBox(budgetsBox);
    final gBox = await Hive.openBox(goalsBox);
    final sBox = await Hive.openBox(subscriptionsBox);
    final blBox = await Hive.openBox(billsBox);
    final cBox = await Hive.openBox(challengesBox);
    final grBox = await Hive.openBox(groupsBox);

    // Reset database ONCE for clean testing
    final isReset = sSettings.get('is_reset_for_testing_v2', defaultValue: false) as bool;
    if (!isReset) {
      await sSettings.clear();
      await tBox.clear();
      await bBox.clear();
      await gBox.clear();
      await sBox.clear();
      await blBox.clear();
      await cBox.clear();
      await grBox.clear();
      await sSettings.put('is_reset_for_testing_v2', true);
    }

    // Populate default settings (no mock data)
    await _populateMockData();
  }

  static Future<void> _populateMockData() async {
    final sSettings = Hive.box(settingsBox);

    // Initial user settings if empty
    if (sSettings.isEmpty || sSettings.get('user_name') == null) {
      await sSettings.put('user_name', 'User');
      await sSettings.put('user_email', '');
      await sSettings.put('user_currency', '₹');
      await sSettings.put('theme_mode', 'light');
      await sSettings.put('biometrics_enabled', false);
      await sSettings.put('user_xp', 0);
      await sSettings.put('user_level', 1);
      await sSettings.put('budget_reset_day', 1);
      await sSettings.put('has_seen_intro_tour', false);
      await sSettings.put('is_reset_for_testing_v2', true);
    }
  }
}
