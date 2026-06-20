import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

class PdfExportService {
  // ── Color palette ──────────────────────────────────────────────────────────
  static const _accent = PdfColor.fromInt(0xFF00D4AA);
  static const _dark = PdfColor.fromInt(0xFF0D1117);
  static const _grey = PdfColor.fromInt(0xFF8892A4);
  static const _light = PdfColor.fromInt(0xFFF4F6FA);
  static const _danger = PdfColor.fromInt(0xFFFF5757);
  static const _white = PdfColors.white;

  static String _monthName(int m) => const [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m];

  static String _fmtDate(DateTime d) =>
      '${d.day} ${_monthName(d.month)} ${d.year}';

  static String _dateLabel(String isoDate) {
    final date = DateTime.tryParse(isoDate)?.toLocal();
    if (date == null) return '-';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return _fmtDate(date);
  }

  // ── Header widget ──────────────────────────────────────────────────────────
  static pw.Widget _header(String title) {
    final now = DateTime.now();
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: const pw.BoxDecoration(color: _dark),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'ATL Inventory',
                style: pw.TextStyle(
                  color: _white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Atal Tinkering Lab · Component Tracker',
                style: pw.TextStyle(color: _grey, fontSize: 10),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  color: _accent,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${_fmtDate(now)}',
                style: pw.TextStyle(color: _grey, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Export Components PDF ──────────────────────────────────────────────────
  static Future<void> exportComponents(
    BuildContext context,
    List<Map<String, dynamic>> parts,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (_) => _header('Components Report'),
        build: (ctx) => [
          pw.SizedBox(height: 20),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── Summary ───────────────────────────────────────────
                pw.Row(
                  children: [
                    _summaryBox('Total Components', '${parts.length}'),
                    pw.SizedBox(width: 12),
                    _summaryBox(
                      'Total Available',
                      '${parts.fold(0, (s, p) => s + ((p['availability'] as num?)?.toInt() ?? 0))}',
                    ),
                    pw.SizedBox(width: 12),
                    _summaryBox(
                      'Total Quantity',
                      '${parts.fold(0, (s, p) => s + ((p['total_parts'] as num?)?.toInt() ?? 0))}',
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),

                // ── Table ─────────────────────────────────────────────
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColor.fromInt(0xFFDDE1EA),
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(3),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1),
                    3: const pw.FlexColumnWidth(1),
                    4: const pw.FlexColumnWidth(1),
                    5: const pw.FlexColumnWidth(1.5),
                  },
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: _dark),
                      children: [
                        _th('Component Name'),
                        _th('Category'),
                        _th('Box'),
                        _th('Total'),
                        _th('Available'),
                        _th('Condition'),
                      ],
                    ),
                    // Data rows
                    ...parts.asMap().entries.map((entry) {
                      final i = entry.key;
                      final p = entry.value;
                      final avail = (p['availability'] as num?)?.toInt() ?? 0;
                      final total = (p['total_parts'] as num?)?.toInt() ?? 0;
                      final condition = p['condition'] as String? ?? 'Good';
                      final condColor = condition == 'Good'
                          ? _accent
                          : condition == 'Fair'
                          ? PdfColor.fromInt(0xFFFFB300)
                          : _danger;

                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: i.isEven ? _light : _white,
                        ),
                        children: [
                          _td(p['part_name'] ?? '-'),
                          _td(p['category'] ?? '-'),
                          _td('${p['box_no'] ?? '-'}'),
                          _td('$total'),
                          _td('$avail'),
                          _tdColored(condition, condColor),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ── Export Borrow Records PDF ──────────────────────────────────────────────
  static Future<void> exportBorrows(
    BuildContext context,
    List<Map<String, dynamic>> borrows,
  ) async {
    final pdf = pw.Document();

    // Sort by date descending
    final sorted = [...borrows];
    sorted.sort((a, b) {
      final da = DateTime.tryParse(a['issue_date'] ?? '') ?? DateTime(2000);
      final db = DateTime.tryParse(b['issue_date'] ?? '') ?? DateTime(2000);
      return db.compareTo(da);
    });

    // Group by date
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final b in sorted) {
      final label = _dateLabel(b['issue_date'] ?? '');
      grouped.putIfAbsent(label, () => []).add(b);
    }

    final pending = borrows
        .where((b) => !(b['is_fully_returned'] as bool))
        .length;
    final returned = borrows
        .where((b) => b['is_fully_returned'] as bool)
        .length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        header: (_) => _header('Borrow Records'),
        build: (ctx) => [
          pw.SizedBox(height: 20),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // ── Summary ───────────────────────────────────────────
                pw.Row(
                  children: [
                    _summaryBox('Total Records', '${borrows.length}'),
                    pw.SizedBox(width: 12),
                    _summaryBox('Pending', '$pending'),
                    pw.SizedBox(width: 12),
                    _summaryBox('Returned', '$returned'),
                  ],
                ),
                pw.SizedBox(height: 20),

                // ── Grouped records ───────────────────────────────────
                ...grouped.entries.expand((entry) {
                  final label = entry.key;
                  final records = entry.value;

                  return [
                    // Date separator
                    pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8, top: 4),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Divider(color: _grey, thickness: 0.5),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            child: pw.Text(
                              label,
                              style: pw.TextStyle(
                                color: _grey,
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Divider(color: _grey, thickness: 0.5),
                          ),
                        ],
                      ),
                    ),

                    // Records table for this date group
                    pw.Table(
                      border: pw.TableBorder.all(
                        color: PdfColor.fromInt(0xFFDDE1EA),
                        width: 0.5,
                      ),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(2),
                        1: const pw.FlexColumnWidth(1.5),
                        2: const pw.FlexColumnWidth(1),
                        3: const pw.FlexColumnWidth(1),
                        4: const pw.FlexColumnWidth(3),
                        5: const pw.FlexColumnWidth(1.5),
                      },
                      children: [
                        pw.TableRow(
                          decoration: const pw.BoxDecoration(color: _dark),
                          children: [
                            _th('Student'),
                            _th('Class'),
                            _th('Roll'),
                            _th('Contact'),
                            _th('Components'),
                            _th('Status'),
                          ],
                        ),
                        ...records.asMap().entries.map((entry) {
                          final i = entry.key;
                          final b = entry.value;
                          final items = List<Map<String, dynamic>>.from(
                            b['items'] as List,
                          );
                          final isReturned = b['is_fully_returned'] as bool;

                          final componentsText = items
                              .map((item) {
                                final issued = item['qty_issued'] as int;
                                final returned = item['qty_returned'] as int;
                                return '${item['part_name']} ($returned/$issued)';
                              })
                              .join('\n');

                          return pw.TableRow(
                            decoration: pw.BoxDecoration(
                              color: i.isEven ? _light : _white,
                            ),
                            children: [
                              _td(b['student_name'] ?? '-'),
                              _td('${b['class']}-${b['section']}'),
                              _td(b['roll_no'] ?? '-'),
                              _td(b['contact_no'] ?? '-'),
                              _td(componentsText),
                              _tdColored(
                                isReturned ? 'Returned' : 'Pending',
                                isReturned ? _accent : _danger,
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                    pw.SizedBox(height: 16),
                  ];
                }),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  // ── Helper widgets ─────────────────────────────────────────────────────────
  static pw.Widget _summaryBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: _dark,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                color: _accent,
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(label, style: pw.TextStyle(color: _grey, fontSize: 9)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _th(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        color: _white,
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );

  static pw.Widget _td(String text) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 9, color: _dark)),
  );

  static pw.Widget _tdColored(String text, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 9,
        color: color,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
}
