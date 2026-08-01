/// Implementasi tray memakai package `tray_manager`.
///
/// Linux requirement: `libayatana-appindicator` (lihat README agent).
library;

import 'package:tray_manager/tray_manager.dart';

import 'tray_controller.dart';

/// Tray icon berbasis tray_manager.
class TrayManagerController extends TrayController with TrayListener {
  TrayManagerController({this.onAction});

  /// Dipanggil ketika user memilih menu tray (bisa di-set setelah init).
  void Function(TrayAction action)? onAction;

  bool _inited = false;

  @override
  Future<void> init() async {
    if (_inited) return;
    await trayManager.setIcon('assets/tray_icon.png', isTemplate: false);
    _inited = true;
  }

  @override
  Future<void> setMenu(List<TrayMenuItem> items) async {
    final menuItems = <MenuItem>[];
    for (final item in items) {
      if (item.separatorBefore) {
        menuItems.add(MenuItem.separator());
      }
      menuItems.add(MenuItem(key: item.id, label: item.label, type: 'normal'));
    }
    await trayManager.setContextMenu(Menu(items: menuItems));
  }

  @override
  Future<void> showNotification(String title, String body) =>
      trayManager.popUpContextMenu();

  @override
  Future<void> destroy() => trayManager.destroy();

  @override
  Future<void> exit() => trayManager.destroy();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    final action = _actionForId(menuItem.key);
    if (action != null) onAction?.call(action);
  }

  TrayAction? _actionForId(String? key) {
    switch (key) {
      case 'toggle_pause':
        return TrayAction.togglePause;
      case 'sync_now':
        return TrayAction.syncNow;
      case 'show_window':
        return TrayAction.showWindow;
      case 'logout':
        return TrayAction.logout;
      case 'exit':
        return TrayAction.exit;
      default:
        return null;
    }
  }
}
