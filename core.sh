#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — core.sh
# Orquestador. Carga config, functions, y lanza el módulo.
# No tiene lógica de negocio.
#
# Uso: ./core.sh <módulo> [proyecto_dir]
#   ./core.sh auto-doc /home/edu/p/blogos.dev
#   ./core.sh auto-test                         # usa PWD
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

AA_ROOT="$(cd "$(dirname "$0")" && pwd)"
MODULE_NAME="${1:?Uso: core.sh <módulo> [proyecto_dir]}"
PROJECT_DIR="${2:-$(pwd)}"
export PROJECT_DIR

# ── Cargar functions ───────────────────────────────────────────
source "$AA_ROOT/functions.sh"

# ── Cargar config del proyecto ─────────────────────────────────
# .env base (obligatorio para auto-agents, opcional para el proyecto)
[ -f "$PROJECT_DIR/.env" ] && set -a && source "$PROJECT_DIR/.env" && set +a

# .env.<módulo> override (opcional)
MODULE_SHORT="${MODULE_NAME#auto-}"
[ -f "$PROJECT_DIR/.env.${MODULE_SHORT}" ] && set -a && source "$PROJECT_DIR/.env.${MODULE_SHORT}" && set +a

# ── Defaults ───────────────────────────────────────────────────
export PROJECT_NAME="${PROJECT_NAME:-$(basename "$PROJECT_DIR")}"
export STACK="${STACK:-bash}"
export MODEL="${MODEL:-opus}"
export TIMEOUT="${TIMEOUT:-600}"
export LOG_DIR="${LOG_DIR:-logs/ci}"
export CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude || echo /home/edu/.local/bin/claude)}"

# ── Validar y lanzar módulo ────────────────────────────────────
MODULE_FILE="$AA_ROOT/modules/${MODULE_NAME}.sh"
if [ ! -f "$MODULE_FILE" ]; then
  echo "Módulo no encontrado: $MODULE_NAME"
  echo "Disponibles:"
  ls -1 "$AA_ROOT/modules/"*.sh 2>/dev/null | xargs -I{} basename {} .sh
  exit 1
fi

# Inicializar log
agent_init_log "$MODULE_SHORT"
agent_log "═══ $MODULE_NAME — $PROJECT_NAME ($STACK) ═══"
agent_log "Proyecto: $PROJECT_DIR"
agent_log "Modelo: $MODEL | Timeout: ${TIMEOUT}s"

# Lanzar
source "$MODULE_FILE"
