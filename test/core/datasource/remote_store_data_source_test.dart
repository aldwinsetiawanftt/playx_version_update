import 'package:flutter_test/flutter_test.dart';
import 'package:playx_version_update/src/core/datasource/remote_store_data_source.dart';

void main() {
  group('store urls', () {
    test('builds google play url', () {
      expect(
        getGooglePlayUrl(
          packageId: 'com.example.app',
          country: 'us',
          language: 'en',
        ),
        'https://play.google.com/store/apps/details?id=com.example.app&hl=en&gl=us',
      );
    });

    test('builds app store lookup url', () {
      expect(
        getAppStoreInfoUrl(
          packageId: '123456789',
          country: 'in',
          timestamp: 1700000000000,
        ),
        'https://itunes.apple.com/lookup?id=123456789&country=id&_t=1700000000000',
      );
    });
  });
}
