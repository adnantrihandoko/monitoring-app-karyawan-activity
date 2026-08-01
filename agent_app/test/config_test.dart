import 'package:agent_app/core/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('default API base URL mengarah ke backend lokal', () {
      const config = AppConfig(apiBaseUrl: 'http://localhost:8000/api/v1');
      expect(config.apiBaseUrl, 'http://localhost:8000/api/v1');
      expect(config.batchSize, 50);
      expect(config.heartbeatIntervalSeconds, 30);
      expect(config.defaultScreenshotIntervalSeconds, 300);
      expect(config.defaultIdleThresholdSeconds, 300);
    });

    test('toggle fitur', () {
      const config = AppConfig(
        apiBaseUrl: 'http://localhost:8000/api/v1',
        screenshotEnabled: false,
        inputTrackingEnabled: false,
      );
      expect(config.screenshotEnabled, isFalse);
      expect(config.inputTrackingEnabled, isFalse);
    });

    test('dart-define parsing dari environment dihasilkan saat runtime', () {
      final config = AppConfig.fromEnvironment();
      expect(config.apiBaseUrl, isNotEmpty);
    });
  });
}
