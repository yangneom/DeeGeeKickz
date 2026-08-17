// lib/core/utils/csv_export_helper_stub.dart
//
// Stub implementation — used on Android/iOS (anywhere dart:library.html
// isn't available). CSV export via browser download only makes sense
// on web, so this doesn't attempt a native file-save; it just no-ops
// safely so the app compiles and runs on mobile without crashing.
//
// If native mobile export is ever wanted, this is the file to build
// that into (e.g. using a package like file_saver or share_plus to
// write/share the CSV bytes instead of a browser Blob download).

class CsvExportHelper {
  static void exportToCsv({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    // CSV export isn't available on this platform. Safe no-op so the
    // app doesn't crash if an Export button is somehow reachable here.
    print('CsvExportHelper.exportToCsv: not supported on this platform.');
  }
}