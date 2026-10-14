import '../models/app_info.dart';
import 'api_channel.dart';

class VpnService {
  VpnService(this._api);

  final ApiChannel _api;

  Future<bool> prepare() async => (await _api.invoke<bool>('vpnPrepare')) ?? false;

  Future<void> start() async {
    await _api.invoke<bool>('vpnStart');
  }

  Future<void> startProxy() async {
    await _api.invoke<bool>('proxyStart');
  }

  Future<void> setPaused(bool paused) async {
    await _api.invoke<bool>('setPaused', {'paused': paused});
  }

  Future<void> stop() async {
    await _api.invoke<bool>('vpnStop');
  }

  Future<VpnStatus> status() async {
    final json = await _api.invokeJsonObject('vpnStatus');
    return VpnStatus.fromJson(json);
  }

  Future<void> requestNotifications() async {
    await _api.invoke<bool>('requestNotifications');
  }
}
