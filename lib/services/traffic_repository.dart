import 'dart:convert';
import 'dart:typed_data';

import '../models/app_info.dart';
import '../models/request.dart';
import '../models/rule.dart';
import '../models/traffic.dart';
import 'api_channel.dart';

class TrafficRepository {
  TrafficRepository(this._api);

  final ApiChannel _api;

  Future<List<TrafficSummary>> list(TrafficFilter filter, {int limit = 60, int offset = 0}) async {
    final raw = await _api.invokeJsonList('trafficList', {
      'filter': filter.toMap(),
      'limit': limit,
      'offset': offset,
    });
    return raw.map((e) => TrafficSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<TrafficDetail?> detail(int id) async {
    final raw = await _api.invoke<String>('trafficDetail', {'id': id});
    if (raw == null) return null;
    return TrafficDetail.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clear() async {
    await _api.invoke<bool>('trafficClear');
  }

  Future<void> delete(List<int> ids) async {
    await _api.invoke<bool>('trafficDelete', {'ids': ids});
  }

  Future<int> count() async => (await _api.invoke<int>('trafficCount')) ?? 0;

  Future<Facets> facets() async => Facets.fromJson(await _api.invokeJsonObject('facets'));

  Future<StatsData> stats() async => StatsData.fromJson(await _api.invokeJsonObject('stats'));

  Future<int> replay(int id, {ReplayOverride? override}) async {
    final result = await _api.invoke<int>('replay', {'id': id, 'override': override?.toMap()});
    return result ?? 0;
  }

  Future<String?> curlFor(int id) => _api.invoke<String>('curlFor', {'id': id});

  Future<String?> export(String format, {List<int>? ids, TrafficFilter? filter}) {
    return _api.invoke<String>('export', {
      'format': format,
      'ids': ids,
      'filter': (filter ?? const TrafficFilter()).toMap(),
    });
  }

  Future<void> shareFile(String path, String mime) async {
    await _api.invoke<bool>('shareFile', {'path': path, 'mime': mime});
  }

  Future<Uint8List?> appIcon(String package) => _api.invoke<Uint8List>('appIcon', {'package': package});

  Future<int> deleteFiltered(TrafficFilter filter) async =>
      (await _api.invoke<int>('trafficDeleteFiltered', {'filter': filter.toMap()})) ?? 0;

  Future<MonitorStatus> monitorStatus() async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('monitorStatus');
    return MonitorStatus.fromMap(map ?? const {});
  }

  Future<void> monitorStart() async {
    await _api.invoke<bool>('monitorStart');
  }

  Future<void> monitorStop() async {
    await _api.invoke<bool>('monitorStop');
  }

  Future<String> monitorSetPin({String? pin}) async =>
      (await _api.invoke<String>('monitorSetPin', {'pin': pin})) ?? '';

  Future<bool> batteryExempt() async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('appInfo');
    return ((map ?? const {})['batteryExempt'] ?? true) as bool;
  }

  Future<BubbleSupport> bubbleSupport() async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('bubbleSupport');
    return BubbleSupport.fromMap(map ?? const {});
  }

  Future<void> bubbleSetEnabled(bool enabled) async {
    await _api.invoke<bool>('bubbleSetEnabled', {'enabled': enabled});
  }

  Future<void> bubbleRefresh() async {
    await _api.invoke<bool>('bubbleRefresh');
  }

  Future<String?> exportRules() => _api.invoke<String>('rulesExport');

  Future<int> importRules(String json) async => (await _api.invoke<int>('rulesImport', {'json': json})) ?? 0;

  Future<List<DiagnosticItem>> diagnostics() async {
    final raw = await _api.invoke<List<dynamic>>('diagnostics');
    return (raw ?? const []).map((e) => DiagnosticItem.fromMap(e as Map<dynamic, dynamic>)).toList();
  }

  Future<void> openSettings(String target) async {
    await _api.invoke<bool>('openSettings', {'target': target});
  }

  Future<ProxyInfo> proxyInfo() async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('proxyInfo');
    return ProxyInfo.fromMap(map ?? const {});
  }

  Future<String> appVersion() async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('appInfo');
    return ((map ?? const {})['versionName'] ?? '0.0.0') as String;
  }

  Future<bool> openUrl(String url) async => (await _api.invoke<bool>('openUrl', {'url': url})) ?? false;

  Future<List<InstalledApp>> installedApps({bool includeSystem = false}) async {
    final raw = await _api.invokeJsonList('installedApps', {'includeSystem': includeSystem});
    return raw.map((e) => InstalledApp.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<RewriteRule>> rules() async {
    final raw = await _api.invokeJsonList('ruleList');
    return raw.map((e) => RewriteRule.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveRule(RewriteRule rule) async {
    await _api.invoke<int>('ruleSave', {'json': _encode(rule.toJson())});
  }

  Future<void> deleteRule(int id) async {
    await _api.invoke<bool>('ruleDelete', {'id': id});
  }

  Future<void> toggleRule(int id, bool enabled) async {
    await _api.invoke<bool>('ruleToggle', {'id': id, 'enabled': enabled});
  }

  Future<List<BreakpointRule>> breakpoints() async {
    final raw = await _api.invokeJsonList('bpList');
    return raw.map((e) => BreakpointRule.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveBreakpoint(BreakpointRule bp) async {
    await _api.invoke<int>('bpSave', {'json': _encode(bp.toJson())});
  }

  Future<void> deleteBreakpoint(int id) async {
    await _api.invoke<bool>('bpDelete', {'id': id});
  }

  Future<void> toggleBreakpoint(int id, bool enabled) async {
    await _api.invoke<bool>('bpToggle', {'id': id, 'enabled': enabled});
  }

  Future<List<PendingBreakpoint>> pendingBreakpoints() async {
    final raw = await _api.invokeJsonList('bpPending');
    return raw.map((e) => PendingBreakpoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> resumeBreakpoint(String id, {String? editJson}) async {
    await _api.invoke<bool>('bpResume', {'id': id, 'edit': editJson});
  }

  Future<void> abortBreakpoint(String id) async {
    await _api.invoke<bool>('bpAbort', {'id': id});
  }

  Future<CertStatus> certStatus() async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('certStatus');
    return CertStatus.fromMap(map ?? const {});
  }

  Future<CertStatus> certEnsure() async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('certEnsure');
    return CertStatus.fromMap(map ?? const {});
  }

  Future<CertStatus> certRegenerate() async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('certRegenerate');
    return CertStatus.fromMap(map ?? const {});
  }

  Future<String> certInstall() async => (await _api.invoke<String>('certInstall')) ?? '';

  Future<void> certShare() async {
    await _api.invoke<bool>('certShare');
  }

  Future<String> certPem() async => (await _api.invoke<String>('certPem')) ?? '';

  Future<AppSettings> settings() async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('settingsGet');
    return AppSettings.fromMap(map ?? const {});
  }

  Future<AppSettings> updateSettings(Map<String, dynamic> values) async {
    final map = await _api.invoke<Map<dynamic, dynamic>>('settingsSet', values);
    return AppSettings.fromMap(map ?? const {});
  }

  Future<List<String>> logs() async {
    final raw = await _api.invoke<List<dynamic>>('logs');
    return (raw ?? const []).map((e) => e.toString()).toList();
  }

  String _encode(Map<String, dynamic> map) => jsonEncode(map);
}
