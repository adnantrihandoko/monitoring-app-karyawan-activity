# AGENTS.md — OpenCode + ClickUp Configuration

## Agents (7)
| Agent | Role |
|-------|------|
| **planner** | Perencana dan arsitek. PRD, TRD, sprint. |
| **builder** | Developer utama. Implementasi kode. |
| **reviewer** | Code reviewer. Quality gate. |
| **devops** | DevOps. Deploy, CI/CD. |
| **memory** | Memory keeper. Persistent context. |
| **clickup** | ClickUp specialist. Tasks, docs, sprint via MCP. |
| **orchestrator** | Pipeline orchestrator. Koordinator PRD→TRD→Sprint→Tasks. |

## Commands (10)
| Command | Agent | Fungsi |
|---------|-------|--------|
| **/buat-prd** | planner | Buat/update PRD project-level di ClickUp Docs |
| **/buat-trd** | planner | Buat/update TRD project-level dari PRD |
| **/buat-sprint** | planner | Buat sprint di ClickUp Folder berdasarkan timeline PRD |
| **/jalankan-pipeline** | orchestrator | Pipeline: baca PRD+TRD → buat List → Tasks → assign ke Sprint |
| **/test-unit** | builder | Jalankan unit test, update ClickUp |
| **/test-integrasi** | builder | Jalankan integration test, update ClickUp |
| **/test-e2e** | builder | Jalankan E2E test → Status: In Review |
| **/deploy** | devops | Deploy via Docker → Status: Done |
| **/ask** | orchestrator | Tanya codebase, ClickUp, docs, web |
| **/status-proyek** | clickup | Status project dari ClickUp |

## ClickUp MCP
- Server: clickup-mcp-pro (161 tools)
- Folder ID: 901815722728
- Auth: CLICKUP_API_TOKEN (env)
