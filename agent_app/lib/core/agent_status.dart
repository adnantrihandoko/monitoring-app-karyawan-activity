/// Status agent & tipe aktivitas.
library;

/// Status runtime agent yang ditampilkan di UI/tray.
enum AgentStatus {
  unauthenticated('unauthenticated', 'Belum login'),
  running('active', 'Berjalan'),
  idle('idle', 'Idle'),
  paused('paused', 'Dijeda'),
  error('error', 'Error');

  const AgentStatus(this.apiValue, this.label);

  /// Nilai yang dikirim ke backend (enum kontrak activity/heartbeat).
  final String apiValue;
  final String label;
}

/// Tipe aktivitas sesuai kontrak backend
/// (activity_type: active|idle|away|offline).
enum ActivityType {
  active('active'),
  idle('idle'),
  away('away'),
  offline('offline');

  const ActivityType(this.value);
  final String value;
}
