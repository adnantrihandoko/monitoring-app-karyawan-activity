---
description: Membuat Sprint di ClickUp Folder berdasarkan timeline PRD
agent: planner
---

# /buat-sprint — Buat Sprint di ClickUp

Buat sprint untuk: $ARGUMENTS

Sprint adalah time-box (1-2 minggu) yang mengelompokkan task-task dari PRD.
Sprint dibuat di level Folder dan task akan di-assign ke sini via /jalankan-pipeline.

## Langkah
1. Baca PRD dari ClickUp Docs (via @clickup) — lihat bagian Timeline
2. Tentukan scope sprint berdasarkan fase di PRD
3. Buat sprint di ClickUp Folder 901815722728 via @clickup: clickup_sprints_create
4. Beri nama sprint sesuai argumen (misal: "Sprint 1")
5. Tentukan start date dan end date berdasarkan timeline PRD
6. Beri tahu user sprint sudah dibuat dan siap diisi task via /jalankan-pipeline

## Output
- Sprint object baru di ClickUp Folder 901815722728
- Nama sprint: $ARGUMENTS
