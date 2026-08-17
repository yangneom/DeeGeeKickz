// lib/core/utils/csv_export_helper_web.dart
//
// Real implementation — only ever compiled when targeting web,
// via the conditional export in csv_export_helper.dart.
// Logic is unchanged from the original file.

import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

class CsvExportHelper {
  /// Builds a CSV file from [headers] + [rows] and triggers a browser
  /// download named "$filename.csv" (extension added automatically).
  ///
  /// Each row in [rows] must have the same length as [headers]. Cell
  /// values can be any type — they're converted via .toString() and
  /// CSV-escaped (quoted if they contain a comma, quote, or newline).
  static void exportToCsv({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln(headers.map(_escapeCsvField).join(','));

    for (final List<dynamic> row in rows) {
      buffer.writeln(row.map(_escapeCsvField).join(','));
    }

    // UTF-8 BOM (0xEF,0xBB,0xBF) so Excel renders special characters
    // (₱, etc.) correctly instead of showing mojibake.
    const List<int> bom = [0xEF, 0xBB, 0xBF];
    final List<int> csvBytes = utf8.encode(buffer.toString());
    final List<int> fileBytes = [...bom, ...csvBytes];

    final html.Blob blob = html.Blob(
      [Uint8List.fromList(fileBytes)],
      'text/csv;charset=utf-8',
    );
    final String url = html.Url.createObjectUrlFromBlob(blob);

    final html.AnchorElement anchor = html.AnchorElement(href: url)
      ..setAttribute('download', '$filename.csv')
      ..click();

    html.Url.revokeObjectUrl(url);
  }

  /// Escapes a single CSV field: wraps in double quotes if it
  /// contains a comma, double quote, or newline, and doubles up any
  /// embedded double quotes per standard CSV escaping rules.
  static String _escapeCsvField(dynamic value) {
    final String text = (value ?? '').toString();

    final bool needsQuoting =
        text.contains(',') || text.contains('"') || text.contains('\n');

    if (!needsQuoting) return text;

    final String escaped = text.replaceAll('"', '""');
    return '"$escaped"';
  }
}