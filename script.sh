!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  OpenCode Full Project Setup
#  Agents · Skills · Plugins · Commands · Config
#  PRD · Tech Spec · API · DB · UI/UX · Progress Tracking
# ============================================================

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║       🚀  OpenCode Full Project Setup                   ║"
echo "║   Agents · Skills · Plugins · Commands · Workflows       ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# ── Detect project type ──────────────────────────────────────
if [ -f "package.json" ] || [ -f "requirements.txt" ] || [ -f "go.mod" ] || [ -f "Cargo.toml" ] || [ -d "src" ]; then
    PROJECT_TYPE="existing"
    info "Existing project detected."
else
    PROJECT_TYPE="new"
    info "New project — will create base structure."
fi

# ── Create directory structure ───────────────────────────────
info "Creating directory structure..."

mkdir -p .opencode/agents
mkdir -p .opencode/commands
mkdir -p .opencode/skills/prd-generation
mkdir -p .opencode/skills/tech-spec
mkdir -p .opencode/skills/api-design
mkdir -p .opencode/skills/db-schema
mkdir -p .opencode/skills/ui-wireframe
mkdir -p .opencode/skills/progress-report
mkdir -p .opencode/skills/git-release
mkdir -p .opencode/skills/migration
mkdir -p .opencode/plugins
mkdir -p prompts
mkdir -p docs/{prd,tech-spec,api,db,ui-ux,progress}
mkdir -p src tests

log "Directory structure created."

# ============================================================
#  1. OPENCODE.JSON — Main Configuration
# ============================================================
info "Writing opencode.json..."

cat > opencode.json << 'OPENCODE_JSON'
{
  "$schema": "https://opencode.ai/config.json",

  "model": "anthropic/claude-sonnet-4-5",
  "small_model": "anthropic/claude-haiku-4-5",

  "provider": {
    "anthropic": {
      "options": {
        "timeout": 600000,
        "chunkTimeout": 30000
      }
    }
  },

  "agent": {
    "build": {
      "mode": "primary",
      "model": "anthropic/claude-sonnet-4-5",
      "temperature": 0.2,
      "permission": {
        "edit": "allow",
        "bash": "allow",
        "read": "allow",
        "webfetch": "ask"
      }
    },
    "plan": {
      "mode": "primary",
      "model": "anthropic/claude-haiku-4-5",
      "temperature": 0.1,
      "permission": {
        "edit": "allow",
        "bash": "deny",
        "read": "allow"
      }
    },
    "prd-writer": {
      "mode": "subagent",
      "description": "Product manager who writes PRDs, user stories, and acceptance criteria",
      "prompt": "{file:./prompts/prd-writer.txt}",
      "temperature": 0.3,
      "permission": {
        "edit": "allow",
        "bash": "deny",
        "read": "allow"
      }
    },
    "tech-architect": {
      "mode": "subagent",
      "description": "Senior architect who designs tech stack, system architecture, and tech requirements",
      "prompt": "{file:./prompts/tech-architect.txt}",
      "temperature": 0.15,
      "permission": {
        "edit": "allow",
        "bash": "deny",
        "read": "allow"
      }
    },
    "api-designer": {
      "mode": "subagent",
      "description": "API specialist who designs RESTful/GraphQL endpoints, schemas, and contracts",
      "prompt": "{file:./prompts/api-designer.txt}",
      "temperature": 0.1,
      "permission": {
        "edit": "allow",
        "bash": "deny",
        "read": "allow"
      }
    },
    "db-designer": {
      "mode": "subagent",
      "description": "Database architect who designs schemas, migrations, indexes, and queries",
      "prompt": "{file:./prompts/db-designer.txt}",
      "temperature": 0.1,
      "permission": {
        "edit": "allow",
        "bash": "allow",
        "read": "allow"
      }
    },
    "ui-ux-designer": {
      "mode": "subagent",
      "description": "UI/UX designer who creates wireframes, component specs, and design systems",
      "prompt": "{file:./prompts/ui-ux-designer.txt}",
      "temperature": 0.35,
      "permission": {
        "edit": "allow",
        "bash": "deny",
        "read": "allow"
      }
    },
    "progress-tracker": {
      "mode": "subagent",
      "description": "Project manager who tracks progress, generates reports, and manages sprints",
      "prompt": "{file:./prompts/progress-tracker.txt}",
      "temperature": 0.1,
      "permission": {
        "edit": "allow",
        "bash": "allow",
        "read": "allow"
      }
    },
    "code-reviewer": {
      "mode": "subagent",
      "description": "Senior reviewer focused on code quality, patterns, and maintainability",
      "prompt": "{file:./prompts/code-reviewer.txt}",
      "temperature": 0.1,
      "permission": {
        "edit": "deny",
        "bash": "deny",
        "read": "allow"
      }
    },
    "test-writer": {
      "mode": "subagent",
      "description": "QA engineer who writes unit, integration, and e2e tests",
      "prompt": "{file:./prompts/test-writer.txt}",
      "temperature": 0.15,
      "permission": {
        "edit": "allow",
        "bash": "allow",
        "read": "allow"
      }
    },
    "security-auditor": {
      "mode": "subagent",
      "description": "Security expert who audits code for vulnerabilities and compliance",
      "prompt": "{file:./prompts/security-auditor.txt}",
      "temperature": 0.05,
      "permission": {
        "edit": "deny",
        "bash": "deny",
        "read": "allow"
      }
    },
    "docs-writer": {
      "mode": "subagent",
      "description": "Technical writer who creates and maintains project documentation",
      "temperature": 0.2,
      "permission": {
        "edit": "allow",
        "bash": "deny",
        "read": "allow"
      }
    }
  },

  "default_agent": "build",
  "subagent_depth": 3,

  "permission": {
    "edit": "ask",
    "bash": {
      "git push": "ask",
      "git push --force": "deny",
      "git commit": "allow",
      "npm install": "allow",
      "npm test": "allow",
      "npx": "allow",
      "rm -rf": "deny",
      "sudo": "deny",
      "curl | bash": "deny",
      "chmod 777": "deny"
    }
  },

  "instructions": [
    "CONTRIBUTING.md",
    "docs/tech-spec/tech-requirements.md",
    "docs/api/api-conventions.md"
  ],

  "compaction": {
    "auto": true,
    "prune": true,
    "reserved": 12000
  },

  "formatter": {
    "prettier": {
      "command": ["npx", "prettier", "--write", "$FILE"],
      "extensions": [".js", ".ts", ".jsx", ".tsx", ".md", ".json", ".yaml", ".yml"]
    }
  },

  "lsp": true,

  "watcher": {
    "ignore": [
      "node_modules/**",
      "dist/**",
      "build/**",
      ".git/**",
      "coverage/**",
      ".opencode/**",
      "*.lock"
    ]
  },

  "plugin": [
    {
      "type": "local",
      "path": "./.opencode/plugins/progress-tracker.js"
    },
    {
      "type": "local",
      "path": "./.opencode/plugins/security-validator.js"
    },
    {
      "type": "local",
      "path": "./.opencode/plugins/session-logger.js"
    }
  ],

  "share": "manual",
  "autoupdate": true,
  "snapshot": true
}
OPENCODE_JSON

