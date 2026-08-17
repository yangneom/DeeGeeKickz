// lib/core/utils/excel_export_helper.dart
//
// Public entry point — see csv_export_helper.dart for the full
// explanation of why this pattern is needed. Same idea here.

export 'excel_export_helper_stub.dart'
    if (dart.library.html) 'excel_export_helper_web.dart';