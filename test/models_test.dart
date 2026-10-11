import 'package:flutter_test/flutter_test.dart';
import 'package:skytrace/models/app_info.dart';
import 'package:skytrace/models/request.dart';
import 'package:skytrace/models/rule.dart';
import 'package:skytrace/models/traffic.dart';

TrafficSummary summary({
  int status = 200,
  String method = 'GET',
  String host = 'api.example.com',
  String path = '/v1/users',
  String app = 'com.demo',
  bool modified = false,
}) {
  return TrafficSummary.fromJson({
    'id': 1,
    'timestamp': 1700000000000,
    'method': method,
    'scheme': 'https',
    'host': host,
    'path': path,
    'statusCode': status,
    'responseSize': 10,
    'requestSize': 0,
    'contentType': 'application/json',
    'appPackage': app,
    'appName': 'Demo',
    'totalMs': 42,
    'modified': modified,
    'isWebSocket': false,
    'tunnel': false,
    'error': null,
  });
}

void main() {
  group('TrafficSummary.matches', () {
    test('empty filter matches everything', () {
      expect(summary().matches(const TrafficFilter()), isTrue);
    });

    test('status class and method filters', () {
      expect(summary(status: 404).matches(const TrafficFilter(status: '4xx')), isTrue);
      expect(summary(status: 200).matches(const TrafficFilter(status: '4xx')), isFalse);
      expect(summary(method: 'POST').matches(const TrafficFilter(method: 'post')), isTrue);
    });

    test('domain, app and search filters', () {
      expect(summary().matches(const TrafficFilter(domain: 'EXAMPLE')), isTrue);
      expect(summary().matches(const TrafficFilter(app: 'com.other')), isFalse);
      expect(summary().matches(const TrafficFilter(search: 'v1/users')), isTrue);
      expect(summary().matches(const TrafficFilter(search: 'orders')), isFalse);
    });

    test('modified only', () {
      expect(summary().matches(const TrafficFilter(onlyModified: true)), isFalse);
      expect(summary(modified: true).matches(const TrafficFilter(onlyModified: true)), isTrue);
    });
  });

  group('TrafficFilter', () {
    test('copyWith can clear a field', () {
      const filter = TrafficFilter(app: 'a', method: 'GET');
      final cleared = filter.copyWith(app: null);
      expect(cleared.app, isNull);
      expect(cleared.method, 'GET');
      expect(cleared.activeCount, 1);
    });
  });

  group('RewriteRule', () {
    test('json round trip keeps action and phase', () {
      const rule = RewriteRule(
        id: 3,
        name: 'mock users',
        action: RuleAction.mock,
        phase: RulePhase.response,
        mockStatus: 201,
        mockBody: '{}',
      );
      final decoded = RewriteRule.fromJson(rule.toJson());
      expect(decoded.action, RuleAction.mock);
      expect(decoded.phase, RulePhase.response);
      expect(decoded.mockStatus, 201);
      expect(ruleActionToWire(RuleAction.replaceBody), 'REPLACE_BODY');
    });
  });

  group('VpnStatus', () {
    test('parses state names', () {
      final status = VpnStatus.fromJson({'state': 'running', 'requests': 5, 'up': 1, 'down': 2});
      expect(status.isRunning, isTrue);
      expect(status.requests, 5);
      expect(VpnStatus.fromJson({'state': 'unknown'}).phase, VpnPhase.stopped);
    });
  });
}
