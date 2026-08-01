# Agent ↔ Backend API Contract

Kontrak API aktual yang dipakai `agent_app` (berdasarkan implementasi backend
FastAPI di `backend/app/schemas/activities.py` & `backend/app/schemas/auth.py`).

Base path: `/api/v1`

## Autentikasi
Semua endpoint di bawah `/activities/*`, `/auth/me`, `/auth/logout` wajib Bearer token:
```
Authorization: Bearer <access_token>
```

| Method | Path              | Body/Notes                                   |
|--------|-------------------|----------------------------------------------|
| POST   | `/auth/login`     | `{ email, password }` → `{ access_token, refresh_token }` |
| POST   | `/auth/refresh`   | `{ refresh_token }` → `{ access_token, refresh_token }` |
| POST   | `/auth/logout`    | revoke session                               |
| GET    | `/auth/me`        | profile user (`id`, `email`, `full_name`, `role`, `department`) |

`id` pada profile dikirim backend sebagai **string** (agent memperlakukan sebagai string).

## Heartbeat — `POST /activities/heartbeat`
Request:
```json
{
  "timestamp": "2026-08-01T09:00:00.000Z",
  "status": "active",
  "activity_type": "active",
  "current_app": "code",
  "current_window_title": "main.dart",
  "idle_duration_seconds": 120.5
}
```
- `status`: `active | idle | away | offline | paused`
- `activity_type`: `active | idle | away | offline` (sama dgn activity batch)

Response (remote config, diterapkan agent):
```json
{
  "screenshot_interval_seconds": 120,
  "idle_threshold_seconds": 600,
  "config_version": 3
}
```

## Batch Activity — `POST /activities/batch`
Payload **flat** (bukan nested array):
```json
{
  "items": [
    {
      "timestamp": "2026-08-01T09:00:00.000Z",
      "activity_type": "active",
      "duration_seconds": 12.5,
      "metadata": { "app_name": "firefox", "window_title": "Docs" }
    }
  ]
}
```
- `timestamp`: UTC ISO-8601 dengan milidetik (`2026-08-01T09:00:00.000Z`).
- `activity_type`: `active | idle | away | offline`.
- Maksimum **1000 item** per batch (agent default `batchSize = 50`).
- Response: `{ "processed_count": 2 }` — agent menghapus dari buffer lokal hanya
  sejumlah `processed_count` (jika < total, sisanya dikirim ulang di siklus berikutnya).

## Screenshot — `POST /activities/screenshot`
`multipart/form-data`:
- `file`: bytes PNG/JPEG
- `captured_at`: `2026-08-01T09:00:00.000Z`
- `width`, `height`: dimensi piksel

## Detail Implementasi Agent
- `formatTimestamp`: `DateTime.toUtc().toIso8601String()` → `YYYY-MM-DDTHH:MM:SS.mmmZ`.
- Auth refresh: saat API mengembalikan 401, `ApiClient` memanggil `/auth/refresh`
  sekali (singleton future), menyimpan token baru, lalu retry request asli.
- Buffer lokal: SQLite (`agent_activity.db`); item dipindah keluar hanya setelah
  server mengonfirmasi `processed_count`.
- Konfigurasi remote hanya diterapkan jika nilai > 0.

## Referensi
- `backend/app/schemas/activities.py`
- `backend/app/schemas/auth.py`
- `agent_app/lib/core/batch_builder.dart`
- `agent_app/lib/core/heartbeat_payload_builder.dart`
