#!/bin/bash
# auto-agents — English strings

# Lock
MSG_LOCK_ACTIVE="Lock active: %s — another instance running. Exiting."

# Pre-filter
MSG_SKIP_DOCS_ONLY="Only docs/md changed (manual edit). Skip."
MSG_SKIP_POSTS_ONLY="Only posts/docs/assets changed. Skip."
MSG_SKIP_NO_VALIDATIONS="Stack '%s' has no validations defined. Skip."
MSG_SKIP_NO_DOC_MAP="No doc-map.md found — no file-to-doc mapping. Skip."

# Git
MSG_COMMIT_INFO="Commit: %s"
MSG_FILES_CHANGED="Files changed: %s"

# Build
MSG_BUILD_START="Step 1: npm run build..."
MSG_BUILD_OK="Build OK"
MSG_BUILD_FAILED="BUILD FAILED (exit %s)"

# Agent
MSG_AGENT_LAUNCHING="Launching agent (%s, timeout %ss)..."
MSG_AGENT_OK="Agent completed OK"
MSG_AGENT_TIMEOUT="TIMEOUT (%ss)"
MSG_AGENT_ERROR="Agent finished with error (exit %s)"

# Stats
MSG_DURATION="Duration: %ss (%sm %ss)"
MSG_CONSUMPTION="Consumption: %s tokens, \$%s USD"

# Notify
MSG_NOTIFY_ANALYZING="Analyzing"
MSG_NOTIFY_AUDITING="Auditing"
MSG_NOTIFY_BUILD="Build"
MSG_NOTIFY_OK="OK"
MSG_NOTIFY_TIMEOUT="TIMEOUT"
MSG_NOTIFY_ERROR="ERROR"
MSG_NOTIFY_BUILD_FAILED="BUILD FAILED"
MSG_NOTIFY_ATTENTION="ATTENTION"
MSG_NOTIFY_FINDINGS="CRITICAL/HIGH findings: %s"

# Install
MSG_INSTALL_HEADER="Installing in %s"
MSG_INSTALL_GIT_OK="Git repo detected"
MSG_INSTALL_GIT_FAIL="ERROR: %s is not a git repository."
MSG_INSTALL_HOOK_EXISTS="Hook %s already exists — backed up as %s.bak"
MSG_INSTALL_HOOK_OK="Hook installed: %s → %s"
MSG_INSTALL_LOGS_OK="Directory logs/ci/ created"
MSG_INSTALL_GITIGNORE_OK=".gitignore updated"
MSG_INSTALL_ENV_CREATED=".env created with defaults (edit STACK if not astro)"
MSG_INSTALL_ENV_EXISTS=".env already exists — not modified"
MSG_INSTALL_COMPLETE="Installation complete"
MSG_INSTALL_NEXT_STEPS="Next steps:"
MSG_INSTALL_STEP_1="  1. Edit .env (verify STACK, MODEL, paths)"
MSG_INSTALL_STEP_2="  2. Create docs/doc-map.md (file-to-doc mapping)"
MSG_INSTALL_STEP_3="  3. Make a commit to test auto-doc"
MSG_INSTALL_STEP_4="  4. Make a push to test auto-test + auto-sec"

# npm audit
MSG_NPM_AUDIT_START="Step 1: npm audit..."
MSG_NPM_AUDIT_DONE="npm audit completed"

# Report
MSG_REPORT_BUILD_FAILED="Build failed with exit code %s. No additional validations were run."
