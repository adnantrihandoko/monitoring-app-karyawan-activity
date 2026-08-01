/// Implementasi IdleDetector untuk Linux — memakai `xprintidle`.
///
/// Bila `xprintidle` tidak tersedia/gagal, mengembalikan 0 (dianggap aktif)
/// dan dicatat lewat logger (graceful degradation).
library;

import '../../core/app_logger.dart';
import '../../core/process_runner.dart';
import 'idle_detector.dart';

/// Parser murni output `xprintidle` (angka ms, contoh: `12345`).
class XPrintIdleParser {
  XPrintIdleParser._();

  static int? parseMilliseconds(String stdout) {
    final trimmed = stdout.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }
}

/// Detector idle Linux berbasis `xprintidle`.
class LinuxIdleDetector implements IdleDetector {
  LinuxIdleDetector({ProcessRunner? runner, AppLogger? logger})
    : _runner = runner ?? RealProcessRunner(),
      _logger = logger ?? AppLogger();

  final ProcessRunner _runner;
  final AppLogger _logger;

  @override
  Future<int> idleMilliseconds() async {
    final r = await _runner.run('xprintidle', const []);
    if (!r.isSuccess) {
      _logger.debug('IdleDetector', 'xprintidle gagal, anggap aktif');
      return 0;
    }
    final ms = XPrintIdleParser.parseMilliseconds(r.stdout);
    if (ms == null) return 0;
    return ms < 0 ? 0 : ms;
  }
}
