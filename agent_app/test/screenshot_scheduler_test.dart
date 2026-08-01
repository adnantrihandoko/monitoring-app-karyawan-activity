import 'package:agent_app/features/screenshot/screenshot_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 1, 9, 0, 0);

  group('ScreenshotScheduler', () {
    test('capture pertama langsung diambil (referensi awal null)', () {
      final scheduler = ScreenshotScheduler();
      final decision = scheduler.decide(
        intervalSeconds: 300,
        now: now,
        isIdle: false,
      );
      expect(decision, ScreenshotDecision.capture);
    });

    test('skipIdle saat idle', () {
      final scheduler = ScreenshotScheduler(initialReference: now);
      final decision = scheduler.decide(
        intervalSeconds: 300,
        now: now.add(const Duration(seconds: 600)),
        isIdle: true,
      );
      expect(decision, ScreenshotDecision.skipIdle);
    });

    test('skipTooSoon saat interval belum terlampaui', () {
      final scheduler = ScreenshotScheduler(initialReference: now);
      final decision = scheduler.decide(
        intervalSeconds: 300,
        now: now.add(const Duration(seconds: 299)),
        isIdle: false,
      );
      expect(decision, ScreenshotDecision.skipTooSoon);
    });

    test('capture saat interval terlampaui', () {
      final scheduler = ScreenshotScheduler(initialReference: now);
      final decision = scheduler.decide(
        intervalSeconds: 300,
        now: now.add(const Duration(seconds: 300)),
        isIdle: false,
      );
      expect(decision, ScreenshotDecision.capture);
    });

    test('skipTooSoon untuk interval <= 0', () {
      final scheduler = ScreenshotScheduler(initialReference: now);
      final decision = scheduler.decide(
        intervalSeconds: 0,
        now: now.add(const Duration(seconds: 3600)),
        isIdle: false,
      );
      expect(decision, ScreenshotDecision.skipTooSoon);
    });

    test('markCaptured memperbarui referensi', () {
      final scheduler = ScreenshotScheduler();
      expect(scheduler.lastCaptureAt, isNull);
      scheduler.markCaptured(now);
      expect(scheduler.lastCaptureAt, now);
    });
  });
}
