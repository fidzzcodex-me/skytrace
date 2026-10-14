import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../services/update_service.dart';
import 'core_provider.dart';
import 'settings_provider.dart';

class UpdateState {
  const UpdateState({
    this.checking = false,
    this.info,
    this.currentVersion = '',
    this.error,
    this.upToDate = false,
    this.popupPending = false,
  });

  final bool checking;
  final UpdateInfo? info;
  final String currentVersion;
  final String? error;
  final bool upToDate;
  final bool popupPending;

  UpdateState copyWith({
    bool? checking,
    UpdateInfo? info,
    String? currentVersion,
    Object? error = _keep,
    bool? upToDate,
    bool? popupPending,
  }) {
    return UpdateState(
      checking: checking ?? this.checking,
      info: info ?? this.info,
      currentVersion: currentVersion ?? this.currentVersion,
      error: identical(error, _keep) ? this.error : error as String?,
      upToDate: upToDate ?? this.upToDate,
      popupPending: popupPending ?? this.popupPending,
    );
  }

  static const Object _keep = Object();
}

class UpdateController extends StateNotifier<UpdateState> {
  UpdateController(this._ref) : super(const UpdateState());

  final Ref _ref;
  static const Duration interval = Duration(hours: 12);

  Future<void> check({bool manual = false}) async {
    if (state.checking) return;
    final settingsController = _ref.read(settingsProvider.notifier);
    final settings = _ref.read(settingsProvider).settings;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!manual && now - settings.lastUpdateCheck < interval.inMilliseconds) return;
    state = state.copyWith(checking: true, error: null, upToDate: false);
    try {
      final current = await _ref.read(trafficRepositoryProvider).appVersion();
      final latest = await const UpdateService().fetchLatest();
      await settingsController.update({'lastUpdateCheck': now});
      final newer = latest != null && UpdateService.compare(latest.version, current) > 0;
      final skipped = latest != null && latest.version == settings.skippedVersion && !manual;
      if (newer && !skipped) {
        state = state.copyWith(checking: false, info: latest, currentVersion: current, popupPending: true);
      } else {
        state = state.copyWith(checking: false, currentVersion: current, upToDate: !newer);
      }
    } catch (e) {
      state = state.copyWith(checking: false, error: '$e');
    }
  }

  void consumePopup() {
    state = state.copyWith(popupPending: false);
  }

  Future<void> skip(String version) async {
    await _ref.read(settingsProvider.notifier).update({'skippedVersion': version});
  }
}

final updateProvider = StateNotifierProvider<UpdateController, UpdateState>((ref) => UpdateController(ref));

final appVersionProvider = FutureProvider<String>(
  (ref) => ref.watch(trafficRepositoryProvider).appVersion(),
);

final bubbleSupportProvider = FutureProvider.autoDispose<BubbleSupport>(
  (ref) => ref.watch(trafficRepositoryProvider).bubbleSupport(),
);

final proxyInfoProvider = FutureProvider.autoDispose<ProxyInfo>((ref) {
  ref.watch(settingsProvider.select((s) => s.settings.proxyPort));
  ref.watch(settingsProvider.select((s) => s.settings.proxyBindAll));
  ref.watch(settingsProvider.select((s) => s.settings.proxyAuth));
  ref.watch(settingsProvider.select((s) => s.settings.captureMode));
  return ref.watch(trafficRepositoryProvider).proxyInfo();
});
