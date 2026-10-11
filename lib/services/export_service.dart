import 'package:flutter/services.dart';

import '../models/request.dart';
import 'traffic_repository.dart';

enum ExportFormat { har, curl, raw }

class ExportService {
  ExportService(this._repo);

  final TrafficRepository _repo;

  String _mime(ExportFormat f) {
    switch (f) {
      case ExportFormat.har:
        return 'application/json';
      case ExportFormat.curl:
        return 'text/x-shellscript';
      case ExportFormat.raw:
        return 'text/plain';
    }
  }

  Future<bool> exportAndShare(ExportFormat format, {List<int>? ids, TrafficFilter? filter}) async {
    final path = await _repo.export(format.name, ids: ids, filter: filter);
    if (path == null || path.isEmpty) return false;
    await _repo.shareFile(path, _mime(format));
    return true;
  }

  Future<String?> copyCurl(int id) async {
    final curl = await _repo.curlFor(id);
    if (curl != null) await Clipboard.setData(ClipboardData(text: curl));
    return curl;
  }

  Future<void> copyText(String text) => Clipboard.setData(ClipboardData(text: text));
}
