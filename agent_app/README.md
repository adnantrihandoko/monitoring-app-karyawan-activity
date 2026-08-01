# agent_app

Flutter desktop agent untuk **monitoring-app-karyawan-activity**.

Agent berjalan di komputer karyawan, mengumpulkan aktivitas lokal (app aktif, input,
idle, screenshot berkala), lalu mengirimkan ke backend FastAPI secara berkala
(heartbeat + batch activity). Konfigurasi (interval screenshot & ambang idle)
bisa diubah remote melalui response heartbeat.

## Fitur (FR)
- FR-001 Login/logout ke backend (refresh token otomatis).
- FR-005 App Tracker: deteksi window/aplikasi aktif (X11 `xprop`, fallback `xdotool`).
- FR-007 Input Tracker: ringkasan input keyboard & mouse tiap 60 detik (`xinput`, `xdotool`).
- FR-002 Activity: buffer SQLite lokal, sinkronisasi batch ke `/activities/batch`.
- FR-003 Heartbeat: status agent tiap 30 detik ke `/activities/heartbeat`.
- FR-004 Screenshot: tangkapan layar berkala (`import` + `identify`, ImageMagick).
- FR-006 URL Tracker: **belum dikerjakan** (jadwal Sprint 5).

## Struktur
```
lib/
  core/          config, token storage, api client, auth service,
                 batch builder, heartbeat builder, idle logic, buffer (SQLite),
                 process runner, logger
  features/
    app_tracker/  AppTracker + Linux X11 impl + controller
    input_tracker/ InputTracker + Linux X11 impl + aggregator + controller
    idle_detector/ IdleDetector + Linux xprintidle impl + controller
    screenshot/    ScreenshotCapturer + ImageMagick impl + scheduler + service
    sync/          heartbeat service, batch sync service
    agent/         AgentController (orkestrator), AgentComposer (DI)
  tray/          TrayController (+ NullTrayController fallback), TrayManagerController
  ui/            LoginScreen, HomeScreen, App
main.dart        entry point + window_manager
```

## Requirements Native (Linux)
Build-time:
- Flutter SDK (versi saat ini: 3.44.x / Dart 3.12.x)
- `clang`, `cmake`, `ninja`, GTK3 headers
- `libsecret-1-dev`
- **`libayatana-appindicator3-0.1`** (atau `appindicator3-0.1`) — wajib untuk plugin
  `tray_manager`. Tanpa library ini **build gagal** pada tahap CMake:
  ```
  The tray_manager package requires ayatana-appindicator3-0.1 or appindicator3-0.1
  ```
  Install: `sudo pacman -S libayatana-appindicator` / `sudo apt install libayatana-appindicator3-dev`

Runtime (tools X11):
- `xprop` (window aktif, WM_CLASS)
- `xdotool` (fallback window name + lokasi mouse)
- `xinput` (input events keyboard/mouse)
- `xprintidle` (durasi idle)
- ImageMagick: `import` dan `identify` (screenshot)
- Session X11 (Wayland didukung sebagian; screenshot root window perlu X11)

## Build & Run
```bash
cd agent_app
flutter pub get
flutter run -d linux
```

Ubah base URL backend saat run/build:
```bash
flutter run -d linux \
  --dart-define=AGENT_API_BASE_URL=http://localhost:8000/api/v1
flutter build linux --dart-define=AGENT_API_BASE_URL=http://192.168.1.10:8000/api/v1
```

Toggle fitur:
```bash
--dart-define=AGENT_SCREENSHOT_ENABLED=false
--dart-define=AGENT_INPUT_ENABLED=false
```

## Test
```bash
flutter analyze     # 0 issues
flutter test        # unit test (parser, builder, buffer, services, controllers)
```
Semua komponen native diekstrak di balik abstraksi `ProcessRunner` /
`IdleDetector` / `AppTracker` / `InputTracker` agar dapat diuji tanpa X11.

## Lokasi Data
- SQLite buffer: `getApplicationSupportDirectory()/agent_activity.db`
- Token: flutter_secure_storage (keyring/libsecret); fallback shared_preferences.

## Catatan
- UI window & tray action handler minimal: tombol pause/resume/sync ada di HomeScreen;
  saat window ditutup aplikasi tetap berjalan di tray (window_manager).
- Fallback `NullTrayController` disiapkan untuk environment tanpa tray, tetapi
  plugin `tray_manager` tetap harus bisa dikompilasi (perlu appindicator dev).
