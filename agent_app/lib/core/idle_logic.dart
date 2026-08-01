/// Logika murni deteksi idle (dapat diuji tanpa native).
library;

/// Hasil evaluasi status idle.
class IdleEvaluation {
  const IdleEvaluation({
    required this.isIdle,
    required this.idleMilliseconds,
    required this.thresholdMilliseconds,
  });

  final bool isIdle;
  final int idleMilliseconds;
  final int thresholdMilliseconds;
}

/// Logika menentukan idle dari durasi tanpa input.
class IdleLogic {
  IdleLogic._();

  /// `true` jika idle sudah melebihi threshold.
  static bool isIdle({
    required int idleMilliseconds,
    required int thresholdMilliseconds,
  }) => idleMilliseconds >= thresholdMilliseconds;

  /// Evaluasi lengkap idle.
  static IdleEvaluation evaluate({
    required int idleMilliseconds,
    required int thresholdMilliseconds,
  }) => IdleEvaluation(
    isIdle: isIdle(
      idleMilliseconds: idleMilliseconds,
      thresholdMilliseconds: thresholdMilliseconds,
    ),
    idleMilliseconds: idleMilliseconds,
    thresholdMilliseconds: thresholdMilliseconds,
  );

  /// Menghitung durasi idle dalam detik (dibulatkan).
  static double idleDurationSeconds(int idleMilliseconds) =>
      idleMilliseconds / 1000.0;
}
