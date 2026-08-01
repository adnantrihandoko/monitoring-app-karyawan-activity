/// Konfigurasi runtime yang bisa berubah dari response heartbeat server.
///
/// Server mengirim `screenshot_interval_seconds` & `idle_threshold_seconds`
/// pada setiap heartbeat; agent menerapkannya langsung (remote config).
library;

import 'package:flutter/foundation.dart';

/// Config mutable yang di-update dari server.
class RuntimeConfig extends ChangeNotifier {
  RuntimeConfig({
    required this.screenshotIntervalSeconds,
    required this.idleThresholdSeconds,
    this.configVersion,
  });

  int screenshotIntervalSeconds;
  int idleThresholdSeconds;
  int? configVersion;

  /// Menerapkan konfigurasi dari response heartbeat.
  void applyFromHeartbeat({
    required int screenshotIntervalSeconds,
    required int idleThresholdSeconds,
    int? configVersion,
  }) {
    if (screenshotIntervalSeconds > 0) {
      this.screenshotIntervalSeconds = screenshotIntervalSeconds;
    }
    if (idleThresholdSeconds > 0) {
      this.idleThresholdSeconds = idleThresholdSeconds;
    }
    this.configVersion = configVersion;
    notifyListeners();
  }

  @override
  String toString() =>
      'RuntimeConfig(screenshot=${screenshotIntervalSeconds}s, '
      'idle=${idleThresholdSeconds}s, version=$configVersion)';
}
