import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/utils/app_page_route.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/features/auth/presentation/providers/auth_provider.dart';
import 'package:espenseai/core/models/group_model.dart';
import 'package:espenseai/core/models/transaction_model.dart';
import 'group_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

class OweItem {
  final String groupName;
  final String groupId;
  final GroupModel group;
  final String toName;
  final String toEmail;
  final double amount;

  OweItem({
    required this.groupName,
    required this.groupId,
    required this.group,
    required this.toName,
    required this.toEmail,
    required this.amount,
  });
}

class OweDetailsScreen extends ConsumerWidget {
  const OweDetailsScreen({super.key});

  List<OweItem> _calculateOweDetails(List<GroupModel> groups, List<TransactionModel> allTxs, String currentEmail) {
    if (currentEmail.isEmpty) return [];
    final myEmail = currentEmail.trim().toLowerCase();
    final List<OweItem> oweItems = [];

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

        if (debtorEmail == myEmail) {
          String toName = creditorEmail.split('@').first;
          final idx = group.memberEmails.indexOf(creditorEmail);
          if (idx != -1 && idx < group.memberNames.length) {
            toName = group.memberNames[idx];
          }
          oweItems.add(OweItem(
            groupName: group.name,
            groupId: group.id,
            group: group,
            toName: toName,
            toEmail: creditorEmail,
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

    return oweItems;
  }

  void _handleOweTap(BuildContext context, OweItem item) async {
    // 1. Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryPurple),
        ),
      ),
    );

    String upiId = '';
    try {
      final toEmailIndex = item.group.memberEmails.indexWhere((e) => e.trim().toLowerCase() == item.toEmail.trim().toLowerCase());
      final uid = toEmailIndex != -1 && toEmailIndex < item.group.memberUids.length ? item.group.memberUids[toEmailIndex] : '';

      if (uid.isNotEmpty) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && doc.data() != null) {
          upiId = doc.data()!['user_upi_id'] as String? ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error fetching recipient UPI ID: $e');
    }

    // Dismiss loading indicator
    if (context.mounted) {
      Navigator.pop(context);
    }

    if (!context.mounted) return;

    if (upiId.isNotEmpty) {
      // Launch standard UPI chooser directly with all details pre-filled
      final upiUrl = _buildUpiUrl(upiId, item.toName, item.amount, 'standard');
      final uri = Uri.parse(upiUrl);
      try {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          _showNoUpiAppsDialog(context, item);
        }
      } catch (e) {
        _showNoUpiAppsDialog(context, item);
      }
    } else {
      // No UPI ID: launch generic upi://pay to open UPI apps chooser anyway
      try {
        final launched = await launchUrl(Uri.parse('upi://pay'), mode: LaunchMode.externalApplication);
        if (!launched) {
          _showNoUpiAppsDialog(context, item);
        }
      } catch (e) {
        _showNoUpiAppsDialog(context, item);
      }
    }
  }

  void _showNoUpiAppsDialog(BuildContext context, OweItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderCol = isDark ? AppColors.borderDark : AppColors.borderLight;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: borderCol.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 28),
            
            // Premium Icon Badge
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryPurple.withValues(alpha: 0.15),
                      AppColors.accentPink.withValues(alpha: 0.15),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryPurple.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.primaryPurple, AppColors.accentPink],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title
            Text(
              'No UPI Apps Found',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: textColor,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 10),
            
            // Description
            Text(
              'We couldn\'t find any UPI payment apps (like Google Pay, PhonePe, or Paytm) on this device. Install a UPI app to settle instantly, or settle manually.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: subColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            
            // Settle Manually Button
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  AppPageRoute(
                    page: GroupDetailsScreen(
                      groupId: item.groupId,
                      initialGroup: item.group,
                    ),
                    type: RouteTransitionType.slideRight,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryPurple,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: AppColors.primaryPurple.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                'Settle Manually (Go to Group)',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Close Button
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                foregroundColor: subColor,
                side: BorderSide(color: borderCol),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(
                'Got It',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildUpiUrl(String upiId, String name, double amount, String type) {
    final encodedName = Uri.encodeComponent(name);
    final amtStr = amount.toStringAsFixed(2);
    final txnNote = Uri.encodeComponent('ExpenseMate Split Settlement');
    
    switch (type) {
      case 'gpay':
        return 'upi://pay?pa=$upiId&pn=$encodedName&am=$amtStr&cu=INR&tn=$txnNote';
      case 'phonepe':
        return 'phonepe://pay?pa=$upiId&pn=$encodedName&am=$amtStr&cu=INR&tn=$txnNote';
      case 'paytm':
        return 'paytmmp://pay?pa=$upiId&pn=$encodedName&am=$amtStr&cu=INR&tn=$txnNote';
      default:
        return 'upi://pay?pa=$upiId&pn=$encodedName&am=$amtStr&cu=INR&tn=$txnNote';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final allTxs = ref.watch(transactionProvider);
    final authState = ref.watch(authProvider);
    final currentEmail = authState.email ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final oweItems = _calculateOweDetails(groups, allTxs, currentEmail);
    final totalOwed = oweItems.fold<double>(0.0, (sum, item) => sum + item.amount);

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
          'Who You Owe',
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
              // Total Owed Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AppColors.primaryPurple,
                      AppColors.accentPink,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'TOTAL AMOUNT YOU OWE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${totalOwed.toStringAsFixed(2)}',
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
                'PENDING SETTLEMENTS',
                style: AppTextStyles.caption(isDark: isDark).copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: oweItems.isEmpty
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
                              'You are all settled up! 🎉',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'You don\'t owe money to anyone right now.',
                              style: TextStyle(color: subColor, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: oweItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = oweItems[index];

                          return GestureDetector(
                            onTap: () => _handleOweTap(context, item),
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
                                      final toEmailIndex = item.group.memberEmails.indexWhere((e) => e.trim().toLowerCase() == item.toEmail.trim().toLowerCase());
                                      final uid = toEmailIndex != -1 && toEmailIndex < item.group.memberUids.length ? item.group.memberUids[toEmailIndex] : '';
                                      return GroupMemberAvatar(
                                        uid: uid,
                                        initials: item.toName.isNotEmpty ? item.toName.substring(0, 1).toUpperCase() : 'U',
                                        avatarColor: AppColors.primaryPurple,
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
                                          item.toName,
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
                                            color: AppColors.primaryPurple.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            item.groupName,
                                            style: const TextStyle(
                                              color: AppColors.primaryPurple,
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
                                          color: AppColors.accentPink,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Settle Up',
                                            style: TextStyle(
                                              color: isDark ? AppColors.electricBlue : AppColors.primaryPurple,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          Icon(
                                            Icons.chevron_right_rounded,
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
