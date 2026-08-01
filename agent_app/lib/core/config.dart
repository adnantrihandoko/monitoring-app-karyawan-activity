/// Konfigurasi aplikasi agent.
///
/// Nilai default bisa di-override saat build/run via `--dart-define`:
///   flutter run -d linux --dart-define=AGENT_API_BASE_URL=http://localhost:8000
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// Konfigurasi statis agent. Dibuat sekali saat aplikasi start.
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    this.heartbeatIntervalSeconds = 30,
    this.appPollIntervalSeconds = 5,
    this.idleCheckIntervalSeconds = 5,
    this.inputSummaryIntervalSeconds = 60,
    this.batchSyncIntervalSeconds = 30,
    this.batchSize = 50,
    this.defaultScreenshotIntervalSeconds = 300,
    this.defaultIdleThresholdSeconds = 300,
    this.screenshotEnabled = true,
    this.inputTrackingEnabled = true,
  });

  /// Base URL backend FastAPI, contoh: `http://localhost:8000/api/v1`.
  final String apiBaseUrl;

  /// Interval heartbeat ke server (detik).
  final int heartbeatIntervalSeconds;

  /// Interval polling foreground window / app tracker (detik).
  final int appPollIntervalSeconds;

  /// Interval pengecekan idle (detik).
  final int idleCheckIntervalSeconds;

  /// Interval merangkum input (detik) sebelum dimasukkan ke buffer.
  final int inputSummaryIntervalSeconds;

  /// Interval mencoba sinkronisasi batch ke server (detik).
  final int batchSyncIntervalSeconds;

  /// Jumlah maksimum item per batch yang dikirim (server max 1000).
  final int batchSize;

  /// Interval screenshot default (detik), dipakai sebelum config server diterima.
  final int defaultScreenshotIntervalSeconds;

  /// Ambang idle default (detik), dipakai sebelum config server diterima.
  final int defaultIdleThresholdSeconds;

  /// Mengaktifkan/mematikan screenshot.
  final bool screenshotEnabled;

  /// Mengaktifkan/mematikan tracking input.
  final bool inputTrackingEnabled;

  /// Membaca konfigurasi dari `--dart-define`.
  factory AppConfig.fromEnvironment() {
    const base = String.fromEnvironment(
      'AGENT_API_BASE_URL',
      defaultValue: 'http://localhost:8000/api/v1',
    );
    const screenshot = String.fromEnvironment(
      'AGENT_SCREENSHOT_ENABLED',
      defaultValue: 'true',
    );
    const input = String.fromEnvironment(
      'AGENT_INPUT_ENABLED',
      defaultValue: 'true',
    );

    return AppConfig(
      apiBaseUrl: base,
      screenshotEnabled: screenshot.toLowerCase() != 'false',
      inputTrackingEnabled: input.toLowerCase() != 'false',
    );
  }

  /// Mendeteksi apakah platform desktop Linux (untuk fitur native tracking).
  static bool isLinux() => !kIsWeb && Platform.isLinux;
}
