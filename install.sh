#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — install.sh
# Instala hooks de auto-agents en un proyecto.
#
# Uso: ./install.sh /home/edu/p/blogos.dev
#
# Qué hace:
#   1. Verifica que el directorio es un repo git
#   2. Crea symlinks de hooks en .git/hooks/
#   3. Crea logs/ci/ y lo agrega a .gitignore
#   4. Crea .env con defaults si no existe
#   5. Muestra resumen
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

AA_ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:?Uso: install.sh <directorio_del_proyecto>}"
TARGET="$(cd "$TARGET" && pwd)"

echo "═══ auto-agents — Instalando en $TARGET ═══"
echo ""

# ── 1. Verificar repo git ──────────────────────────────────────
if [ ! -d "$TARGET/.git" ] && [ ! -f "$TARGET/.git" ]; then
  echo "ERROR: $TARGET no es un repositorio git."
  exit 1
fi
echo "✓ Repo git detectado"

# ── 2. Instalar hooks ─────────────────────────────────────────
HOOKS_DIR="$TARGET/.git/hooks"
mkdir -p "$HOOKS_DIR"

for hook in "$AA_ROOT"/hooks/*.hook; do
  [ -f "$hook" ] || continue
  hook_name="$(basename "$hook" .hook)"
  target_hook="$HOOKS_DIR/$hook_name"

  if [ -f "$target_hook" ] || [ -L "$target_hook" ]; then
    echo "⚠ Hook $hook_name ya existe — respaldado como ${hook_name}.bak"
    mv "$target_hook" "${target_hook}.bak"
  fi

  ln -sf "$hook" "$target_hook"
  chmod +x "$target_hook"
  echo "✓ Hook instalado: $hook_name → $(basename "$hook")"
done

# ── 3. Crear logs/ci/ ─────────────────────────────────────────
mkdir -p "$TARGET/logs/ci"
echo "✓ Directorio logs/ci/ creado"

# Agregar a .gitignore si no está
GITIGNORE="$TARGET/.gitignore"
for entry in "logs/" "TEST_REPORT.md" "SECURITY_REPORT.md"; do
  if [ -f "$GITIGNORE" ]; then
    grep -qxF "$entry" "$GITIGNORE" 2>/dev/null || echo "$entry" >> "$GITIGNORE"
  else
    echo "$entry" >> "$GITIGNORE"
  fi
done
echo "✓ .gitignore actualizado"

# ── 4. Crear .env si no existe ─────────────────────────────────
ENV_FILE="$TARGET/.env"
if [ ! -f "$ENV_FILE" ]; then
  project_name="$(basename "$TARGET")"
  cat > "$ENV_FILE" <<EOF
# auto-agents config — $project_name
PROJECT_NAME="$project_name"
STACK="astro"
MODEL="opus"
TIMEOUT=600
# CLAUDE_BIN="/home/edu/.local/bin/claude"
# LOG_DIR="logs/ci"
# NOTIFY_PS="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
# NOTIFY_SCRIPT="C:\\Users\\jamro\\.cpa25\\show-toast.ps1"
EOF
  echo "✓ .env creado con defaults (editar STACK si no es astro)"
else
  echo "· .env ya existe — no se modificó"
fi

# ── 5. Resumen ─────────────────────────────────────────────────
echo ""
echo "═══ Instalación completa ═══"
echo "Proyecto:  $TARGET"
echo "Hooks:     $(ls "$HOOKS_DIR"/post-commit "$HOOKS_DIR"/pre-push 2>/dev/null | wc -l) instalados"
echo "Config:    $ENV_FILE"
echo ""
echo "Próximos pasos:"
echo "  1. Editar .env (verificar STACK, MODEL, paths)"
echo "  2. Crear docs/doc-map.md (mapeo archivos → docs)"
echo "  3. Hacer un commit para probar auto-doc"
echo "  4. Hacer un push para probar auto-test + auto-sec"
