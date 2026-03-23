#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — install.sh
# Installs auto-agents hooks in a project.
#
# Usage: ./install.sh /home/edu/p/blogos.dev
#
# What it does:
#   1. Verifies the directory is a git repo
#   2. Creates hook symlinks in .git/hooks/
#   3. Creates logs/ci/ and adds to .gitignore
#   4. Creates .env with defaults if it doesn't exist
#   5. Shows summary
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

AA_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?Usage: install.sh <project_directory>}"
TARGET="$(cd "$TARGET" && pwd)"

# Load i18n (detect from existing .env or default to en)
LANG="en"
[ -f "$TARGET/.env" ] && LANG=$(grep -oP '^LANG=\K.*' "$TARGET/.env" 2>/dev/null || echo "en")
LANG_FILE="$AA_ROOT/i18n/${LANG}.sh"
[ -f "$LANG_FILE" ] || LANG_FILE="$AA_ROOT/i18n/en.sh"
source "$LANG_FILE"

# shellcheck disable=SC2059
printf "═══ auto-agents — $(printf "$MSG_INSTALL_HEADER" "$TARGET") ═══\n\n"

# ── 1. Verify git repo ────────────────────────────────────────
if [ ! -d "$TARGET/.git" ] && [ ! -f "$TARGET/.git" ]; then
  # shellcheck disable=SC2059
  printf "$MSG_INSTALL_GIT_FAIL\n" "$TARGET"
  exit 1
fi
echo "✓ $MSG_INSTALL_GIT_OK"

# ── 2. Install hooks ──────────────────────────────────────────
HOOKS_DIR="$TARGET/.git/hooks"
mkdir -p "$HOOKS_DIR"

for hook in "$AA_ROOT"/hooks/*.hook; do
  [ -f "$hook" ] || continue
  hook_name="$(basename "$hook" .hook)"
  target_hook="$HOOKS_DIR/$hook_name"

  if [ -f "$target_hook" ] || [ -L "$target_hook" ]; then
    # shellcheck disable=SC2059
    printf "⚠ $(printf "$MSG_INSTALL_HOOK_EXISTS" "$hook_name" "$hook_name")\n"
    mv "$target_hook" "${target_hook}.bak"
  fi

  ln -sf "$hook" "$target_hook"
  chmod +x "$target_hook"
  # shellcheck disable=SC2059
  printf "✓ $(printf "$MSG_INSTALL_HOOK_OK" "$hook_name" "$(basename "$hook")")\n"
done

# ── 3. Create logs/ci/ ────────────────────────────────────────
mkdir -p "$TARGET/logs/ci"
echo "✓ $MSG_INSTALL_LOGS_OK"

# Add to .gitignore if not already there
GITIGNORE="$TARGET/.gitignore"
for entry in "logs/" "TEST_REPORT.md" "SECURITY_REPORT.md"; do
  if [ -f "$GITIGNORE" ]; then
    grep -qxF "$entry" "$GITIGNORE" 2>/dev/null || echo "$entry" >> "$GITIGNORE"
  else
    echo "$entry" >> "$GITIGNORE"
  fi
done
echo "✓ $MSG_INSTALL_GITIGNORE_OK"

# ── 4. Create .env if it doesn't exist ────────────────────────
ENV_FILE="$TARGET/.env"
if [ ! -f "$ENV_FILE" ]; then
  project_name="$(basename "$TARGET")"
  cat > "$ENV_FILE" <<EOF
# auto-agents config — $project_name
PROJECT_NAME="$project_name"
STACK="astro"
MODEL="opus"
TIMEOUT=600
LANG="en"
# CLAUDE_BIN="/home/edu/.local/bin/claude"
# LOG_DIR="logs/ci"
# NOTIFY_PS="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
# NOTIFY_SCRIPT="C:\\Users\\jamro\\.cpa25\\show-toast.ps1"
EOF
  echo "✓ $MSG_INSTALL_ENV_CREATED"
else
  echo "· $MSG_INSTALL_ENV_EXISTS"
fi

# ── 5. Summary ─────────────────────────────────────────────────
echo ""
echo "═══ $MSG_INSTALL_COMPLETE ═══"
echo "Project:   $TARGET"
echo "Hooks:     $(ls "$HOOKS_DIR"/post-commit "$HOOKS_DIR"/pre-push 2>/dev/null | wc -l) installed"
echo "Config:    $ENV_FILE"
echo ""
echo "$MSG_INSTALL_NEXT_STEPS"
echo "$MSG_INSTALL_STEP_1"
echo "$MSG_INSTALL_STEP_2"
echo "$MSG_INSTALL_STEP_3"
echo "$MSG_INSTALL_STEP_4"
