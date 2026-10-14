class AppFacet {
  const AppFacet({required this.appPackage, required this.appName, required this.requests});

  final String appPackage;
  final String appName;
  final int requests;

  factory AppFacet.fromJson(Map<String, dynamic> j) => AppFacet(
        appPackage: (j['appPackage'] ?? '') as String,
        appName: (j['appName'] ?? '') as String,
        requests: ((j['requests'] ?? 0) as num).toInt(),
      );
}

class HostFacet {
  const HostFacet({required this.host, required this.requests});

  final String host;
  final int requests;

  factory HostFacet.fromJson(Map<String, dynamic> j) => HostFacet(
        host: (j['host'] ?? '') as String,
        requests: ((j['requests'] ?? 0) as num).toInt(),
      );
}

class Facets {
  const Facets({this.apps = const [], this.hosts = const []});

  final List<AppFacet> apps;
  final List<HostFacet> hosts;

  factory Facets.fromJson(Map<String, dynamic> j) => Facets(
        apps: ((j['apps'] ?? const []) as List).map((e) => AppFacet.fromJson(e as Map<String, dynamic>)).toList(),
        hosts: ((j['hosts'] ?? const []) as List).map((e) => HostFacet.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

enum VpnPhase { stopped, starting, running, stopping, error }

class VpnStatus {
  const VpnStatus({
    this.phase = VpnPhase.stopped,
    this.mode = 'vpn',
    this.paused = false,
    this.error = '',
    this.startedAt = 0,
    this.requests = 0,
    this.up = 0,
    this.down = 0,
    this.connections = 0,
  });

  final VpnPhase phase;
  final String mode;
  final bool paused;
  final String error;
  final int startedAt;
  final int requests;
  final int up;
  final int down;
  final int connections;

  VpnStatus copyWith({bool? paused}) => VpnStatus(
        phase: phase,
        mode: mode,
        paused: paused ?? this.paused,
        error: error,
        startedAt: startedAt,
        requests: requests,
        up: up,
        down: down,
        connections: connections,
      );

  bool get isRunning => phase == VpnPhase.running;
  bool get isBusy => phase == VpnPhase.starting || phase == VpnPhase.stopping;

  factory VpnStatus.fromJson(Map<String, dynamic> j) {
    final raw = (j['state'] ?? 'stopped') as String;
    final phase = VpnPhase.values.firstWhere((p) => p.name == raw, orElse: () => VpnPhase.stopped);
    return VpnStatus(
      phase: phase,
      mode: (j['mode'] ?? 'vpn') as String,
      paused: (j['paused'] ?? false) as bool,
      error: (j['error'] ?? '') as String,
      startedAt: ((j['startedAt'] ?? 0) as num).toInt(),
      requests: ((j['requests'] ?? 0) as num).toInt(),
      up: ((j['up'] ?? 0) as num).toInt(),
      down: ((j['down'] ?? 0) as num).toInt(),
      connections: ((j['connections'] ?? 0) as num).toInt(),
    );
  }
}

class CertStatus {
  const CertStatus({
    this.generated = false,
    this.installed = false,
    this.fingerprint = '',
    this.subject = '',
    this.notAfter = 0,
  });

  final bool generated;
  final bool installed;
  final String fingerprint;
  final String subject;
  final int notAfter;

  factory CertStatus.fromMap(Map<dynamic, dynamic> m) => CertStatus(
        generated: (m['generated'] ?? false) as bool,
        installed: (m['installed'] ?? false) as bool,
        fingerprint: (m['fingerprint'] ?? '') as String,
        subject: (m['subject'] ?? '') as String,
        notAfter: ((m['notAfter'] ?? 0) as num).toInt(),
      );
}

class InstalledApp {
  const InstalledApp({required this.package, required this.label, required this.system});

  final String package;
  final String label;
  final bool system;

  factory InstalledApp.fromJson(Map<String, dynamic> j) => InstalledApp(
        package: (j['package'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        system: (j['system'] ?? false) as bool,
      );
}

class AppSettings {
  const AppSettings({
    this.targetApps = const [],
    this.bubbleEnabled = false,
    this.monitorPort = 8080,
    this.monitorStopWithCapture = true,
    this.monitorPinSet = false,
    this.captureMode = 'vpn',
    this.proxyPort = 8888,
    this.proxyAuth = '',
    this.proxyBindAll = false,
    this.bypassHosts = '',
    this.skippedVersion = '',
    this.lastUpdateCheck = 0,
    this.dns = '8.8.8.8',
    this.connectTimeoutMs = 15000,
    this.readTimeoutMs = 30000,
    this.maxBodyKb = 2048,
    this.maxEntries = 5000,
    this.blockQuic = true,
    this.tlsInterception = true,
    this.normalizeEncoding = true,
    this.ignoreUpstreamCertErrors = false,
    this.breakpointTimeoutSec = 120,
    this.clearOnStart = false,
    this.theme = 'system',
    this.language = 'id',
    this.onboardingDone = false,
  });

  final List<String> targetApps;
  final bool bubbleEnabled;
  final int monitorPort;
  final bool monitorStopWithCapture;
  final bool monitorPinSet;
  final String captureMode;
  final int proxyPort;
  final String proxyAuth;
  final bool proxyBindAll;
  final String bypassHosts;
  final String skippedVersion;
  final int lastUpdateCheck;
  final String dns;
  final int connectTimeoutMs;
  final int readTimeoutMs;
  final int maxBodyKb;
  final int maxEntries;
  final bool blockQuic;
  final bool tlsInterception;
  final bool normalizeEncoding;
  final bool ignoreUpstreamCertErrors;
  final int breakpointTimeoutSec;
  final bool clearOnStart;
  final String theme;
  final String language;
  final bool onboardingDone;

  factory AppSettings.fromMap(Map<dynamic, dynamic> m) => AppSettings(
        targetApps: ((m['targetApps'] ?? const []) as List).map((e) => e.toString()).toList(),
        monitorPort: ((m['monitorPort'] ?? 8080) as num).toInt(),
        monitorStopWithCapture: (m['monitorStopWithCapture'] ?? true) as bool,
        monitorPinSet: (m['monitorPinSet'] ?? false) as bool,
        bubbleEnabled: (m['bubbleEnabled'] ?? false) as bool,
        captureMode: (m['captureMode'] ?? 'vpn') as String,
        proxyPort: ((m['proxyPort'] ?? 8888) as num).toInt(),
        proxyAuth: (m['proxyAuth'] ?? '') as String,
        proxyBindAll: (m['proxyBindAll'] ?? false) as bool,
        bypassHosts: (m['bypassHosts'] ?? '') as String,
        skippedVersion: (m['skippedVersion'] ?? '') as String,
        lastUpdateCheck: ((m['lastUpdateCheck'] ?? 0) as num).toInt(),
        dns: (m['dns'] ?? '8.8.8.8') as String,
        connectTimeoutMs: ((m['connectTimeoutMs'] ?? 15000) as num).toInt(),
        readTimeoutMs: ((m['readTimeoutMs'] ?? 30000) as num).toInt(),
        maxBodyKb: ((m['maxBodyKb'] ?? 2048) as num).toInt(),
        maxEntries: ((m['maxEntries'] ?? 5000) as num).toInt(),
        blockQuic: (m['blockQuic'] ?? true) as bool,
        tlsInterception: (m['tlsInterception'] ?? true) as bool,
        normalizeEncoding: (m['normalizeEncoding'] ?? true) as bool,
        ignoreUpstreamCertErrors: (m['ignoreUpstreamCertErrors'] ?? false) as bool,
        breakpointTimeoutSec: ((m['breakpointTimeoutSec'] ?? 120) as num).toInt(),
        clearOnStart: (m['clearOnStart'] ?? false) as bool,
        theme: (m['theme'] ?? 'system') as String,
        language: (m['language'] ?? 'id') as String,
        onboardingDone: (m['onboardingDone'] ?? false) as bool,
      );
}

class StatsData {
  const StatsData({
    this.requests = 0,
    this.up = 0,
    this.down = 0,
    this.avgMs = 0,
    this.perApp = const [],
    this.topDomains = const [],
    this.timeBuckets = const [0, 0, 0, 0, 0],
    this.statusBuckets = const [0, 0, 0, 0, 0, 0],
    this.series = const [],
  });

  final int requests;
  final int up;
  final int down;
  final double avgMs;
  final List<AppStat> perApp;
  final List<DomainStat> topDomains;
  final List<int> timeBuckets;
  final List<int> statusBuckets;
  final List<SeriesPoint> series;

  factory StatsData.fromJson(Map<String, dynamic> j) => StatsData(
        requests: ((j['requests'] ?? 0) as num).toInt(),
        up: ((j['up'] ?? 0) as num).toInt(),
        down: ((j['down'] ?? 0) as num).toInt(),
        avgMs: ((j['avgMs'] ?? 0) as num).toDouble(),
        perApp: ((j['perApp'] ?? const []) as List).map((e) => AppStat.fromJson(e as Map<String, dynamic>)).toList(),
        topDomains:
            ((j['topDomains'] ?? const []) as List).map((e) => DomainStat.fromJson(e as Map<String, dynamic>)).toList(),
        timeBuckets: ((j['timeBuckets'] ?? const [0, 0, 0, 0, 0]) as List).map((e) => (e as num).toInt()).toList(),
        statusBuckets:
            ((j['statusBuckets'] ?? const [0, 0, 0, 0, 0, 0]) as List).map((e) => (e as num).toInt()).toList(),
        series: ((j['series'] ?? const []) as List).map((e) => SeriesPoint.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class AppStat {
  const AppStat({
    required this.appPackage,
    required this.appName,
    required this.requests,
    required this.up,
    required this.down,
    required this.avgMs,
  });

  final String appPackage;
  final String appName;
  final int requests;
  final int up;
  final int down;
  final double avgMs;

  factory AppStat.fromJson(Map<String, dynamic> j) => AppStat(
        appPackage: (j['appPackage'] ?? '') as String,
        appName: (j['appName'] ?? '') as String,
        requests: ((j['requests'] ?? 0) as num).toInt(),
        up: ((j['up'] ?? 0) as num).toInt(),
        down: ((j['down'] ?? 0) as num).toInt(),
        avgMs: ((j['avgMs'] ?? 0) as num).toDouble(),
      );
}

class DomainStat {
  const DomainStat({required this.host, required this.requests, required this.down, required this.avgMs});

  final String host;
  final int requests;
  final int down;
  final double avgMs;

  factory DomainStat.fromJson(Map<String, dynamic> j) => DomainStat(
        host: (j['host'] ?? '') as String,
        requests: ((j['requests'] ?? 0) as num).toInt(),
        down: ((j['down'] ?? 0) as num).toInt(),
        avgMs: ((j['avgMs'] ?? 0) as num).toDouble(),
      );
}

class SeriesPoint {
  const SeriesPoint({required this.minute, required this.count});

  final int minute;
  final int count;

  factory SeriesPoint.fromJson(Map<String, dynamic> j) => SeriesPoint(
        minute: ((j['minute'] ?? 0) as num).toInt(),
        count: ((j['count'] ?? 0) as num).toInt(),
      );
}

class ProxyInfo {
  const ProxyInfo({this.port = 8888, this.bindAll = false, this.authSet = false, this.addresses = const []});

  final int port;
  final bool bindAll;
  final bool authSet;
  final List<String> addresses;

  factory ProxyInfo.fromMap(Map<dynamic, dynamic> m) => ProxyInfo(
        port: ((m['port'] ?? 8888) as num).toInt(),
        bindAll: (m['bindAll'] ?? false) as bool,
        authSet: (m['authSet'] ?? false) as bool,
        addresses: ((m['addresses'] ?? const []) as List).map((e) => e.toString()).toList(),
      );
}

class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.apkUrl,
    required this.publishedAt,
  });

  final String version;
  final String notes;
  final String pageUrl;
  final String? apkUrl;
  final String publishedAt;
}

class DiagnosticItem {
  const DiagnosticItem({required this.id, required this.level, required this.value});

  final String id;
  final String level;
  final String value;

  factory DiagnosticItem.fromMap(Map<dynamic, dynamic> m) => DiagnosticItem(
        id: (m['id'] ?? '') as String,
        level: (m['level'] ?? 'info') as String,
        value: (m['value'] ?? '') as String,
      );
}

class MonitorStatus {
  const MonitorStatus({
    this.state = 'stopped',
    this.port = 8080,
    this.error = '',
    this.pinSet = false,
    this.sessions = 0,
    this.urls = const [],
  });

  final String state;
  final int port;
  final String error;
  final bool pinSet;
  final int sessions;
  final List<String> urls;

  bool get running => state == 'running';

  factory MonitorStatus.fromMap(Map<dynamic, dynamic> m) => MonitorStatus(
        state: (m['state'] ?? 'stopped') as String,
        port: ((m['port'] ?? 8080) as num).toInt(),
        error: (m['error'] ?? '') as String,
        pinSet: (m['pinSet'] ?? false) as bool,
        sessions: ((m['sessions'] ?? 0) as num).toInt(),
        urls: ((m['urls'] ?? const []) as List).map((e) => e.toString()).toList(),
      );
}

class BubbleSupport {
  const BubbleSupport({this.status = 'unsupported', this.reason = ''});

  final String status;
  final String reason;

  bool get supported => status == 'supported';
  bool get needsPermission => status == 'needs_permission';
  bool get unsupported => !supported && !needsPermission;

  factory BubbleSupport.fromMap(Map<dynamic, dynamic> m) => BubbleSupport(
        status: (m['status'] ?? 'unsupported') as String,
        reason: (m['reason'] ?? '') as String,
      );
}
