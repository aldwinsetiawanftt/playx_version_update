import 'package:playx_network/playx_network.dart';
import 'package:playx_version_update/src/core/model/store_info.dart';
import 'package:playx_version_update/src/core/network/network_client.dart';

class RemoteStoreDataSource {
  static final RemoteStoreDataSource _instance =
      RemoteStoreDataSource._internal();

  factory RemoteStoreDataSource() {
    return _instance;
  }

  RemoteStoreDataSource._internal();

  final PlayxNetworkClient _client = NetworkClient.createClient();

  /// Minimum time between two App Store lookups for the same app.
  static const Duration appStoreThrottle = Duration(seconds: 10);

  // Throttle state for App Store lookups, keyed by packageId + country.
  // Repeated calls within [appStoreThrottle] reuse the in-flight request or
  // the last successful result instead of hitting the network again.
  final Map<String, Future<NetworkResult<StoreInfo>>> _appStoreInFlight = {};
  final Map<String, _CachedResult> _appStoreCache = {};

  Future<NetworkResult<StoreInfo>> getPlayStoreInfo({
    required String packageId,
    required String country,
    required String language,
    bool enableLog = false,
  }) {
    final url = getGooglePlayUrl(
      packageId: packageId,
      country: country,
      language: language,
    );
    return _client.get(
      url,
      fromJson: StoreInfo.fromGooglePlay,
      settings: _client.settings.copyWith(
        logSettings: PlayxNetworkLoggerSettings(
          printResponseData: false,
          enabled: enableLog,
        ),
      ),
    );
  }

  Future<NetworkResult<StoreInfo>> getAppStoreInfo({
    required String packageId,
    required String country,
    bool enableLog = false,
  }) {
    final key = '$packageId|$country';

    final inFlight = _appStoreInFlight[key];
    if (inFlight != null) return inFlight;

    final cached = _appStoreCache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < appStoreThrottle) {
      return Future.value(cached.result);
    }

    final url = getAppStoreInfoUrl(
      packageId: packageId,
      country: country,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    final request = _client
        .get(
          url,
          fromJson: StoreInfo.fromAppStore,
          settings: _client.settings.copyWith(
            logSettings: PlayxNetworkLoggerSettings(
              printResponseData: false,
              enabled: enableLog,
            ),
          ),
        )
        .then((result) {
          // Only successes are cached so a failed lookup can be retried right away.
          if (result.isSuccess) {
            _appStoreCache[key] = _CachedResult(result, DateTime.now());
          }
          return result;
        })
        .whenComplete(() => _appStoreInFlight.remove(key));

    _appStoreInFlight[key] = request;
    return request;
  }
}

class _CachedResult {
  final NetworkResult<StoreInfo> result;
  final DateTime fetchedAt;

  _CachedResult(this.result, this.fetchedAt);
}

String getGooglePlayUrl({
  required String packageId,
  required String country,
  required String language,
}) =>
    "https://play.google.com/store/apps/details?id=$packageId&hl=$language&gl=$country";

String getAppStoreInfoUrl({
  required String packageId,
  String country = 'US',
  int? timestamp,
}) =>
    "https://itunes.apple.com/lookup?id=$packageId&country=id"
    "&_t=${timestamp ?? DateTime.now().millisecondsSinceEpoch}";
