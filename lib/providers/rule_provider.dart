import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../models/rule.dart';
import '../services/api_channel.dart';
import '../services/traffic_repository.dart';
import 'core_provider.dart';

class RulesState {
  const RulesState({
    this.rules = const [],
    this.breakpoints = const [],
    this.pending = const [],
    this.loading = true,
  });

  final List<RewriteRule> rules;
  final List<BreakpointRule> breakpoints;
  final List<PendingBreakpoint> pending;
  final bool loading;

  RulesState copyWith({
    List<RewriteRule>? rules,
    List<BreakpointRule>? breakpoints,
    List<PendingBreakpoint>? pending,
    bool? loading,
  }) {
    return RulesState(
      rules: rules ?? this.rules,
      breakpoints: breakpoints ?? this.breakpoints,
      pending: pending ?? this.pending,
      loading: loading ?? this.loading,
    );
  }
}

class RulesController extends StateNotifier<RulesState> {
  RulesController(this._repo, this._api) : super(const RulesState()) {
    _sub = _api.events.listen(_onEvent);
    load();
  }

  final TrafficRepository _repo;
  final ApiChannel _api;
  StreamSubscription<AppEvent>? _sub;

  void _onEvent(AppEvent event) {
    if (event.type == 'breakpoint_hit') {
      final item = PendingBreakpoint.fromJson(event.data);
      if (state.pending.any((p) => p.id == item.id)) return;
      state = state.copyWith(pending: [...state.pending, item]);
    } else if (event.type == 'breakpoint_resolved') {
      final id = (event.data['id'] ?? '') as String;
      state = state.copyWith(pending: state.pending.where((p) => p.id != id).toList());
    } else if (event.type == 'vpn_state' && (event.data['state'] == 'stopped')) {
      state = state.copyWith(pending: const []);
    }
  }

  Future<void> load() async {
    try {
      final rules = await _repo.rules();
      final bps = await _repo.breakpoints();
      final pending = await _repo.pendingBreakpoints();
      state = RulesState(rules: rules, breakpoints: bps, pending: pending, loading: false);
    } on ApiException {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> saveRule(RewriteRule rule) async {
    await _repo.saveRule(rule);
    await load();
  }

  Future<void> deleteRule(int id) async {
    await _repo.deleteRule(id);
    await load();
  }

  Future<void> toggleRule(RewriteRule rule, bool enabled) async {
    state = state.copyWith(
      rules: state.rules.map((r) => r.id == rule.id ? r.copyWith(enabled: enabled) : r).toList(),
    );
    await _repo.toggleRule(rule.id, enabled);
  }

  Future<void> saveBreakpoint(BreakpointRule bp) async {
    await _repo.saveBreakpoint(bp);
    await load();
  }

  Future<void> deleteBreakpoint(int id) async {
    await _repo.deleteBreakpoint(id);
    await load();
  }

  Future<void> toggleBreakpoint(BreakpointRule bp, bool enabled) async {
    state = state.copyWith(
      breakpoints: state.breakpoints.map((b) => b.id == bp.id ? b.copyWith(enabled: enabled) : b).toList(),
    );
    await _repo.toggleBreakpoint(bp.id, enabled);
  }

  Future<void> resume(String id, {String? editJson}) async {
    await _repo.resumeBreakpoint(id, editJson: editJson);
    state = state.copyWith(pending: state.pending.where((p) => p.id != id).toList());
  }

  Future<void> abort(String id) async {
    await _repo.abortBreakpoint(id);
    state = state.copyWith(pending: state.pending.where((p) => p.id != id).toList());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final rulesProvider = StateNotifierProvider<RulesController, RulesState>(
  (ref) => RulesController(ref.watch(trafficRepositoryProvider), ref.watch(apiProvider)),
);

class CertState {
  const CertState({this.status = const CertStatus(), this.busy = false, this.savedTo = '', this.error});

  final CertStatus status;
  final bool busy;
  final String savedTo;
  final String? error;

  CertState copyWith({CertStatus? status, bool? busy, String? savedTo, Object? error = _keep}) {
    return CertState(
      status: status ?? this.status,
      busy: busy ?? this.busy,
      savedTo: savedTo ?? this.savedTo,
      error: identical(error, _keep) ? this.error : error as String?,
    );
  }

  static const Object _keep = Object();
}

class CertController extends StateNotifier<CertState> {
  CertController(this._repo) : super(const CertState()) {
    refresh();
  }

  final TrafficRepository _repo;

  Future<void> refresh() async {
    try {
      final status = await _repo.certStatus();
      state = state.copyWith(status: status, error: null);
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }

  Future<void> generate() => _run(() async => state = state.copyWith(status: await _repo.certEnsure()));

  Future<void> regenerate() => _run(() async => state = state.copyWith(status: await _repo.certRegenerate()));

  Future<void> install() => _run(() async {
        final where = await _repo.certInstall();
        state = state.copyWith(savedTo: where);
      });

  Future<void> share() => _run(() => _repo.certShare());

  Future<void> _run(Future<void> Function() job) async {
    state = state.copyWith(busy: true, error: null);
    try {
      await job();
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    } finally {
      state = state.copyWith(busy: false);
    }
  }
}

final certProvider = StateNotifierProvider<CertController, CertState>(
  (ref) => CertController(ref.watch(trafficRepositoryProvider)),
);
