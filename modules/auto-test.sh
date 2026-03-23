#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — auto-test module
# Automated testing: build check + stack-specific validations.
# ═══════════════════════════════════════════════════════════════

# ── Lock ───────────────────────────────────────────────────────
agent_lock "${PROJECT_NAME}-test"

# ── Pre-filter ─────────────────────────────────────────────────
if agent_prefilter "docs/**" "docs/*.md" "*.md" ".claude/**" "*.txt" "*.log"; then
  agent_log "$MSG_SKIP_DOCS_ONLY"
  exit 0
fi

# ── Commit info ────────────────────────────────────────────────
COMMIT_INFO=$(agent_git_last_commit)
export COMMIT_HASH=$(agent_git_last_hash)

# shellcheck disable=SC2059
agent_log "$(printf "$MSG_COMMIT_INFO" "$COMMIT_INFO")"
agent_notify "auto-test — $MSG_NOTIFY_BUILD" "${COMMIT_HASH}: ${COMMIT_INFO#*|}"

# ── Step 1: Build check (bash, no agent) ───────────────────────
agent_log "$MSG_BUILD_START"

cd "$PROJECT_DIR"
BUILD_OUTPUT=$(npm run build 2>&1) || {
  BUILD_EXIT=$?
  # shellcheck disable=SC2059
  agent_log "$(printf "$MSG_BUILD_FAILED" "$BUILD_EXIT")"

  cat > "$PROJECT_DIR/TEST_REPORT.md" <<EOF
$(agent_report_header "TEST")

## Status: BUILD FAILED

\`\`\`
$BUILD_OUTPUT
\`\`\`

$(printf "$MSG_REPORT_BUILD_FAILED" "$BUILD_EXIT")
EOF

  agent_notify "auto-test — $MSG_NOTIFY_BUILD_FAILED" "$PROJECT_NAME"
  exit 1
}

agent_log "$MSG_BUILD_OK"

# ── Step 2: Stack-specific validations (Claude agent) ──────────
START=$(date +%s)

case "$STACK" in
  astro)
    PROMPT=$(agent_load_prompt "test-astro")
    ;;
  next)
    PROMPT=$(agent_load_prompt "test-next")
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
SUMMARY="auto-test — $PROJECT_NAME
Commit: $COMMIT_HASH | Build: OK
$(printf "$MSG_DURATION" "$DURATION" "$((DURATION / 60))" "$((DURATION % 60))")
$(printf "$MSG_CONSUMPTION" "$TOKENS" "$COST")"

if [ $AGENT_EXIT -eq 0 ]; then
  agent_notify "auto-test — $MSG_NOTIFY_OK" "$((DURATION / 60))m" "$SUMMARY"
else
  agent_notify "auto-test — $MSG_NOTIFY_ERROR" "Exit $AGENT_EXIT" "$SUMMARY"
fi
