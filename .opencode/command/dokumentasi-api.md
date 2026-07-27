---
description: Membuat atau update dokumentasi API
agent: documenter
model: anthropic/claude-sonnet-4-6
---

# Dokumentasi API

Buat/update dokumentasi API untuk: $ARGUMENTS

## Komponen:
- Overview (Base URL, Auth, Rate limiting)
- Endpoints documentation
- Authentication guide
- Error handling guide
- Code examples

## Output:
- API docs: docs/api/API_DOCS.md
- OpenAPI spec: docs/api/openapi.yaml
- Postman collection: docs/api/postman_collection.json
