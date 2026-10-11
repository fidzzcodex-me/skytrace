import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

class AppEvent {
  const AppEvent(this.type, this.data);

  final String type;
  final Map<String, dynamic> data;
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiChannel {
  ApiChannel();

  static const MethodChannel _method = MethodChannel('skytrace/api');
  static const EventChannel _events = EventChannel('skytrace/events');

  Stream<AppEvent>? _stream;

  Stream<AppEvent> get events {
    return _stream ??= _events.receiveBroadcastStream().map((dynamic raw) {
      final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
      final data = decoded['data'];
      return AppEvent(
        (decoded['type'] ?? '') as String,
        data is Map<String, dynamic> ? data : <String, dynamic>{},
      );
    }).asBroadcastStream();
  }

  Future<T?> invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _method.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw ApiException(e.message ?? e.code);
    } on MissingPluginException {
      throw const ApiException('Native bridge is not available');
    }
  }

  Future<Map<String, dynamic>> invokeJsonObject(String method, [Map<String, dynamic>? args]) async {
    final raw = await invoke<String>(method, args);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<dynamic>> invokeJsonList(String method, [Map<String, dynamic>? args]) async {
    final raw = await invoke<String>(method, args);
    if (raw == null || raw.isEmpty) return <dynamic>[];
    return jsonDecode(raw) as List<dynamic>;
  }
}
