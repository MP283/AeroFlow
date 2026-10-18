export 'web_export_stub.dart' if (dart.library.js_interop) 'web_export_web.dart';

/// Builds RFC 4180 CSV: fields containing a comma, quote or line break are quoted, with quotes doubled.
String toCsv(List<List<Object?>> rows) => rows.map((row) => row.map((v) { final s = v?.toString() ?? ''; return RegExp(r'[",\r\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s; }).join(',')).join('\r\n');
