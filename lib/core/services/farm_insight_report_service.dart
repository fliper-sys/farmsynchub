import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/currency_utils.dart';
import '../utils/date_utils.dart' as app_date;
import '../../domain/models/crop.dart';
import '../../domain/models/farm.dart';
import '../../domain/models/livestock.dart';
import '../../domain/models/transaction.dart';

class FarmInsightReportService {
  Future<Uint8List> buildReport({
    required Farm farm,
    required List<Crop> crops,
    required List<Livestock> livestock,
    required List<Transaction> transactions,
    required String aiBriefing,
  }) async {
    final _FinanceSnapshot snapshot = _FinanceSnapshot.fromTransactions(transactions);

    final pw.Document document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => <pw.Widget>[
          _buildHeader(farm),
          pw.SizedBox(height: 18),
          _buildOverviewGrid(farm, crops, livestock, transactions, snapshot),
          pw.SizedBox(height: 18),
          _buildAiBriefing(aiBriefing),
          pw.SizedBox(height: 18),
          _buildFinancialSection(snapshot, transactions),
          pw.SizedBox(height: 18),
          _buildRecordsSection(farm, crops, livestock),
          pw.SizedBox(height: 18),
          _buildFooter(),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _buildHeader(Farm farm) {
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
                  'FarmSync Hub\u2122 Farm Insight Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#214B34'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  farm.name,
                  style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey800),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'Prepared ${app_date.DateUtils.formatDateTime(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOverviewGrid(
    Farm farm,
    List<Crop> crops,
    List<Livestock> livestock,
    List<Transaction> transactions,
    _FinanceSnapshot snapshot,
  ) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <pw.Widget>[
        _metricCard('Farm size', '${farm.sizeHa.toStringAsFixed(2)} ha', '#E5F5D8'),
        _metricCard('Crops', '${crops.length}', '#DFF1FF'),
        _metricCard('Livestock', '${livestock.fold<int>(0, (int sum, Livestock item) => sum + item.count)}', '#FFEBD0'),
        _metricCard('Documents', '${farm.documents.length}', '#EDE8FF'),
        _metricCard('Income', CurrencyUtils.formatCurrency(snapshot.income), '#E5F5D8'),
        _metricCard('Expenses', CurrencyUtils.formatCurrency(snapshot.expenses), '#FDE3D8'),
        _metricCard('Balance', CurrencyUtils.formatCurrency(snapshot.balance), '#DFF1FF'),
        _metricCard('Tasks', '${farm.openWorkspaceTaskCount} open', '#FFF0C7'),
      ],
    );
  }

  pw.Widget _metricCard(String title, String value, String colorHex) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex(colorHex),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
          pw.SizedBox(height: 6),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#214B34'),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildAiBriefing(String aiBriefing) {
    return _sectionCard(
      title: 'AI briefing',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: _briefingBlocks(aiBriefing),
      ),
    );
  }

  pw.Widget _buildFinancialSection(_FinanceSnapshot snapshot, List<Transaction> transactions) {
    return _sectionCard(
      title: 'Financial report',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Row(
            children: <pw.Widget>[
              pw.Expanded(child: _smallStat('Income', CurrencyUtils.formatCurrency(snapshot.income))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _smallStat('Expenses', CurrencyUtils.formatCurrency(snapshot.expenses))),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _smallStat('Balance', CurrencyUtils.formatCurrency(snapshot.balance))),
            ],
          ),
          pw.SizedBox(height: 14),
          pw.Text(
            'Recent transactions',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#214B34')),
          ),
          pw.SizedBox(height: 8),
          ...transactions.take(6).map(
            (Transaction transaction) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                children: <pw.Widget>[
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      transaction.description.isEmpty ? transaction.productName : transaction.description,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      transaction.type.name,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Text(
                    CurrencyUtils.formatCurrency(transaction.amount),
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildRecordsSection(Farm farm, List<Crop> crops, List<Livestock> livestock) {
    return _sectionCard(
      title: 'Records and activities',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          _bullet('Crop records: ${crops.length} linked entries.'),
          _bullet('Livestock groups: ${livestock.length} linked entries.'),
          _bullet('Documents stored: ${farm.documents.length}.'),
          _bullet('Activity log entries: ${farm.activityLog.length}.'),
          if (farm.notes.trim().isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 8),
            pw.Text(
              'Farm notes',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#214B34')),
            ),
            pw.SizedBox(height: 4),
            pw.Text(farm.notes, style: const pw.TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }

  pw.Widget _sectionCard({
    required String title,
    required pw.Widget child,
  }) {
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
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromHex('#214B34'),
            ),
          ),
          pw.SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  pw.Widget _smallStat(String title, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F7FAF4'),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  pw.Widget _bullet(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text('• ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(child: pw.Text(text, style: const pw.TextStyle(fontSize: 10))),
        ],
      ),
    );
  }

  List<pw.Widget> _briefingBlocks(String briefing) {
    final List<pw.Widget> blocks = <pw.Widget>[];
    for (final String rawLine in briefing.split('\n')) {
      final String line = rawLine.trim();
      if (line.isEmpty) {
        blocks.add(pw.SizedBox(height: 6));
        continue;
      }
      if (line.startsWith('- ')) {
        blocks.add(_bullet(line.substring(2)));
        continue;
      }
      final bool isHeading = !line.startsWith('-') &&
          !line.startsWith('*') &&
          !line.contains(':') &&
          line.length < 42;
      blocks.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Text(
            line,
            style: pw.TextStyle(
              fontSize: isHeading ? 13 : 10.5,
              fontWeight: isHeading ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeading ? PdfColor.fromHex('#214B34') : PdfColors.grey900,
            ),
          ),
        ),
      );
    }
    return blocks;
  }

  pw.Widget _buildFooter() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#FFF5DE'),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Text(
        'Generated by FarmSync Hub\u2122 for farm planning, record keeping, and management review.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }
}

class _FinanceSnapshot {
  const _FinanceSnapshot({
    required this.income,
    required this.expenses,
    required this.balance,
  });

  final double income;
  final double expenses;
  final double balance;

  factory _FinanceSnapshot.fromTransactions(List<Transaction> transactions) {
    double income = 0;
    double expenses = 0;
    for (final Transaction transaction in transactions) {
      if (transaction.type == TransactionType.income) {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;
      }
    }
    return _FinanceSnapshot(
      income: income,
      expenses: expenses,
      balance: income - expenses,
    );
  }
}
