import 'package:flutter_test/flutter_test.dart';
import 'package:skytrace/models/app_info.dart';
import 'package:skytrace/services/update_service.dart';

void main() {
  bubbleTests();

  group('UpdateService.compare', () {
    test('orders versions numerically', () {
      expect(UpdateService.compare('1.2.0', '1.1.9'), 1);
      expect(UpdateService.compare('1.0.0', '1.0.0'), 0);
      expect(UpdateService.compare('1.0.9', '1.0.10'), -1);
    });

    test('ignores v prefix, build number and missing parts', () {
      expect(UpdateService.compare('v2.0', '2.0.0+7'), 0);
      expect(UpdateService.compare('v1.1.0', '1.0.0+12'), 1);
    });

    test('normalize strips the tag prefix', () {
      expect(UpdateService.normalize('v1.4.2'), '1.4.2');
      expect(UpdateService.normalize('1.4.2'), '1.4.2');
    });
  });

  group('ProxyInfo', () {
    test('parses native map', () {
      final info = ProxyInfo.fromMap({
        'port': 9090,
        'bindAll': false,
        'authSet': true,
        'addresses': ['192.168.1.5'],
      });
      expect(info.port, 9090);
      expect(info.bindAll, isFalse);
      expect(info.authSet, isTrue);
      expect(info.addresses, ['192.168.1.5']);
    });
  });

  group('VpnStatus mode', () {
    test('defaults to vpn and reads proxy', () {
      expect(VpnStatus.fromJson({'state': 'running'}).mode, 'vpn');
      expect(VpnStatus.fromJson({'state': 'running', 'mode': 'proxy'}).mode, 'proxy');
    });
  });
}

void bubbleTests() {
  group('BubbleSupport', () {
    test('maps the three native states', () {
      expect(const BubbleSupport(status: 'supported').supported, isTrue);
      expect(const BubbleSupport(status: 'needs_permission').needsPermission, isTrue);
      expect(const BubbleSupport(status: 'unsupported', reason: 'device').unsupported, isTrue);
    });

    test('parses native map and falls back to unsupported', () {
      expect(BubbleSupport.fromMap({'status': 'supported', 'reason': ''}).supported, isTrue);
      expect(BubbleSupport.fromMap(const {}).unsupported, isTrue);
    });
  });
}
