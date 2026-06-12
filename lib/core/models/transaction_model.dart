class TransactionModel {
  final String id;
  final double amount;
  final String category;
  final String notes;
  final DateTime date;
  final String paymentMethod;
  final String merchant;
  final bool isApproved;
  final bool isReceiptUploaded;
  final String receiptPath;
  final bool isRecurring;
  final List<String> splitWith;
  final bool isSettled;
  final String paidByEmail;
  final double totalAmount;
  final String? groupId;
  final String? createdBy;
  final Map<String, double>? splitShares;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.notes,
    required this.date,
    required this.paymentMethod,
    required this.merchant,
    required this.isApproved,
    required this.isReceiptUploaded,
    required this.receiptPath,
    required this.isRecurring,
    required this.splitWith,
    this.isSettled = false,
    this.paidByEmail = '',
    this.totalAmount = 0.0,
    this.groupId,
    this.createdBy,
    this.splitShares,
  });

  factory TransactionModel.fromMap(Map<dynamic, dynamic> map) {
    return TransactionModel(
      id: map['id'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Other',
      notes: map['notes'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      paymentMethod: map['paymentMethod'] ?? 'Cash',
      merchant: map['merchant'] ?? '',
      isApproved: map['isApproved'] ?? true,
      isReceiptUploaded: map['isReceiptUploaded'] ?? false,
      receiptPath: map['receiptPath'] ?? '',
      isRecurring: map['isRecurring'] ?? false,
      splitWith: map['splitWith'] != null ? List<String>.from(map['splitWith']) : [],
      isSettled: map['isSettled'] ?? false,
      paidByEmail: map['paidByEmail'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      groupId: map['groupId'],
      createdBy: map['createdBy'],
      splitShares: map['splitShares'] != null
          ? Map<String, double>.from((map['splitShares'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())))
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'notes': notes,
      'date': date.toIso8601String(),
      'paymentMethod': paymentMethod,
      'merchant': merchant,
      'isApproved': isApproved,
      'isReceiptUploaded': isReceiptUploaded,
      'receiptPath': receiptPath,
      'isRecurring': isRecurring,
      'splitWith': splitWith,
      'isSettled': isSettled,
      'paidByEmail': paidByEmail,
      'totalAmount': totalAmount,
      'groupId': groupId,
      'createdBy': createdBy,
      'splitShares': splitShares,
    };
  }

  TransactionModel copyWith({
    String? id,
    double? amount,
    String? category,
    String? notes,
    DateTime? date,
    String? paymentMethod,
    String? merchant,
    bool? isApproved,
    bool? isReceiptUploaded,
    String? receiptPath,
    bool? isRecurring,
    List<String>? splitWith,
    bool? isSettled,
    String? paidByEmail,
    double? totalAmount,
    String? groupId,
    String? createdBy,
    Map<String, double>? splitShares,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      notes: notes ?? this.notes,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      merchant: merchant ?? this.merchant,
      isApproved: isApproved ?? this.isApproved,
      isReceiptUploaded: isReceiptUploaded ?? this.isReceiptUploaded,
      receiptPath: receiptPath ?? this.receiptPath,
      isRecurring: isRecurring ?? this.isRecurring,
      splitWith: splitWith ?? this.splitWith,
      isSettled: isSettled ?? this.isSettled,
      paidByEmail: paidByEmail ?? this.paidByEmail,
      totalAmount: totalAmount ?? this.totalAmount,
      groupId: groupId ?? this.groupId,
      createdBy: createdBy ?? this.createdBy,
      splitShares: splitShares ?? this.splitShares,
    );
  }
}
