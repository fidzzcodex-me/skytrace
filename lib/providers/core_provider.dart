import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_channel.dart';
import '../services/export_service.dart';
import '../services/traffic_repository.dart';
import '../services/vpn_service.dart';

final apiProvider = Provider<ApiChannel>((ref) => ApiChannel());

final vpnServiceProvider = Provider<VpnService>((ref) => VpnService(ref.watch(apiProvider)));

final trafficRepositoryProvider =
    Provider<TrafficRepository>((ref) => TrafficRepository(ref.watch(apiProvider)));

final exportServiceProvider =
    Provider<ExportService>((ref) => ExportService(ref.watch(trafficRepositoryProvider)));
