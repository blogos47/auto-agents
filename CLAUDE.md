# auto-agents

## Language
- All commits, README, docs, and code comments in **English**
- This is a public open-source project — English is the default language

## Stack
- Pure Bash (POSIX-compatible where possible)
- No external dependencies beyond Claude Code CLI

## Conventions
- Conventional commits: `feat:`, `fix:`, `docs:`, `chore:`
- Keep modules independent — each auto-X should work standalone
- Core functions in `functions.sh`, orchestration in `core.sh`
- No downloads, no curl, no external fetches in scripts
