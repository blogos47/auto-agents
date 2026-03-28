#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — functions.sh
# Pure function library. No side effects when sourced.
# Each function does one thing. Auditable in 10 minutes.
# ═══════════════════════════════════════════════════════════════

# ── Logging ────────────────────────────────────────────────────

agent_log() {
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1"
  [ -n "${_LOG_FILE:-}" ] && printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" >> "$_LOG_FILE"
}

# ── Lock / Unlock ──────────────────────────────────────────────
# Prevents 2 instances of the same module from running in parallel.
# Uses flock (non-blocking). If lock exists, exits with 0.

agent_lock() {
  local name="${1:?agent_lock requires a name}"
  _LOCK_FILE="/tmp/auto-${name}.lock"
  exec 9>"$_LOCK_FILE"
  flock -n 9 || {
    # shellcheck disable=SC2059
    agent_log "$(printf "$MSG_LOCK_ACTIVE" "$_LOCK_FILE")"
    exit 0
  }
}

# ── Notification (Windows toast via PowerShell) ────────────────
# No-op if PowerShell is not available (native Linux, macOS).

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

# ── Pre-filter ─────────────────────────────────────────────────
# Receives patterns (1 per arg). If ALL changed files match
# some pattern, returns 0 (skip). Otherwise returns 1.
#
# Usage:
#   agent_prefilter "docs/**" "*.md" ".claude/**" && exit 0

agent_prefilter() {
  local changed
  changed=$(agent_git_changed_files)
  [ -z "$changed" ] && return 0

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

# ── Run Claude agent ───────────────────────────────────────────
# Writes prompt to temp file, launches claude -p, captures log.
#
# Requires: CLAUDE_BIN, MODEL, TIMEOUT, _LOG_FILE, PROJECT_DIR

agent_run() {
  local prompt="$1"
  local timeout="${TIMEOUT:-600}"
  local model="${MODEL:-opus}"
  local claude="${CLAUDE_BIN:-$(command -v claude || echo /home/edu/.local/bin/claude)}"
  local allowed_tools="${ALLOWED_TOOLS:-Bash Read Write Edit Grep Glob}"

  local prompt_file
  prompt_file=$(mktemp /tmp/auto-agents-prompt.XXXXXX)
  echo "$prompt" > "$prompt_file"

  # shellcheck disable=SC2059
  agent_log "$(printf "$MSG_AGENT_LAUNCHING" "$model" "$timeout")"

  cat "$prompt_file" | timeout "$timeout" "$claude" \
    -p \
    --model "$model" \
    --effort max \
    --verbose \
    --output-format stream-json \
    --allowedTools $allowed_tools \
    > "$_LOG_FILE" 2>&1

  local exit_code=$?
  rm -f "$prompt_file"

  if [ $exit_code -eq 124 ]; then
    # shellcheck disable=SC2059
    agent_log "$(printf "$MSG_AGENT_TIMEOUT" "$timeout")"
  elif [ $exit_code -ne 0 ]; then
    # shellcheck disable=SC2059
    agent_log "$(printf "$MSG_AGENT_ERROR" "$exit_code")"
  else
    agent_log "$MSG_AGENT_OK"
  fi

  return $exit_code
}

# ── Parse stats from stream-json ───────────────────────────────
# Reads the log and extracts tokens and cost from the final result.
# Prints: "TOKENS|COST" (e.g.: "45230|1.12")

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

# ── Load prompt from file with variable interpolation ──────────
# Reads prompt template and replaces ${VAR} with env values.

agent_load_prompt() {
  local prompt_name="$1"
  local lang="${LANG:-en}"
  local prompt_file="${AA_ROOT}/prompts/${lang}/${prompt_name}.txt"

  [ -f "$prompt_file" ] || prompt_file="${AA_ROOT}/prompts/en/${prompt_name}.txt"
  [ -f "$prompt_file" ] || { agent_log "Prompt not found: $prompt_name"; return 1; }

  envsubst < "$prompt_file"
}

# ── Standard report header ─────────────────────────────────────

agent_report_header() {
  local module="${1:-unknown}"
  local project="${PROJECT_NAME:-unknown}"
  local commit_info
  commit_info=$(agent_git_last_commit)
  local hash="${commit_info%%|*}"
  local msg="${commit_info#*|}"

  cat <<EOF
# ${module^^} Report — $project
Generated: $(date '+%Y-%m-%d %H:%M') | Commit: \`$hash\` — $msg
EOF
}

# ── Initialize log ─────────────────────────────────────────────

agent_init_log() {
  local module="${1:-agent}"
  local log_dir="${PROJECT_DIR:-.}/${LOG_DIR:-logs/ci}"
  mkdir -p "$log_dir"
  _LOG_FILE="$log_dir/${module}-$(date '+%Y%m%d_%H%M%S').log"
  touch "$_LOG_FILE"
}
