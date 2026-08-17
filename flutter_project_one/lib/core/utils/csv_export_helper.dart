// lib/core/utils/csv_export_helper.dart
//
// ================================================
// CSV EXPORT HELPER — public entry point
//
// This file no longer contains dart:html directly. Instead it
// conditionally exports one of two real implementations:
//   - csv_export_helper_web.dart   (real browser download, dart:html)
//   - csv_export_helper_stub.dart  (no-op, used on Android/iOS)
//
// The Dart compiler picks the correct one automatically based on
// the target platform at COMPILE time — this is what actually fixes
// the mobile build, since dart:html simply doesn't exist as a
// library outside of web and a runtime kIsWeb check can't prevent
// the compiler from needing to resolve an unconditional import.
//
// Every existing call site (CsvExportHelper.exportToCsv(...)) keeps
// working unchanged — same class name, same method signature.
// ================================================

export 'csv_export_helper_stub.dart'
    if (dart.library.html) 'csv_export_helper_web.dart';