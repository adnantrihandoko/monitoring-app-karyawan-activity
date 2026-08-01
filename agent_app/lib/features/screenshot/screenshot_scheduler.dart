/// Scheduler murni menentukan kapan screenshot perlu diambil
/// berdasarkan interval (default 300 detik, remote-configurable).
library;

/// Keputusan scheduler.
enum ScreenshotDecision { capture, skipTooSoon, skipIdle }

/// Menentukan kapan screenshot diambil (testable, tanpa native).
class ScreenshotScheduler {
  ScreenshotScheduler({DateTime? initialReference})
    : lastCaptureAt = initialReference;

  DateTime? lastCaptureAt;

  /// `true` jika sudah waktunya screenshot (interval terlampaui & tidak idle).
  ScreenshotDecision decide({
    required int intervalSeconds,
    required DateTime now,
    required bool isIdle,
  }) {
    if (isIdle) return ScreenshotDecision.skipIdle;
    final last = lastCaptureAt;
    if (last == null) {
      lastCaptureAt = now;
      return ScreenshotDecision.capture;
    }
    if (intervalSeconds <= 0) return ScreenshotDecision.skipTooSoon;
    final elapsed = now.difference(last).inSeconds;
    if (elapsed >= intervalSeconds) {
      lastCaptureAt = now;
      return ScreenshotDecision.capture;
    }
    return ScreenshotDecision.skipTooSoon;
  }

  /// Catat bahwa capture baru saja dilakukan.
  void markCaptured(DateTime now) => lastCaptureAt = now;
}
