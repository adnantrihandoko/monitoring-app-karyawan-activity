---
description: Menulis test cases dan test suites
agent: tester
model: anthropic/claude-sonnet-4-6
---

# Buat Test Cases

Buat test cases untuk: $ARGUMENTS

## Tipe Testing:
- Unit Testing: test individual functions
- Integration Testing: test component interactions
- E2E Testing: test full user flows

## Test Case Format:
**ID:** TC-XXX
**Priority:** High/Medium/Low
**Preconditions:** [Kondisi sebelum test]
**Steps:** [Langkah-langkah]
**Expected:** [Hasil diharapkan]
**Status:** Pass/Fail

## Lokasi:
- Unit: tests/unit/
- Integration: tests/integration/
- E2E: tests/e2e/
