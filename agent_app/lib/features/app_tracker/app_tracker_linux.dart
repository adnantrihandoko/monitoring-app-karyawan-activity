/// Implementasi AppTracker untuk Linux X11.
///
/// Menggunakan `xprop` untuk membaca:
///  - `_NET_ACTIVE_WINDOW` (id window aktif dari root window)
///  - `_NET_WM_NAME` / `WM_NAME` (judul window)
///  - `WM_CLASS` (nama aplikasi)
///
/// Fallback ke `xdotool getactivewindow getwindowname` bila tersedia.
library;

import '../../core/process_runner.dart';
import 'app_tracker.dart';

/// Parser murni output X11 (dapat diuji).
class X11OutputParser {
  X11OutputParser._();

  /// Parse id window dari `xprop -root _NET_ACTIVE_WINDOW`.
  ///
  /// Contoh output:
  /// `_NET_ACTIVE_WINDOW(WINDOW): window id # 0x2a00007`
  static String? parseActiveWindowId(String stdout) {
    final match = RegExp(r'window id # (0x[0-9a-fA-F]+)').firstMatch(stdout);
    return match?.group(1);
  }

  /// Parse string value dari output xprop.
  ///
  /// Contoh:
  /// `_NET_WM_NAME(UTF8_STRING) = "Judul Window"`
  /// `WM_CLASS(STRING) = "firefox", "Firefox"`
  static String? parseStringValue(String stdout) {
    final eq = stdout.indexOf('=');
    if (eq == -1) return null;
    final raw = stdout.substring(eq + 1).trim();
    final match = RegExp(r'"([^"]*)"').firstMatch(raw);
    return match?.group(1);
  }

  /// Parse WM_CLASS — instance name (elemen pertama) dipakai sebagai app_name.
  static String? parseWmClassAppName(String stdout) {
    final eq = stdout.indexOf('=');
    if (eq == -1) return null;
    final raw = stdout.substring(eq + 1).trim();
    final matches = RegExp(r'"([^"]*)"').allMatches(raw).toList();
    if (matches.isEmpty) return null;
    final value = matches.first.group(1) ?? '';
    return value.isEmpty ? null : value;
  }
}

/// AppTracker berbasis X11.
class LinuxAppTracker implements AppTracker {
  LinuxAppTracker({ProcessRunner? runner})
    : _runner = runner ?? RealProcessRunner();

  final ProcessRunner _runner;

  @override
  Future<AppWindowInfo?> activeWindow() async {
    final windowId = await _activeWindowId();
    if (windowId == null) return null;

    final title = await _windowProperty(windowId, ['_NET_WM_NAME', 'WM_NAME']);
    final appName = await _windowClass(windowId);

    return AppWindowInfo(
      appName: appName ?? _fallbackAppName(title),
      windowTitle: title ?? '',
    );
  }

  Future<String?> _activeWindowId() async {
    final r = await _runner.run('xprop', ['-root', '_NET_ACTIVE_WINDOW']);
    if (!r.isSuccess) return null;
    return X11OutputParser.parseActiveWindowId(r.stdout);
  }

  Future<String?> _windowClass(String windowId) async {
    final r = await _runner.run('xprop', ['-id', windowId, 'WM_CLASS']);
    if (!r.isSuccess) return null;
    return X11OutputParser.parseWmClassAppName(r.stdout);
  }

  Future<String?> _windowProperty(String windowId, List<String> props) async {
    for (final prop in props) {
      final r = await _runner.run('xprop', ['-id', windowId, prop]);
      if (r.isSuccess) {
        final value = X11OutputParser.parseStringValue(r.stdout);
        if (value != null && value.isNotEmpty) return value;
      }
    }
    // Fallback via xdotool.
    final r2 = await _runner.run('xdotool', [
      'getactivewindow',
      'getwindowname',
    ]);
    if (r2.isSuccess && r2.stdout.trim().isNotEmpty) {
      return r2.stdout.trim();
    }
    return null;
  }

  String _fallbackAppName(String? title) {
    if (title == null || title.isEmpty) return 'unknown';
    final lower = title.toLowerCase();
    for (final known in const [
      'firefox',
      'chrome',
      'chromium',
      'code',
      'visual studio code',
      'terminal',
      'gnome-terminal',
      'slack',
      'discord',
      'spotify',
      'libreoffice',
      'files',
      'nautilus',
    ]) {
      if (lower.contains(known)) return known;
    }
    return title.split(' ').first;
  }
}
