/// Implementasi ScreenshotCapturer Linux memakai ImageMagick.
///
/// Memanggil:
///  - `import -window root -quality 80 png:-` → bytes PNG layar penuh
///  - `identify -format "%w %h" png:-` → dimensi gambar
///
/// Membutuhkan ImageMagick terinstal. Bila gagal, mengembalikan null
/// (screenshot di-skip, dicatat di logger).
library;

import 'dart:typed_data';

import '../../core/app_logger.dart';
import '../../core/process_runner.dart';
import 'screenshot_capturer.dart';

/// Parser murni output `identify -format "%w %h"`.
class IdentifyParser {
  IdentifyParser._();

  /// Parse `1920 1080` → (width, height).
  static (int, int)? parseDimensions(String stdout) {
    final parts = stdout.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return null;
    final w = int.tryParse(parts[0]);
    final h = int.tryParse(parts[1]);
    if (w == null || h == null || w <= 0 || h <= 0) return null;
    return (w, h);
  }
}

/// Screenshot capturer Linux berbasis ImageMagick.
class LinuxScreenshotCapturer implements ScreenshotCapturer {
  LinuxScreenshotCapturer({ProcessRunner? runner, AppLogger? logger})
    : _runner = runner ?? RealProcessRunner(),
      _logger = logger ?? AppLogger();

  final ProcessRunner _runner;
  final AppLogger _logger;

  @override
  Future<CapturedScreenshot?> capture() async {
    final importResult = await _runner.run('import', [
      '-window',
      'root',
      '-quality',
      '80',
      'png:-',
    ]);
    if (!importResult.isSuccess) {
      _logger.warning('Screenshot', 'import gagal: ${importResult.stderr}');
      return null;
    }
    final bytes = importResult.stdoutBytes;
    if (bytes.isEmpty) {
      _logger.warning('Screenshot', 'import menghasilkan 0 byte');
      return null;
    }

    final (int, int)? dims = await _dimensions(bytes);
    return CapturedScreenshot(
      bytes: bytes,
      capturedAt: DateTime.now().toUtc(),
      width: dims?.$1,
      height: dims?.$2,
      format: 'png',
    );
  }

  Future<(int, int)?> _dimensions(Uint8List bytes) async {
    final r = await _runner.run('identify', ['-format', '%w %h', 'png:-']);
    if (!r.isSuccess) return null;
    return IdentifyParser.parseDimensions(r.stdout);
  }
}
