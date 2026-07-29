---
description: Deploy via Docker ke staging/production, update ClickUp ke Done
agent: devops
---

# /deploy — Deploy via Docker

Environment: $ARGUMENTS

Deploy project ke environment staging atau production.

## Langkah
1. Scan project untuk Dockerfile / docker-compose.yml
2. Jika tidak ada → minta user buat Dockerfile, jangan lanjut
3. Build Docker image
4. Deploy ke environment yang diminta
5. Health check — tunggu container siap
6. Jika staging → deploy langsung
7. Jika production → minta konfirmasi user dulu
8. Jika sukses:
   - Update ClickUp task status ke **Done** via @clickup
   - Beri tahu user URL deploy
9. Jika gagal:
   - Rollback
   - Comment error ke ClickUp task
   - Beri tahu user

## Catatan
- Staging: deploy langsung tanpa approval
- Production: wajib tanya konfirmasi user
- Agent DevOps akan cari dan manage Docker sendiri
