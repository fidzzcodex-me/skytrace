import 'request.dart';
import 'response.dart';

class TrafficSummary {
  const TrafficSummary({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.scheme,
    required this.host,
    required this.path,
    required this.statusCode,
    required this.responseSize,
    required this.requestSize,
    required this.contentType,
    required this.appPackage,
    required this.appName,
    required this.totalMs,
    required this.modified,
    required this.isWebSocket,
    required this.tunnel,
    required this.statusMessage,
    required this.error,
  });

  final int id;
  final int timestamp;
  final String method;
  final String scheme;
  final String host;
  final String path;
  final int statusCode;
  final int responseSize;
  final int requestSize;
  final String contentType;
  final String appPackage;
  final String appName;
  final int totalMs;
  final bool modified;
  final bool isWebSocket;
  final bool tunnel;
  final String statusMessage;
  final String? error;

  bool get possiblePinning => (method == 'TLS' && error != null) || (tunnel && statusMessage == 'bypass-auto');

  bool get blocked => method == 'BLOCKED';

  bool get isPending => statusCode == 0 && error == null && !tunnel && totalMs == 0;
  bool get isFailed => error != null;

  factory TrafficSummary.fromJson(Map<String, dynamic> json) => TrafficSummary(
        id: (json['id'] as num).toInt(),
        timestamp: (json['timestamp'] as num).toInt(),
        method: (json['method'] ?? '') as String,
        scheme: (json['scheme'] ?? '') as String,
        host: (json['host'] ?? '') as String,
        path: (json['path'] ?? '') as String,
        statusCode: ((json['statusCode'] ?? 0) as num).toInt(),
        responseSize: ((json['responseSize'] ?? 0) as num).toInt(),
        requestSize: ((json['requestSize'] ?? 0) as num).toInt(),
        contentType: (json['contentType'] ?? '') as String,
        appPackage: (json['appPackage'] ?? '') as String,
        appName: (json['appName'] ?? '') as String,
        totalMs: ((json['totalMs'] ?? 0) as num).toInt(),
        modified: (json['modified'] ?? false) as bool,
        isWebSocket: (json['isWebSocket'] ?? false) as bool,
        tunnel: (json['tunnel'] ?? false) as bool,
        statusMessage: (json['statusMessage'] ?? '') as String,
        error: json['error'] as String?,
      );

  bool matches(TrafficFilter f) {
    if (f.app != null && f.app != appPackage) return false;
    if (f.method != null && f.method!.toUpperCase() != method) return false;
    if (f.domain != null && !host.toLowerCase().contains(f.domain!.toLowerCase())) return false;
    if (f.contentType != null && !contentType.toLowerCase().contains(f.contentType!.toLowerCase())) return false;
    if (f.onlyModified && !modified) return false;
    final s = f.status;
    if (s != null) {
      switch (s) {
        case '1xx':
          if (statusCode < 100 || statusCode > 199) return false;
        case '2xx':
          if (statusCode < 200 || statusCode > 299) return false;
        case '3xx':
          if (statusCode < 300 || statusCode > 399) return false;
        case '4xx':
          if (statusCode < 400 || statusCode > 499) return false;
        case '5xx':
          if (statusCode < 500) return false;
        case 'error':
          if (statusCode != 0 && error == null) return false;
        default:
          if (statusCode.toString() != s) return false;
      }
    }
    final q = f.search;
    if (q != null && q.isNotEmpty) {
      final url = '$scheme://$host$path'.toLowerCase();
      if (!url.contains(q.toLowerCase())) return false;
    }
    return true;
  }
}

class TrafficDetail {
  const TrafficDetail({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.scheme,
    required this.host,
    required this.port,
    required this.path,
    required this.url,
    required this.httpVersion,
    required this.statusCode,
    required this.statusMessage,
    required this.appPackage,
    required this.appName,
    required this.remoteIp,
    required this.error,
    required this.isWebSocket,
    required this.tunnel,
    required this.modified,
    required this.replayOf,
    required this.requestHeaders,
    required this.responseHeaders,
    required this.request,
    required this.response,
    required this.timings,
    required this.raw,
  });

  final int id;
  final int timestamp;
  final String method;
  final String scheme;
  final String host;
  final int port;
  final String path;
  final String url;
  final String httpVersion;
  final int statusCode;
  final String statusMessage;
  final String appPackage;
  final String appName;
  final String remoteIp;
  final String? error;
  final bool isWebSocket;
  final bool tunnel;
  final bool modified;
  final int replayOf;
  final List<HeaderPair> requestHeaders;
  final List<HeaderPair> responseHeaders;
  final BodyView request;
  final BodyView response;
  final Timings timings;
  final String raw;

  bool get possiblePinning => (method == 'TLS' && error != null) || (tunnel && statusMessage == 'bypass-auto');

  static List<HeaderPair> _headers(dynamic value) =>
      ((value ?? const []) as List).map((e) => HeaderPair.fromJson(e as Map<String, dynamic>)).toList();

  factory TrafficDetail.fromJson(Map<String, dynamic> json) => TrafficDetail(
        id: (json['id'] as num).toInt(),
        timestamp: (json['timestamp'] as num).toInt(),
        method: (json['method'] ?? '') as String,
        scheme: (json['scheme'] ?? '') as String,
        host: (json['host'] ?? '') as String,
        port: ((json['port'] ?? 0) as num).toInt(),
        path: (json['path'] ?? '') as String,
        url: (json['url'] ?? '') as String,
        httpVersion: (json['httpVersion'] ?? '') as String,
        statusCode: ((json['statusCode'] ?? 0) as num).toInt(),
        statusMessage: (json['statusMessage'] ?? '') as String,
        appPackage: (json['appPackage'] ?? '') as String,
        appName: (json['appName'] ?? '') as String,
        remoteIp: (json['remoteIp'] ?? '') as String,
        error: json['error'] as String?,
        isWebSocket: (json['isWebSocket'] ?? false) as bool,
        tunnel: (json['tunnel'] ?? false) as bool,
        modified: (json['modified'] ?? false) as bool,
        replayOf: ((json['replayOf'] ?? 0) as num).toInt(),
        requestHeaders: _headers(json['requestHeaders']),
        responseHeaders: _headers(json['responseHeaders']),
        request: BodyView.fromJson(json['request'] as Map<String, dynamic>),
        response: BodyView.fromJson(json['response'] as Map<String, dynamic>),
        timings: Timings.fromJson(json['timings'] as Map<String, dynamic>),
        raw: (json['raw'] ?? '') as String,
      );
}
