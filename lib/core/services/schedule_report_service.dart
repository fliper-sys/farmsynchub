import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/date_utils.dart' as app_date;

enum ScheduleReportSourceType { farm, crop, livestock }

/// Lightweight, report-service-facing view of a schedule entry so
/// [ScheduleReportService] doesn't need to depend on the schedule screen's
/// private entry type.
class ScheduleReportItem {
  const ScheduleReportItem({
    required this.title,
    required this.dueDate,
    required this.sourceType,
    required this.sourceLabel,
  });

  final String title;
  final DateTime dueDate;
  final ScheduleReportSourceType sourceType;
  final String sourceLabel;
}

/// Builds a shareable PDF summary of upcoming farm, crop, and livestock
/// reminders, grouped the same way as the in-app schedule list (Overdue /
/// Today / Tomorrow / This week / Later) so the printed report matches what
/// the farmer sees on screen.
class ScheduleReportService {
  Future<Uint8List> buildReport({
    required List<ScheduleReportItem> items,
  }) async {
    final List<ScheduleReportItem> sorted = List<ScheduleReportItem>.of(items)
      ..sort((ScheduleReportItem a, ScheduleReportItem b) =>
          a.dueDate.compareTo(b.dueDate));

    final pw.Document document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) => <pw.Widget>[
          _buildHeader(sorted.length),
          pw.SizedBox(height: 18),
          if (sorted.isEmpty)
            pw.Text(
              'No upcoming reminders scheduled.',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
            )
          else
            ..._buildGroupedSections(sorted),
          pw.SizedBox(height: 18),
          _buildFooter(),
        ],
      ),
    );
    return document.save();
  }

  pw.Widget _buildHeader(int count) {
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
                  'FarmSync Hub™ Schedule Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#214B34'),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '$count upcoming reminder${count == 1 ? '' : 's'} across farms, crops, and livestock',
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey800),
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

  List<pw.Widget> _buildGroupedSections(List<ScheduleReportItem> sorted) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final DateTime endOfThisWeek = today.add(Duration(days: 7 - today.weekday));

    final Map<String, List<ScheduleReportItem>> grouped = <String, List<ScheduleReportItem>>{
      'Overdue': <ScheduleReportItem>[],
      'Today': <ScheduleReportItem>[],
      'Tomorrow': <ScheduleReportItem>[],
      'This week': <ScheduleReportItem>[],
      'Later': <ScheduleReportItem>[],
    };

    for (final ScheduleReportItem item in sorted) {
      final DateTime day = DateTime(item.dueDate.year, item.dueDate.month, item.dueDate.day);
      if (day.isBefore(today)) {
        grouped['Overdue']!.add(item);
      } else if (day == today) {
        grouped['Today']!.add(item);
      } else if (day == tomorrow) {
        grouped['Tomorrow']!.add(item);
      } else if (!day.isAfter(endOfThisWeek)) {
        grouped['This week']!.add(item);
      } else {
        grouped['Later']!.add(item);
      }
    }
    grouped.removeWhere((String key, List<ScheduleReportItem> bucket) => bucket.isEmpty);

    return <pw.Widget>[
      for (final MapEntry<String, List<ScheduleReportItem>> group in grouped.entries)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 14),
          child: _sectionCard(
            title: group.key,
            highlightRed: group.key == 'Overdue',
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                for (final ScheduleReportItem item in group.value) _itemRow(item),
              ],
            ),
          ),
        ),
    ];
  }

  pw.Widget _itemRow(ScheduleReportItem item) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 3, right: 8),
            width: 6,
            height: 6,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: PdfColor.fromHex(_sourceColorHex(item.sourceType)),
            ),
          ),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  item.title,
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '${item.sourceLabel} · ${_dateLabel(item.dueDate)}',
                  style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sourceColorHex(ScheduleReportSourceType type) {
    switch (type) {
      case ScheduleReportSourceType.farm:
        return '#E58A2C';
      case ScheduleReportSourceType.crop:
        return '#5F9A3C';
      case ScheduleReportSourceType.livestock:
        return '#3B82C4';
    }
  }

  String _dateLabel(DateTime date) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final String hh = date.hour.toString().padLeft(2, '0');
    final String mm = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${months[date.month - 1]} ${date.year} at $hh:$mm';
  }

  pw.Widget _sectionCard({
    required String title,
    required pw.Widget child,
    bool highlightRed = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColor.fromHex('#E3E8DE')),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: highlightRed ? PdfColor.fromHex('#C0392B') : PdfColor.fromHex('#214B34'),
            ),
          ),
          pw.SizedBox(height: 10),
          child,
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
        'Generated by FarmSync Hub™ to help plan and share upcoming farm work.',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }
}
