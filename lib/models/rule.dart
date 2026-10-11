import 'request.dart';

enum RuleAction { redirect, modifyHeader, replaceBody, mock, delay }

enum RulePhase { request, response }

String ruleActionToWire(RuleAction a) {
  switch (a) {
    case RuleAction.redirect:
      return 'REDIRECT';
    case RuleAction.modifyHeader:
      return 'MODIFY_HEADER';
    case RuleAction.replaceBody:
      return 'REPLACE_BODY';
    case RuleAction.mock:
      return 'MOCK';
    case RuleAction.delay:
      return 'DELAY';
  }
}

RuleAction ruleActionFromWire(String v) {
  switch (v) {
    case 'REDIRECT':
      return RuleAction.redirect;
    case 'REPLACE_BODY':
      return RuleAction.replaceBody;
    case 'MOCK':
      return RuleAction.mock;
    case 'DELAY':
      return RuleAction.delay;
    default:
      return RuleAction.modifyHeader;
  }
}

class RewriteRule {
  const RewriteRule({
    this.id = 0,
    this.name = '',
    this.enabled = true,
    this.urlPattern = '*',
    this.isRegex = false,
    this.method = '*',
    this.action = RuleAction.modifyHeader,
    this.phase = RulePhase.request,
    this.redirectUrl = '',
    this.headerOp = 'set',
    this.headerName = '',
    this.headerValue = '',
    this.bodyFind = '',
    this.bodyReplace = '',
    this.bodyRegex = false,
    this.mockStatus = 200,
    this.mockBody = '',
    this.mockContentType = 'application/json',
    this.delayMs = 0,
  });

  final int id;
  final String name;
  final bool enabled;
  final String urlPattern;
  final bool isRegex;
  final String method;
  final RuleAction action;
  final RulePhase phase;
  final String redirectUrl;
  final String headerOp;
  final String headerName;
  final String headerValue;
  final String bodyFind;
  final String bodyReplace;
  final bool bodyRegex;
  final int mockStatus;
  final String mockBody;
  final String mockContentType;
  final int delayMs;

  RewriteRule copyWith({
    int? id,
    String? name,
    bool? enabled,
    String? urlPattern,
    bool? isRegex,
    String? method,
    RuleAction? action,
    RulePhase? phase,
    String? redirectUrl,
    String? headerOp,
    String? headerName,
    String? headerValue,
    String? bodyFind,
    String? bodyReplace,
    bool? bodyRegex,
    int? mockStatus,
    String? mockBody,
    String? mockContentType,
    int? delayMs,
  }) {
    return RewriteRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      urlPattern: urlPattern ?? this.urlPattern,
      isRegex: isRegex ?? this.isRegex,
      method: method ?? this.method,
      action: action ?? this.action,
      phase: phase ?? this.phase,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      headerOp: headerOp ?? this.headerOp,
      headerName: headerName ?? this.headerName,
      headerValue: headerValue ?? this.headerValue,
      bodyFind: bodyFind ?? this.bodyFind,
      bodyReplace: bodyReplace ?? this.bodyReplace,
      bodyRegex: bodyRegex ?? this.bodyRegex,
      mockStatus: mockStatus ?? this.mockStatus,
      mockBody: mockBody ?? this.mockBody,
      mockContentType: mockContentType ?? this.mockContentType,
      delayMs: delayMs ?? this.delayMs,
    );
  }

  factory RewriteRule.fromJson(Map<String, dynamic> j) => RewriteRule(
        id: ((j['id'] ?? 0) as num).toInt(),
        name: (j['name'] ?? '') as String,
        enabled: (j['enabled'] ?? true) as bool,
        urlPattern: (j['urlPattern'] ?? '*') as String,
        isRegex: (j['isRegex'] ?? false) as bool,
        method: (j['method'] ?? '*') as String,
        action: ruleActionFromWire((j['action'] ?? 'MODIFY_HEADER') as String),
        phase: (j['phase'] ?? 'REQUEST') == 'RESPONSE' ? RulePhase.response : RulePhase.request,
        redirectUrl: (j['redirectUrl'] ?? '') as String,
        headerOp: (j['headerOp'] ?? 'set') as String,
        headerName: (j['headerName'] ?? '') as String,
        headerValue: (j['headerValue'] ?? '') as String,
        bodyFind: (j['bodyFind'] ?? '') as String,
        bodyReplace: (j['bodyReplace'] ?? '') as String,
        bodyRegex: (j['bodyRegex'] ?? false) as bool,
        mockStatus: ((j['mockStatus'] ?? 200) as num).toInt(),
        mockBody: (j['mockBody'] ?? '') as String,
        mockContentType: (j['mockContentType'] ?? 'application/json') as String,
        delayMs: ((j['delayMs'] ?? 0) as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'urlPattern': urlPattern,
        'isRegex': isRegex,
        'method': method,
        'action': ruleActionToWire(action),
        'phase': phase == RulePhase.response ? 'RESPONSE' : 'REQUEST',
        'redirectUrl': redirectUrl,
        'headerOp': headerOp,
        'headerName': headerName,
        'headerValue': headerValue,
        'bodyFind': bodyFind,
        'bodyReplace': bodyReplace,
        'bodyRegex': bodyRegex,
        'mockStatus': mockStatus,
        'mockBody': mockBody,
        'mockContentType': mockContentType,
        'mockHeaders': <Map<String, dynamic>>[],
        'delayMs': delayMs,
      };
}

