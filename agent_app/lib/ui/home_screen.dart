/// HomeScreen — dashboard status agent: status, config server, buffer,
/// kontrol pause/resume/sync/logout.
library;

import 'package:flutter/material.dart';

import '../core/agent_status.dart';
import '../features/agent/agent_controller.dart';

/// Layar utama setelah login.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AgentController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final user = c.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Monitoring Karyawan'),
        actions: [
          IconButton(
            tooltip: 'Sync sekarang',
            icon: const Icon(Icons.sync),
            onPressed: () => c.syncNow(),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () => c.logout(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (user != null) ...[
            Text(
              'Selamat datang, ${user.fullName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${user.email} • ${user.role}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
          ],
          _StatusCard(controller: c),
          const SizedBox(height: 16),
          _ConfigCard(controller: c),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: c.status == AgentStatus.paused ? null : c.pause,
                  icon: const Icon(Icons.pause),
                  label: const Text('Pause'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: c.status == AgentStatus.paused ? c.resume : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Resume'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: c.syncNow,
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Sync Now'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final AgentController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.status;
    final color = switch (status) {
      AgentStatus.running => Colors.green,
      AgentStatus.idle => Colors.orange,
      AgentStatus.paused => Colors.grey,
      AgentStatus.error => Colors.red,
      AgentStatus.unauthenticated => Colors.blueGrey,
    };
    return Card(
      child: ListTile(
        leading: Icon(Icons.circle, color: color, size: 18),
        title: Text('Status: ${status.label}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (controller.currentApp != null)
              Text('App aktif: ${controller.currentApp}'),
            if (controller.bufferCount > 0)
              Text('Antrian belum terkirim: ${controller.bufferCount}'),
            if (controller.lastHeartbeatAt != null)
              Text(
                'Heartbeat terakhir: ${controller.lastHeartbeatAt!.toLocal()}',
              ),
            if (controller.lastSyncAt != null)
              Text('Sync terakhir: ${controller.lastSyncAt!.toLocal()}'),
            if (controller.lastError != null)
              Text(
                'Error: ${controller.lastError}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.controller});

  final AgentController controller;

  @override
  Widget build(BuildContext context) {
    final cfg = controller.runtimeConfig;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.settings),
        title: const Text('Konfigurasi Server'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Screenshot interval: ${cfg.screenshotIntervalSeconds}s'),
            Text('Idle threshold: ${cfg.idleThresholdSeconds}s'),
            if (cfg.configVersion != null)
              Text('Config version: ${cfg.configVersion}'),
          ],
        ),
      ),
    );
  }
}
