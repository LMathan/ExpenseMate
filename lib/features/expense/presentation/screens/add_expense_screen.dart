import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:espenseai/core/constants/colors.dart';
import 'package:espenseai/core/constants/text_styles.dart';
import 'package:espenseai/core/widgets/glass_card.dart';
import 'package:espenseai/features/expense/presentation/providers/expense_provider.dart';
import 'package:espenseai/core/utils/category_emoji_helper.dart';
import 'package:espenseai/core/widgets/vector_illustrations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final double? preFilledAmount;
  final String? preFilledCategory;
  final String? preFilledMerchant;
  final String? preFilledNotes;
  final String? preFilledReceiptPath;
  final dynamic editTransaction; // When set, this is an edit operation

  const AddExpenseScreen({
    super.key,
    this.preFilledAmount,
    this.preFilledCategory,
    this.preFilledMerchant,
    this.preFilledNotes,
    this.preFilledReceiptPath,
    this.editTransaction,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _receiptPath = '';
  bool _isReceiptUploaded = false;

  String _selectedCategory = 'Food';
  String _selectedPaymentMethod = 'UPI';
  DateTime _selectedDate = DateTime.now();

  final List<String> _categories = [
    'Food',
    'Travel',
    'Shopping',
    'Entertainment',
    'Bills',
    'Healthcare',
    'Education',
    'Rent',
    'EMI',
    'Fuel',
    'Other',
  ];

  static const List<Map<String, String>> _paymentMethods = [
    {'name': 'UPI',         'emoji': '📱'},
    {'name': 'Credit Card', 'emoji': '💳'},
    {'name': 'Debit Card',  'emoji': '🏧'},
    {'name': 'NetBanking',  'emoji': '🏦'},
    {'name': 'Cash',        'emoji': '💵'},
  ];

  @override
  void initState() {
    super.initState();
    _prefillFields();
  }

  void _prefillFields() {
    // Editing existing transaction takes priority
    final tx = widget.editTransaction;
    if (tx != null) {
      _amountController.text = tx.amount.toStringAsFixed(2);
      _merchantController.text = tx.merchant ?? '';
      _notesController.text = tx.notes ?? '';
      _selectedDate = tx.date ?? DateTime.now();
      _receiptPath = tx.receiptPath ?? '';
      _isReceiptUploaded = tx.isReceiptUploaded ?? false;
      if (_categories.contains(tx.category)) _selectedCategory = tx.category;
      final names = _paymentMethods.map((m) => m['name']!).toList();
      if (names.contains(tx.paymentMethod)) _selectedPaymentMethod = tx.paymentMethod;
      return;
    }
    if (widget.preFilledAmount != null && widget.preFilledAmount! > 0) {
      _amountController.text = widget.preFilledAmount!.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    }
    if (widget.preFilledMerchant != null) {
      _merchantController.text = widget.preFilledMerchant!;
    }
    if (widget.preFilledNotes != null) {
      _notesController.text = widget.preFilledNotes!;
    }
    if (widget.preFilledReceiptPath != null) {
      _receiptPath = widget.preFilledReceiptPath!;
      _isReceiptUploaded = true;
    }
    if (widget.preFilledCategory != null &&
        _categories.contains(widget.preFilledCategory)) {
      _selectedCategory = widget.preFilledCategory!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _presentDatePicker() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
              surface: AppColors.cardDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _onSubmit() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final merchant = _merchantController.text.trim();
      final notes = _notesController.text.trim();
      final isEditing = widget.editTransaction != null;

      // Copy receipt file persistently if it is temporary
      String savedReceiptPath = _receiptPath;
      bool savedIsUploaded = _isReceiptUploaded;
      if (_receiptPath.isNotEmpty && !_receiptPath.contains('/app_flutter/receipts/')) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          final receiptsDir = Directory('${appDocDir.path}/receipts');
          if (!await receiptsDir.exists()) {
            await receiptsDir.create(recursive: true);
          }
          final uniqueId = DateTime.now().millisecondsSinceEpoch;
          final newFile = File('${receiptsDir.path}/receipt_$uniqueId.jpg');
          await File(_receiptPath).copy(newFile.path);
          savedReceiptPath = newFile.path;
          savedIsUploaded = true;
        } catch (e) {
          debugPrint("Error copying receipt file: $e");
        }
      }

      if (isEditing) {
        final updated = widget.editTransaction.copyWith(
          amount: amount,
          category: _selectedCategory,
          merchant: merchant.isEmpty ? _selectedCategory : merchant,
          notes: notes,
          paymentMethod: _selectedPaymentMethod,
          date: _selectedDate,
          isReceiptUploaded: savedIsUploaded,
          receiptPath: savedReceiptPath,
        );
        await ref.read(transactionProvider.notifier).editTransaction(updated);
      } else {
        await ref.read(transactionProvider.notifier).addTransaction(
          amount: amount,
          category: _selectedCategory,
          merchant: merchant.isEmpty ? _selectedCategory : merchant,
          notes: notes,
          paymentMethod: _selectedPaymentMethod,
          date: _selectedDate,
          isReceiptUploaded: savedIsUploaded,
          receiptPath: savedReceiptPath,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing ? 'Transaction updated!' : 'Expense logged!'),
            backgroundColor: AppColors.emeraldGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          widget.editTransaction != null ? 'Edit Transaction' : 'Log Expense',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppBackground(
        type: PageBg.expense,
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassCard(
                  gradientColors: [
                    AppColors.primaryPurple.withValues(alpha: 0.12),
                    AppColors.electricBlue.withValues(alpha: 0.04),
                  ],
                  child: Column(
                    children: [
                      Text(
                        'ENTER AMOUNT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '₹',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 180,
                            child: TextFormField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black38),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Enter amount';
                                if (double.tryParse(value) == null)
                                  return 'Invalid number';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'SELECT CATEGORY',
                  style: AppTextStyles.caption(
                    isDark: isDark,
                  ).copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = cat),
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryPurple
                                  : (isDark ? AppColors.borderDark : Colors.grey[300]!),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            color: isSelected
                                ? AppColors.primaryPurple.withValues(
                                    alpha: 0.15,
                                  )
                                : (isDark
                                    ? AppColors.cardDark.withValues(alpha: 0.3)
                                    : Colors.grey[200]),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                getCategoryEmoji(cat),
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? AppColors.primaryPurple
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                GlassCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _merchantController,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                        decoration: InputDecoration(
                          labelText: 'Merchant Name',
                          labelStyle: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.electricBlue,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryPurple,
                              width: 2.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _notesController,
                        style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
                        decoration: InputDecoration(
                          labelText: 'Add Notes / Description',
                          labelStyle: TextStyle(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.description_outlined,
                            color: AppColors.electricBlue,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primaryPurple,
                              width: 2.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildReceiptSection(isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                GlassCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _presentDatePicker,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: AppColors.accentOrange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DATE',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(_selectedDate),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 36,
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Icons.credit_card_rounded,
                              color: AppColors.emeraldGreen,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'METHOD',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  DropdownButton<String>(
                                    value: _selectedPaymentMethod,
                                    dropdownColor: isDark ? AppColors.cardDark : Colors.white,
                                    iconEnabledColor: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    isDense: true,
                                    isExpanded: true,
                                    underline: const SizedBox(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    ),
                                    items: _paymentMethods.map((m) {
                                      return DropdownMenuItem(
                                        value: m['name'],
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(m['emoji']!,
                                                style: const TextStyle(
                                                    fontSize: 15)),
                                            const SizedBox(width: 6),
                                            Text(m['name']!, style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight)),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedPaymentMethod = val;
                                        });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                ElevatedButton(
                  onPressed: _onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 8,
                    shadowColor: AppColors.primaryPurple.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    'Save Transaction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildReceiptSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECEIPT ATTACHMENT',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryPurple,
                letterSpacing: 1.2,
              ),
            ),
            if (_receiptPath.isNotEmpty)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _receiptPath = '';
                    _isReceiptUploaded = false;
                  });
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.accentPink),
                label: Text(
                  'Remove',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.accentPink,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _receiptPath.isNotEmpty
            ? Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.file(
                          File(_receiptPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withValues(alpha: 0.4),
                                Colors.transparent,
                              ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Text(
                          _receiptPath.split('/').last,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : InkWell(
                onTap: _pickReceiptFromScreen,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_rounded,
                        color: isDark ? Colors.white54 : Colors.black45,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Attach Receipt Photo',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  void _pickReceiptFromScreen() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
        final bgColor = isDark ? AppColors.cardDark : Colors.white;

        return Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Attach Receipt',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryPurple),
                title: const Text('Take Photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
                  if (picked != null) {
                    setState(() {
                      _receiptPath = picked.path;
                      _isReceiptUploaded = true;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppColors.electricBlue),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                  if (picked != null) {
                    setState(() {
                      _receiptPath = picked.path;
                      _isReceiptUploaded = true;
                    });
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
