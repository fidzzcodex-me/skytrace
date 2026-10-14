import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_info.dart';
import '../models/request.dart';
import '../models/traffic.dart';
import '../services/api_channel.dart';
import '../services/traffic_repository.dart';
import 'core_provider.dart';

class TrafficState {
  const TrafficState({
    this.items = const [],
    this.filter = const TrafficFilter(),
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = true,
    this.held = 0,
    this.error,
  });

  final List<TrafficSummary> items;
  final TrafficFilter filter;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int held;
  final String? error;

  TrafficState copyWith({
    List<TrafficSummary>? items,
    TrafficFilter? filter,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? held,
    Object? error = _keep,
  }) {
    return TrafficState(
      items: items ?? this.items,
      filter: filter ?? this.filter,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      held: held ?? this.held,
      error: identical(error, _keep) ? this.error : error as String?,
    );
  }

  static const Object _keep = Object();
}

class TrafficController extends StateNotifier<TrafficState> {
  TrafficController(this._repo, this._api) : super(const TrafficState()) {
    _sub = _api.events.listen(_onEvent);
    load();
  }

  static const int pageSize = 60;

  final TrafficRepository _repo;
  final ApiChannel _api;
  StreamSubscription<AppEvent>? _sub;
  Timer? _flush;
  final Map<int, TrafficSummary> _incoming = {};
  int _generation = 0;
  bool _frozen = false;
  final Set<int> _heldIds = {};

  void setFrozen(bool value) {
    if (_frozen == value) return;
    _frozen = value;
    if (!value && _heldIds.isNotEmpty) {
      _heldIds.clear();
      state = state.copyWith(held: 0);
      load();
    }
  }

  Future<void> deleteItem(int id) async {
    state = state.copyWith(items: state.items.where((e) => e.id != id).toList());
    await _repo.delete([id]);
  }

  Future<void> deleteFiltered() async {
    await _repo.deleteFiltered(state.filter);
    await load();
  }

  void _onEvent(AppEvent event) {
    if (event.type == 'traffic_deleted') {
      final ids = event.data['ids'];
      if (ids is List) {
        final gone = ids.map((e) => (e as num).toInt()).toSet();
        state = state.copyWith(items: state.items.where((e) => !gone.contains(e.id)).toList());
      } else {
        load();
      }
      return;
    }
    if (event.type == 'traffic_new' || event.type == 'traffic_update') {
      final summary = TrafficSummary.fromJson(event.data);
      _incoming[summary.id] = summary;
      _flush ??= Timer(const Duration(milliseconds: 180), _applyIncoming);
    }
  }

  void _applyIncoming() {
    _flush = null;
    if (_incoming.isEmpty) return;
    final batch = _incoming.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    _incoming.clear();
    final list = List<TrafficSummary>.from(state.items);
    for (final item in batch) {
      final index = list.indexWhere((e) => e.id == item.id);
      if (index >= 0) {
        if (item.matches(state.filter)) {
          list[index] = item;
        } else {
          list.removeAt(index);
        }
      } else if (item.matches(state.filter)) {
        if (_frozen) {
          _heldIds.add(item.id);
        } else {
          list.insert(0, item);
        }
      }
    }
    state = state.copyWith(items: list, loading: false, held: _heldIds.length);
  }

  Future<void> load() async {
    final gen = ++_generation;
    state = state.copyWith(loading: state.items.isEmpty, error: null);
    try {
      final rows = await _repo.list(state.filter, limit: pageSize, offset: 0);
      if (gen != _generation) return;
      state = state.copyWith(items: rows, loading: false, hasMore: rows.length >= pageSize, loadingMore: false);
    } on ApiException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loading: false, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.loading || !state.hasMore) return;
    final gen = _generation;
    state = state.copyWith(loadingMore: true);
    try {
      final rows = await _repo.list(state.filter, limit: pageSize, offset: state.items.length);
      if (gen != _generation) return;
      final known = state.items.map((e) => e.id).toSet();
      final fresh = rows.where((e) => !known.contains(e.id)).toList();
      state = state.copyWith(
        items: [...state.items, ...fresh],
        loadingMore: false,
        hasMore: rows.length >= pageSize,
      );
    } on ApiException {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> setFilter(TrafficFilter filter) async {
    _heldIds.clear();
    state = state.copyWith(filter: filter, items: const [], loading: true, hasMore: true, held: 0);
    await load();
  }

  Future<void> clearAll() async {
    await _repo.clear();
    _incoming.clear();
    _heldIds.clear();
    state = state.copyWith(items: const [], hasMore: false, loading: false, held: 0);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _flush?.cancel();
    super.dispose();
  }
}

final trafficProvider = StateNotifierProvider<TrafficController, TrafficState>(
  (ref) => TrafficController(ref.watch(trafficRepositoryProvider), ref.watch(apiProvider)),
);

final batteryExemptProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(trafficRepositoryProvider).batteryExempt(),
);

final batteryBannerDismissedProvider = StateProvider<bool>((ref) => false);

final facetsProvider = FutureProvider.autoDispose<Facets>(
  (ref) => ref.watch(trafficRepositoryProvider).facets(),
);

final trafficDetailProvider = FutureProvider.autoDispose.family<TrafficDetail?, int>(
  (ref, id) => ref.watch(trafficRepositoryProvider).detail(id),
);

final statsProvider = FutureProvider.autoDispose<StatsData>(
  (ref) => ref.watch(trafficRepositoryProvider).stats(),
);
