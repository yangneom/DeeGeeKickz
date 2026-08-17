// lib/core/utils/excel_export_helper_stub.dart
//
// Stub implementation — used on Android/iOS. Excel export via
// browser download only makes sense on web, so this no-ops safely
// so the app compiles and runs on mobile without crashing.

class ExcelExportHelper {
  static void exportToExcel({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
    String sheetName = 'Sheet1',
  }) {
    // Excel export isn't available on this platform. Safe no-op so
    // the app doesn't crash if an Export button is somehow reachable.
    print('ExcelExportHelper.exportToExcel: not supported on this platform.');
  }
}