/// AgentApp — shell aplikasi: gate login ↔ home.
library;

import 'package:flutter/material.dart';

import '../features/agent/agent_composer.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Root widget agent.
class AgentApp extends StatefulWidget {
  const AgentApp({super.key, required this.components});

  final AgentComponents components;

  @override
  State<AgentApp> createState() => _AgentAppState();
}

class _AgentAppState extends State<AgentApp> {
  bool _authenticated = false;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  /// Cek token tersimpan saat start → langsung masuk bila ada.
  Future<void> _restoreSession() async {
    final auth = widget.components.authService;
    final controller = widget.components.controller;
    try {
      final hasTokens = await auth.hasStoredTokens();
      if (hasTokens) {
        final user = await auth.fetchMe();
        controller.setUser(user);
        await controller.start();
        if (mounted) setState(() => _authenticated = true);
      }
    } catch (_) {
      // Token tidak valid/expired — minta login ulang.
      await auth.logout();
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _handleLogin(String email, String password) async {
    final auth = widget.components.authService;
    final controller = widget.components.controller;
    final result = await auth.login(email, password);
    controller.setUser(result.user);
    await controller.start();
    if (mounted) setState(() => _authenticated = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoring Karyawan Agent',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_authenticated) {
      return LoginScreen(
        onLogin: _handleLogin,
        baseUrl: widget.components.config.apiBaseUrl,
      );
    }
    return HomeScreen(controller: widget.components.controller);
  }
}
