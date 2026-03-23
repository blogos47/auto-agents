#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — auto-sec module
# Automated security audit, stack-aware.
# ═══════════════════════════════════════════════════════════════

# ── Lock ───────────────────────────────────────────────────────
agent_lock "${PROJECT_NAME}-sec"

# ── Pre-filter by stack ────────────────────────────────────────
case "$STACK" in
  astro)
    if agent_prefilter "src/content/blog/**" "src/content/blog/es/**" "docs/**" "*.md" "src/assets/**" "public/images/**"; then
      agent_log "$MSG_SKIP_POSTS_ONLY"
      exit 0
    fi
    ;;
  next)
    # Do NOT skip CSS (may have CSP implications)
    if agent_prefilter "docs/**" "*.md" "src/assets/**" "public/images/**" "*.txt" "*.log"; then
      agent_log "$MSG_SKIP_DOCS_ONLY"
      exit 0
    fi
    ;;
esac

# ── Commit info ────────────────────────────────────────────────
COMMIT_INFO=$(agent_git_last_commit)
export COMMIT_HASH=$(agent_git_last_hash)
export CHANGED_FILES=$(agent_git_changed_files)
export DIFF_CONTENT=$(git -C "$PROJECT_DIR" diff HEAD~1..HEAD 2>/dev/null || echo "")

# shellcheck disable=SC2059
agent_log "$(printf "$MSG_COMMIT_INFO" "$COMMIT_INFO")"
agent_notify "auto-sec — $MSG_NOTIFY_AUDITING" "${COMMIT_HASH}: ${COMMIT_INFO#*|}"

# ── Step 1: npm audit (bash, no agent) ─────────────────────────
export NPM_AUDIT_OUTPUT=""
if [ -f "$PROJECT_DIR/package.json" ]; then
  agent_log "$MSG_NPM_AUDIT_START"
  NPM_AUDIT_OUTPUT=$(cd "$PROJECT_DIR" && npm audit 2>&1 || true)
  agent_log "$MSG_NPM_AUDIT_DONE"
fi

# ── Step 2: Stack-specific audit (Claude agent) ────────────────
START=$(date +%s)

case "$STACK" in
  astro)
    PROMPT=$(agent_load_prompt "sec-astro")
    ;;
  next)
    PROMPT=$(agent_load_prompt "sec-next")
    ;;
  *)
    # shellcheck disable=SC2059
    agent_log "$(printf "$MSG_SKIP_NO_VALIDATIONS" "$STACK")"
    exit 0
    ;;
esac

agent_run "$PROMPT"
AGENT_EXIT=$?

END=$(date +%s)
DURATION=$((END - START))
STATS=$(agent_parse_stats)
TOKENS="${STATS%%|*}"
COST="${STATS#*|}"

# shellcheck disable=SC2059
agent_log "$(printf "$MSG_DURATION" "$DURATION" "$((DURATION / 60))" "$((DURATION % 60))")"
agent_log "$(printf "$MSG_CONSUMPTION" "$TOKENS" "$COST")"

# ── Notification ───────────────────────────────────────────────
ALTO_COUNT=0
[ -f "$PROJECT_DIR/SECURITY_REPORT.md" ] && \
  ALTO_COUNT=$(grep -cE 'CRITICAL|CRITICO|HIGH|ALTO' "$PROJECT_DIR/SECURITY_REPORT.md" 2>/dev/null || echo 0)

SUMMARY="auto-sec — $PROJECT_NAME
Commit: $COMMIT_HASH
$(printf "$MSG_DURATION" "$DURATION" "$((DURATION / 60))" "$((DURATION % 60))")
$(printf "$MSG_CONSUMPTION" "$TOKENS" "$COST")
$(printf "$MSG_NOTIFY_FINDINGS" "$ALTO_COUNT")"

if [ $AGENT_EXIT -eq 0 ]; then
  if [ "$ALTO_COUNT" -gt 0 ] 2>/dev/null; then
    agent_notify "auto-sec — $MSG_NOTIFY_ATTENTION" "$(printf "$MSG_NOTIFY_FINDINGS" "$ALTO_COUNT")" "$SUMMARY"
  else
    agent_notify "auto-sec — $MSG_NOTIFY_OK" "$((DURATION / 60))m" "$SUMMARY"
  fi
else
  agent_notify "auto-sec — $MSG_NOTIFY_ERROR" "Exit $AGENT_EXIT" "$SUMMARY"
fi
