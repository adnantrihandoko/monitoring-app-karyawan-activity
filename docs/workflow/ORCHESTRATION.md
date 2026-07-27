# Workflow Orchestration Guide

## Agent Orchestration

### When to Use Which Agent

#### Planning Phase
- Planner: Semua keputusan arsitektur
- Analyst: Business requirements

#### Design Phase
- Designer: UI/UX design
- Planner: Technical design
- DBA: Database design

#### Implementation Phase
- Builder: Semua implementasi kode
- DBA: Database implementation
- Security: Security implementation

#### Quality Phase
- Reviewer: Code review
- Tester: Testing dan QA
- Security: Security audit

#### Operations Phase
- DevOps: Deployment
- Documenter: Dokumentasi

## Workflow Triggers

### New Feature Flow
1. /buat-prd → Planner creates PRD
2. /desain-api → Planner designs API
3. /desain-database → DBA designs database
4. /desain-uiux → Designer creates UI/UX
5. /buat-tech-spec → Planner creates tech spec
6. /sprint-planning → Planner plans sprint
7. /buat-component → Builder implements
8. /review-kode → Reviewer reviews
9. /buat-test → Tester creates tests
10. /deploy → DevOps deploys
11. /dokumentasi-api → Documenter documents

## Quality Gates
1. Code Review - Reviewer approves
2. Security Review - Security approves
3. Deployment Ready - All gates passed
