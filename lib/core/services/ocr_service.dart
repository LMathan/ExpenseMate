import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage(ImageSource source) async {
    try {
      return await _picker.pickImage(source: source, imageQuality: 85);
    } catch (_) {
      return null;
    }
  }

  // Performs actual OCR text recognition using Google ML Kit or mock simulation
  Future<Map<String, dynamic>> scanReceipt(File file, {String? mockType}) async {
    if (mockType != null) {
      // Simulate network/OCR processing delay for mocks
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mockType == 'starbucks') {
        return {
          'merchant': 'Starbucks Coffee',
          'amount': 380.00,
          'tax': 18.10,
          'date': DateTime.now().toIso8601String(),
          'category': 'Food',
          'notes': 'OCR Scan: Starbucks Beverage',
        };
      } else if (mockType == 'amazon') {
        return {
          'merchant': 'Amazon India',
          'amount': 1249.00,
          'tax': 224.82,
          'date': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'category': 'Shopping',
          'notes': 'OCR Scan: Amazon Purchase',
        };
      } else if (mockType == 'shell') {
        return {
          'merchant': 'Shell Petrol Station',
          'amount': 1500.00,
          'tax': 0.00,
          'date': DateTime.now().toIso8601String(),
          'category': 'Fuel',
          'notes': 'OCR Scan: Vehicle Refuel',
        };
      } else if (mockType == 'electricity') {
        return {
          'merchant': 'Electricity Board',
          'amount': 2840.00,
          'tax': 142.00,
          'date': DateTime.now().toIso8601String(),
          'category': 'Bills',
          'notes': 'OCR Scan: Monthly Utility Bill',
        };
      }
    }

    try {
      // Initialize the ML Kit Text Recognizer
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(InputImage.fromFilePath(file.path));
      final String fullText = recognizedText.text;
      await textRecognizer.close();

      // Debug print to console so developers/users can see the exact parsed OCR text in flutter logs
      print('========================================');
      print('OCR RECOGNIZED TEXT START:');
      print(fullText);
      print('OCR RECOGNIZED TEXT END');
      print('========================================');

      if (fullText.trim().isEmpty) {
        return {
          'error': 'No readable text was detected in the receipt. Please try again with a clearer picture.',
        };
      }

      // Normalize spaces around decimal points and commas (common OCR artifacts)
      final normalizedText = fullText
          .replaceAll(RegExp(r'\s*\.\s*(?=\d)'), '.')
          .replaceAll(RegExp(r'\s*,\s*(?=\d)'), ',');

      // Parse details from the text
      final lines = normalizedText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      
      // 1. Merchant Extraction: Find the first line that is likely to be a merchant name (not date, time, or pure numbers)
      String merchant = 'Unknown Merchant';
      final dateRegex = RegExp(r'\b\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}\b');
      final timeRegex = RegExp(r'\b\d{1,2}:\d{2}(:\d{2})?(\s*(am|pm))?\b', caseSensitive: false);
      final numberOnlyRegex = RegExp(r'^[\d\s.,\-\/\\:()]+$');

      for (var line in lines) {
        if (!dateRegex.hasMatch(line) &&
            !timeRegex.hasMatch(line) &&
            !numberOnlyRegex.hasMatch(line) &&
            line.length > 2 &&
            line.length < 40) {
          merchant = line;
          break;
        }
      }

      // 2. Amount Extraction (Robust parsed layout heuristics)
      double? amount;
      final totalKeywords = ['total', 'grand total', 'net total', 'amount due', 'amount paid', 'paid', 'due', 'sum', 'net', 'total:', 'amt', 'subtotal'];
      final rawNumberRegex = RegExp(r'\d+(?:[.,]\d+)?'); // match any positive number (decimals or integers)

      List<double> candidatesFromTotalLines = [];

      for (var line in lines) {
        final lowerLine = line.toLowerCase();
        if (totalKeywords.any((kw) => lowerLine.contains(kw))) {
          final matches = rawNumberRegex.allMatches(line);
          for (var match in matches) {
            final matchedStr = match.group(0)!.replaceAll(',', '');
            final parsed = double.tryParse(matchedStr);
            if (parsed != null && parsed > 0) {
              candidatesFromTotalLines.add(parsed);
            }
          }
        }
      }

      if (candidatesFromTotalLines.isNotEmpty) {
        // Filter out current/previous year values and tiny indexes
        final cleanCandidates = candidatesFromTotalLines.where((val) {
          final isYear = val == DateTime.now().year || val == DateTime.now().year - 1;
          final isTiny = val <= 5;
          return !isYear && !isTiny;
        }).toList();

        if (cleanCandidates.isNotEmpty) {
          cleanCandidates.sort();
          amount = cleanCandidates.last; // Typically total is the largest price figure on total-labeled lines
        } else {
          amount = candidatesFromTotalLines.first;
        }
      }

      // Fallback 1: Look for numbers preceded by currency symbols or containing decimal places
      if (amount == null || amount <= 0) {
        final currencyPriceRegex = RegExp(r'(?:[\$₹¥€£]|rs\.?|inr)\s*(\d+(?:[.,]\d{2})?)', caseSensitive: false);
        final decimalPriceRegex = RegExp(r'\b\d{1,6}[.,]\d{2}\b');
        List<double> fallbackPriceCandidates = [];

        // Check currency symbol prefix
        for (var line in lines) {
          final matches = currencyPriceRegex.allMatches(line);
          for (var match in matches) {
            final valStr = match.group(1)!.replaceAll(',', '');
            final parsed = double.tryParse(valStr);
            if (parsed != null && parsed > 0) {
              fallbackPriceCandidates.add(parsed);
            }
          }
        }

        // Check generic two-decimal numbers
        if (fallbackPriceCandidates.isEmpty) {
          for (var line in lines) {
            final matches = decimalPriceRegex.allMatches(line);
            for (var match in matches) {
              final valStr = match.group(0)!.replaceAll(',', '');
              final parsed = double.tryParse(valStr);
              if (parsed != null && parsed > 0) {
                fallbackPriceCandidates.add(parsed);
              }
            }
          }
        }

        if (fallbackPriceCandidates.isNotEmpty) {
          fallbackPriceCandidates.sort();
          final filtered = fallbackPriceCandidates.where((p) => p < 100000).toList();
          if (filtered.isNotEmpty) {
            amount = filtered.last;
          }
        }
      }

      // Fallback 2: General scan for any reasonable numeric value between 10 and 50000 (excluding years & invoice metadata lines)
      if (amount == null || amount <= 0) {
        List<double> generalNumbers = [];
        final ignoreKeywords = ['invoice', 'bill', 'phone', 'tel', 'gstin', 'tin', 'txn', 'transaction', 'date', 'time', 'order', 'no.'];

        for (var line in lines) {
          final lowerLine = line.toLowerCase();
          // Skip lines containing invoice, bill, order, phone, or date/time info
          if (ignoreKeywords.any((kw) => lowerLine.contains(kw))) {
            continue;
          }

          final matches = rawNumberRegex.allMatches(line);
          for (var match in matches) {
            final valStr = match.group(0)!.replaceAll(',', '');
            final parsed = double.tryParse(valStr);
            if (parsed != null && parsed >= 10 && parsed <= 50000) {
              final isYear = parsed == DateTime.now().year || parsed == DateTime.now().year - 1;
              if (!isYear) {
                generalNumbers.add(parsed);
              }
            }
          }
        }
        if (generalNumbers.isNotEmpty) {
          generalNumbers.sort();
          amount = generalNumbers.last;
        }
      }

      if (amount == null || amount <= 0) {
        return {
          'error': 'Failed to extract total amount from the receipt. Please try taking a clearer photo or entering the expense manually.',
        };
      }

      // 3. Category Extraction (smart keyword mapping)
      String category = 'Other';
      final lowerFullText = fullText.toLowerCase();

      final categoryKeywords = {
        'Food': ['starbucks', 'coffee', 'cafe', 'restaurant', 'food', 'mcdonalds', 'burger', 'pizza', 'dinner', 'lunch', 'bakery', 'diner', 'eats', 'subway', 'kfc', 'swiggy', 'zomato'],
        'Travel': ['uber', 'ola', 'cab', 'metro', 'train', 'bus', 'flight', 'airline', 'travel', 'irctc', 'ride', 'taxi', 'rapido'],
        'Shopping': ['amazon', 'flipkart', 'myntra', 'reliance', 'retail', 'mart', 'grocery', 'store', 'mall', 'clothing', 'fashion', 'supermarket', 'd-mart', 'billing', 'buy', 'shop'],
        'Entertainment': ['movie', 'cinema', 'bookmyshow', 'netflix', 'spotify', 'game', 'theatre', 'event', 'concert', 'show', 'fun', 'amusement'],
        'Bills': ['electricity', 'water', 'power', 'bill', 'recharge', 'telecom', 'jio', 'airtel', 'utility', 'broadband', 'wifi', 'gas connection'],
        'Fuel': ['petrol', 'diesel', 'gas', 'shell', 'hp', 'bpcl', 'iocl', 'fuel', 'station', 'refuel', 'oil'],
        'Healthcare': ['medical', 'hospital', 'pharmacy', 'doctor', 'medicine', 'clinic', 'health', 'lab', 'diagnostics'],
        'Education': ['school', 'college', 'tuition', 'book', 'fees', 'course', 'academy'],
        'Rent': ['rent', 'owner', 'flat', 'house rent', 'pg rent'],
        'EMI': ['emi', 'loan', 'bank', 'interest', 'mortgage'],
      };

      for (var entry in categoryKeywords.entries) {
        if (entry.value.any((keyword) => lowerFullText.contains(keyword))) {
          category = entry.key;
          break;
        }
      }

      return {
        'merchant': merchant,
        'amount': amount,
        'tax': 0.00,
        'date': DateTime.now().toIso8601String(),
        'category': category,
        'notes': 'OCR Scan: Extracted from receipt image',
      };
    } catch (e) {
      return {
        'error': 'An error occurred during scanning: ${e.toString()}',
      };
    }
  }
}
