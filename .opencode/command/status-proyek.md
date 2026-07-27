---
description: Menampilkan status dan progress proyek saat ini
agent: planner
model: anthropic/claude-sonnet-4-6
---

# Status Proyek

Tampilkan status lengkap proyek: $ARGUMENTS

## Komponen:
- Project overview (nama, deskripsi, timeline)
- Progress summary (completed, in-progress, blocked, pending)
- Sprint status (current sprint, progress, velocity)
- Quality metrics (code coverage, bug count)
- Risk status (active, mitigated, new)
- Next steps (immediate actions, upcoming milestones)

## Output:
Dashboard-style dengan charts dan tables.

## Lokasi:
- Display di terminal
- Simpan di: logs/STATUS_[TANGGAL].md
