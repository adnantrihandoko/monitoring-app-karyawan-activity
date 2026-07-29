---
description: Menjalankan unit test, update ClickUp
agent: builder
---

# /test-unit — Unit Test

Fitur: $ARGUMENTS

Jalankan unit test untuk fitur yang ditentukan.

## Langkah
1. Scan project dan deteksi framework test
2. Jalankan unit test suite
3. Jika lulus:
   - Beri tahu user
   - Update ClickUp jika perlu
4. Jika gagal:
   - Tampilkan error detail
   - Comment ke ClickUp task via @clickup
   - Jangan lanjut

## Catatan
- Agent akan otomatis mendeteksi framework test dari project
- Jangan hardcode perintah test — scan dulu
