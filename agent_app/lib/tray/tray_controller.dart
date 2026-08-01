/// System tray icon & menu.
///
/// Abstraksi platform; implementasi produksi memakai `tray_manager`
/// (membutuhkan `libayatana-appindicator` di Linux). Bila tray tidak
/// tersedia, digunakan [NullTrayController] agar aplikasi tetap berjalan.
library;

/// Aksi yang dipicu dari menu tray.
enum TrayAction { togglePause, syncNow, showWindow, logout, exit }

/// Item menu tray.
class TrayMenuItem {
  const TrayMenuItem({
    required this.id,
    required this.label,
    this.action,
    this.separatorBefore = false,
  });

  final String id;
  final String label;
  final TrayAction? action;
  final bool separatorBefore;
}

/// Kontrak controller tray.
abstract class TrayController {
  /// Inisialisasi tray icon & menu.
  Future<void> init();

  /// Memperbarui menu (misal saat status berubah: Pause ↔ Resume).
  Future<void> setMenu(List<TrayMenuItem> items);

  /// Menampilkan notifikasi balon (didukung sebagian platform).
  Future<void> showNotification(String title, String body);

  /// Menghentikan & menghapus tray.
  Future<void> destroy();

  /// Menutup aplikasi penuh (tray ikut dihapus).
  Future<void> exit();
}

/// No-op tray untuk environment tanpa dukungan native tray.
class NullTrayController implements TrayController {
  @override
  Future<void> init() async {}

  @override
  Future<void> setMenu(List<TrayMenuItem> items) async {}

  @override
  Future<void> showNotification(String title, String body) async {}

  @override
  Future<void> destroy() async {}

  @override
  Future<void> exit() async {}
}
