/// Idle Detector — mendeteksi tidak ada input dari user (FR-009).
library;

/// Kontrak pembaca durasi idle (ms).
abstract class IdleDetector {
  /// Durasi tanpa input dalam milidetik.
  Future<int> idleMilliseconds();
}

/// Detector idle yang mengembalikan nilai tetap (untuk test / fallback).
class StaticIdleDetector implements IdleDetector {
  StaticIdleDetector(this.milliseconds, {this.onRead});

  int milliseconds;
  final Future<int> Function(int current)? onRead;

  @override
  Future<int> idleMilliseconds() async {
    if (onRead != null) milliseconds = await onRead!(milliseconds);
    return milliseconds;
  }
}
