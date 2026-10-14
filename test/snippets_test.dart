import 'package:flutter_test/flutter_test.dart';
import 'package:skytrace/models/traffic.dart';
import 'package:skytrace/utils/snippets.dart';

TrafficDetail detail({String method = 'POST', String body = '{"a":"b"}'}) {
  Map<String, dynamic> bodyView(String text) => {
        'size': text.length,
        'storedSize': text.length,
        'truncated': false,
        'contentType': 'application/json',
        'encoding': '',
        'isBinary': false,
        'text': text,
        'base64': '',
      };
  return TrafficDetail.fromJson({
    'id': 1,
    'timestamp': 1700000000000,
    'method': method,
    'scheme': 'https',
    'host': 'api.example.com',
    'port': 443,
    'path': '/v1/login',
    'url': 'https://api.example.com/v1/login',
    'httpVersion': 'HTTP/1.1',
    'statusCode': 200,
    'statusMessage': 'OK',
    'appPackage': 'com.demo',
    'appName': 'Demo',
    'remoteIp': '1.2.3.4',
    'error': null,
    'isWebSocket': false,
    'tunnel': false,
    'modified': false,
    'replayOf': 0,
    'requestHeaders': [
      {'name': 'Host', 'value': 'api.example.com'},
      {'name': 'Content-Type', 'value': 'application/json'},
      {'name': 'Content-Length', 'value': '9'},
    ],
    'responseHeaders': [],
    'request': bodyView(body),
    'response': bodyView(''),
    'timings': {'connect': 1, 'tls': 1, 'send': 1, 'wait': 1, 'receive': 1, 'total': 5},
    'raw': '',
  });
}

void main() {
  test('python snippet escapes quotes and drops hop headers', () {
    final out = Snippets.python(detail());
    expect(out, contains('requests.request('));
    expect(out, contains('"POST"'));
    expect(out, contains('"Content-Type": "application/json"'));
    expect(out, contains('data="{\\"a\\":\\"b\\"}"'));
    expect(out, isNot(contains('Content-Length')));
    expect(out, isNot(contains('"Host"')));
  });

  test('fetch snippet omits body for GET', () {
    final out = Snippets.fetch(detail(method: 'GET', body: ''));
    expect(out, contains('method: "GET"'));
    expect(out, isNot(contains('body:')));
  });

  test('okhttp snippet builds a request body for POST', () {
    final out = Snippets.okhttp(detail());
    expect(out, contains('toRequestBody("application/json".toMediaType())'));
    expect(out, contains('.addHeader("Content-Type", "application/json")'));
  });

  test('httpie snippet shell quotes the body', () {
    final out = Snippets.httpie(detail());
    expect(out, startsWith("http POST 'https://api.example.com/v1/login'"));
    expect(out, contains("--raw '{\"a\":\"b\"}'"));
  });
}
