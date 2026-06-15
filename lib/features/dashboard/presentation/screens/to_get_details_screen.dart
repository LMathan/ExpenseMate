import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/features/auth/presentation/providers/auth_provider.dart';
import 'package:espenseai/core/models/group_model.dart';
import 'package:espenseai/core/models/transaction_model.dart';
import 'group_details_screen.dart';

class GetItem {
  final String groupName;
  final String groupId;
  final GroupModel group;
  final String fromName;
  final String fromEmail;
  final double amount;

  GetItem({
    required this.groupName,
    required this.groupId,
    required this.group,
    required this.fromName,
    required this.fromEmail,
    required this.amount,
  });
}

class ToGetDetailsScreen extends ConsumerWidget {
  const ToGetDetailsScreen({super.key});

  List<GetItem> _calculateGetDetails(List<GroupModel> groups, List<TransactionModel> allTxs, String currentEmail) {
    if (currentEmail.isEmpty) return [];
    final myEmail = currentEmail.trim().toLowerCase();
    final List<GetItem> getItems = [];

    for (var group in groups) {
      final groupTxs = allTxs.where((tx) => tx.groupId == group.id).toList();
      final Map<String, double> balances = {};
      for (var tx in groupTxs) {
        if (tx.isSettled) continue;
        final payerEmail = tx.paidByEmail.trim().toLowerCase();
        final splitWith = tx.splitWith.map((e) => e.trim().toLowerCase()).toList();
        final totalSplitCount = splitWith.length + 1;
        if (totalSplitCount <= 1) continue;

        final perHeadAmount = tx.totalAmount > 0 
            ? tx.totalAmount / totalSplitCount 
            : tx.amount;

        if (tx.splitShares != null && tx.splitShares!.isNotEmpty) {
          double payerCredit = 0.0;
          for (var email in splitWith) {
            final share = tx.splitShares![email] ?? perHeadAmount;
            balances[email] = (balances[email] ?? 0.0) - share;
            payerCredit += share;
          }
          balances[payerEmail] = (balances[payerEmail] ?? 0.0) + payerCredit;
        } else {
          final payerCredit = perHeadAmount * splitWith.length;
          balances[payerEmail] = (balances[payerEmail] ?? 0.0) + payerCredit;
          for (var email in splitWith) {
            balances[email] = (balances[email] ?? 0.0) - perHeadAmount;
          }
        }
      }

      // Debt Simplifier algorithm
      final List<MapEntry<String, double>> debtors = [];
      final List<MapEntry<String, double>> creditors = [];

      balances.forEach((email, val) {
        if (val < -0.01) {
          debtors.add(MapEntry(email, val));
        } else if (val > 0.01) {
          creditors.add(MapEntry(email, val));
        }
      });

      debtors.sort((a, b) => a.value.compareTo(b.value));
      creditors.sort((a, b) => b.value.compareTo(a.value));

      int debtorIdx = 0;
      int creditorIdx = 0;
      final Map<String, double> tempBalances = Map.from(balances);

      while (debtorIdx < debtors.length && creditorIdx < creditors.length) {
        final debtorEmail = debtors[debtorIdx].key;
        final creditorEmail = creditors[creditorIdx].key;

        final double debtorOwes = -tempBalances[debtorEmail]!;
        final double creditorOwed = tempBalances[creditorEmail]!;

        if (debtorOwes <= 0.01) {
          debtorIdx++;
          continue;
        }
        if (creditorOwed <= 0.01) {
          creditorIdx++;
          continue;
        }

        final double settleAmount = debtorOwes < creditorOwed ? debtorOwes : creditorOwed;

        // If current user is the creditor (we receive money)
        if (creditorEmail == myEmail) {
          String fromName = debtorEmail.split('@').first;
          final idx = group.memberEmails.indexOf(debtorEmail);
          if (idx != -1 && idx < group.memberNames.length) {
            fromName = group.memberNames[idx];
          }
          getItems.add(GetItem(
            groupName: group.name,
            groupId: group.id,
            group: group,
            fromName: fromName,
            fromEmail: debtorEmail,
            amount: settleAmount,
          ));
        }

        tempBalances[debtorEmail] = tempBalances[debtorEmail]! + settleAmount;
        tempBalances[creditorEmail] = tempBalances[creditorEmail]! - settleAmount;

        if (tempBalances[debtorEmail]! >= -0.01) {
          debtorIdx++;
        }
        if (tempBalances[creditorEmail]! <= 0.01) {
          creditorIdx++;
        }
      }
    }

    return getItems;
  }