class BreakpointRule {
  const BreakpointRule({
    this.id = 0,
    this.name = '',
    this.enabled = true,
    this.urlPattern = '*',
    this.isRegex = false,
    this.method = '*',
    this.onRequest = true,
    this.onResponse = false,
  });

  final int id;
  final String name;
  final bool enabled;
  final String urlPattern;
  final bool isRegex;
  final String method;
  final bool onRequest;
  final bool onResponse;

  BreakpointRule copyWith({
    int? id,
    String? name,
    bool? enabled,
    String? urlPattern,
    bool? isRegex,
    String? method,
    bool? onRequest,
    bool? onResponse,
  }) {
    return BreakpointRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      urlPattern: urlPattern ?? this.urlPattern,
      isRegex: isRegex ?? this.isRegex,
      method: method ?? this.method,
      onRequest: onRequest ?? this.onRequest,
      onResponse: onResponse ?? this.onResponse,
    );
  }

  factory BreakpointRule.fromJson(Map<String, dynamic> j) => BreakpointRule(
        id: ((j['id'] ?? 0) as num).toInt(),
        name: (j['name'] ?? '') as String,
        enabled: (j['enabled'] ?? true) as bool,
        urlPattern: (j['urlPattern'] ?? '*') as String,
        isRegex: (j['isRegex'] ?? false) as bool,
        method: (j['method'] ?? '*') as String,
        onRequest: (j['onRequest'] ?? true) as bool,
        onResponse: (j['onResponse'] ?? false) as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'urlPattern': urlPattern,
        'isRegex': isRegex,
        'method': method,
        'onRequest': onRequest,
        'onResponse': onResponse,
      };
}

class PendingBreakpoint {
  const PendingBreakpoint({
    required this.id,
    required this.trafficId,
    required this.phase,
    required this.method,
    required this.url,
    required this.startLine,
    required this.status,
    required this.headers,
    required this.bodyText,
    required this.isBinary,
    required this.createdAt,
  });

  final String id;
  final int trafficId;
  final String phase;
  final String method;
  final String url;
  final String startLine;
  final int status;
  final List<HeaderPair> headers;
  final String bodyText;
  final bool isBinary;
  final int createdAt;

  bool get isRequest => phase == 'request';

  factory PendingBreakpoint.fromJson(Map<String, dynamic> j) => PendingBreakpoint(
        id: (j['id'] ?? '') as String,
        trafficId: ((j['trafficId'] ?? 0) as num).toInt(),
        phase: (j['phase'] ?? 'request') as String,
        method: (j['method'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        startLine: (j['startLine'] ?? '') as String,
        status: ((j['status'] ?? 0) as num).toInt(),
        headers: ((j['headers'] ?? const []) as List)
            .map((e) => HeaderPair.fromJson(e as Map<String, dynamic>))
            .toList(),
        bodyText: (j['bodyText'] ?? '') as String,
        isBinary: (j['isBinary'] ?? false) as bool,
        createdAt: ((j['createdAt'] ?? 0) as num).toInt(),
      );
}
