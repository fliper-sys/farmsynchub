import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/currency_utils.dart';
import '../utils/date_utils.dart' as app_date;
import '../../domain/models/farm.dart';
import '../../domain/models/transaction.dart';

class OperationsHistoryReportService {
  Future<Uint8List> buildReport({
    required String title,
    required String subtitle,
    required List<Farm> farms,
    required List<Transaction> entries,
    required double income,
    required double expenses,
    required Map<TransactionCategory, double> categoryTotals,
  }) async {
    final pw.Document document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => <pw.Widget>[
          _buildHeader(title, subtitle),
          pw.SizedBox(height: 18),
          _buildSummary(income, expenses, entries.length),
          pw.SizedBox(height: 18),
          _buildCategorySection(categoryTotals),
          pw.SizedBox(height: 18),
          _buildHistoryTable(farms, entries),
          pw.SizedBox(height: 18),
          _buildFooter(),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _buildHeader(String title, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(22),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F2F7EC'),
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            'FarmSync Hub\u2122',
            style: pw.TextStyle(
              fontSize: 11,
              letterSpacing: 1.1,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#4C6B57'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#214B34'),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Exported ${app_date.DateUtils.formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummary(double income, double expenses, int count) {
    return pw.Row(
      children: <pw.Widget>[
        pw.Expanded(child: _summaryCard('Income', CurrencyUtils.formatCurrency(income), '#E5F5D8')),
        pw.SizedBox(width: 10),
        pw.Expanded(child: _summaryCard('Expenses', CurrencyUtils.formatCurrency(expenses), '#FDE3D8')),
        pw.SizedBox(width: 10),
        pw.Expanded(child: _summaryCard('Entries', '$count', '#DFF1FF')),
      ],
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

  pw.Widget _buildCategorySection(Map<TransactionCategory, double> totals) {
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
            'Category breakdown',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#214B34'),
            ),
          ),
          pw.SizedBox(height: 12),
          ...totals.entries.map(
            (MapEntry<TransactionCategory, double> entry) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(child: pw.Text(_categoryLabel(entry.key))),
                  pw.Text(
                    CurrencyUtils.formatCurrency(entry.value),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildHistoryTable(List<Farm> farms, List<Transaction> entries) {
    final List<List<String>> rows = entries.map((Transaction transaction) {
      final String farmName = farms.firstWhere(
        (Farm farm) => farm.id == transaction.farmId,
        orElse: () => farms.isEmpty
            ? Farm(
                id: '',
                name: 'Unknown farm',
                ward: '',
                sizeHa: 0,
                farmType: FarmType.combined,
                farmerCategory: FarmerCategory.subsistence,
                soilType: SoilType.loamy,
                waterSource: WaterSource.rainfall,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                isSynced: true,
              )
            : farms.first,
      ).name;
      return <String>[
        app_date.DateUtils.formatDate(transaction.transactionDate),
        farmName,
        transaction.recordKind.name,
        transaction.description.isEmpty ? transaction.productName : transaction.description,
        CurrencyUtils.formatCurrency(transaction.amount),
      ];
    }).toList(growable: false);

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
            'History',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#214B34'),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const <String>['Date', 'Farm', 'Type', 'Detail', 'Amount'],
            data: rows,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#214B34')),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: <int, pw.TableColumnWidth>{
              0: const pw.FlexColumnWidth(1.1),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.0),
              3: const pw.FlexColumnWidth(2.3),
              4: const pw.FlexColumnWidth(0.9),
            },
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF5DE'),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Text(
        'Generated by FarmSync Hub\u2122 for procurement, expense, and sales history review.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  String _categoryLabel(TransactionCategory category) {
    return switch (category) {
      TransactionCategory.cropSale => 'Crop sale',
      TransactionCategory.livestockSale => 'Livestock sale',
      TransactionCategory.feed => 'Feed',
      TransactionCategory.fertiliser => 'Fertiliser',
      TransactionCategory.labour => 'Labour',
      TransactionCategory.veterinary => 'Veterinary',
      TransactionCategory.other => 'Other',
    };
  }
}
