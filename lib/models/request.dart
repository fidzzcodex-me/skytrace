class HeaderPair {
  const HeaderPair(this.name, this.value);

  final String name;
  final String value;

  factory HeaderPair.fromJson(Map<String, dynamic> json) =>
      HeaderPair((json['name'] ?? '') as String, (json['value'] ?? '') as String);

  Map<String, dynamic> toJson() => {'name': name, 'value': value};
}

class TrafficFilter {
  const TrafficFilter({
    this.app,
    this.method,
    this.status,
    this.domain,
    this.contentType,
    this.search,
    this.searchBodies = false,
    this.onlyModified = false,
  });

  final String? app;
  final String? method;
  final String? status;
  final String? domain;
  final String? contentType;
  final String? search;
  final bool searchBodies;
  final bool onlyModified;

  bool get isEmpty =>
      app == null &&
      method == null &&
      status == null &&
      domain == null &&
      contentType == null &&
      (search == null || search!.isEmpty) &&
      !onlyModified;

  int get activeCount {
    var n = 0;
    if (app != null) n++;
    if (method != null) n++;
    if (status != null) n++;
    if (domain != null) n++;
    if (contentType != null) n++;
    if (onlyModified) n++;
    return n;
  }

  TrafficFilter copyWith({
    Object? app = _keep,
    Object? method = _keep,
    Object? status = _keep,
    Object? domain = _keep,
    Object? contentType = _keep,
    Object? search = _keep,
    bool? searchBodies,
    bool? onlyModified,
  }) {
    return TrafficFilter(
      app: identical(app, _keep) ? this.app : app as String?,
      method: identical(method, _keep) ? this.method : method as String?,
      status: identical(status, _keep) ? this.status : status as String?,
      domain: identical(domain, _keep) ? this.domain : domain as String?,
      contentType: identical(contentType, _keep) ? this.contentType : contentType as String?,
      search: identical(search, _keep) ? this.search : search as String?,
      searchBodies: searchBodies ?? this.searchBodies,
      onlyModified: onlyModified ?? this.onlyModified,
    );
  }

  Map<String, dynamic> toMap() => {
        'app': app,
        'method': method,
        'status': status,
        'domain': domain,
        'contentType': contentType,
        'search': search,
        'searchBodies': searchBodies,
        'onlyModified': onlyModified,
      };

  static const Object _keep = Object();
}

class ReplayOverride {
  const ReplayOverride({this.method, this.url, this.headers, this.bodyText});

  final String? method;
  final String? url;
  final List<HeaderPair>? headers;
  final String? bodyText;

  Map<String, dynamic> toMap() => {
        'method': method,
        'url': url,
        'headers': headers?.map((h) => h.toJson()).toList(),
        'bodyText': bodyText,
      };
}
