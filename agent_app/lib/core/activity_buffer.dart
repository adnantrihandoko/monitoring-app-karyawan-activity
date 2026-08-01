/// Buffer lokal SQLite untuk event aktivitas sebelum disinkronkan.
///
/// Menggunakan `sqflite_common_ffi` sehingga berjalan di desktop Linux.
/// Data disimpan sebagai antrian; saat sync berhasil, baris dihapus.
library;

import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Helper membuka database SQLite untuk agent.
class ActivityDatabase {
  ActivityDatabase._();

  /// Membuka (atau membuat) database agent pada `path`.
  ///
  /// Jika `path` null → in-memory (untuk test).
  /// `factory` bisa di-override (misal `databaseFactoryFfiNoIsolate` di test).
  static Future<Database> open({String? path, DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactoryFfi;
    if (path == null) {
      return f.openDatabase(inMemoryDatabasePath, options: _options);
    }
    return f.openDatabase(path, options: _options);
  }

  static final _options = OpenDatabaseOptions(
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          activity_type TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          duration_seconds REAL,
          metadata TEXT,
          created_at INTEGER NOT NULL
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_activity_queue_created '
        'ON activity_queue(created_at)',
      );
    },
  );
}

/// Antrian aktivitas di SQLite.
class ActivityBuffer {
  ActivityBuffer({required this.database, this.maxQueueSize = 10000});

  final Database database;
  final int maxQueueSize;

  /// Menambahkan satu event ke antrian. Mengembalikan id baris.
  Future<int> add({
    required String activityType,
    DateTime? timestamp,
    double? durationSeconds,
    Map<String, dynamic>? metadata,
  }) async {
    final now = DateTime.now().toUtc();
    final inserted = await database.insert('activity_queue', {
      'activity_type': activityType,
      'timestamp': (timestamp ?? now).toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
      'metadata': metadata == null ? null : jsonEncode(metadata),
      'created_at': now.millisecondsSinceEpoch,
    });
    await _trimIfNeeded();
    return inserted;
  }

  /// Mengambil `limit` item tertua untuk dikirim.
  Future<List<ActivityQueueRow>> take(int limit) async {
    final rows = await database.query(
      'activity_queue',
      columns: [
        'id',
        'activity_type',
        'timestamp',
        'duration_seconds',
        'metadata',
      ],
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
    return rows.map(ActivityQueueRow.fromRow).toList();
  }

  /// Menghapus item berdasarkan id (setelah sukses terkirim).
  Future<void> removeByIds(List<int> ids) async {
    if (ids.isEmpty) return;
    final placeholders = List.filled(ids.length, '?').join(',');
    await database.delete(
      'activity_queue',
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  /// Jumlah item di antrian.
  Future<int> count() async {
    final result = await database.rawQuery(
      'SELECT COUNT(*) AS c FROM activity_queue',
    );
    return result.first['c'] as int? ?? 0;
  }

  /// Mencegah antrian membengkak saat offline berkepanjangan.
  Future<void> _trimIfNeeded() async {
    final c = await count();
    if (c <= maxQueueSize) return;
    final overflow = c - maxQueueSize;
    await database.rawDelete(
      'DELETE FROM activity_queue WHERE id IN ('
      'SELECT id FROM activity_queue ORDER BY created_at ASC, id ASC LIMIT ?)',
      [overflow],
    );
  }
}

/// Satu baris antrian aktivitas.
class ActivityQueueRow {
  const ActivityQueueRow({
    required this.id,
    required this.activityType,
    required this.timestamp,
    this.durationSeconds,
    this.metadata,
  });

  final int id;
  final String activityType;
  final DateTime timestamp;
  final double? durationSeconds;
  final Map<String, dynamic>? metadata;

  factory ActivityQueueRow.fromRow(Map<String, Object?> row) {
    Map<String, dynamic>? meta;
    final rawMeta = row['metadata'] as String?;
    if (rawMeta != null && rawMeta.isNotEmpty) {
      try {
        meta = (jsonDecode(rawMeta) as Map).cast<String, dynamic>();
      } catch (_) {
        meta = null;
      }
    }
    return ActivityQueueRow(
      id: row['id'] as int,
      activityType: row['activity_type'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      durationSeconds: (row['duration_seconds'] as num?)?.toDouble(),
      metadata: meta,
    );
  }
}
