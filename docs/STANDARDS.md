# Coding Standards

## General Principles
1. Readability - Kode mudah dibaca
2. Maintainability - Kode mudah dimaintain
3. Simplicity - Kode sesederhana mungkin
4. Consistency - Kode konsisten
5. Testability - Kode mudah ditest

## Naming Conventions
- Variables: camelCase (JS/TS), snake_case (Python)
- Functions: verb phrases, descriptive
- Classes: PascalCase
- Files: kebab-case

## Code Style
- Gunakan formatter (Prettier, Black)
- Konsisten indentation
- Max line length: 100 chars
- Tulis why, bukan what

## Error Handling
- Selalu handle errors
- Gunakan custom errors
- Log errors dengan konteks
- Jangan swallow errors

## Testing
- Test untuk setiap fitur baru
- Test deterministic
- Test edge cases
- Mock external dependencies

## Security
- Validasi semua input
- Sanitize output
- Parameterized queries
- Jangan hardcode secrets
