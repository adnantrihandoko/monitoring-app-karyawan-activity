/// Layanan screenshot: capture → (kompresi opsional) → upload ke backend.
///
/// Upload ke `POST /api/v1/activities/screenshot` (multipart):
///  - file: image (PNG/JPEG)
///  - captured_at: ISO timestamp
///  - width, height: opsional
library;

import '../../core/api_client.dart';
import '../../core/app_logger.dart';
import 'screenshot_capturer.dart';

/// Hasil upload screenshot.
class ScreenshotUploadResult {
  const ScreenshotUploadResult({
    required this.success,
    this.screenshotId,
    this.filePath,
    this.errorMessage,
  });

  final bool success;
  final String? screenshotId;
  final String? filePath;
  final String? errorMessage;
}

/// Layanan screenshot agent.
class ScreenshotService {
  ScreenshotService({
    required ScreenshotCapturer capturer,
    required ApiClient apiClient,
    AppLogger? logger,
  }) : _capturer = capturer,
       _api = apiClient,
       _logger = logger ?? AppLogger();

  final ScreenshotCapturer _capturer;
  final ApiClient _api;
  final AppLogger _logger;

  /// Capture sekali lalu upload. Mengembalikan hasil upload.
  Future<ScreenshotUploadResult> captureAndUpload() async {
    final shot = await _capturer.capture();
    if (shot == null) {
      return const ScreenshotUploadResult(
        success: false,
        errorMessage: 'Capture gagal',
      );
    }
    return upload(shot);
  }

  /// Upload screenshot yang sudah di-capture.
  Future<ScreenshotUploadResult> upload(CapturedScreenshot shot) async {
    try {
      final response = await _api.postMultipart(
        '/activities/screenshot',
        fields: {
          'captured_at': shot.capturedAt.toUtc().toIso8601String(),
          if (shot.width != null) 'width': '${shot.width}',
          if (shot.height != null) 'height': '${shot.height}',
        },
        fileBytes: shot.bytes,
        fileName:
            'screenshot_${shot.capturedAt.millisecondsSinceEpoch}.${shot.format}',
        contentType: shot.mimeType,
      );
      return ScreenshotUploadResult(
        success: true,
        screenshotId: response['id']?.toString(),
        filePath: response['file_path']?.toString(),
      );
    } on ApiException catch (e) {
      _logger.warning('Screenshot', 'Upload gagal: $e');
      return ScreenshotUploadResult(success: false, errorMessage: e.message);
    } catch (e) {
      _logger.warning('Screenshot', 'Upload gagal: $e');
      return ScreenshotUploadResult(success: false, errorMessage: '$e');
    }
  }
}
