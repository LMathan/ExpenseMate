import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:espenseai/core/storage/hive_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/core/models/group_model.dart';
import 'package:espenseai/core/models/transaction_model.dart';
import 'package:espenseai/core/services/firestore_sync_service.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/features/dashboard/presentation/screens/tabs/home_tab.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/core/utils/category_emoji_helper.dart';
import 'package:espenseai/core/widgets/vector_illustrations.dart';
import 'package:espenseai/core/utils/transaction_permissions.dart';
import 'package:espenseai/features/auth/presentation/providers/auth_provider.dart';

class GroupDetailsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final GroupModel initialGroup;

  const GroupDetailsScreen({
    super.key,
    required this.groupId,
    required this.initialGroup,
  });

  @override
  ConsumerState<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends ConsumerState<GroupDetailsScreen> {
  final _searchController = TextEditingController();
  final FirestoreSyncService _syncService = FirestoreSyncService();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
    });
    final results = await _syncService.searchUsersByName(query);

    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final groups = ref.read(groupsProvider);
    final group = groups.firstWhere(
      (g) => g.id == widget.groupId,
      orElse: () => widget.initialGroup,
    );

    // Filter out current user and anyone already in the group
    final filtered = results.where((user) =>
        user['uid'] != currentUid &&
        !group.memberUids.contains(user['uid'])).toList();

    setState(() {
      _searchResults = filtered;
      _isSearching = false;
    });
  }

  void _addFriend(GroupModel group, Map<String, dynamic> user) async {
    await ref.read(groupsProvider.notifier).addMemberToGroup(group.id, user);
    setState(() {
      _searchController.clear();
      _searchResults = [];
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user['displayName']} added to the group!'),
          backgroundColor: AppColors.emeraldGreen,
        ),
      );
    }
  }

  void _showAddGroupExpense(GroupModel group) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddGroupExpenseSheet(group: group),
    );
  }

  void _showEditGroupNameDialog(BuildContext context, GroupModel group, bool isDark) {
    final nameController = TextEditingController(text: group.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Group Name',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: TextField(
          controller: nameController,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: 'Enter group name',
            hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.black38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primaryPurple),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                await ref.read(groupsProvider.notifier).editGroupName(group.id, newName);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Group name updated to "$newName"'),
                      backgroundColor: AppColors.emeraldGreen,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGroup(BuildContext context, GroupModel group, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Group?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${group.name}"? This action will remove the group permanently.',
          style: GoogleFonts.inter(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await ref.read(groupsProvider.notifier).deleteGroup(group.id);
              if (context.mounted) {
                Navigator.pop(context); // Go back from GroupDetailsScreen
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('"${group.name}" group deleted successfully.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.bgDark : AppColors.bgLight;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final groups = ref.watch(groupsProvider);
    final group = groups.firstWhere(
      (g) => g.id == widget.groupId,
      orElse: () => widget.initialGroup,
    );
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isOwner = group.createdBy.isEmpty || group.createdBy == currentUid;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          group.name,
          style: GoogleFonts.outfit(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete Group',
              onPressed: () => _confirmDeleteGroup(context, group, isDark),
            ),
        ],
      ),
      body: AppBackground(
        type: PageBg.group,
        child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final syncService = FirestoreSyncService();
                  await syncService.syncCloudToLocal();
                  ref.read(transactionProvider.notifier).loadTransactions();
                  ref.read(groupsProvider.notifier).loadGroups();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Group Info Summary
                    GlassCard(
                      gradientColors: isDark
                          ? [
                              AppColors.primaryPurple.withOpacity(0.15),
                              AppColors.electricBlue.withOpacity(0.05),
                            ]
                          : [
                              Colors.grey[200]!,
                              Colors.grey[100]!,
                            ],
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.group_rounded,
                              color: AppColors.primaryPurple,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    if (isOwner)
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryPurple),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => _showEditGroupNameDialog(context, group, isDark),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${group.memberNames.length} members sharing expenses',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Add Friends Section
                    Text(
                      'ADD MEMBERS',
                      style: AppTextStyles.caption(isDark: isDark).copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Search user by username...',
                        hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
                        suffixIcon: _isSearching
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.electricBlue,
                                  ),
                                ),
                              )
                            : null,
                        filled: true,
                        fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onChanged: _searchUsers,
                    ),

                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black26 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey[300]!,
                          ),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final res = _searchResults[index];
                            return ListTile(
                              leading: (res['photoUrl'] != null && res['photoUrl'].toString().isNotEmpty)
                                  ? CircleAvatar(
                                      backgroundImage: () {
                                        final photoUrl = res['photoUrl'] as String;
                                        if (photoUrl.startsWith('data:image')) {
                                          final base64String = photoUrl.split('base64,').last;
                                          return MemoryImage(base64Decode(base64String)) as ImageProvider;
                                        }
                                        return NetworkImage(photoUrl) as ImageProvider;
                                      }(),
                                      backgroundColor: Colors.transparent,
                                    )
                                  : CircleAvatar(
                                      backgroundColor: AppColors.electricBlue.withOpacity(0.12),
                                      child: Text(
                                        (res['displayName'] ?? 'U').toString().isNotEmpty
                                            ? (res['displayName'] as String)[0].toUpperCase()
                                            : 'U',
                                        style: const TextStyle(
                                          color: AppColors.electricBlue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                              title: Text(
                                res['displayName'] ?? '',
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                res['email'] ?? '',
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.add_circle_outline,
                                  color: AppColors.electricBlue,
                                ),
                                onPressed: () => _addFriend(group, res),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Members List Section
                    Row(
                      children: [
                        Text(
                          'GROUP MEMBERS',
                          style: AppTextStyles.caption(isDark: isDark).copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${group.memberNames.length}',
                            style: const TextStyle(
                              color: AppColors.primaryPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: group.memberNames.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final name = group.memberNames[index];
                          final uid = group.memberUids.length > index ? group.memberUids[index] : '';
                          final isMe = uid == FirebaseAuth.instance.currentUser?.uid;
                          final initials = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
                          final avatarColors = [
                            AppColors.primaryPurple,
                            AppColors.electricBlue,
                            AppColors.emeraldGreen,
                            AppColors.accentPink,
                            AppColors.accentOrange,
                          ];
                          final avatarColor = avatarColors[index % avatarColors.length];
                          final displayName = isMe ? 'You' : name.split(' ').first;

                          return SizedBox(
                            width: 70,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Stack(
                                  children: [
                                    GroupMemberAvatar(
                                      uid: uid,
                                      initials: initials,
                                      avatarColor: avatarColor,
                                      radius: 29,
                                    ),
                                    if (isMe)
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: AppColors.emeraldGreen,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark ? AppColors.bgDark : Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 10,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Group Transaction History
                    _GroupTransactionHistory(
                      group: group,
                      isDark: isDark,
                      textColor: textColor,
                      textSecondary: textSecondary,
                    ),
                  ],
                ),
              ),
              ),
            ),

            // Bottom Action Area
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.bgDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddGroupExpense(group),
                  icon: const Icon(Icons.call_split_rounded, color: Colors.white),
                  label: Text(
                    'Add Group Expense',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
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

class _GroupTransactionHistory extends ConsumerWidget {
  final GroupModel group;
  final bool isDark;
  final Color textColor;
  final Color textSecondary;

  const _GroupTransactionHistory({
    required this.group,
    required this.isDark,
    required this.textColor,
    required this.textSecondary,
  });

  void _showSplitDetails(BuildContext context, WidgetRef ref, TransactionModel tx) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final payerEmail = tx.paidByEmail.isNotEmpty ? tx.paidByEmail : (currentUser?.email ?? '');
    
    // Resolve who paid display name
    String payerName = 'Unknown';
    if (payerEmail == currentUser?.email) {
      payerName = 'You';
    } else {
      final idx = group.memberEmails.indexOf(payerEmail);
      if (idx != -1) {
        payerName = group.memberNames[idx];
      } else {
        payerName = payerEmail.split('@').first;
      }
    }
    
    final formattedDate = DateFormat('MMMM dd, yyyy • hh:mm a').format(tx.date);
    final perHeadAmount = tx.splitWith.isNotEmpty 
        ? (tx.totalAmount > 0 ? tx.totalAmount / (tx.splitWith.length + 1) : tx.amount)
        : tx.amount;
    final myShareAmount = tx.splitShares != null && tx.splitShares!.containsKey(currentUser?.email)
        ? tx.splitShares![currentUser?.email]!
        : perHeadAmount;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isPayer = payerEmail == currentUser?.email;
        
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Category emoji & title
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(getCategoryEmoji(tx.category), style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tx.merchant.isEmpty ? tx.category : tx.merchant,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(formattedDate, style: TextStyle(fontSize: 11, color: textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Split Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.bgDark.withValues(alpha: 0.5) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Bill', style: TextStyle(color: textSecondary, fontSize: 13)),
                        Text(
                          '₹${(tx.totalAmount > 0 ? tx.totalAmount : tx.amount * (tx.splitWith.length + 1)).toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Paid By', style: TextStyle(color: textSecondary, fontSize: 13)),
                        Text(
                          payerName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.electricBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Your Share', style: TextStyle(color: textSecondary, fontSize: 13)),
                        Text(
                          '₹${myShareAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.accentPink),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Settlement Status', style: TextStyle(color: textSecondary, fontSize: 13)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: (tx.isSettled ? AppColors.emeraldGreen : AppColors.accentOrange).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            tx.isSettled ? 'Settled ✓' : 'Pending',
                            style: TextStyle(
                              color: tx.isSettled ? AppColors.emeraldGreen : AppColors.accentOrange,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Split breakdown list
              Text(
                'SPLIT BREAKDOWN',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.electricBlue,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              
              // Render split member rows
              ...List.generate(group.memberNames.length, (i) {
                final name = group.memberNames[i];
                final email = group.memberEmails[i];
                final isMemberPayer = email == payerEmail;
                final isMe = email == currentUser?.email;
                
                String statusText;
                Color statusColor;
                if (isMemberPayer) {
                  statusText = 'Paid total bill';
                  statusColor = AppColors.electricBlue;
                } else if (tx.isSettled) {
                  statusText = 'Settled';
                  statusColor = AppColors.emeraldGreen;
                } else {
                  final memberShareAmount = tx.splitShares != null && tx.splitShares!.containsKey(email)
                      ? tx.splitShares![email]!
                      : perHeadAmount;
                  statusText = 'Owes ₹${memberShareAmount.toStringAsFixed(0)}';
                  statusColor = AppColors.accentOrange;
                }
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isMemberPayer 
                            ? AppColors.electricBlue.withValues(alpha: 0.15) 
                            : AppColors.primaryPurple.withValues(alpha: 0.1),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: TextStyle(
                            color: isMemberPayer ? AppColors.electricBlue : AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMe ? '$name (You)' : name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(email, style: TextStyle(fontSize: 10, color: textSecondary)),
                          ],
                        ),
                      ),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              
              const SizedBox(height: 32),
              
              // Settlement Button Flow
              if (!tx.isSettled) ...[
                if (isPayer)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final updatedTx = tx.copyWith(isSettled: true);
                      await ref.read(transactionProvider.notifier).editTransaction(updatedTx);
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Split successfully marked as settled!'),
                            backgroundColor: AppColors.emeraldGreen,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Confirm Payment Received'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_empty, color: AppColors.accentOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Waiting for $payerName to confirm receipt and mark as settled.',
                            style: const TextStyle(color: AppColors.accentOrange, fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.emeraldGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.emeraldGreen, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'All splits for this expense are settled!',
                        style: TextStyle(color: AppColors.emeraldGreen, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
              if (canEditTransaction(tx, ref)) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _confirmDeleteTransaction(context, ref, tx, isDark, textColor, textSecondary);
                    },
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                    label: const Text(
                      'Delete Expense',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteTransaction(BuildContext context, WidgetRef ref, TransactionModel tx,
      bool isDark, Color textColor, Color textSecondary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Expense?',
            style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this expense from the group?',
            style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
              Navigator.pop(context); // close bottom sheet
              await ref.read(transactionProvider.notifier).deleteTransaction(tx.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Expense deleted successfully'), backgroundColor: AppColors.accentPink),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showGroupSummary(BuildContext context, WidgetRef ref, List<TransactionModel> display, GroupModel group) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bgColor = isDark ? AppColors.bgDark : Colors.white;

    // Filter unsettled transactions for this group
    final unsettledTxs = display.where((tx) => !tx.isSettled).toList();

    // Map member email to net balance
    final Map<String, double> balances = {};
    for (var email in group.memberEmails) {
      balances[email] = 0.0;
    }

    for (var tx in unsettledTxs) {
      final payerEmail = tx.paidByEmail.isNotEmpty ? tx.paidByEmail : (group.createdBy.isEmpty ? group.memberEmails.first : group.createdBy);
      final splitWith = tx.splitWith;
      if (splitWith.isEmpty) continue;

      final totalSplitCount = splitWith.length + 1;
      final perHeadAmount = tx.totalAmount > 0 
          ? tx.totalAmount / totalSplitCount 
          : tx.amount;

      if (tx.splitShares != null && tx.splitShares!.isNotEmpty) {
        // Custom split calculation
        double payerCredit = 0.0;
        for (var email in splitWith) {
          final share = tx.splitShares![email] ?? perHeadAmount;
          balances[email] = (balances[email] ?? 0.0) - share;
          payerCredit += share;
        }
        balances[payerEmail] = (balances[payerEmail] ?? 0.0) + payerCredit;
      } else {
        // Equal split calculation
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

    debtors.sort((a, b) => a.value.compareTo(b.value)); // largest debt first
    creditors.sort((a, b) => b.value.compareTo(a.value)); // largest credit first

    final List<SettlementItem> settlements = [];
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

      settlements.add(SettlementItem(
        fromEmail: debtorEmail,
        toEmail: creditorEmail,
        amount: settleAmount,
      ));

      tempBalances[debtorEmail] = tempBalances[debtorEmail]! + settleAmount;
      tempBalances[creditorEmail] = tempBalances[creditorEmail]! - settleAmount;

      if (tempBalances[debtorEmail]! >= -0.01) {
        debtorIdx++;
      }
      if (tempBalances[creditorEmail]! <= 0.01) {
        creditorIdx++;
      }
    }

    // Helper functions to resolve details
    String getMemberName(String email) {
      final idx = group.memberEmails.indexOf(email);
      if (idx != -1 && idx < group.memberNames.length) {
        return group.memberNames[idx];
      }
      return email.split('@').first;
    }

    String getMemberUid(String email) {
      final idx = group.memberEmails.indexOf(email);
      if (idx != -1 && idx < group.memberUids.length) {
        return group.memberUids[idx];
      }
      return '';
    }

    Color getMemberColor(String email) {
      final idx = group.memberEmails.indexOf(email);
      final colors = [
        AppColors.primaryPurple,
        AppColors.electricBlue,
        AppColors.emeraldGreen,
        AppColors.accentPink,
        AppColors.accentOrange,
      ];
      return colors[idx == -1 ? 0 : idx % colors.length];
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '✨ Settlement Summary',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (unsettledTxs.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AlertDialog(
                                backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text('Mark All Settled?'),
                                content: const Text('This will mark all current group expenses as settled. Balance totals will reset to zero.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogCtx),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      Navigator.pop(dialogCtx); // close dialog
                                      Navigator.pop(ctx); // close bottom sheet
                                      
                                      // Settle all transactions
                                      for (var tx in unsettledTxs) {
                                        final updatedTx = tx.copyWith(isSettled: true);
                                        await ref.read(transactionProvider.notifier).editTransaction(updatedTx);
                                      }
                                      
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('All group expenses marked as settled!'),
                                            backgroundColor: AppColors.emeraldGreen,
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGreen, foregroundColor: Colors.white),
                                    child: const Text('Confirm'),
                                  ),
                                ],
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          child: const Text('Settle All', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Net balances card
                          Text(
                            'NET BALANCES',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryPurple,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.bgDark.withValues(alpha: 0.5) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: group.memberEmails.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                              itemBuilder: (context, i) {
                                final email = group.memberEmails[i];
                                final name = group.memberNames[i];
                                final uid = group.memberUids.length > i ? group.memberUids[i] : '';
                                final balance = balances[email] ?? 0.0;
                                final initials = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
                                final avatarColor = getMemberColor(email);

                                String balanceText;
                                Color balanceColor;
                                if (balance > 0.01) {
                                  balanceText = 'Owed ₹${balance.toStringAsFixed(2)}';
                                  balanceColor = AppColors.emeraldGreen;
                                } else if (balance < -0.01) {
                                  balanceText = 'Owes ₹${(-balance).toStringAsFixed(2)}';
                                  balanceColor = AppColors.accentOrange;
                                } else {
                                  balanceText = 'Settled';
                                  balanceColor = textSecondary;
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                                  child: Row(
                                    children: [
                                      GroupMemberAvatar(
                                        uid: uid,
                                        initials: initials,
                                        avatarColor: avatarColor,
                                        radius: 18,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: textColor,
                                              ),
                                            ),
                                            Text(email, style: TextStyle(fontSize: 10, color: textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        balanceText,
                                        style: TextStyle(
                                          color: balanceColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Suggested Settlements
                          Text(
                            'SUGGESTED SETTLEMENTS',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.electricBlue,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          if (settlements.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.bgDark.withValues(alpha: 0.3) : Colors.grey[50],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                              ),
                              child: Column(
                                children: [
                                  const Text('🎉', style: TextStyle(fontSize: 36)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'All settled up!',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'No payments needed for this group.',
                                    style: TextStyle(color: textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: settlements.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, idx) {
                                final item = settlements[idx];
                                final fromName = getMemberName(item.fromEmail);
                                final toName = getMemberName(item.toEmail);
                                final fromUid = getMemberUid(item.fromEmail);
                                final toUid = getMemberUid(item.toEmail);
                                
                                final fromInitials = fromName.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
                                final toInitials = toName.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
                                
                                final fromColor = getMemberColor(item.fromEmail);
                                final toColor = getMemberColor(item.toEmail);

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.bgDark.withValues(alpha: 0.5) : Colors.grey[50],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                                  ),
                                  child: Row(
                                    children: [
                                      // Debtor
                                      Expanded(
                                        child: Row(
                                          children: [
                                            GroupMemberAvatar(
                                              uid: fromUid,
                                              initials: fromInitials,
                                              avatarColor: fromColor,
                                              radius: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                fromName,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Connection text
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Column(
                                          children: [
                                            const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.electricBlue),
                                            Text(
                                              '₹${item.amount.toStringAsFixed(0)}',
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: AppColors.accentPink,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Creditor
                                      Expanded(
                                        child: Row(
                                          children: [
                                            GroupMemberAvatar(
                                              uid: toUid,
                                              initials: toInitials,
                                              avatarColor: toColor,
                                              radius: 16,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                toName,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(width: 8),
                                      
                                      // Record Payment action
                                      ElevatedButton(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (dialogCtx) => AlertDialog(
                                              backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              title: const Text('Record Settlement?'),
                                              content: Text('Mark that $fromName paid ₹${item.amount.toStringAsFixed(0)} to $toName?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(dialogCtx),
                                                  child: const Text('Cancel'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () async {
                                                    Navigator.pop(dialogCtx); // close dialog
                                                    Navigator.pop(ctx); // close bottom sheet
                                                    
                                                    // Add Settlement transaction
                                                    await ref.read(transactionProvider.notifier).addTransaction(
                                                      amount: item.amount,
                                                      category: 'Settlement',
                                                      merchant: 'Settlement Payment',
                                                      notes: 'Settlement: $fromName paid $toName',
                                                      paymentMethod: 'Cash',
                                                      date: DateTime.now(),
                                                      splitWith: [item.toEmail],
                                                      isSettled: true,
                                                      paidByEmail: item.fromEmail,
                                                      totalAmount: item.amount,
                                                      groupId: group.id,
                                                    );
                                                    
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: Text('Recorded settlement of ₹${item.amount.toStringAsFixed(0)}!'),
                                                          backgroundColor: AppColors.emeraldGreen,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryPurple, foregroundColor: Colors.white),
                                                  child: const Text('Record'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryPurple.withValues(alpha: 0.1),
                                          foregroundColor: AppColors.primaryPurple,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        child: Text(
                                          'Settle',
                                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
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
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTxs = ref.watch(transactionProvider);
    
    // Filter transactions belonging strictly to this group
    final display = allTxs.where((tx) {
      if (tx.groupId == group.id) return true;
      // Fallback for legacy transactions
      if (tx.groupId == null || tx.groupId!.isEmpty) {
        return tx.notes.contains('in group ${group.name}.') ||
               tx.merchant.contains('(${group.name})');
      }
      return false;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.electricBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.electricBlue, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              'GROUP TRANSACTIONS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.electricBlue,
                letterSpacing: 1.0,
              ),
            ),
            if (display.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.electricBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${display.length}',
                  style: const TextStyle(color: AppColors.electricBlue, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const Spacer(),
            if (display.isNotEmpty)
              GestureDetector(
                onTap: () => _showGroupSummary(context, ref, display, group),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        'Summary',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (display.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark.withValues(alpha: 0.4) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_outlined, size: 36, color: textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text('No group expenses yet.', style: TextStyle(color: textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Add a group expense using the button below.', style: TextStyle(color: textSecondary.withValues(alpha: 0.6), fontSize: 11)),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: display.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final currentUser = FirebaseAuth.instance.currentUser;
              final tx = display[index];
              final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(tx.date);
              final perHead = tx.splitWith.isNotEmpty
                  ? (tx.totalAmount > 0 ? tx.totalAmount / (tx.splitWith.length + 1) : tx.amount)
                  : tx.amount;
              final myShareOnCard = tx.splitShares != null && tx.splitShares!.containsKey(currentUser?.email)
                  ? tx.splitShares![currentUser?.email]!
                  : perHead;

              return GestureDetector(
                onTap: () => _showSplitDetails(context, ref, tx),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(getCategoryEmoji(tx.category), style: const TextStyle(fontSize: 20)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.merchant.isEmpty ? tx.category : tx.merchant,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                                ),
                                const SizedBox(height: 2),
                                Text(formattedDate, style: TextStyle(fontSize: 10, color: textSecondary)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '₹${(tx.totalAmount > 0 ? tx.totalAmount : tx.amount * (tx.splitWith.length + 1)).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppColors.accentPink,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (tx.splitWith.isNotEmpty) ...[
                                Text(
                                  tx.splitShares != null
                                      ? 'Your Share: ₹${myShareOnCard.toStringAsFixed(0)}'
                                      : '÷ ${tx.splitWith.length + 1} = ₹${perHead.toStringAsFixed(0)}/person',
                                  style: TextStyle(color: textSecondary, fontSize: 9),
                                ),
                                if (tx.isSettled)
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_circle, color: AppColors.emeraldGreen, size: 10),
                                      SizedBox(width: 2),
                                      Text(
                                        'Settled',
                                        style: TextStyle(color: AppColors.emeraldGreen, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      if (tx.splitWith.isNotEmpty || tx.notes.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(tx.category, style: const TextStyle(color: AppColors.primaryPurple, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.electricBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(tx.paymentMethod, style: const TextStyle(color: AppColors.electricBlue, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                            if (tx.splitWith.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (tx.isSettled ? AppColors.emeraldGreen : AppColors.accentOrange).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tx.isSettled ? 'Settled ✓' : 'Split ${tx.splitWith.length + 1} ways',
                                  style: TextStyle(
                                    color: tx.isSettled ? AppColors.emeraldGreen : AppColors.accentOrange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class GroupMemberAvatar extends ConsumerWidget {
  final String uid;
  final String initials;
  final Color avatarColor;
  final double radius;

  const GroupMemberAvatar({
    super.key,
    required this.uid,
    required this.initials,
    required this.avatarColor,
    this.radius = 29,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (uid.isEmpty) {
      return _buildPlaceholder();
    }

    if (uid == currentUid) {
      final authState = ref.watch(authProvider);
      final profilePicPath = authState.profilePicPath;
      final profilePicUrl = authState.profilePicUrl;

      if ((profilePicPath != null && profilePicPath.isNotEmpty) || (profilePicUrl != null && profilePicUrl.isNotEmpty)) {
        final photoUrl = profilePicPath ?? profilePicUrl;
        ImageProvider imageProvider;
        if (photoUrl!.startsWith('data:image')) {
          final base64String = photoUrl.split('base64,').last;
          imageProvider = MemoryImage(base64Decode(base64String));
        } else if (!photoUrl.startsWith('http') && File(photoUrl).existsSync()) {
          imageProvider = FileImage(File(photoUrl));
        } else {
          imageProvider = NetworkImage(photoUrl);
        }

        return CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
          backgroundColor: Colors.transparent,
        );
      }
      return _buildPlaceholder();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          final photoUrl = data?['photoUrl'] as String?;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            ImageProvider imageProvider;
            if (photoUrl.startsWith('data:image')) {
              final base64String = photoUrl.split('base64,').last;
              imageProvider = MemoryImage(base64Decode(base64String));
            } else if (!photoUrl.startsWith('http') && File(photoUrl).existsSync()) {
              imageProvider = FileImage(File(photoUrl));
            } else {
              imageProvider = NetworkImage(photoUrl);
            }
            return CircleAvatar(
              radius: radius,
              backgroundImage: imageProvider,
              backgroundColor: Colors.transparent,
            );
          }
        }
        return _buildPlaceholder();
      },
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            avatarColor.withOpacity(0.9),
            avatarColor.withOpacity(0.5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: avatarColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.62,
        ),
      ),
    );
  }
}

class SettlementItem {
  final String fromEmail;
  final String toEmail;
  final double amount;

  SettlementItem({
    required this.fromEmail,
    required this.toEmail,
    required this.amount,
  });
}
