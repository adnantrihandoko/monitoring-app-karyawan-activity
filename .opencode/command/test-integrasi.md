---
description: Menjalankan integration test, update ClickUp
agent: builder
---

# /test-integrasi — Integration Test

Fitur: $ARGUMENTS

Jalankan integration test untuk fitur yang ditentukan.

## Langkah
1. Scan project dan deteksi framework integration test
2. Jalankan integration test suite
3. Jika lulus:
   - Beri tahu user
   - Lanjut ke E2E jika ada
4. Jika gagal:
   - Tampilkan error detail
   - Comment ke ClickUp task via @clickup
   - Jangan lanjut

## Catatan
- Jika project tidak punya integration test, beri tahu user
- Agent akan otomatis mencari test/*.integration.* atau folder tests/integration/
