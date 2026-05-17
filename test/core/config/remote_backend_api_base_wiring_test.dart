import 'package:flutter_test/flutter_test.dart';
import 'package:nimon/core/config/nimon_api_config.dart';
import 'package:nimon/features/create/data/remote_backend_config.dart';

void main() {
  test('RemoteBackendConfig.apiBaseUrl delegates to NimonApiConfig', () {
    expect(RemoteBackendConfig.apiBaseUrl, NimonApiConfig.apiBaseUrl);
  });

  test('RemoteBackendConfig.publicWebBaseUrl delegates to NimonApiConfig', () {
    expect(
      RemoteBackendConfig.publicWebBaseUrl,
      NimonApiConfig.publicWebBaseUrl,
    );
  });
}
