---
description: Melakukan code review terhadap kode yang sudah ditulis
agent: reviewer
model: anthropic/claude-sonnet-4-6
---

# Review Kode

Lakukan code review untuk: $ARGUMENTS

## Checklist:
- Kode readable dan understandable
- Follow coding standards
- Tidak ada code duplication
- Error handling proper
- Input validation
- Security best practices
- Test coverage cukup
- Documentation updated

## Format Output:
1. Ringkasan
2. Issues (Critical/Major/Minor)
3. Saran perbaikan
4. Verdict (APPROVED/CHANGES_REQUESTED)