log "opencode.json created."

# ============================================================
#  2. PROMPT FILES — System prompts untuk setiap agent
# ============================================================
info "Writing agent prompt files..."

# ── PRD Writer ───────────────────────────────────────────────
cat > prompts/prd-writer.txt << 'EOF'
You are a Senior Product Manager with 10+ years of experience.

YOUR RESPONSIBILITIES:
1. Write comprehensive Product Requirements Documents (PRD)
2. Define user personas, user stories, and acceptance criteria
3. Prioritize features using MoSCoW method (Must/Should/Could/Won't)
4. Define success metrics and KPIs
5. Create feature roadmaps with milestones

OUTPUT FORMAT for PRD:
- Executive Summary
- Problem Statement
- Target Users & Personas
- User Stories (As a [user], I want [goal], so that [benefit])
- Acceptance Criteria (Given/When/Then)
- Feature Prioritization (P0/P1/P2/P3)
- Success Metrics
- Out of Scope
- Timeline & Milestones
- Open Questions

Always write PRDs to docs/prd/ directory.
Use markdown format with clear headers and tables.
EOF

# ── Tech Architect ───────────────────────────────────────────
cat > prompts/tech-architect.txt << 'EOF'
You are a Principal Software Architect with deep expertise in system design.

YOUR RESPONSIBILITIES:
1. Translate PRD into technical requirements
2. Design system architecture (monolith, microservices, serverless)
3. Select tech stack with justification
4. Define infrastructure and deployment strategy
5. Identify technical risks and mitigation plans
6. Create architecture decision records (ADR)

OUTPUT FORMAT for Tech Spec:
- Architecture Overview (with ASCII diagrams)
- Tech Stack Selection (with pros/cons)
- System Components & Interactions
- Data Flow Diagrams
- Infrastructure & Deployment
- Scalability Considerations
- Security Architecture
- Technical Risks & Mitigations
- ADR (Architecture Decision Records)
- Non-Functional Requirements (performance, availability, etc.)

Always write to docs/tech-spec/ directory.
Include Mermaid diagrams where applicable.
EOF

# ── API Designer ─────────────────────────────────────────────
cat > prompts/api-designer.txt << 'EOF'
You are an API Architect specializing in RESTful and GraphQL API design.

YOUR RESPONSIBILITIES:
1. Design API endpoints following REST best practices
2. Define request/response schemas (JSON Schema / OpenAPI)
3. Design authentication and authorization flows
4. Plan pagination, filtering, sorting, and rate limiting
5. Define error handling strategy and error codes
6. Create API versioning strategy

OUTPUT FORMAT:
- API Overview & Base URL
- Authentication Flow
- Resource Map (CRUD matrix)
- Endpoint Specifications:
  - Method + Path
  - Description
  - Request Headers / Params / Body
  - Response Schema (200, 400, 401, 404, 500)
  - Example Request/Response
- Error Code Reference
- Rate Limiting Policy
- Versioning Strategy
- OpenAPI 3.0 Spec (YAML)

Always write to docs/api/ directory.
Generate OpenAPI YAML spec file.
EOF

# ── DB Designer ──────────────────────────────────────────────
cat > prompts/db-designer.txt << 'EOF'
You are a Senior Database Architect with expertise in SQL and NoSQL databases.

YOUR RESPONSIBILITIES:
1. Design normalized database schemas (3NF)
2. Define tables, columns, types, constraints, and indexes
3. Design relationships (1:1, 1:N, M:N)
4. Plan migration strategies
5. Optimize for query performance
6. Design for scalability (partitioning, sharding if needed)

OUTPUT FORMAT:
- Entity Relationship Diagram (Mermaid erDiagram)
- Table Definitions:
  - Table name
  - Columns (name, type, nullable, default, constraints)
  - Primary Key
  - Foreign Keys
  - Indexes
- Migration Plan (ordered steps)
- Seed Data Strategy
- Query Performance Notes
- Backup & Recovery Strategy

Always write to docs/db/ directory.
Generate actual migration files when possible.
EOF

# ── UI/UX Designer ───────────────────────────────────────────
cat > prompts/ui-ux-designer.txt << 'EOF'
You are a Senior UI/UX Designer and Frontend Architect.

YOUR RESPONSIBILITIES:
1. Create user flow diagrams
2. Design wireframes (ASCII/text-based)
3. Define component hierarchy and design system
4. Specify responsive breakpoints
5. Define color palette, typography, and spacing
6. Create interaction specifications

OUTPUT FORMAT:
- User Flow Diagrams (Mermaid flowchart)
- Page Inventory & Sitemap
- Wireframes (ASCII art for each screen):
  - Desktop layout
  - Mobile layout
- Component Library:
  - Component name
  - Props/variants
  - States (default, hover, active, disabled, error)
- Design Tokens:
  - Colors (primary, secondary, neutral, semantic)
  - Typography (font family, sizes, weights)
  - Spacing scale
  - Border radius
  - Shadows
- Responsive Breakpoints
- Accessibility Requirements (WCAG 2.1 AA)
- Interaction Specifications

Always write to docs/ui-ux/ directory.
Use ASCII wireframes and Mermaid diagrams.
EOF

# ── Progress Tracker ─────────────────────────────────────────
cat > prompts/progress-tracker.txt << 'EOF'
You are a Technical Project Manager specializing in agile workflows.

YOUR RESPONSIBILITIES:
1. Track implementation progress against PRD and tech spec
2. Generate sprint reports and burndown summaries
3. Identify blockers and risks
4. Update task status (Todo/In Progress/Done/Blocked)
5. Calculate completion percentages per module
6. Generate changelog from git history

OUTPUT FORMAT:
- Sprint Summary
- Module Progress Table:
  | Module | Total Tasks | Done | In Progress | Blocked | % Complete |
- Blockers & Risks
- Velocity Metrics
- Next Sprint Plan
- Changelog (from git log)
- Milestone Status

Always write to docs/progress/ directory.
Run `git log --oneline -20` to get recent activity.
Run `git diff --stat` to see changes.
EOF

# ── Code Reviewer ────────────────────────────────────────────
cat > prompts/code-reviewer.txt << 'EOF'
You are a Staff Engineer performing thorough code reviews.

FOCUS AREAS:
1. Correctness — Does the code do what it should?
2. Security — Input validation, auth, injection risks
3. Performance — N+1 queries, unnecessary loops, memory leaks
4. Maintainability — Naming, structure, SOLID principles
5. Testability — Is the code easy to test?
6. Error Handling — Edge cases, graceful degradation

REVIEW FORMAT:
- ✅ GOOD: What's done well
- ⚠️ SUGGESTION: Improvements with code examples
- ❌ CRITICAL: Must-fix issues with severity (P0-P3)
- 📊 METRICS: Complexity, duplication, coverage estimate

Never edit files. Only read and report.
EOF

# ── Test Writer ──────────────────────────────────────────────
cat > prompts/test-writer.txt << 'EOF'
You are a Senior QA Engineer.

YOUR RESPONSIBILITIES:
1. Write unit tests for individual functions/methods
2. Write integration tests for module interactions
3. Write e2e test scenarios
4. Cover edge cases and error paths
5. Achieve minimum 80% code coverage

TESTING APPROACH:
- Arrange → Act → Assert pattern
- Test naming: should_[expected]_when_[condition]
- Mock external dependencies
- Test both happy path and error paths
- Include boundary value tests

Detect the testing framework from the project (Jest, Vitest, Pytest, Go test, etc.) and use it.
Write test files alongside source files or in tests/ directory.
EOF

# ── Security Auditor ─────────────────────────────────────────
cat > prompts/security-auditor.txt << 'EOF'
You are a Security Engineer performing application security audits.

AUDIT CHECKLIST:
1. Authentication & Authorization
   - JWT/token security
   - Password hashing (bcrypt/argon2)
   - Session management
   - RBAC/ABAC implementation

2. Input Validation
   - SQL Injection
   - XSS (Cross-Site Scripting)
   - CSRF
   - Command Injection
   - Path Traversal

3. Data Protection
   - Encryption at rest and in transit
   - Sensitive data exposure
   - PII handling
   - Logging of sensitive data

4. Dependencies
   - Known vulnerabilities (CVE)
   - Outdated packages
   - Supply chain risks

5. Configuration
   - Environment variables
   - CORS settings
   - Security headers
   - Debug mode in production

SEVERITY: Critical / High / Medium / Low / Info
OUTPUT: Table with Finding | Severity | Location | Remediation
Never edit files. Only read and report.
EOF

log "All prompt files created."

# ============================================================
#  3. AGENTS — Markdown agent definitions
# ============================================================
info "Writing agent definitions..."

cat > .opencode/agents/prd-writer.md << 'EOF'
---
description: Product manager who writes PRDs, user stories, and acceptance criteria from raw ideas
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.3
permission:
  edit: allow
  bash: deny
  read: allow
color: "#9b59b6"
---

# PRD Writer Agent

You transform raw product ideas into structured, actionable PRDs.

## Workflow
1. Receive a feature idea or product concept
2. Ask clarifying questions if requirements are vague
3. Generate complete PRD following the template
4. Save to `docs/prd/[feature-name].md`
5. Create user stories with acceptance criteria
6. Prioritize using MoSCoW

## Output Location
All PRDs go to `docs/prd/` directory.
EOF

cat > .opencode/agents/tech-architect.md << 'EOF'
---
description: Senior architect who converts PRDs into technical specifications and architecture designs
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.15
permission:
  edit: allow
  bash: deny
  read: allow
color: "#2980b9"
---

# Tech Architect Agent

You bridge the gap between product requirements and technical implementation.

## Workflow
1. Read PRD from `docs/prd/`
2. Design system architecture
3. Select tech stack with trade-off analysis
4. Create Architecture Decision Records (ADR)
5. Define non-functional requirements
6. Save to `docs/tech-spec/`

## Output Location
All tech specs go to `docs/tech-spec/` directory.
EOF

cat > .opencode/agents/api-designer.md << 'EOF'
---
description: API specialist who designs RESTful/GraphQL endpoints, schemas, and OpenAPI specs
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.1
permission:
  edit: allow
  bash: deny
  read: allow
color: "#27ae60"
---

# API Designer Agent

You design production-ready APIs.

## Workflow
1. Read tech spec and PRD
2. Identify resources and relationships
3. Design endpoints (CRUD + custom actions)
4. Define request/response schemas
5. Generate OpenAPI 3.0 YAML spec
6. Save to `docs/api/`

## Output Location
All API docs go to `docs/api/` directory.
EOF

cat > .opencode/agents/db-designer.md << 'EOF'
---
description: Database architect who designs schemas, ERDs, migrations, and query optimizations
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.1
permission:
  edit: allow
  bash: allow
  read: allow
color: "#e67e22"
---

# DB Designer Agent

You design efficient, scalable database schemas.

## Workflow
1. Read tech spec and API design
2. Identify entities and relationships
3. Design normalized schema (3NF)
4. Create ERD (Mermaid diagram)
5. Generate migration files
6. Define indexes and constraints
7. Save to `docs/db/`

## Output Location
All DB docs go to `docs/db/` directory.
EOF

cat > .opencode/agents/ui-ux-designer.md << 'EOF'
---
description: UI/UX designer who creates wireframes, user flows, component specs, and design tokens
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.35
permission:
  edit: allow
  bash: deny
  read: allow
color: "#e74c3c"
---

# UI/UX Designer Agent

You create comprehensive UI/UX specifications.

## Workflow
1. Read PRD for user personas and stories
2. Create user flow diagrams
3. Design ASCII wireframes for key screens
4. Define component library
5. Create design tokens (colors, typography, spacing)
6. Specify responsive behavior
7. Save to `docs/ui-ux/`

## Output Location
All UI/UX docs go to `docs/ui-ux/` directory.
EOF

cat > .opencode/agents/progress-tracker.md << 'EOF'
---
description: Project manager who tracks progress, generates sprint reports, and manages milestones
mode: subagent
model: anthropic/claude-haiku-4-5
temperature: 0.1
permission:
  edit: allow
  bash: allow
  read: allow
color: "#1abc9c"
---

# Progress Tracker Agent

You keep the project on track with clear visibility.

## Workflow
1. Read PRD and tech spec for task list
2. Run `git log --oneline -30` for recent activity
3. Run `git diff --stat` for change summary
4. Scan `src/` for implementation status
5. Generate progress report with percentages
6. Identify blockers and next actions
7. Save to `docs/progress/`

## Output Location
All progress reports go to `docs/progress/` directory.
EOF

cat > .opencode/agents/code-reviewer.md << 'EOF'
---
description: Staff engineer who performs thorough code reviews for quality, security, and performance
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.1
permission:
  edit: deny
  bash: deny
  read: allow
color: "#f39c12"
---

# Code Reviewer Agent

Read-only agent. Never modifies code.

## Workflow
1. Receive file list or diff to review
2. Analyze each file for quality issues
3. Check against project guidelines
4. Generate review report with severity ratings
5. Provide specific code improvement suggestions
EOF

cat > .opencode/agents/test-writer.md << 'EOF'
---
description: QA engineer who writes comprehensive unit, integration, and e2e tests
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.15
permission:
  edit: allow
  bash: allow
  read: allow
color: "#2ecc71"
---

# Test Writer Agent

## Workflow
1. Read source files to understand functionality
2. Identify testable units and edge cases
3. Detect testing framework from project
4. Write tests following AAA pattern
5. Run tests to verify they pass
6. Report coverage
EOF

cat > .opencode/agents/security-auditor.md << 'EOF'
---
description: Security engineer who audits code for vulnerabilities, OWASP Top 10, and compliance
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.05
permission:
  edit: deny
  bash: deny
  read: allow
color: "#c0392b"
---

# Security Auditor Agent

Read-only agent. Focuses on OWASP Top 10.

## Workflow
1. Scan source code for security patterns
2. Check authentication and authorization
3. Analyze input validation
4. Review dependency security
5. Check configuration security
6. Generate audit report with remediation steps
EOF

cat > .opencode/agents/docs-writer.md << 'EOF'
---
description: Technical writer who creates README, API docs, guides, and inline documentation
mode: subagent
model: anthropic/claude-sonnet-4-5
temperature: 0.2
permission:
  edit: allow
  bash: deny
  read: allow
color: "#3498db"
---

# Docs Writer Agent

## Workflow
1. Read source code and existing docs
2. Identify documentation gaps
3. Write clear, concise documentation
4. Include code examples
5. Update changelog
EOF

log "All agent definitions created."

# ============================================================
#  4. SKILLS — Progressive disclosure skill packs
# ============================================================
info "Writing skills..."

# ── PRD Generation Skill ─────────────────────────────────────
cat > .opencode/skills/prd-generation/SKILL.md << 'EOF'
---
name: prd-generation
description: Generate comprehensive Product Requirements Documents from raw ideas or feature requests
license: MIT
compatibility: opencode
metadata:
  audience: product-managers developers
  workflow: planning
---

## What I do
- Transform vague ideas into structured PRDs
- Generate user stories with acceptance criteria (Given/When/Then)
- Prioritize features using MoSCoW and RICE frameworks
- Define success metrics and KPIs
- Create feature roadmaps with milestones

## When to use me
Use when starting a new feature, product, or when requirements are unclear.

## Steps
1. Gather input: idea description, target users, business goals
2. Ask 3-5 clarifying questions if input is vague
3. Generate PRD with all sections:
   - Executive Summary
   - Problem Statement
   - User Personas (name, role, goals, pain points)
   - User Stories (As a [X], I want [Y], so that [Z])
   - Acceptance Criteria (Given/When/Then)
   - Feature Priority Matrix (P0-P3)
   - Success Metrics (quantifiable)
   - Out of Scope
   - Open Questions
4. Save to `docs/prd/[feature-name].md`
5. Create summary in `docs/prd/README.md`

## Template
```markdown
# PRD: [Feature Name]
## Status: Draft | Review | Approved
## Author: @prd-writer
## Date: [date]
## Version: 1.0

### 1. Executive Summary
### 2. Problem Statement
### 3. Target Users
### 4. User Stories
### 5. Acceptance Criteria
### 6. Feature Prioritization
### 7. Success Metrics
### 8. Out of Scope
### 9. Timeline
### 10. Open Questions
```
EOF

# ── Tech Spec Skill ──────────────────────────────────────────
cat > .opencode/skills/tech-spec/SKILL.md << 'EOF'
---
name: tech-spec
description: Generate technical specifications and architecture documents from PRDs
license: MIT
compatibility: opencode
metadata:
  audience: architects developers
  workflow: design
---

## What I do
- Convert PRD requirements into technical specifications
- Design system architecture with diagrams
- Select and justify tech stack
- Define non-functional requirements
- Create Architecture Decision Records (ADR)

## When to use me
Use after PRD is approved, before implementation begins.

## Steps
1. Read PRD from `docs/prd/`
2. Analyze functional and non-functional requirements
3. Design architecture:
   - High-level system diagram (Mermaid)
   - Component breakdown
   - Data flow diagram
4. Select tech stack with trade-off table
5. Define infrastructure requirements
6. Identify technical risks
7. Create ADRs for key decisions
8. Save to `docs/tech-spec/`

## Output Files
- `docs/tech-spec/tech-requirements.md` — Main tech spec
- `docs/tech-spec/architecture.md` — System architecture
- `docs/tech-spec/adr/` — Architecture Decision Records
- `docs/tech-spec/infrastructure.md` — Infra requirements
EOF

# ── API Design Skill ─────────────────────────────────────────
cat > .opencode/skills/api-design/SKILL.md << 'EOF'
---
name: api-design
description: Design RESTful/GraphQL APIs with OpenAPI specs, schemas, and error handling
license: MIT
compatibility: opencode
metadata:
  audience: backend-developers
  workflow: design
---

## What I do
- Design RESTful endpoints following Richardson Maturity Model
- Create OpenAPI 3.0 specifications (YAML)
- Define request/response JSON schemas
- Design authentication and authorization flows
- Plan pagination, filtering, rate limiting
- Define error handling strategy

## When to use me
Use when designing new APIs or refactoring existing ones.

## Steps
1. Read tech spec and PRD for requirements
2. Identify resources and relationships
3. Create resource CRUD matrix
4. Design each endpoint:
   - HTTP Method + Path
   - Auth requirements
   - Request params/body with validation rules
   - Response schema (200, 201, 400, 401, 403, 404, 429, 500)
   - Example curl request/response
5. Define error code taxonomy
6. Generate OpenAPI 3.0 YAML
7. Save to `docs/api/`

## Output Files
- `docs/api/api-design.md` — Human-readable API docs
- `docs/api/openapi.yaml` — Machine-readable OpenAPI spec
- `docs/api/api-conventions.md` — API design conventions
- `docs/api/error-codes.md` — Error code reference
EOF

# ── DB Schema Skill ──────────────────────────────────────────
cat > .opencode/skills/db-schema/SKILL.md << 'EOF'
---
name: db-schema
description: Design database schemas, ERDs, indexes, and migration plans
license: MIT
compatibility: opencode
metadata:
  audience: backend-developers dbas
  workflow: design
---

## What I do
- Design normalized database schemas (3NF)
- Create Entity Relationship Diagrams (Mermaid erDiagram)
- Define tables, columns, types, constraints
- Plan indexes for query performance
- Generate migration files
- Design for scalability

## When to use me
Use when designing new database schemas or planning migrations.

## Steps
1. Read tech spec and API design
2. Identify entities from resources
3. Define relationships (1:1, 1:N, M:N)
4. Create ERD using Mermaid syntax
5. Define each table:
   - Column name, type, nullable, default
   - Primary key, foreign keys
   - Unique constraints
   - Check constraints
6. Define indexes (B-tree, GIN, GiST)
7. Create migration plan (ordered)
8. Save to `docs/db/`

## Output Files
- `docs/db/schema-design.md` — Schema documentation
- `docs/db/erd.md` — Entity Relationship Diagram
- `docs/db/migrations/` — Migration files
- `docs/db/indexes.md` — Index strategy
EOF

# ── UI Wireframe Skill ───────────────────────────────────────
cat > .opencode/skills/ui-wireframe/SKILL.md << 'EOF'
---
name: ui-wireframe
description: Create UI/UX wireframes, user flows, component specs, and design tokens
license: MIT
compatibility: opencode
metadata:
  audience: frontend-developers designers
  workflow: design
---

## What I do
- Create user flow diagrams (Mermaid flowchart)
- Design ASCII wireframes for all screens
- Define component library with states
- Create design tokens (colors, typography, spacing)
- Specify responsive breakpoints
- Define accessibility requirements (WCAG 2.1 AA)

## When to use me
Use when designing UI for new features or redesigning existing screens.

## Steps
1. Read PRD for user personas and stories
2. Create user flow diagram
3. List all screens/pages needed
4. For each screen, create:
   - ASCII wireframe (desktop + mobile)
   - Component breakdown
   - Interaction notes
5. Define design tokens
6. Create component specification
7. Save to `docs/ui-ux/`

## Output Files
- `docs/ui-ux/user-flows.md` — User flow diagrams
- `docs/ui-ux/wireframes.md` — ASCII wireframes
- `docs/ui-ux/components.md` — Component library spec
- `docs/ui-ux/design-tokens.md` — Design system tokens
- `docs/ui-ux/accessibility.md` — A11y requirements
EOF

# ── Progress Report Skill ────────────────────────────────────
cat > .opencode/skills/progress-report/SKILL.md << 'EOF'
---
name: progress-report
description: Generate project progress reports, sprint summaries, and milestone tracking
license: MIT
compatibility: opencode
metadata:
  audience: project-managers developers
  workflow: tracking
---

## What I do
- Track implementation progress against PRD tasks
- Generate sprint reports with velocity metrics
- Create burndown summaries
- Identify blockers and risks
- Generate changelog from git history
- Calculate completion percentages per module

## When to use me
Use at end of sprint, before standups, or when stakeholders need updates.

## Steps
1. Read PRD for task list and milestones
2. Read tech spec for module breakdown
3. Run `git log --oneline --since="2 weeks ago"` for activity
4. Run `git diff --stat HEAD~20` for change summary
5. Scan `src/` directory structure for implementation status
6. Cross-reference with test coverage
7. Generate report:
   - Overall progress percentage
   - Per-module progress table
   - Completed items this sprint
   - Blockers and risks
   - Next sprint plan
8. Save to `docs/progress/`

## Output Files
- `docs/progress/current-sprint.md` — Active sprint status
- `docs/progress/changelog.md` — Running changelog
- `docs/progress/milestones.md` — Milestone tracker
- `docs/progress/risks.md` — Risk register
EOF

# ── Git Release Skill ────────────────────────────────────────
cat > .opencode/skills/git-release/SKILL.md << 'EOF'
---
name: git-release
description: Create consistent releases, changelogs, and version bumps following semver
license: MIT
compatibility: opencode
metadata:
  audience: maintainers
  workflow: release
---

## What I do
- Analyze commits since last tag
- Determine version bump (major/minor/patch)
- Generate changelog grouped by type
- Create release notes
- Provide copy-pasteable git commands

## When to use me
Use when preparing a tagged release.

## Steps
1. Run `git log --oneline $(git describe --tags --abbrev=0)..HEAD`
2. Categorize commits: feat, fix, docs, refactor, test, chore
3. Determine semver bump
4. Generate changelog
5. Provide release commands
EOF

# ── Migration Skill ──────────────────────────────────────────
cat > .opencode/skills/migration/SKILL.md << 'EOF'
---
name: migration
description: Generate database migration files for schema changes
license: MIT
compatibility: opencode
metadata:
  audience: backend-developers
  workflow: implementation
---

## What I do
- Generate up/down migration files
- Handle schema changes safely (add column, rename, drop)
- Create data migration scripts
- Ensure zero-downtime migrations

## When to use me
Use when modifying database schema in existing projects.

## Steps
1. Read current schema from `docs/db/`
2. Understand the required change
3. Generate migration with:
   - Up migration (apply change)
   - Down migration (rollback)
   - Data migration if needed
4. Validate migration safety
5. Update schema documentation
EOF

log "All skills created."

# ============================================================
#  5. PLUGINS — JavaScript event hooks
# ============================================================
info "Writing plugins..."

# ── Progress Tracker Plugin ──────────────────────────────────
cat > .opencode/plugins/progress-tracker.js << 'PLUGINJS'
/**
 * Progress Tracker Plugin
 * Tracks session activity and writes progress snapshots
 */
export const ProgressTrackerPlugin = async ({ project, client, $ }) => {
  const startTime = Date.now();
  let toolCallCount = 0;
  let fileEditCount = 0;

  return {
    "session.created": async (input) => {
      const timestamp = new Date().toISOString();
      try {
        await $`mkdir -p docs/progress/sessions`;
        await $`echo "Session ${input.sessionId} started at ${timestamp}" >> docs/progress/sessions/log.txt`;
      } catch (e) {
        // silently fail if directory doesn't exist yet
      }
    },

    "tool.execute.after": async (input, output) => {
      toolCallCount++;
      if (input.tool === "edit" || input.tool === "write") {
        fileEditCount++;
      }
    },

    "session.idle": async (input) => {
      const duration = Math.round((Date.now() - startTime) / 1000);
      const minutes = Math.floor(duration / 60);
      const timestamp = new Date().toISOString();

      const summary = [
        `## Session Summary — ${timestamp}`,
        `- Duration: ${minutes}m ${duration % 60}s`,
        `- Tool calls: ${toolCallCount}`,
        `- File edits: ${fileEditCount}`,
        `- Session ID: ${input.sessionId}`,
        ""
      ].join("\n");

      try {
        await $`echo ${summary} >> docs/progress/sessions/log.txt`;
      } catch (e) {
        // silently fail
      }
    }
  };
};
PLUGINJS

# ── Security Validator Plugin ────────────────────────────────
cat > .opencode/plugins/security-validator.js << 'PLUGINJS'
/**
 * Security Validator Plugin
 * Blocks dangerous commands and validates file operations
 */
export const SecurityValidatorPlugin = async ({ project, client, $ }) => {
  const DANGEROUS_COMMANDS = [
    "rm -rf /",
    "rm -rf ~",
    "mkfs",
    "dd if=",
    ":(){:|:&};:",
    "chmod -R 777 /",
    "curl | sh",
    "wget | sh",
    "eval(",
    "> /dev/sda"
  ];

  const SENSITIVE_FILES = [
    ".env",
    ".env.local",
    ".env.production",
    "credentials.json",
    "service-account.json",
    "id_rsa",
    "id_ed25519",
    ".npmrc",
    ".pypirc"
  ];

  return {
    "tool.execute.before": async (input, output) => {
      // Block dangerous bash commands
      if (input.tool === "bash" && output.args?.command) {
        const cmd = output.args.command.toLowerCase();
        for (const dangerous of DANGEROUS_COMMANDS) {
          if (cmd.includes(dangerous.toLowerCase())) {
            throw new Error(
              `🚨 SECURITY BLOCK: Dangerous command detected: "${dangerous}"\n` +
              `Command "${output.args.command}" has been blocked for safety.`
            );
          }
        }
      }

      // Warn about sensitive file edits
      if (input.tool === "edit" || input.tool === "write") {
        const filePath = output.args?.path || "";
        const fileName = filePath.split("/").pop();
        if (SENSITIVE_FILES.includes(fileName)) {
          console.warn(
            `⚠️  SECURITY WARNING: Editing sensitive file "${fileName}". ` +
            `Ensure no secrets are being committed.`
          );
        }
      }
    },

    "file.edited": async (input) => {
      const fileName = input.path?.split("/").pop() || "";
      if (SENSITIVE_FILES.includes(fileName)) {
        try {
          await $`echo "[SECURITY] Sensitive file edited: ${input.path} at $(date)" >> docs/progress/sessions/security-log.txt`;
        } catch (e) {
          // silently fail
        }
      }
    }
  };
};
PLUGINJS

# ── Session Logger Plugin ────────────────────────────────────
cat > .opencode/plugins/session-logger.js << 'PLUGINJS'
/**
 * Session Logger Plugin
 * Logs all session events for audit trail and debugging
 */
export const SessionLoggerPlugin = async ({ project, client, $ }) => {
  const logFile = "docs/progress/sessions/audit.log";

  const writeLog = async (event, data = {}) => {
    const timestamp = new Date().toISOString();
    const entry = JSON.stringify({ timestamp, event, ...data });
    try {
      await $`mkdir -p docs/progress/sessions`;
      await $`echo '${entry}' >> ${logFile}`;
    } catch (e) {
      // silently fail
    }
  };

  return {
    "session.created": async (input) => {
      await writeLog("session.created", { sessionId: input.sessionId });
    },

    "session.idle": async (input) => {
      await writeLog("session.idle", { sessionId: input.sessionId });
    },

    "session.compacted": async (input) => {
      await writeLog("session.compacted", { sessionId: input.sessionId });
    },

    "tool.execute.before": async (input, output) => {
      await writeLog("tool.execute.before", {
        tool: input.tool,
        args: output.args
      });
    },

    "tool.execute.after": async (input, output) => {
      await writeLog("tool.execute.after", {
        tool: input.tool,
        success: !output.error
      });
    },

    "permission.asked": async (input) => {
      await writeLog("permission.asked", {
        tool: input.tool,
        permission: input.permission
      });
    },

    "permission.replied": async (input) => {
      await writeLog("permission.replied", {
        tool: input.tool,
        decision: input.decision
      });
    },

    "file.edited": async (input) => {
      await writeLog("file.edited", { path: input.path });
    }
  };
};
PLUGINJS

log "All plugins created."

# ============================================================
#  6. COMMANDS — Custom slash commands
# ============================================================
info "Writing custom commands..."

cat > .opencode/commands/prd.md << 'EOF'
---
description: Generate a complete Product Requirements Document for a feature or product
agent: prd-writer
model: anthropic/claude-sonnet-4-5
---

Generate a comprehensive PRD for the requested feature/product.

## Instructions
1. If no feature is specified, ask the user what they want to build
2. Read any existing docs in `docs/prd/` for context
3. Generate complete PRD following the PRD skill template
4. Include user personas, user stories, acceptance criteria
5. Prioritize features using MoSCoW
6. Define measurable success metrics
7. Save to `docs/prd/[feature-name].md`
8. Update `docs/prd/README.md` with index of all PRDs

## Output Checklist
- [ ] Executive Summary
- [ ] Problem Statement
- [ ] User Personas (min 2)
- [ ] User Stories (min 5 per persona)
- [ ] Acceptance Criteria (Given/When/Then)
- [ ] Feature Priority Matrix
- [ ] Success Metrics (quantifiable)
- [ ] Out of Scope
- [ ] Timeline & Milestones
- [ ] Open Questions
EOF

cat > .opencode/commands/tech-spec.md << 'EOF'
---
description: Generate technical specification and architecture from PRD
agent: tech-architect
model: anthropic/claude-sonnet-4-5
---

Convert the PRD into a detailed technical specification.

## Instructions
1. Read the latest PRD from `docs/prd/`
2. Design system architecture with Mermaid diagrams
3. Select tech stack with trade-off analysis table
4. Define system components and their interactions
5. Create data flow diagrams
6. Define non-functional requirements (performance, scalability, security)
7. Create Architecture Decision Records for key choices
8. Identify technical risks and mitigations
9. Save to `docs/tech-spec/`

## Output Checklist
- [ ] Architecture Overview (Mermaid diagram)
- [ ] Tech Stack Selection (with justification)
- [ ] Component Diagram
- [ ] Data Flow Diagram
- [ ] Infrastructure Requirements
- [ ] Non-Functional Requirements
- [ ] Security Architecture
- [ ] ADRs (min 3 key decisions)
- [ ] Risk Register
- [ ] Implementation Phases
EOF

cat > .opencode/commands/api-design.md << 'EOF'
---
description: Design complete API with endpoints, schemas, and OpenAPI spec
agent: api-designer
model: anthropic/claude-sonnet-4-5
---

Design the complete API for the project.

## Instructions
1. Read PRD from `docs/prd/` and tech spec from `docs/tech-spec/`
2. Identify all resources and their relationships
3. Design CRUD endpoints for each resource
4. Define authentication flow (JWT/OAuth/API Key)
5. Create request/response schemas with validation rules
6. Define error handling strategy with error codes
7. Plan pagination, filtering, sorting
8. Generate OpenAPI 3.0 YAML specification
9. Save to `docs/api/`

## Output Checklist
- [ ] Resource Map (CRUD matrix)
- [ ] Authentication Flow Diagram
- [ ] Endpoint Specifications (all routes)
- [ ] Request/Response Schemas
- [ ] Error Code Reference
- [ ] Rate Limiting Policy
- [ ] OpenAPI 3.0 YAML file
- [ ] Example Requests (curl)
- [ ] API Versioning Strategy
EOF

cat > .opencode/commands/db-design.md << 'EOF'
---
description: Design database schema with ERD, migrations, and indexes
agent: db-designer
model: anthropic/claude-sonnet-4-5
---

Design the complete database schema for the project.

## Instructions
1. Read PRD, tech spec, and API design from `docs/`
2. Identify all entities and relationships
3. Design normalized schema (3NF)
4. Create ERD using Mermaid erDiagram syntax
5. Define all tables with columns, types, constraints
6. Plan indexes for common query patterns
7. Generate migration files (up + down)
8. Define seed data strategy
9. Save to `docs/db/`

## Output Checklist
- [ ] ERD (Mermaid erDiagram)
- [ ] Table Definitions (all columns, types, constraints)
- [ ] Relationship Map
- [ ] Index Strategy
- [ ] Migration Files (ordered)
- [ ] Seed Data Plan
- [ ] Query Performance Notes
- [ ] Backup Strategy
EOF

cat > .opencode/commands/ui-design.md << 'EOF'
---
description: Create UI/UX wireframes, user flows, and design system
agent: ui-ux-designer
model: anthropic/claude-sonnet-4-5
---

Design the complete UI/UX for the project.

## Instructions
1. Read PRD from `docs/prd/` for user personas and stories
2. Create user flow diagrams (Mermaid flowchart)
3. List all screens/pages needed
4. Create ASCII wireframes for each screen (desktop + mobile)
5. Define component library with all states
6. Create design tokens (colors, typography, spacing, shadows)
7. Specify responsive breakpoints
8. Define accessibility requirements (WCAG 2.1 AA)
9. Save to `docs/ui-ux/`

## Output Checklist
- [ ] User Flow Diagrams
- [ ] Sitemap / Page Inventory
- [ ] Wireframes (min 5 key screens)
- [ ] Component Library Spec
- [ ] Design Tokens
- [ ] Responsive Breakpoints
- [ ] Accessibility Checklist
- [ ] Interaction Specifications
EOF

cat > .opencode/commands/progress.md << 'EOF'
---
description: Generate comprehensive progress report with metrics and milestones
agent: progress-tracker
model: anthropic/claude-haiku-4-5
---

Generate a detailed project progress report.

## Instructions
1. Read PRD from `docs/prd/` for task list
2. Read tech spec from `docs/tech-spec/` for modules
3. Run `git log --oneline -30` for recent activity
4. Run `git diff --stat HEAD~20` for change summary
5. Run `git log --format="%h %s" --since="1 week ago"` for weekly progress
6. Scan `src/` for implementation status
7. Check test coverage if available
8. Generate report with:
   - Overall completion percentage
   - Per-module progress table
   - Completed items this week
   - Blockers and risks
   - Next steps
9. Save to `docs/progress/`

## Output Checklist
- [ ] Overall Progress %
- [ ] Module Progress Table
- [ ] Sprint Summary
- [ ] Git Activity Summary
- [ ] Blockers & Risks
- [ ] Next Sprint Plan
- [ ] Milestone Status
- [ ] Velocity Metrics
EOF

cat > .opencode/commands/review.md << 'EOF'
---
description: Perform comprehensive code review on changed files
agent: code-reviewer
model: anthropic/claude-sonnet-4-5
---

Review all recently changed code.

## Instructions
1. Run `git diff --name-only HEAD~5` to find changed files
2. Read each changed file
3. Review for:
   - Code correctness and logic errors
   - Security vulnerabilities
   - Performance issues
   - Code style and best practices
   - Error handling
   - Test coverage gaps
4. Generate review report with severity ratings
5. Provide specific code improvement suggestions with examples

## Output Format
For each file:
- ✅ GOOD: What's done well
- ⚠️ SUGGESTION: Improvements with code examples
- ❌ CRITICAL: Must-fix issues
- 📊 METRICS: Complexity score
EOF

cat > .opencode/commands/test.md << 'EOF'
---
description: Run test suite, analyze failures, and write missing tests
agent: test-writer
model: anthropic/claude-sonnet-4-5
---

Run and analyze the complete test suite.

## Instructions
1. Detect testing framework (Jest/Vitest/Pytest/Go test)
2. Run full test suite with coverage
3. If tests fail:
   - Identify root cause
   - Suggest fix
   - Implement fix
4. Identify untested files/functions
5. Write missing tests for critical paths
6. Re-run tests to verify
7. Report final coverage

## Output Checklist
- [ ] Test Results Summary
- [ ] Failed Tests Analysis
- [ ] Coverage Report
- [ ] Missing Tests List
- [ ] New Tests Written
- [ ] Final Coverage %
EOF

cat > .opencode/commands/audit.md << 'EOF'
---
description: Perform security audit on the entire codebase
agent: security-auditor
model: anthropic/claude-sonnet-4-5
---

Perform comprehensive security audit.

## Instructions
1. Scan all source files in `src/`
2. Check OWASP Top 10 vulnerabilities
3. Review authentication and authorization
4. Analyze input validation
5. Check for hardcoded secrets
6. Review dependency security
7. Check configuration security
8. Generate audit report with remediation steps
9. Save to `docs/progress/security-audit.md`

## Output Format
| # | Finding | Severity | Location | Remediation |
|---|---------|----------|----------|-------------|
EOF

cat > .opencode/commands/deploy.md << 'EOF'
---
description: Safe deployment workflow with pre-flight checks
agent: build
model: anthropic/claude-sonnet-4-5
---

Execute safe deployment workflow.

## Instructions
1. Pre-flight checks:
   - Run `/test` — all tests must pass
   - Run `/review` — no critical issues
   - Run `/audit` — no critical vulnerabilities
   - Build production bundle
2. Deployment:
   - Create git tag
   - Push to remote
   - Deploy to staging (if configured)
   - Smoke test
   - Deploy to production (ask for confirmation)
3. Post-deployment:
   - Monitor error logs
   - Verify health endpoints
   - Update changelog
EOF

cat > .opencode/commands/release.md << 'EOF'
---
description: Create release with changelog and version bump
agent: build
model: anthropic/claude-sonnet-4-5
---

Create a new release following semver.

## Instructions
1. Run `git log --oneline $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD`
2. Categorize commits (feat/fix/docs/refactor/test/chore)
3. Determine version bump (major/minor/patch)
4. Generate changelog
5. Update version in package.json / pyproject.toml / etc.
6. Create git tag
7. Generate release notes
8. Save changelog to `docs/progress/changelog.md`
EOF

cat > .opencode/commands/full-pipeline.md << 'EOF'
---
description: Run the complete project pipeline from PRD to deployment
agent: plan
model: anthropic/claude-sonnet-4-5
---

Execute the full project pipeline. This is the master workflow.

## Pipeline Steps

### Phase 1: Product Definition
1. `/prd` — Generate Product Requirements Document
2. Review PRD with user, iterate until approved

### Phase 2: Technical Design
3. `/tech-spec` — Generate technical specification from PRD
4. `/api-design` — Design API endpoints and schemas
5. `/db-design` — Design database schema and migrations
6. `/ui-design` — Create UI/UX wireframes and design system

### Phase 3: Implementation
7. `@build` — Implement based on all design docs
8. `/test` — Write and run tests

### Phase 4: Quality Assurance
9. `/review` — Code review
10. `/audit` — Security audit
11. Fix all critical and high issues

### Phase 5: Release
12. `/progress` — Generate progress report
13. `/release` — Create release with changelog
14. `/deploy` — Deploy to production

## Instructions
Execute each phase sequentially. Pause after each phase for user approval before proceeding. Save all outputs to the appropriate `docs/` subdirectory.
EOF

cat > .opencode/commands/init-project.md << 'EOF'
---
description: Initialize a new project with complete scaffolding
agent: build
model: anthropic/claude-sonnet-4-5
---

Initialize a new project from scratch.

## Instructions
1. Ask user for:
   - Project name and description
   - Tech stack preference
   - Project type (web app, API, CLI, library, mobile)
2. Initialize project:
   - Package manager setup (npm/yarn/pnpm/pip/go mod)
   - Folder structure
   - Core dependencies
   - Config files (tsconfig, eslint, prettier, etc.)
   - Testing framework setup
   - CI/CD template (GitHub Actions)
   - Docker setup (Dockerfile + docker-compose)
   - .gitignore
   - README.md
3. Run `/prd` to start product definition
4. Initial git commit

## Output Checklist
- [ ] Project initialized
- [ ] Dependencies installed
- [ ] Linting configured
- [ ] Testing configured
- [ ] CI/CD configured
- [ ] Docker configured
- [ ] README created
- [ ] Initial commit made
EOF

cat > .opencode/commands/analyze.md << 'EOF'
---
description: Deep analysis of existing project structure, quality, and improvement areas
agent: plan
model: anthropic/claude-sonnet-4-5
---

Perform deep analysis of the existing project.

## Instructions
1. Scan project structure:
   - `find . -type f -name "*.js" -o -name "*.ts" -o -name "*.py" | head -50`
   - `wc -l src/**/*` (line counts)
   - `git log --oneline -20` (recent history)
2. Analyze:
   - Code organization and architecture
   - Dependency health
   - Test coverage
   - Documentation completeness
   - Security posture
   - Performance patterns
3. Generate report:
   - Project overview
   - Strengths
   - Weaknesses and improvement areas
   - Recommended actions (prioritized)
   - Estimated effort for each action
4. Save to `docs/progress/project-analysis.md`
EOF

log "All commands created."

# ============================================================
#  7. SUPPORTING FILES
# ============================================================
info "Writing supporting files..."

# ── CONTRIBUTING.md ──────────────────────────────────────────
cat > CONTRIBUTING.md << 'EOF'
# Contributing Guide

## Development Workflow

### 1. Planning Phase
- Run `/prd` to create or update Product Requirements
- Run `/tech-spec` to generate technical specification
- Run `/api-design` for API changes
- Run `/db-design` for database changes
- Run `/ui-design` for UI changes

### 2. Implementation Phase
- Use `@build` agent for coding
- Follow the architecture defined in `docs/tech-spec/`
- Follow API contracts in `docs/api/`
- Follow database schema in `docs/db/`
- Follow UI specs in `docs/ui-ux/`

### 3. Quality Phase
- Run `/test` before committing
- Run `/review` before pushing
- Run `/audit` before releasing

### 4. Release Phase
- Run `/progress` to check milestone status
- Run `/release` to create versioned release
- Run `/deploy` for deployment

## Code Style
- Follow existing patterns in the codebase
- Write meaningful commit messages (conventional commits)
- Keep functions small and focused
- Add comments for complex logic
- Write tests for all new functionality

## Commit Convention
```
feat: add user authentication
fix: resolve JWT token expiration bug
docs: update API documentation
test: add unit tests for auth module
refactor: simplify database query
chore: update dependencies
```
EOF

# ── docs/README.md ───────────────────────────────────────────
cat > docs/README.md << 'EOF'
# Project Documentation

## 📋 Documents Index

### Product
- [PRDs](prd/) — Product Requirements Documents
- [Progress](progress/) — Sprint reports and tracking

### Technical
- [Tech Spec](tech-spec/) — Architecture and technical requirements
- [API Design](api/) — API endpoints and OpenAPI specs
- [Database](db/) — Schema, ERD, and migrations
- [UI/UX](ui-ux/) — Wireframes, components, and design tokens

## 🚀 Quick Commands

| Command | Description |
|---------|-------------|
| `/prd` | Generate PRD |
| `/tech-spec` | Generate tech spec |
| `/api-design` | Design API |
| `/db-design` | Design database |
| `/ui-design` | Design UI/UX |
| `/progress` | Track progress |
| `/test` | Run tests |
| `/review` | Code review |
| `/audit` | Security audit |
| `/deploy` | Deploy |
| `/release` | Create release |
| `/full-pipeline` | Run everything |
| `/init-project` | Init new project |
| `/analyze` | Analyze existing |
EOF

# ── Placeholder docs ─────────────────────────────────────────
cat > docs/prd/README.md << 'EOF'
# Product Requirements Documents

Run `/prd` to generate a new PRD.

## Index
_No PRDs yet. Run `/prd [feature name]` to create one._
EOF

cat > docs/tech-spec/tech-requirements.md << 'EOF'
# Technical Requirements

> This file is auto-loaded as project instructions.
> Run `/tech-spec` to generate the full technical specification.

## Status: Not yet generated
EOF

cat > docs/api/api-conventions.md << 'EOF'
# API Conventions

> This file is auto-loaded as project instructions.
> Run `/api-design` to generate the full API specification.

## General Rules
- Use RESTful conventions
- JSON request/response bodies
- Bearer token authentication
- Pagination: `?page=1&limit=20`
- Filtering: `?status=active&role=admin`
- Sorting: `?sort=created_at&order=desc`
- Error format: `{ "error": { "code": "NOT_FOUND", "message": "..." } }`
EOF

# ── .gitignore additions ─────────────────────────────────────
if [ -f ".gitignore" ]; then
    if ! grep -q "opencode" .gitignore 2>/dev/null; then
        cat >> .gitignore << 'EOF'

# OpenCode
.opencode.json
docs/progress/sessions/
EOF
        log "Updated .gitignore"
    fi
else
    cat > .gitignore << 'EOF'
# Dependencies
node_modules/
__pycache__/
venv/

# Build
dist/
build/
*.o
*.exe

# Environment
.env
.env.local
.env.production

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# OpenCode
.opencode.json
docs/progress/sessions/
EOF
    log "Created .gitignore"
fi

# ============================================================
#  8. SUMMARY
# ============================================================
echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║                  ✅  SETUP COMPLETE                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}Created:${NC}"
echo "  📄 opencode.json              — Main configuration"
echo "  📁 .opencode/agents/          — $(ls .opencode/agents/ | wc -l | tr -d ' ') agent definitions"
echo "  📁 .opencode/commands/        — $(ls .opencode/commands/ | wc -l | tr -d ' ') custom commands"
echo "  📁 .opencode/skills/          — $(ls .opencode/skills/ | wc -l | tr -d ' ') skill packs"
echo "  📁 .opencode/plugins/         — $(ls .opencode/plugins/ | wc -l | tr -d ' ') event plugins"
echo "  📁 prompts/                   — $(ls prompts/ | wc -l | tr -d ' ') system prompts"
echo "  📁 docs/                      — Documentation structure"
echo ""
echo -e "${CYAN}Available Commands:${NC}"
echo "  /prd            Generate Product Requirements Document"
echo "  /tech-spec      Generate Technical Specification"
echo "  /api-design     Design API Endpoints & OpenAPI Spec"
echo "  /db-design      Design Database Schema & ERD"
echo "  /ui-design      Create UI/UX Wireframes & Design System"
echo "  /progress       Generate Progress Report"
echo "  /test           Run Tests & Write Missing Tests"
echo "  /review         Code Review"
echo "  /audit          Security Audit"
echo "  /deploy         Safe Deployment Workflow"
echo "  /release        Create Release & Changelog"
echo "  /full-pipeline  Run Complete Pipeline (PRD → Deploy)"
echo "  /init-project   Initialize New Project"
echo "  /analyze        Analyze Existing Project"
echo ""
echo -e "${CYAN}Available Agents:${NC}"
echo "  @build           Senior Developer (primary)"
echo "  @plan            Tech Lead / Planner (primary)"
echo "  @prd-writer      Product Manager"
echo "  @tech-architect  System Architect"
echo "  @api-designer    API Specialist"
echo "  @db-designer     Database Architect"
echo "  @ui-ux-designer  UI/UX Designer"
echo "  @progress-tracker Project Manager"
echo "  @code-reviewer   Code Reviewer"
echo "  @test-writer     QA Engineer"
echo "  @security-auditor Security Engineer"
echo "  @docs-writer     Technical Writer"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
if [ "$PROJECT_TYPE" = "existing" ]; then
    echo "  1. Run: opencode"
    echo "  2. Type: /analyze"
    echo "  3. Type: /prd [your next feature]"
    echo "  4. Type: /full-pipeline"
else
    echo "  1. Run: opencode"
    echo "  2. Type: /init-project"
    echo "  3. Type: /prd [your product idea]"
    echo "  4. Type: /full-pipeline"
fi
echo ""