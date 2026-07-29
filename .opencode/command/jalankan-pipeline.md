---
description: "Pipeline: Baca PRD+TRD → buat List → buat Tasks → assign ke Sprint"
agent: orchestrator
---

# /jalankan-pipeline — Pipeline Otomatis

Sprint: $ARGUMENTS

Pipeline ini TIDAK membuat PRD/TRD/Sprint (itu sudah dilakukan via /buat-prd, /buat-trd, /buat-sprint).
Pipeline ini hanya: breakdown sprint scope dari PRD/TRD → buat tasks → assign ke sprint.

## Pipeline Steps

### Step 1: Cek Dokumen & Sprint
Panggil @clickup via Task tool:
task({ subagent_type: "clickup", description: "Cek PRD, TRD & Sprint", prompt: "Cari doc 'PRD: [Nama Project]' dan 'TRD: [Nama Project]' di ClickUp Docs. Cari sprint '$ARGUMENTS' di Folder 901815722728. Jika PRD/TRD tidak ada, suruh user jalankan /buat-prd dan /buat-trd dulu. Jika sprint tidak ada, suruh user jalankan /buat-sprint dulu." })

### Step 2: Baca PRD & TRD
Panggil @planner via Task tool:
task({ subagent_type: "planner", description: "Analisis PRD & TRD untuk sprint: $ARGUMENTS", prompt: "Baca PRD dan TRD dari ClickUp Docs. Analisis scope sprint '$ARGUMENTS' berdasarkan timeline PRD. Identifikasi task-task yang perlu dibuat: apa, dependensi, prioritas." })

### Step 3: Buat List untuk Sprint
Panggil @clickup via Task tool:
task({ subagent_type: "clickup", description: "Buat List untuk sprint di Folder", prompt: "Cek apakah sudah ada List bernama '$ARGUMENTS' di Folder 901815722728. Jika belum, buat List baru dengan nama '$ARGUMENTS'." })

### Step 4: Buat Tasks di List
Panggil @clickup via Task tool:
task({ subagent_type: "clickup", description: "Buat tasks untuk sprint: $ARGUMENTS", prompt: "Berdasarkan analisis planner, buat task-task di List '$ARGUMENTS' di Folder 901815722728. Setiap task punya: name, description teknis, priority." })

### Step 5: Assign Tasks ke Sprint
Panggil @clickup via Task tool:
task({ subagent_type: "clickup", description: "Assign tasks ke sprint: $ARGUMENTS", prompt: "Cari sprint '$ARGUMENTS' di Folder 901815722728. Assign semua task yang baru dibuat ke sprint tersebut." })

### Step 6: Summary
Tampilkan summary ke user:
- PRD ✅ | TRD ✅ | Sprint "$ARGUMENTS" ✅
- List "$ARGUMENTS" dibuat ✅
- Tasks dibuat dan di-assign ke sprint ✅

## Catatan
- PRD/TRD/Sprint harus sudah ada sebelum pipeline dijalankan
- Urutan: /buat-prd → /buat-trd → /buat-sprint → /jalankan-pipeline
