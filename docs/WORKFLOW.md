# Workflow Documentation

## Branch Strategy
```
main (production)
├── develop (development)
├── feature/[name] (features)
├── fix/[name] (bug fixes)
├── release/[version] (releases)
└── hotfix/[name] (hotfixes)
```

## Commit Convention
```
<type>(<scope>): <subject>

Types:
- feat: New feature
- fix: Bug fix
- refactor: Code refactoring
- test: Adding tests
- docs: Documentation
- chore: Maintenance
```

## Pull Request Process
1. Create feature branch
2. Make changes
3. Write tests
4. Update documentation
5. Create PR
6. Code review
7. Address feedback
8. Merge

## Sprint Workflow
- Daily: Standup, update status
- Weekly: Sprint review, demo
- Bi-weekly: Planning, retrospective
