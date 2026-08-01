import 'package:agent_app/core/runtime_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuntimeConfig', () {
    test('default sesuai nilai awal', () {
      final cfg = RuntimeConfig(
        screenshotIntervalSeconds: 300,
        idleThresholdSeconds: 300,
      );
      expect(cfg.screenshotIntervalSeconds, 300);
      expect(cfg.idleThresholdSeconds, 300);
      expect(cfg.configVersion, isNull);
    });

    test('applyFromHeartbeat memperbarui konfigurasi', () {
      final cfg = RuntimeConfig(
        screenshotIntervalSeconds: 300,
        idleThresholdSeconds: 300,
      );
      cfg.applyFromHeartbeat(
        screenshotIntervalSeconds: 120,
        idleThresholdSeconds: 600,
        configVersion: 3,
      );
      expect(cfg.screenshotIntervalSeconds, 120);
      expect(cfg.idleThresholdSeconds, 600);
      expect(cfg.configVersion, 3);
    });

    test('applyFromHeartbeat mengabaikan nilai <= 0', () {
      final cfg = RuntimeConfig(
        screenshotIntervalSeconds: 300,
        idleThresholdSeconds: 300,
      );
      cfg.applyFromHeartbeat(
        screenshotIntervalSeconds: 0,
        idleThresholdSeconds: -5,
      );
      expect(cfg.screenshotIntervalSeconds, 300);
      expect(cfg.idleThresholdSeconds, 300);
    });

    test('notifyListeners dipanggil saat apply', () {
      final cfg = RuntimeConfig(
        screenshotIntervalSeconds: 300,
        idleThresholdSeconds: 300,
      );
      var notified = 0;
      cfg.addListener(() => notified++);
      cfg.applyFromHeartbeat(
        screenshotIntervalSeconds: 60,
        idleThresholdSeconds: 60,
      );
      expect(notified, 1);
    });
  });
}
