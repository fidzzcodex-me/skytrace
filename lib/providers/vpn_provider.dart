import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../services/api_channel.dart';
import '../services/vpn_service.dart';
import 'core_provider.dart';
import 'settings_provider.dart';

class VpnController extends StateNotifier<VpnStatus> {
  VpnController(this._vpn, this._api, this._ref) : super(const VpnStatus()) {
    _sub = _api.events.listen(_onEvent);
    refresh();
  }

  final VpnService _vpn;
  final ApiChannel _api;
  final Ref _ref;
  StreamSubscription<AppEvent>? _sub;

  void _onEvent(AppEvent event) {
    if (event.type == 'vpn_state' || event.type == 'stats') {
      state = VpnStatus.fromJson(event.data);
    }
  }

  Future<void> refresh() async {
    try {
      state = await _vpn.status();
    } catch (_) {
      return;
    }
  }

  Future<String?> start() async {
    try {
      final mode = _ref.read(settingsProvider).settings.captureMode;
      if (mode == 'proxy') {
        await _vpn.requestNotifications();
        await _vpn.startProxy();
        return null;
      }
      final granted = await _vpn.prepare();
      if (!granted) return 'vpn_denied';
      await _vpn.requestNotifications();
      await _vpn.start();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> stop() async {
    try {
      await _vpn.stop();
    } on ApiException {
      return;
    }
  }

  Future<void> setPaused(bool paused) async {
    state = state.copyWith(paused: paused);
    try {
      await _vpn.setPaused(paused);
    } on ApiException {
      state = state.copyWith(paused: !paused);
    }
  }

  Future<String?> toggle() async {
    if (state.isBusy) return null;
    if (state.isRunning) {
      await stop();
      return null;
    }
    return start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final vpnProvider = StateNotifierProvider<VpnController, VpnStatus>(
  (ref) => VpnController(ref.watch(vpnServiceProvider), ref.watch(apiProvider), ref),
);
