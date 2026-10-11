import 'package:flutter_test/flutter_test.dart';
import 'package:skytrace/utils/format.dart';
import 'package:skytrace/utils/json_pretty.dart';

void main() {
  group('Fmt', () {
    test('bytes picks the right unit', () {
      expect(Fmt.bytes(512), '512 B');
      expect(Fmt.bytes(2048), '2.0 KB');
      expect(Fmt.bytes(5 * 1024 * 1024), '5.00 MB');
    });

    test('duration handles ms, seconds and empty', () {
      expect(Fmt.duration(0), '-');
      expect(Fmt.duration(250), '250 ms');
      expect(Fmt.duration(1500), '1.50 s');
    });

    test('shortType trims parameters and suffixes', () {
      expect(Fmt.shortType('application/json; charset=utf-8'), 'json');
      expect(Fmt.shortType('application/vnd.api+json'), 'json');
      expect(Fmt.shortType(''), '-');
    });

    test('ellipsize shortens long text', () {
      expect(Fmt.ellipsize('abcdef', 4), 'abc...');
      expect(Fmt.ellipsize('abc', 4), 'abc');
    });
  });

  group('JsonPretty', () {
    test('formats valid json and rejects invalid', () {
      expect(JsonPretty.tryFormat('{"a":1}'), '{\n  "a": 1\n}');
      expect(JsonPretty.tryFormat('not json'), isNull);
    });

    test('looksJson uses content type or leading brace', () {
      expect(JsonPretty.looksJson('application/json', 'x'), isTrue);
      expect(JsonPretty.looksJson('text/plain', '  [1,2]'), isTrue);
      expect(JsonPretty.looksJson('text/plain', 'hello'), isFalse);
    });
  });
}
