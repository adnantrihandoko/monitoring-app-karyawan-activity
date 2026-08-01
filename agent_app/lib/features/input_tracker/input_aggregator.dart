/// Agregator input murni — menjumlahkan klik/ketikan/gerakan mouse
/// dalam satu periode lalu menghasilkan ringkasan.
library;

import 'input_tracker.dart';

/// Mengakumulasi input dalam periode dan bisa di-flush.
class InputAggregator {
  InputAggregator({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _startedAt = _now();
  }

  final DateTime Function() _now;

  late DateTime _startedAt;
  int _mouseClicks = 0;
  int _keyPresses = 0;
  double _mouseDistance = 0;

  int get mouseClicks => _mouseClicks;
  int get keyPresses => _keyPresses;
  double get mouseDistance => _mouseDistance;

  /// Mencatat satu klik mouse.
  void recordClick() => _mouseClicks++;

  /// Mencatat satu penekanan tombol keyboard.
  void recordKeyPress() => _keyPresses++;

  /// Menambahkan jarak gerakan mouse (piksel).
  void recordDistance(double distance) {
    if (distance.isFinite && distance > 0) {
      _mouseDistance += distance;
    }
  }

  /// Mengambil ringkasan periode dan mereset counter.
  InputSummary flush() {
    final endedAt = _now();
    final summary = InputSummary(
      mouseClicks: _mouseClicks,
      keyPresses: _keyPresses,
      mouseDistance: _mouseDistance,
      startedAt: _startedAt,
      endedAt: endedAt,
    );
    _mouseClicks = 0;
    _keyPresses = 0;
    _mouseDistance = 0;
    _startedAt = endedAt;
    return summary;
  }
}
