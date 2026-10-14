import '../models/request.dart';
import '../models/traffic.dart';

class Snippets {
  const Snippets._();

  static const Set<String> _skip = {
    'host',
    'content-length',
    'connection',
    'accept-encoding',
    'transfer-encoding',
    'proxy-connection',
    'keep-alive',
  };

  static List<HeaderPair> _headers(TrafficDetail d) =>
      d.requestHeaders.where((h) => !_skip.contains(h.name.toLowerCase())).toList();

  static bool _hasBody(TrafficDetail d) {
    final m = d.method.toUpperCase();
    return d.request.text.isNotEmpty && m != 'GET' && m != 'HEAD';
  }

  static String _quote(String s, {bool dollar = false}) {
    final sb = StringBuffer('"');
    for (final unit in s.runes) {
      switch (unit) {
        case 0x5C:
          sb.write('\\\\');
        case 0x22:
          sb.write('\\"');
        case 0x0A:
          sb.write('\\n');
        case 0x0D:
          sb.write('\\r');
        case 0x09:
          sb.write('\\t');
        case 0x24:
          sb.write(dollar ? '\\\$' : '\$');
        default:
          sb.writeCharCode(unit);
      }
    }
    sb.write('"');
    return sb.toString();
  }

  static String _shellQuote(String s) => "'${s.replaceAll("'", "'\\''")}'";

  static String python(TrafficDetail d) {
    final sb = StringBuffer('import requests\n\nresponse = requests.request(\n');
    sb.writeln('    ${_quote(d.method.toUpperCase())},');
    sb.writeln('    ${_quote(d.url)},');
    final headers = _headers(d);
    if (headers.isNotEmpty) {
      sb.writeln('    headers={');
      for (final h in headers) {
        sb.writeln('        ${_quote(h.name)}: ${_quote(h.value)},');
      }
      sb.writeln('    },');
    }
    if (_hasBody(d)) sb.writeln('    data=${_quote(d.request.text)},');
    sb.writeln(')');
    sb.writeln('print(response.status_code)');
    sb.writeln('print(response.text)');
    return sb.toString();
  }

  static String fetch(TrafficDetail d) {
    final sb = StringBuffer('const response = await fetch(${_quote(d.url)}, {\n');
    sb.writeln('  method: ${_quote(d.method.toUpperCase())},');
    final headers = _headers(d);
    if (headers.isNotEmpty) {
      sb.writeln('  headers: {');
      for (final h in headers) {
        sb.writeln('    ${_quote(h.name)}: ${_quote(h.value)},');
      }
      sb.writeln('  },');
    }
    if (_hasBody(d)) sb.writeln('  body: ${_quote(d.request.text)},');
    sb.writeln('});');
    sb.writeln('console.log(response.status);');
    sb.writeln('console.log(await response.text());');
    return sb.toString();
  }

  static String okhttp(TrafficDetail d) {
    final sb = StringBuffer('val client = OkHttpClient()\n');
    sb.writeln('val request = Request.Builder()');
    sb.writeln('    .url(${_quote(d.url, dollar: true)})');
    if (_hasBody(d)) {
      final type = d.request.contentType.isEmpty ? 'text/plain' : d.request.contentType;
      sb.writeln(
        '    .method(${_quote(d.method.toUpperCase())}, ${_quote(d.request.text, dollar: true)}.toRequestBody(${_quote(type, dollar: true)}.toMediaType()))',
      );
    } else {
      final m = d.method.toUpperCase();
      final needsBody = m == 'POST' || m == 'PUT' || m == 'PATCH';
      sb.writeln(
        needsBody
            ? '    .method(${_quote(m)}, "".toRequestBody())'
            : '    .method(${_quote(m)}, null)',
      );
    }
    for (final h in _headers(d)) {
      sb.writeln('    .addHeader(${_quote(h.name, dollar: true)}, ${_quote(h.value, dollar: true)})');
    }
    sb.writeln('    .build()');
    sb.writeln('client.newCall(request).execute().use { println(it.code) }');
    return sb.toString();
  }

  static String httpie(TrafficDetail d) {
    final sb = StringBuffer('http ${d.method.toUpperCase()} ${_shellQuote(d.url)}');
    for (final h in _headers(d)) {
      sb.write(' ${_shellQuote('${h.name}:${h.value}')}');
    }
    if (_hasBody(d)) sb.write(' --raw ${_shellQuote(d.request.text)}');
    sb.writeln();
    return sb.toString();
  }
}
