import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/app_info.dart';
import '../utils/app_config.dart';

class UpdateService {
  const UpdateService();

  static List<int> _parts(String version) {
    var v = version.trim();
    if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
    final core = v.split('+').first.split('-').first;
    return core.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  static int compare(String a, String b) {
    final pa = _parts(a);
    final pb = _parts(b);
    final length = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < length; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    return 0;
  }

  static String normalize(String tag) {
    var v = tag.trim();
    if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
    return v;
  }

  Future<UpdateInfo?> fetchLatest() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse('https://api.github.com/repos/$kRepoSlug/releases/latest'));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('User-Agent', 'SkyTrace');
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) {
        throw HttpException('GitHub responded ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tag = (json['tag_name'] ?? '') as String;
      if (tag.isEmpty) return null;
      String? apk;
      for (final asset in (json['assets'] ?? const []) as List) {
        final map = asset as Map<String, dynamic>;
        final name = (map['name'] ?? '') as String;
        if (name.toLowerCase().endsWith('.apk')) {
          apk = map['browser_download_url'] as String?;
          break;
        }
      }
      return UpdateInfo(
        version: normalize(tag),
        notes: ((json['body'] ?? '') as String).trim(),
        pageUrl: (json['html_url'] ?? kReleasesUrl) as String,
        apkUrl: apk,
        publishedAt: (json['published_at'] ?? '') as String,
      );
    } finally {
      client.close(force: true);
    }
  }
}
