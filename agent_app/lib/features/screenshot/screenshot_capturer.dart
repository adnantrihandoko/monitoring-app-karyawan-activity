/// Screenshot Capturer — menangkap screenshot layar (FR-008).
///
/// Abstraksi platform; implementasi Linux memakai ImageMagick (`import`).
library;

import 'dart:typed_data';

/// Hasil capture screenshot.
class CapturedScreenshot {
  const CapturedScreenshot({
    required this.bytes,
    required this.capturedAt,
    this.width,
    this.height,
    this.format = 'png',
  });

  final Uint8List bytes;
  final DateTime capturedAt;
  final int? width;
  final int? height;
  final String format;

  String get mimeType => format == 'jpg' ? 'image/jpeg' : 'image/png';
}

/// Kontrak penangkap layar.
abstract class ScreenshotCapturer {
  /// Mengambil screenshot layar, atau null bila gagal/tidak didukung.
  Future<CapturedScreenshot?> capture();
}
