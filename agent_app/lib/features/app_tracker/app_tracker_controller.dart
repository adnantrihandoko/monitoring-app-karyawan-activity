/// Controller App Tracker — memonitor foreground window dan menghasilkan
/// event `active` ketika aplikasi berubah.
///
/// Event yang dihasilkan (`ActivityQueueItem`) dimasukkan ke buffer lokal.
library;

import 'dart:async';

import '../../core/activity_buffer.dart';
import '../../core/app_logger.dart';
import 'app_tracker.dart';

/// Sesi window yang sedang aktif.
class AppWindowSession {
  AppWindowSession({
    required this.appName,
    required this.windowTitle,
    required this.startedAt,
  });

  final String appName;
  final String windowTitle;
  final DateTime startedAt;
}

/// Menghasilkan event saat foreground window berubah.
class AppTrackerController {
  AppTrackerController({
    required AppTracker tracker,
    required ActivityBuffer buffer,
    AppLogger? logger,
  }) : _tracker = tracker,
       _buffer = buffer,
       _logger = logger ?? AppLogger();

  final AppTracker _tracker;
  final ActivityBuffer _buffer;
  final AppLogger _logger;

  AppWindowSession? _current;
  bool _isPaused = false;

  /// Sesi window yang sedang aktif (untuk UI/heartbeat).
  AppWindowSession? get current => _current;

  bool get isPaused => _isPaused;

  /// Menjeda/melanjutkan deteksi.
  void setPaused(bool paused) => _isPaused = paused;

  /// Poll foreground window sekali. Dipanggil tiap interval dari controller.
  Future<void> poll() async {
    if (_isPaused) return;

    AppWindowInfo? info;
    try {
      info = await _tracker.activeWindow();
    } catch (e) {
      _logger.warning('AppTracker', 'Gagal membaca window: $e');
      return;
    }
    if (info == null || info.isEmpty) return;

    final current = _current;
    if (current != null &&
        current.appName == info.appName &&
        current.windowTitle == info.windowTitle) {
      return; // tidak berubah
    }

    // Tutup sesi sebelumnya + catat event durasi.
    if (current != null) {
      await _recordSession(current, endTime: DateTime.now().toUtc());
    }

    _current = AppWindowSession(
      appName: info.appName,
      windowTitle: info.windowTitle,
      startedAt: DateTime.now().toUtc(),
    );
  }

  /// Menutup sesi aktif sekarang dan mencatat durasi akhir.
  /// Dipanggil saat agent berhenti / logout.
  Future<void> closeCurrentSession() async {
    final current = _current;
    if (current == null) return;
    await _recordSession(current, endTime: DateTime.now().toUtc());
    _current = null;
  }

  /// Mereset sesi tanpa mencatat (misal saat pause).
  void reset() {
    _current = null;
  }

  Future<void> _recordSession(
    AppWindowSession session, {
    required DateTime endTime,
  }) async {
    final duration =
        endTime.difference(session.startedAt).inMilliseconds / 1000.0;
    await _buffer.add(
      activityType: 'active',
      timestamp: session.startedAt,
      durationSeconds: duration > 0 ? duration : null,
      metadata: {
        'app_name': session.appName,
        'window_title': session.windowTitle,
      },
    );
  }
}
