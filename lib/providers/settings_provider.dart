import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../services/traffic_repository.dart';
import '../theme/app_theme.dart';
import '../utils/strings.dart';
import 'core_provider.dart';

class SettingsState {
  const SettingsState({this.settings = const AppSettings(), this.loaded = false});

  final AppSettings settings;
  final bool loaded;
}

class SettingsController extends StateNotifier<SettingsState> {
  SettingsController(this._repo) : super(const SettingsState()) {
    load();
  }

  final TrafficRepository _repo;

  Future<void> load() async {
    try {
      final s = await _repo.settings();
      state = SettingsState(settings: s, loaded: true);
    } catch (_) {
      state = const SettingsState(loaded: true);
    }
  }

  Future<void> update(Map<String, dynamic> values) async {
    try {
      final s = await _repo.updateSettings(values);
      state = SettingsState(settings: s, loaded: true);
    } catch (_) {
      return;
    }
  }
}

final settingsProvider = StateNotifierProvider<SettingsController, SettingsState>(
  (ref) => SettingsController(ref.watch(trafficRepositoryProvider)),
);

final installedAppsProvider = FutureProvider.autoDispose.family<List<InstalledApp>, bool>(
  (ref, includeSystem) => ref.watch(trafficRepositoryProvider).installedApps(includeSystem: includeSystem),
);

final stringsProvider = Provider<Strings>(
  (ref) => Strings(ref.watch(settingsProvider.select((s) => s.settings.language))),
);

final themeModeProvider = Provider<ThemeMode>(
  (ref) => AppTheme.modeFrom(ref.watch(settingsProvider.select((s) => s.settings.theme))),
);
