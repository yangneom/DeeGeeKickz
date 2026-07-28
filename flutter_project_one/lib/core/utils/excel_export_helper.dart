// lib/utils/excel_export_helper.dart
//
// ================================================
// EXCEL EXPORT HELPER
//
// Web-only. Builds a real .xlsx file (not a renamed CSV) using the
// `excel` package, then triggers a browser download the same way
// csv_export_helper.dart does — a Blob + temporary anchor tag.
//
// Reusable across every "Export as Excel" option in the app —
// each screen just needs to build its own headers + rows from
// whatever data it already has on screen, then hand them to
// exportToExcel(), same calling shape as CsvExportHelper.exportToCsv().
// ================================================

import 'dart:html' as html;
import 'dart:typed_data';
import 'package:excel/excel.dart';

class ExcelExportHelper {
  /// Builds an .xlsx file from [headers] + [rows] and triggers a
  /// browser download named "$filename.xlsx" (extension added
  /// automatically).
  ///
  /// Each row in [rows] must have the same length as [headers].
  /// Cell values can be String, int, double, bool, DateTime, or
  /// null — anything else is converted via .toString().
  static void exportToExcel({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String sheetName = 'Sheet1',
  }) {
    final Excel workbook = Excel.createExcel();

    // Excel.createExcel() always starts with a default 'Sheet1' —
    // rename it to the requested name instead of creating a second,
    // unused default sheet alongside it.
    if (sheetName != 'Sheet1') {
      workbook.rename('Sheet1', sheetName);
    }
    final Sheet sheet = workbook[sheetName];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final List<dynamic> row in rows) {
      sheet.appendRow(row.map(_toCellValue).toList());
    }

    final List<int>? fileBytes = workbook.save();
    if (fileBytes == null) {
      print('ExcelExportHelper.exportToExcel: workbook.save() returned null');
      return;
    }

    final html.Blob blob = html.Blob(
      [Uint8List.fromList(fileBytes)],
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    final String url = html.Url.createObjectUrlFromBlob(blob);

    final html.AnchorElement anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '$filename.xlsx')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  /// Converts a raw Dart value into the typed CellValue the `excel`
  /// package requires (as of v4+, cell values are a sealed class,
  /// not `dynamic`).
  static CellValue _toCellValue(dynamic value) {
    if (value == null) return TextCellValue('');
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    if (value is DateTime) {
      return DateTimeCellValue(
        year: value.year,
        month: value.month,
        day: value.day,
        hour: value.hour,
        minute: value.minute,
      );
    }
    return TextCellValue(value.toString());
  }
}