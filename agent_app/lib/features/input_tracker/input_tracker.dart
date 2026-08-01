/// Input Tracker — mencatat mouse & keyboard (FR-007).
///
/// Abstraksi platform; implementasi Linux memakai X11 (`xinput`, `xdotool`).
library;

/// Ringkasan input dalam satu periode.
class InputSummary {
  const InputSummary({
    required this.mouseClicks,
    required this.keyPresses,
    required this.mouseDistance,
    required this.startedAt,
    required this.endedAt,
  });

  final int mouseClicks;
  final int keyPresses;
  final double mouseDistance;
  final DateTime startedAt;
  final DateTime endedAt;

  bool get hasActivity =>
      mouseClicks > 0 || keyPresses > 0 || mouseDistance > 0;

  /// Durasi periode dalam detik.
  double get durationSeconds =>
      endedAt.difference(startedAt).inMilliseconds / 1000.0;

  Map<String, dynamic> toMetadata() => {
    'mouse_clicks': mouseClicks,
    'keys_pressed': keyPresses,
    'mouse_distance_px': mouseDistance,
    'active': hasActivity,
  };
}

/// Kontrak tracker input.
abstract class InputTracker {
  /// Snapshot kumulatif input sejak tracker mulai.
  Future<InputCounters> snapshot();
}

/// Counter kumulatif input.
class InputCounters {
  const InputCounters({
    required this.mouseClicks,
    required this.keyPresses,
    required this.mouseDistance,
  });

  final int mouseClicks;
  final int keyPresses;
  final double mouseDistance;

  const InputCounters.zero()
    : mouseClicks = 0,
      keyPresses = 0,
      mouseDistance = 0;
}
