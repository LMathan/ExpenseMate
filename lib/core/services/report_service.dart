import 'dart:io';
import 'package:excel/excel.dart' as ex;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../storage/hive_helper.dart';
import '../models/transaction_model.dart';

class ReportService {
  List<TransactionModel> _getTransactions() {
    final tBox = Hive.box(HiveHelper.transactionsBox);
    final List<TransactionModel> txs = [];
    for (var key in tBox.keys) {
      txs.add(
        TransactionModel.fromMap(Map<String, dynamic>.from(tBox.get(key))),
      );
    }
    txs.sort((a, b) => b.date.compareTo(a.date));
    return txs;
  }

  // 1. Generate PDF Report
  Future<File> generatePdfReport() async {
    final pdf = pw.Document();
    final txs = _getTransactions();

    double totalSpent = txs.fold(0.0, (sum, item) => sum + item.amount);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'ExpenseAI Financial Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(DateTime.now().toString().substring(0, 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total Expenses Recorded:',
                  style: const pw.TextStyle(fontSize: 14),
                ),
                pw.Text(
                  'INR ${totalSpent.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: [
                'Date',
                'Merchant',
                'Category',
                'Payment Method',
                'Amount (INR)',
              ],
              data: txs.map((tx) {
                return [
                  tx.date.toString().substring(0, 10),
                  tx.merchant,
                  tx.category,
                  tx.paymentMethod,
                  tx.amount.toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final file = File(
      '${outputDir.path}/ExpenseAI_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  // 2. Generate Excel Report
  Future<File> generateExcelReport() async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Sheet1'];
    final txs = _getTransactions();

    // Headers
    sheet.appendRow([
      ex.TextCellValue('Transaction ID'),
      ex.TextCellValue('Date'),
      ex.TextCellValue('Merchant'),
      ex.TextCellValue('Category'),
      ex.TextCellValue('Payment Method'),
      ex.TextCellValue('Amount (INR)'),
      ex.TextCellValue('Notes'),
    ]);

    // Rows
    for (var tx in txs) {
      sheet.appendRow([
        ex.TextCellValue(tx.id),
        ex.TextCellValue(tx.date.toIso8601String().substring(0, 10)),
        ex.TextCellValue(tx.merchant),
        ex.TextCellValue(tx.category),
        ex.TextCellValue(tx.paymentMethod),
        ex.DoubleCellValue(tx.amount),
        ex.TextCellValue(tx.notes),
      ]);
    }

    final outputDir = await getTemporaryDirectory();
    final file = File(
      '${outputDir.path}/ExpenseAI_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
    );
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
    }
    return file;
  }

  // 3. Generate CSV Report
  Future<File> generateCsvReport() async {
    final txs = _getTransactions();
    final buffer = StringBuffer();

    // Headers
    buffer.writeln(
      'Transaction ID,Date,Merchant,Category,Payment Method,Amount,Notes',
    );

    for (var tx in txs) {
      buffer.writeln(
        '"${tx.id}","${tx.date.toIso8601String().substring(0, 10)}","${tx.merchant.replaceAll('"', '""')}","${tx.category}","${tx.paymentMethod}",${tx.amount},"${tx.notes.replaceAll('"', '""')}"',
      );
    }

    final outputDir = await getTemporaryDirectory();
    final file = File(
      '${outputDir.path}/ExpenseAI_Report_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(buffer.toString());
    return file;
  }

  // Share report
  Future<void> shareReport(
    File file, {
    String subject = 'My Financial Report',
  }) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles(
      [xFile],
      text: 'Here is my financial statement generated by ExpenseAI.',
      subject: subject,
    );
  }
}
