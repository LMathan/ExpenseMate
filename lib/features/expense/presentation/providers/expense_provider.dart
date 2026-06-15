import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/storage/hive_helper.dart';
import '../../../../core/services/firestore_sync_service.dart';
import '../../../../core/models/transaction_model.dart';
import '../../../../core/models/budget_model.dart';
import '../../../../core/models/goal_model.dart';
import '../../../../core/models/subscription_model.dart';
import '../../../../core/models/bill_reminder_model.dart';
import '../../../../core/models/challenge_model.dart';
import '../../../../core/models/group_model.dart';

// 1. Transactions State Notifier
class TransactionNotifier extends StateNotifier<List<TransactionModel>> {
  final FirestoreSyncService _syncService = FirestoreSyncService();

  TransactionNotifier() : super([]) {
    loadTransactions();
  }

  void loadTransactions() {
    final box = Hive.box(HiveHelper.transactionsBox);
    final List<TransactionModel> items = [];
    for (var key in box.keys) {
      final map = Map<dynamic, dynamic>.from(box.get(key));
      items.add(TransactionModel.fromMap(map));
    }
    // Sort descending by date
    items.sort((a, b) => b.date.compareTo(a.date));
    state = items;
  }

  Future<void> addTransaction({
    required double amount,
    required String category,
    required String merchant,
    required String notes,
    required String paymentMethod,
    required DateTime date,
    bool isApproved = true,
    bool isRecurring = false,
    List<String> splitWith = const [],
    bool isSettled = false,
    String paidByEmail = '',
    double totalAmount = 0.0,
    String? groupId,
    String? createdBy,
    Map<String, double>? splitShares,
  }) async {
    final box = Hive.box(HiveHelper.transactionsBox);
    final id = const Uuid().v4();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final tx = TransactionModel(
      id: id,
      amount: amount,
      category: category,
      merchant: merchant,
      notes: notes,
      paymentMethod: paymentMethod,
      date: date,
      isApproved: isApproved,
      isReceiptUploaded: false,
      receiptPath: '',
      isRecurring: isRecurring,
      splitWith: splitWith,
      isSettled: isSettled,
      paidByEmail: paidByEmail,
      totalAmount: totalAmount,
      groupId: groupId,
      createdBy: createdBy ?? currentUid,
      splitShares: splitShares,
    );

    await box.put(id, tx.toMap());
    
    // Sync to Firestore in background
    _syncService.syncTransaction(tx);
    
    // Add XP to user for logging a transaction!
    final sBox = Hive.box(HiveHelper.settingsBox);
    final currentXp = sBox.get('user_xp', defaultValue: 0) as int;
    await sBox.put('user_xp', currentXp + 15); // Log transaction rewards 15XP

    loadTransactions();
    _checkGoalProgress(amount, category);
  }

  Future<void> editTransaction(TransactionModel updated) async {
    final box = Hive.box(HiveHelper.transactionsBox);
    await box.put(updated.id, updated.toMap());
    _syncService.syncTransaction(updated);
    loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    final box = Hive.box(HiveHelper.transactionsBox);
    await box.delete(id);
    _syncService.deleteTransaction(id);
    loadTransactions();
  }

  void _checkGoalProgress(double amount, String category) {
    // If saving category, update goals
  }
}

final transactionProvider = StateNotifierProvider<TransactionNotifier, List<TransactionModel>>((ref) {
  return TransactionNotifier();
});

// 2. Budget State Notifier
class BudgetNotifier extends StateNotifier<BudgetModel> {
  final FirestoreSyncService _syncService = FirestoreSyncService();

  BudgetNotifier() : super(BudgetModel(monthlyIncome: 65000, categoryBudgets: {})) {
    loadBudget();
  }

  void loadBudget() {
    final box = Hive.box(HiveHelper.budgetsBox);
    final data = Map<dynamic, dynamic>.from(box.toMap());
    state = BudgetModel.fromMap(data);
  }

  Future<void> updateIncome(double income) async {
    final box = Hive.box(HiveHelper.budgetsBox);
    await box.put('monthly_income', income);
    loadBudget();
    _syncService.syncBudget(state);
  }

  Future<void> updateCategoryBudget(String category, double limit) async {
    final box = Hive.box(HiveHelper.budgetsBox);
    await box.put('category_$category', limit);
    loadBudget();
    _syncService.syncBudget(state);
  }
}

final budgetProvider = StateNotifierProvider<BudgetNotifier, BudgetModel>((ref) {
  return BudgetNotifier();
});

// 3. Goals State Notifier
class GoalsNotifier extends StateNotifier<List<GoalModel>> {
  final FirestoreSyncService _syncService = FirestoreSyncService();

  GoalsNotifier() : super([]) {
    loadGoals();
  }

