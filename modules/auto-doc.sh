#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — auto-doc module
# Detects drift between code and documentation after each commit.
# Reads doc-map.md from the project to know which docs to check.
# ═══════════════════════════════════════════════════════════════

# ── Lock ───────────────────────────────────────────────────────
agent_lock "${PROJECT_NAME}-doc"

# ── Pre-filter ─────────────────────────────────────────────────
if agent_prefilter "docs/*.md" "docs/**/*.md" "*.md" ".claude/**"; then
  agent_log "$MSG_SKIP_DOCS_ONLY"
  exit 0
fi

# ── Commit info ────────────────────────────────────────────────
COMMIT_INFO=$(agent_git_last_commit)
COMMIT_HASH=$(agent_git_last_hash)
export COMMIT_MSG="${COMMIT_INFO#*|}"
export CHANGED_FILES=$(agent_git_changed_files)
export DIFF_CONTENT=$(git -C "$PROJECT_DIR" diff HEAD~1..HEAD 2>/dev/null || echo "")
export REPORT_FILE="$PROJECT_DIR/docs/DOC_REPORT.md"

# shellcheck disable=SC2059
agent_log "$(printf "$MSG_COMMIT_INFO" "$COMMIT_INFO")"
agent_log "$(printf "$MSG_FILES_CHANGED" "$(echo "$CHANGED_FILES" | wc -l)")"

# ── Read doc-map ───────────────────────────────────────────────
export DOC_MAP=""
[ -f "$PROJECT_DIR/docs/doc-map.md" ] && DOC_MAP=$(cat "$PROJECT_DIR/docs/doc-map.md")

if [ -z "$DOC_MAP" ]; then
  agent_log "$MSG_SKIP_NO_DOC_MAP"
  exit 0
fi

# ── Notify start ───────────────────────────────────────────────
agent_notify "auto-doc — $MSG_NOTIFY_ANALYZING" "${COMMIT_HASH}: ${COMMIT_MSG}"

# ── Load and run prompt ────────────────────────────────────────
START=$(date +%s)

PROMPT=$(agent_load_prompt "doc")
agent_run "$PROMPT"
AGENT_EXIT=$?

END=$(date +%s)
DURATION=$((END - START))

# ── Stats ──────────────────────────────────────────────────────
STATS=$(agent_parse_stats)
TOKENS="${STATS%%|*}"
COST="${STATS#*|}"

# shellcheck disable=SC2059
agent_log "$(printf "$MSG_DURATION" "$DURATION" "$((DURATION / 60))" "$((DURATION % 60))")"
agent_log "$(printf "$MSG_CONSUMPTION" "$TOKENS" "$COST")"

# ── Final notification ─────────────────────────────────────────
SUMMARY="auto-doc — $PROJECT_NAME
Commit: $COMMIT_HASH
$(printf "$MSG_DURATION" "$DURATION" "$((DURATION / 60))" "$((DURATION % 60))")
$(printf "$MSG_CONSUMPTION" "$TOKENS" "$COST")"

if [ $AGENT_EXIT -eq 0 ]; then
  agent_notify "auto-doc — $MSG_NOTIFY_OK" "$((DURATION / 60))m" "$SUMMARY"
elif [ $AGENT_EXIT -eq 124 ]; then
  agent_notify "auto-doc — $MSG_NOTIFY_TIMEOUT" "${TIMEOUT}s" "$SUMMARY"
else
  agent_notify "auto-doc — $MSG_NOTIFY_ERROR" "Exit $AGENT_EXIT" "$SUMMARY"
fi
