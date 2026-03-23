#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — core.sh
# Orchestrator. Loads config, functions, i18n, and runs module.
# No business logic here.
#
# Usage: ./core.sh <module> [project_dir]
#   ./core.sh auto-doc /home/edu/p/blogos.dev
#   ./core.sh auto-test                         # uses PWD
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

AA_ROOT="$(cd "$(dirname "$0")" && pwd)"
MODULE_NAME="${1:?Usage: core.sh <module> [project_dir]}"
PROJECT_DIR="${2:-$(pwd)}"
export PROJECT_DIR

# ── Load project config ────────────────────────────────────────
[ -f "$PROJECT_DIR/.env" ] && set -a && source "$PROJECT_DIR/.env" && set +a

# Per-module override (.env.test, .env.sec, .env.doc)
MODULE_SHORT="${MODULE_NAME#auto-}"
[ -f "$PROJECT_DIR/.env.${MODULE_SHORT}" ] && set -a && source "$PROJECT_DIR/.env.${MODULE_SHORT}" && set +a

# ── Defaults ───────────────────────────────────────────────────
export PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_DIR")}"
export STACK="${STACK:-bash}"
export MODEL="${MODEL:-opus}"
export TIMEOUT="${TIMEOUT:-600}"
export LOG_DIR="${LOG_DIR:-logs/ci}"
export LANG="${LANG:-en}"
export CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || echo /home/edu/.local/bin/claude)}"

# ── Load functions + i18n ──────────────────────────────────────
source "$AA_ROOT/functions.sh"

LANG_FILE="$AA_ROOT/i18n/${LANG}.sh"
[ -f "$LANG_FILE" ] || LANG_FILE="$AA_ROOT/i18n/en.sh"
source "$LANG_FILE"

# ── Validate and run module ────────────────────────────────────
MODULE_FILE="$AA_ROOT/modules/${MODULE_NAME}.sh"
if [ ! -f "$MODULE_FILE" ]; then
  echo "Module not found: $MODULE_NAME"
  echo "Available:"
  ls -1 "$AA_ROOT/modules/"*.sh 2>/dev/null | xargs -I{} basename {} .sh
  exit 1
fi

# Initialize log
agent_init_log "$MODULE_SHORT"
agent_log "═══ $MODULE_NAME — $PROJECT_NAME ($STACK) ═══"
agent_log "Project: $PROJECT_DIR"
agent_log "Model: $MODEL | Timeout: ${TIMEOUT}s | Lang: $LANG"

# Run
source "$MODULE_FILE"
