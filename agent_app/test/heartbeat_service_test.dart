import 'dart:convert';

import 'package:agent_app/core/api_client.dart';
import 'package:agent_app/core/runtime_config.dart';
import 'package:agent_app/core/token_storage.dart';
import 'package:agent_app/features/sync/heartbeat_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('HeartbeatService', () {
    test('send sukses mengirim payload & menerapkan remote config', () async {
      final storage = InMemoryTokenStorage();
      await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
      final config = RuntimeConfig(
        screenshotIntervalSeconds: 300,
        idleThresholdSeconds: 300,
      );

      late Map<String, dynamic> sentBody;
      final mock = MockClient((request) async {
        expect(request.url.path.endsWith('/activities/heartbeat'), isTrue);
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'screenshot_interval_seconds': 120,
            'idle_threshold_seconds': 600,
            'config_version': 2,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final api = ApiClient(
        baseUrl: 'http://localhost:8000/api/v1',
        tokenStorage: storage,
        httpClient: mock,
      );
      final service = HeartbeatService(apiClient: api, runtimeConfig: config);

      final result = await service.send(
        status: 'idle',
        activityType: 'idle',
        currentApp: 'code',
        currentWindowTitle: 'main.dart',
        idleDurationSeconds: 120.5,
      );

      expect(result.success, isTrue);
      expect(sentBody['status'], 'idle');
      expect(sentBody['current_app'], 'code');
      expect(sentBody['idle_duration_seconds'], 120.5);
      expect(config.screenshotIntervalSeconds, 120);
      expect(config.idleThresholdSeconds, 600);
      expect(config.configVersion, 2);
    });

    test(
      'send gagal → HeartbeatResult failure tanpa mengubah config',
      () async {
        final storage = InMemoryTokenStorage();
        await storage.saveTokens(accessToken: 'acc', refreshToken: 'ref');
        final config = RuntimeConfig(
          screenshotIntervalSeconds: 300,
          idleThresholdSeconds: 300,
        );

        final mock = MockClient((request) async {
          return http.Response('{"detail":"server error"}', 500);
        });

        final api = ApiClient(
          baseUrl: 'http://localhost:8000/api/v1',
          tokenStorage: storage,
          httpClient: mock,
        );
        final service = HeartbeatService(apiClient: api, runtimeConfig: config);

        final result = await service.send(
          status: 'active',
          activityType: 'active',
        );
        expect(result.success, isFalse);
        expect(result.errorMessage, isNotEmpty);
        expect(config.screenshotIntervalSeconds, 300);
      },
    );
  });
}
