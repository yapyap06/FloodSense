// Web implementation
// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:convert';

void downloadPdfWeb(List<int> bytes, String filename) {
  final base64String = base64Encode(bytes);
  final url = 'data:application/octet-stream;base64,$base64String';

  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