  void _handleSettleTap(BuildContext context, WidgetRef ref, GetItem item, String currentEmail) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Record Settlement?',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppColors.textPrimaryLight),
        ),
        content: Text(
          'Mark that ${item.fromName} paid you ₹${item.amount.toStringAsFixed(2)}? This will settle all outstanding split expenses from them in this group.',
          style: GoogleFonts.inter(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx); // close dialog

              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
                  ),
                ),
              );

              try {
                // 1. Find all unsettled transactions in this group where current user paid (paidByEmail == currentEmail)
                // and debtor (item.fromEmail) is in the split list (splitWith contains item.fromEmail).
                final allTxs = ref.read(transactionProvider);
                final groupTxs = allTxs.where((tx) => 
                  tx.groupId == item.groupId && 
                  !tx.isSettled &&
                  tx.paidByEmail.trim().toLowerCase() == currentEmail.trim().toLowerCase() &&
                  tx.splitWith.any((email) => email.trim().toLowerCase() == item.fromEmail.trim().toLowerCase())
                ).toList();

                // 2. Mark them as settled
                for (var tx in groupTxs) {
                  final updatedTx = tx.copyWith(isSettled: true);
                  await ref.read(transactionProvider.notifier).editTransaction(updatedTx);
                }

                // 3. Add a settlement transaction in history
                await ref.read(transactionProvider.notifier).addTransaction(
                  amount: item.amount,
                  category: 'Settlement',
                  merchant: 'Settlement Payment',
                  notes: 'Settlement: ${item.fromName} paid Me',
                  paymentMethod: 'Cash',
                  date: DateTime.now(),
                  splitWith: [currentEmail],
                  isSettled: true,
                  paidByEmail: item.fromEmail,
                  totalAmount: item.amount,
                  groupId: item.groupId,
                );

                if (context.mounted) {
                  Navigator.pop(context); // close loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Settlement of ₹${item.amount.toStringAsFixed(2)} from ${item.fromName} recorded!'),
                      backgroundColor: AppColors.emeraldGreen,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // close loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error recording settlement: $e'),
                      backgroundColor: AppColors.accentPink,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emeraldGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Settle',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final allTxs = ref.watch(transactionProvider);
    final authState = ref.watch(authProvider);
    final currentEmail = authState.email ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final getItems = _calculateGetDetails(groups, allTxs, currentEmail);
    final totalToGet = getItems.fold<double>(0.0, (sum, item) => sum + item.amount);

    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          'Who Owes You',
          style: GoogleFonts.outfit(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Total Owed Header Card (Green themed for money to receive)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.emeraldGreen,
                      AppColors.electricBlue,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldGreen.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL AMOUNT TO RECEIVE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${totalToGet.toStringAsFixed(2)}',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(
                'PENDING RECEIVABLES',
                style: AppTextStyles.caption(isDark: isDark).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: getItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.emeraldGreen,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All squared up! 🌟',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'No one owes you money right now.',
                              style: TextStyle(color: subColor, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: getItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = getItems[index];

                          return GestureDetector(
                            onTap: () => _handleSettleTap(context, ref, item, currentEmail),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : AppColors.borderLight,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final toEmailIndex = item.group.memberEmails.indexWhere((e) => e.trim().toLowerCase() == item.fromEmail.trim().toLowerCase());
                                      final uid = toEmailIndex != -1 && toEmailIndex < item.group.memberUids.length ? item.group.memberUids[toEmailIndex] : '';
                                      return GroupMemberAvatar(
                                        uid: uid,
                                        initials: item.fromName.isNotEmpty ? item.fromName.substring(0, 1).toUpperCase() : 'U',
                                        avatarColor: AppColors.emeraldGreen,
                                        radius: 22,
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.fromName,
                                          style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.emeraldGreen.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.groupName,
                                            style: const TextStyle(
                                              color: AppColors.emeraldGreen,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${item.amount.toStringAsFixed(2)}',
                                        style: GoogleFonts.spaceGrotesk(
                                          color: AppColors.emeraldGreen,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Settle',
                                            style: TextStyle(
                                              color: isDark ? AppColors.electricBlue : AppColors.primaryPurple,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.check_circle_outline_rounded,
                                            size: 14,
                                            color: isDark ? AppColors.electricBlue : AppColors.primaryPurple,
                                          ),
                                        ],
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
