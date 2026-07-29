---
description: Menjalankan E2E/blackbox test, update ClickUp ke In Review jika lulus
agent: builder
---

# /test-e2e — End-to-End / Blackbox Test

Fitur: $ARGUMENTS

Jalankan E2E atau blackbox test untuk fitur yang ditentukan.

## Langkah
1. Scan project dan deteksi framework E2E (Playwright, Cypress, Selenium, dll)
2. Jalankan E2E test suite
3. Jika lulus:
   - Update ClickUp task status ke **In Review** via @clickup
   - Beri tahu user siap untuk di-review
4. Jika gagal:
   - Tampilkan error detail
   - Comment ke ClickUp task via @clickup
   - Jangan lanjut ke deploy

## Catatan
- E2E adalah gate terakhir sebelum In Review
- Jika project tidak punya E2E test, anggap lulus dan update ke In Review
