# ClickUp Configuration

## Project: monitoring-app-karyawan-activity
- **ClickUp Folder ID:** 901815722728[C
- **MCP Server:** clickup-mcp-pro

## Environment Variables
- CLICKUP_API_TOKEN — Personal API token dari ClickUp (Settings → Apps)

## Cara Mendapatkan API Token
1. Buka https://app.clickup.com/settings/apps
2. Generate Personal API Token
3. Set sebagai environment variable: `CLICKUP_API_TOKEN=pk_...`

## Agent ClickUp
Gunakan @clickup agent untuk:
- Membuat/membaca/mengupdate docs
- Membuat/mengelola tasks
- Sprint management
- Comments dan attachments

## Status Sprint 2 — Activity Tracking Agent (`agent_app/`)
- Implementasi kode: **selesai** (agent Flutter Linux di `agent_app/`).
- `flutter analyze`: 0 issue.
- `flutter test`: 77 unit test lulus (parser X11, builder payload, buffer SQLite,
  api client/refresh, auth service, heartbeat/batch sync, controller).
- `flutter build linux`: **terblokir** oleh missing `libayatana-appindicator3-0.1`
  (plugin `tray_manager`); fallback `NullTrayController` sudah disiapkan.
- FR-006 URL Tracker: belum dikerjakan (Sprint 5).
- API contract agent ↔ backend: `docs/agent_api_contract.md`.

