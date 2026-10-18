import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Saves [content] as a file by clicking a temporary `download` link to a Blob URL (with a UTF-8 BOM so Excel reads ₹ correctly).
void downloadFile(String filename, String content, String mimeType) {
  final url = web.URL.createObjectURL(web.Blob(['﻿$content'.toJS].toJS, web.BlobPropertyBag(type: mimeType)));
  final link = web.HTMLAnchorElement()..href = url..download = filename; web.document.body!.append(link); link.click(); link.remove();
  Future.delayed(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}

/// Opens a standalone HTML page in a new tab (it prints itself on load), so printing isn't a snapshot of the Flutter canvas.
void openPrintable(String html) {
  final url = web.URL.createObjectURL(web.Blob([html.toJS].toJS, web.BlobPropertyBag(type: 'text/html')));
  web.window.open(url, '_blank');
  Future.delayed(const Duration(minutes: 2), () => web.URL.revokeObjectURL(url));
}