  void loadGoals() {
    final box = Hive.box(HiveHelper.goalsBox);
    final List<GoalModel> items = [];
    for (var key in box.keys) {
      items.add(GoalModel.fromMap(Map<dynamic, dynamic>.from(box.get(key))));
    }
    state = items;
  }

  Future<void> addGoal(String title, double target, double current, DateTime targetDate, String cat) async {
    final box = Hive.box(HiveHelper.goalsBox);
    final id = const Uuid().v4();
    final goal = GoalModel(id: id, title: title, targetAmount: target, currentAmount: current, targetDate: targetDate, category: cat);
    await box.put(id, goal.toMap());
    _syncService.syncGoal(goal);
    loadGoals();
  }

  Future<void> contributeToGoal(String id, double amount) async {
    final box = Hive.box(HiveHelper.goalsBox);
    final item = box.get(id);
    if (item != null) {
      final goal = GoalModel.fromMap(Map<dynamic, dynamic>.from(item));
      final updated = goal.copyWith(currentAmount: goal.currentAmount + amount);
      await box.put(id, updated.toMap());
      _syncService.syncGoal(updated);
      loadGoals();
    }
  }
}

final goalsProvider = StateNotifierProvider<GoalsNotifier, List<GoalModel>>((ref) {
  return GoalsNotifier();
});

// 4. Subscriptions State Notifier
class SubscriptionsNotifier extends StateNotifier<List<SubscriptionModel>> {
  final FirestoreSyncService _syncService = FirestoreSyncService();

  SubscriptionsNotifier() : super([]) {
    loadSubscriptions();
  }

  void loadSubscriptions() {
    final box = Hive.box(HiveHelper.subscriptionsBox);
    final List<SubscriptionModel> items = [];
    for (var key in box.keys) {
      items.add(SubscriptionModel.fromMap(Map<dynamic, dynamic>.from(box.get(key))));
    }
    state = items;
  }

  Future<void> toggleReminder(String id) async {
    final box = Hive.box(HiveHelper.subscriptionsBox);
    final item = box.get(id);
    if (item != null) {
      final sub = SubscriptionModel.fromMap(Map<dynamic, dynamic>.from(item));
      final updated = sub.copyWith(reminderEnabled: !sub.reminderEnabled);
      await box.put(id, updated.toMap());
      _syncService.syncSubscription(updated);
      loadSubscriptions();
    }
  }

  Future<void> addSubscription({
    required String title,
    required double amount,
    required DateTime dueDate,
    required String billingCycle,
    required String category,
  }) async {
    final box = Hive.box(HiveHelper.subscriptionsBox);
    final id = const Uuid().v4();
    final sub = SubscriptionModel(
      id: id,
      title: title,
      amount: amount,
      dueDate: dueDate,
      billingCycle: billingCycle,
      category: category,
      reminderEnabled: true,
    );
    await box.put(id, sub.toMap());
    _syncService.syncSubscription(sub);
    loadSubscriptions();
  }
}

final subscriptionsProvider = StateNotifierProvider<SubscriptionsNotifier, List<SubscriptionModel>>((ref) {
  return SubscriptionsNotifier();
});

// 5. Bill Reminders State Notifier
class BillRemindersNotifier extends StateNotifier<List<BillReminderModel>> {
  final FirestoreSyncService _syncService = FirestoreSyncService();

  BillRemindersNotifier() : super([]) {
    loadBills();
  }

  void loadBills() {
    final box = Hive.box(HiveHelper.billsBox);
    final List<BillReminderModel> items = [];
    for (var key in box.keys) {
      items.add(BillReminderModel.fromMap(Map<dynamic, dynamic>.from(box.get(key))));
    }
    state = items;
  }

  Future<void> togglePaid(String id) async {
    final box = Hive.box(HiveHelper.billsBox);
    final item = box.get(id);
    if (item != null) {
      final bill = BillReminderModel.fromMap(Map<dynamic, dynamic>.from(item));
      final updated = bill.copyWith(isPaid: !bill.isPaid);
      await box.put(id, updated.toMap());
      _syncService.syncBill(updated);
      loadBills();
    }
  }

  Future<void> addBill({
    required String title,
    required double amount,
    required DateTime dueDate,
    required String category,
    String recurrence = 'One-time',
  }) async {
    final box = Hive.box(HiveHelper.billsBox);
    final id = const Uuid().v4();
    final bill = BillReminderModel(
      id: id,
      title: title,
      amount: amount,
      dueDate: dueDate,
      category: category,
      isPaid: false,
      recurrence: recurrence,
    );
    await box.put(id, bill.toMap());
    _syncService.syncBill(bill);
    loadBills();
  }
}

