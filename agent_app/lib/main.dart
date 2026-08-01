/// Entry point agent Flutter Desktop.
///
/// Inisialisasi window_manager (close → tray), merakit komponen agent,
/// dan menjalankan aplikasi.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'features/agent/agent_composer.dart';
import 'features/agent/agent_controller.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Konfigurasi window desktop (close → sembunyi ke tray).
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(560, 760),
    center: true,
    title: 'Monitoring Karyawan Agent',
    minimumSize: Size(420, 560),
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  await windowManager.setPreventClose(true);
  WindowManager.instance.addListener(_AgentWindowListener());

  // Wire handler tray → window/exit.
  windowShowHandler = () => windowManager.show();
  appExitHandler = () async {
    await windowManager.destroy();
    exit(0);
  };

  // Rakit komponen agent.
  final components = await AgentComposer.compose();

  runApp(AgentApp(components: components));
}

/// Listener window: saat user menutup window → sembunyikan (tetap di tray).
class _AgentWindowListener extends WindowListener {
  @override
  void onWindowClose() async {
    await windowManager.hide();
  }
}
