#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — functions.sh
# Librería de funciones puras. No ejecuta nada al ser sourceado.
# Cada función hace 1 cosa. Sin side effects.
# ═══════════════════════════════════════════════════════════════

# ── Logging ────────────────────────────────────────────────────

agent_log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
  [ -n "${_LOG_FILE:-}" ] && printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$_LOG_FILE"
}

# ── Lock / Unlock ──────────────────────────────────────────────
# Impide que 2 instancias del mismo módulo corran en paralelo.
# Usa flock (non-blocking). Si el lock ya existe, sale con 0.

agent_lock() {
  local name="${1:?agent_lock requiere nombre}"
  _LOCK_FILE="/tmp/auto-${name}.lock"
  exec 9>"$_LOCK_FILE"
  flock -n 9 || {
    agent_log "Lock activo: $_LOCK_FILE — otra instancia corriendo. Saliendo."
    exit 0
  }
}

# ── Notificación (toast Windows vía PowerShell) ────────────────
# No-op si PowerShell no está disponible (Linux nativo, macOS).

agent_notify() {
  local title="${1:-auto-agents}"
  local body="${2:-}"
  local summary="${3:-$title $body}"
  local ps="${NOTIFY_PS:-/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe}"
  local script="${NOTIFY_SCRIPT:-}"

  [ -f "$ps" ] || return 0
  [ -n "$script" ] || return 0

  "$ps" -Command "
[System.IO.File]::WriteAllText('$(dirname "$script")\\auto-agents-summary.txt', '$summary', [System.Text.Encoding]::UTF8)
" > /dev/null 2>&1 || true

  "$ps" -ExecutionPolicy Bypass -File "$script" \
    -Title "$title" -Body "$body" > /dev/null 2>&1 &
}

# ── Pre-filtro ─────────────────────────────────────────────────
# Recibe patterns (1 por línea). Si TODOS los archivos cambiados
# matchean algún pattern, sale con 0 (skip). Sino retorna 1.
#
# Uso:
#   agent_prefilter "docs/**" "*.md" ".claude/**" && exit 0

agent_prefilter() {
  local changed
  changed=$(agent_git_changed_files)
  [ -z "$changed" ] && return 0  # sin cambios = skip

  local file match_all=true
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local matched=false
    for pattern in "$@"; do
      case "$file" in
        $pattern) matched=true; break ;;
      esac
    done
    if [ "$matched" = false ]; then
      match_all=false
      break
    fi
  done <<< "$changed"

  [ "$match_all" = true ]
}

# ── Git helpers ────────────────────────────────────────────────

agent_git_changed_files() {
  git -C "${PROJECT_DIR:-.}" diff HEAD~1..HEAD --name-only 2>/dev/null || echo ""
}

agent_git_last_commit() {
  git -C "${PROJECT_DIR:-.}" log -1 --format='%h|%s' 2>/dev/null || echo "|"
}

agent_git_last_hash() {
  git -C "${PROJECT_DIR:-.}" log -1 --format='%h' 2>/dev/null || echo ""
}

# ── Invocar agente Claude ──────────────────────────────────────
# Escribe el prompt a un archivo temporal, lanza claude -p,
# captura el log en stream-json.
#
# Requiere: CLAUDE_BIN, MODEL, TIMEOUT, _LOG_FILE, PROJECT_DIR

agent_run() {
  local prompt="$1"
  local timeout="${TIMEOUT:-600}"
  local model="${MODEL:-opus}"
  local claude="${CLAUDE_BIN:-$(command -v claude || echo /home/edu/.local/bin/claude)}"
  local allowed_tools="${ALLOWED_TOOLS:-Bash Read Write Edit Grep Glob}"

  local prompt_file
  prompt_file=$(mktemp /tmp/auto-agents-prompt.XXXXXX)
  echo "$prompt" > "$prompt_file"

  agent_log "Lanzando agente ($model, timeout ${timeout}s)..."

  cat "$prompt_file" | timeout "$timeout" "$claude" \
    -p \
    --model "$model" \
    --verbose \
    --output-format stream-json \
    --allowedTools $allowed_tools \
    > "$_LOG_FILE" 2>&1

  local exit_code=$?
  rm -f "$prompt_file"

  if [ $exit_code -eq 124 ]; then
    agent_log "TIMEOUT (${timeout}s)"
  elif [ $exit_code -ne 0 ]; then
    agent_log "Agente terminó con error (exit $exit_code)"
  else
    agent_log "Agente completado OK"
  fi

  return $exit_code
}

# ── Parsear stats del stream-json ──────────────────────────────
# Lee el log y extrae tokens y costo del resultado final.
# Imprime: "TOKENS|COST" (ej: "45230|1.12")

agent_parse_stats() {
  local log_file="${1:-$_LOG_FILE}"
  python3 -c "
import json, sys
with open('$log_file') as f:
    for line in f:
        try:
            d = json.loads(line.strip())
            if d.get('type') == 'result':
                tokens = d.get('total_tokens', 0)
                cost = d.get('total_cost_usd', 0)
                print(f'{tokens}|{cost:.2f}')
                sys.exit(0)
        except: pass
print('0|0.00')
" 2>/dev/null || echo "0|0.00"
}

# ── Header estándar para reportes ──────────────────────────────

agent_report_header() {
  local module="${1:-unknown}"
  local project="${PROJECT_NAME:-unknown}"
  local commit_info
  commit_info=$(agent_git_last_commit)
  local hash="${commit_info%%|*}"
  local msg="${commit_info#*|}"

  cat <<EOF
# ${module^^} Report — $project
Generado: $(date '+%Y-%m-%d %H:%M') | Commit: \`$hash\` — $msg
EOF
}

# ── Inicializar log ────────────────────────────────────────────

agent_init_log() {
  local module="${1:-agent}"
  local log_dir="${PROJECT_DIR:-.}/${LOG_DIR:-logs/ci}"
  mkdir -p "$log_dir"
  _LOG_FILE="$log_dir/${module}-$(date '+%Y%m%d_%H%M%S').log"
  touch "$_LOG_FILE"
}
