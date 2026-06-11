import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:espenseai/core/models/transaction_model.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';

/// Checks if the current user has permission to edit or delete a transaction.
/// Users can edit/delete their personal transactions, group transactions they created,
/// or group transactions if they are the owner of that group.
bool canEditTransaction(TransactionModel tx, WidgetRef ref) {
  final currentUser = FirebaseAuth.instance.currentUser;
  final currentUid = currentUser?.uid;
  final currentEmail = currentUser?.email;

  // Personal transactions (not part of any group) can always be edited by the local user.
  if (tx.groupId == null || tx.groupId!.isEmpty) {
    return true;
  }

  // Group transaction created by the current user (using UID)
  if (tx.createdBy == currentUid) {
    return true;
  }

  // Fallback for legacy transactions where createdBy is not set yet (using Email)
  if ((tx.createdBy == null || tx.createdBy!.isEmpty) && 
      tx.paidByEmail.toLowerCase() == currentEmail?.toLowerCase()) {
    return true;
  }

  // Check if current user is the Group Owner
  try {
    final groups = ref.read(groupsProvider);
    final group = groups.firstWhere((g) => g.id == tx.groupId);
    if (group.createdBy == currentUid) {
      return true;
    }
  } catch (_) {
    // Group not found locally or error parsing
  }

  return false;
}
