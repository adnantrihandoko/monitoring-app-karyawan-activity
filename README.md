# monitoring-karyawan-activity

Aplikasi desktop untuk monitoring aktivitas komputer karyawan: presentase
produktivitas, waktu kerja, status aktif/tidak, dan atasan dapat melihat
aktivitas komputer karyawan.

## Komponen
| Path        | Deskripsi                                            |
|-------------|------------------------------------------------------|
| `backend/`  | FastAPI backend (auth, activities, screenshot, dashboard) |
| `agent_app/`| Flutter desktop agent (Linux) — berjalan di komputer karyawan |

## Agent (`agent_app/`)
- Fitur: login/logout, app tracker, input tracker, idle detector, screenshot
  berkala, heartbeat + batch sync ke backend.
- Bahasa/tooling: Flutter (Dart) desktop Linux; detail lengkap di
  [agent_app/README.md](agent_app/README.md).
- Status: kode selesai, `flutter analyze` 0 issue, 77 unit test lulus.
- Build Linux membutuhkan `libayatana-appindicator3-0.1` untuk plugin
  `tray_manager` (lihat README agent).
- FR-006 (URL Tracker) belum dikerjakan — dijadwalkan Sprint 5.

## Dokumentasi
- [Agent API contract](docs/agent_api_contract.md)
- [Agent README](agent_app/README.md)
- [ClickUp config](docs/CLICKUP.md)

## Getting Started

### Prerequisites
- Flutter 3.x (desktop linux) untuk agent
- Python 3.11+ untuk backend

### Installation
```bash
git clone [repository-url]
cd monitoring-karyawan-activity
# backend
cd backend && pip install -r requirements.txt
# agent
cd agent_app && flutter pub get
```

### Running
```bash
# backend
cd backend && uvicorn app.main:app --reload --port 8000
# agent
cd agent_app && flutter run -d linux
```

## License
[License]