final billsProvider = StateNotifierProvider<BillRemindersNotifier, List<BillReminderModel>>((ref) {
  return BillRemindersNotifier();
});

// 6. Challenges State Notifier
class ChallengesNotifier extends StateNotifier<List<ChallengeModel>> {
  final FirestoreSyncService _syncService = FirestoreSyncService();

  ChallengesNotifier() : super([]) {
    loadChallenges();
  }

  void loadChallenges() {
    final box = Hive.box(HiveHelper.challengesBox);
    final List<ChallengeModel> items = [];
    for (var key in box.keys) {
      items.add(ChallengeModel.fromMap(Map<dynamic, dynamic>.from(box.get(key))));
    }
    state = items;
  }

  Future<void> claimReward(String id) async {
    final box = Hive.box(HiveHelper.challengesBox);
    final item = box.get(id);
    if (item != null) {
      final challenge = ChallengeModel.fromMap(Map<dynamic, dynamic>.from(item));
      if (challenge.isCompleted) {
        // Reward XP to user
        final sBox = Hive.box(HiveHelper.settingsBox);
        final currentXp = sBox.get('user_xp', defaultValue: 0) as int;
        await sBox.put('user_xp', currentXp + challenge.rewardXp);
        
        // Remove completed challenge or keep logged
        await box.delete(id);
        _syncService.syncChallenge(challenge); // sync state
        loadChallenges();
      }
    }
  }
}

final challengesProvider = StateNotifierProvider<ChallengesNotifier, List<ChallengeModel>>((ref) {
  return ChallengesNotifier();
});

// 7. Groups State Notifier
class GroupsNotifier extends StateNotifier<List<GroupModel>> {
  final FirestoreSyncService _syncService = FirestoreSyncService();

  GroupsNotifier() : super([]) {
    loadGroups();
  }

  void loadGroups() {
    final box = Hive.box(HiveHelper.groupsBox);
    final List<GroupModel> items = [];
    for (var key in box.keys) {
      items.add(GroupModel.fromMap(Map<dynamic, dynamic>.from(box.get(key))));
    }
    state = items;
  }

  Future<void> addGroup(String name, List<Map<String, dynamic>> members) async {
    final box = Hive.box(HiveHelper.groupsBox);
    final id = const Uuid().v4();
    
    final memberNames = members.map((m) => m['displayName'] as String).toList();
    final memberEmails = members.map((m) => m['email'] as String).toList();
    final memberUids = members.map((m) => m['uid'] as String).toList();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    final group = GroupModel(
      id: id,
      name: name,
      memberNames: memberNames,
      memberEmails: memberEmails,
      memberUids: memberUids,
      createdBy: currentUid,
    );

    await box.put(id, group.toMap());
    
    // Sync to Firestore in background
    _syncService.syncGroup(group);

    loadGroups();
  }

  Future<void> addMemberToGroup(String groupId, Map<String, dynamic> newMember) async {
    final box = Hive.box(HiveHelper.groupsBox);
    final item = box.get(groupId);
    if (item != null) {
      final group = GroupModel.fromMap(Map<dynamic, dynamic>.from(item));
      
      final newUid = newMember['uid'] as String;
      if (group.memberUids.contains(newUid)) return;

      final updatedNames = List<String>.from(group.memberNames)..add(newMember['displayName'] as String);
      final updatedEmails = List<String>.from(group.memberEmails)..add(newMember['email'] as String);
      final updatedUids = List<String>.from(group.memberUids)..add(newUid);

      final updated = GroupModel(
        id: group.id,
        name: group.name,
        memberNames: updatedNames,
        memberEmails: updatedEmails,
        memberUids: updatedUids,
        createdBy: group.createdBy,
      );

      await box.put(groupId, updated.toMap());
      _syncService.syncGroup(updated);
      loadGroups();
    }
  }

  Future<void> deleteGroup(String groupId) async {
    final box = Hive.box(HiveHelper.groupsBox);
    await box.delete(groupId);
    _syncService.deleteGroup(groupId);
    loadGroups();
  }

  Future<void> editGroupName(String groupId, String newName) async {
    final box = Hive.box(HiveHelper.groupsBox);
    final item = box.get(groupId);
    if (item != null) {
      final group = GroupModel.fromMap(Map<dynamic, dynamic>.from(item));
      final updated = GroupModel(
        id: group.id,
        name: newName,
        memberNames: group.memberNames,
        memberEmails: group.memberEmails,
        memberUids: group.memberUids,
        createdBy: group.createdBy,
      );
      await box.put(groupId, updated.toMap());
      _syncService.syncGroup(updated);
      loadGroups();
    }
  }
}

final groupsProvider = StateNotifierProvider<GroupsNotifier, List<GroupModel>>((ref) {
  return GroupsNotifier();
});
