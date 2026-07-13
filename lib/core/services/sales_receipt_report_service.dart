import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/currency_utils.dart';
import '../utils/date_utils.dart' as app_date;
import '../../domain/models/transaction.dart';

class SalesReceiptReportService {
  Future<Uint8List> buildReceipt({
    required List<Transaction> transactions,
    required String farmName,
    required String sellerName,
  }) async {
    final Transaction first = transactions.isEmpty ? throw StateError('No receipt transactions provided.') : transactions.first;
    final double total = transactions.fold<double>(0, (double sum, Transaction item) => sum + item.amount);
    final double quantity = transactions.fold<double>(0, (double sum, Transaction item) => sum + item.quantity);
    final pw.Document document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => <pw.Widget>[
          _buildHeader(),
          pw.SizedBox(height: 18),
          _buildReceiptSummary(
            receiptNumber: first.receiptNumber.isEmpty ? first.id : first.receiptNumber,
            farmName: farmName,
            sellerName: sellerName,
            customerName: first.counterpartyName.isEmpty ? 'Walk-in customer' : first.counterpartyName,
            customerEmail: first.counterpartyEmail,
            customerPhone: first.counterpartyPhone,
            date: first.transactionDate,
          ),
          pw.SizedBox(height: 18),
          _buildLineItems(transactions),
          pw.SizedBox(height: 18),
          _buildTotals(total: total, quantity: quantity),
          pw.SizedBox(height: 18),
          _buildNotes(first.notes),
        ],
      ),
    );

    return document.save();
  }

  pw.Widget _buildHeader() {
    final DateTime now = DateTime.now();
    return pw.Container(
      padding: const pw.EdgeInsets.all(22),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F2F7EC'),
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Container(
            width: 54,
            height: 54,
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#214B34'),
              borderRadius: pw.BorderRadius.circular(14),
            ),
            child: pw.Center(
              child: pw.Text(
                'FS',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'FarmSync Sales Receipt',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#214B34'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Exported ${app_date.DateUtils.formatDateTime(now)}',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildReceiptSummary({
    required String receiptNumber,
    required String farmName,
    required String sellerName,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required DateTime date,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F7FAF4'),
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColor.fromHex('#E3E8DE')),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'Receipt details',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#214B34'),
            ),
          ),
          pw.SizedBox(height: 12),
          _receiptRow('Receipt No', receiptNumber),
          _receiptRow('Farm', farmName),
          _receiptRow('Seller', sellerName),
          _receiptRow('Customer', customerName),
          _receiptRow('Email', customerEmail.isEmpty ? 'Not provided' : customerEmail),
          _receiptRow('Phone', customerPhone.isEmpty ? 'Not provided' : customerPhone),
          _receiptRow('Date', app_date.DateUtils.formatDate(date)),
        ],
      ),
    );
  }

  pw.Widget _buildLineItems(List<Transaction> transactions) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E3E8DE')),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'Line items',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#214B34'),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.symmetric(
              inside: pw.BorderSide(color: PdfColor.fromHex('#E9EEE6')),
            ),
            columnWidths: const <int, pw.TableColumnWidth>{
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.2),
            },
            children: <pw.TableRow>[
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EEF5E8')),
                children: <pw.Widget>[
                  _tableCell('Product', isHeader: true),
                  _tableCell('Qty', isHeader: true),
                  _tableCell('Price', isHeader: true),
                  _tableCell('Amount', isHeader: true),
                ],
              ),
              ...transactions.map(
                (Transaction transaction) => pw.TableRow(
                  children: <pw.Widget>[
                    _tableCell(transaction.productName.isEmpty ? transaction.description : transaction.productName),
                    _tableCell('${transaction.quantity.toStringAsFixed(2)} ${transaction.unit}'),
                    _tableCell(CurrencyUtils.formatCurrency(transaction.unitPrice)),
                    _tableCell(CurrencyUtils.formatCurrency(transaction.amount)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotals({
    required double total,
    required double quantity,
  }) {
    return pw.Row(
      children: <pw.Widget>[
        pw.Expanded(child: _summaryCard('Items sold', quantity.toStringAsFixed(2), '#E4F4D6')),
        pw.SizedBox(width: 10),
        pw.Expanded(child: _summaryCard('Grand total', CurrencyUtils.formatCurrency(total), '#DDEEFF')),
      ],
    );
  }

  pw.Widget _buildNotes(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF5DE'),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Text(
        notes.isEmpty ? 'Generated by FarmSync sales desk.' : notes,
        style: const pw.TextStyle(fontSize: 11),
      ),
    );
  }

  pw.Widget _summaryCard(String title, String value, String colorHex) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(colorHex),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(title, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
          pw.SizedBox(height: 8),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#214B34'),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _receiptRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _tableCell(String value, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
