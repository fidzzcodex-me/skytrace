import 'dart:convert';

class JsonPretty {
  const JsonPretty._();

  static bool looksJson(String contentType, String text) {
    if (contentType.contains('json')) return true;
    final t = text.trimLeft();
    return t.startsWith('{') || t.startsWith('[');
  }

  static String? tryFormat(String text) {
    try {
      final decoded = jsonDecode(text);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return null;
    }
  }

  static dynamic tryDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return null;
    }
  }
}
