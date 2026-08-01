/// App Tracker — mendeteksi aplikasi/window aktif (FR-005).
///
/// Abstraksi platform; implementasi Linux memakai X11 tools
/// (`xprop`, fallback `xdotool`).
library;

/// Informasi window/aplikasi yang sedang aktif.
class AppWindowInfo {
  const AppWindowInfo({required this.appName, required this.windowTitle});

  final String appName;
  final String windowTitle;

  bool get isEmpty => appName.isEmpty && windowTitle.isEmpty;

  @override
  String toString() => 'AppWindowInfo(app: $appName, title: $windowTitle)';
}

/// Kontrak tracker aplikasi foreground.
abstract class AppTracker {
  /// Mengambil aplikasi/window aktif saat ini, atau null bila gagal.
  Future<AppWindowInfo?> activeWindow();
}
