#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — módulo auto-test
# Testing automatizado: build check + validaciones por stack.
# ═══════════════════════════════════════════════════════════════

# ── Lock ───────────────────────────────────────────────────────
agent_lock "${PROJECT_NAME}-test"

# ── Pre-filtro ─────────────────────────────────────────────────
if agent_prefilter "docs/**" "docs/*.md" "*.md" ".claude/**" "*.txt" "*.log"; then
  agent_log "Solo docs/md/txt cambiados. Skip."
  exit 0
fi

# ── Commit info ────────────────────────────────────────────────
COMMIT_INFO=$(agent_git_last_commit)
COMMIT_HASH=$(agent_git_last_hash)

agent_log "Commit: $COMMIT_INFO"
agent_notify "auto-test — Build" "${COMMIT_HASH}: ${COMMIT_INFO#*|}"

# ── Paso 1: Build check (bash, sin agente) ─────────────────────
agent_log "Paso 1: npm run build..."

cd "$PROJECT_DIR"
BUILD_OUTPUT=$(npm run build 2>&1) || {
  BUILD_EXIT=$?
  agent_log "BUILD FAILED (exit $BUILD_EXIT)"

  # Generar reporte de fallo
  cat > "$PROJECT_DIR/TEST_REPORT.md" <<EOF
$(agent_report_header "TEST")

## Estado: BUILD FAILED

\`\`\`
$BUILD_OUTPUT
\`\`\`

Build falló con exit code $BUILD_EXIT. No se ejecutaron validaciones adicionales.
EOF

  agent_notify "auto-test — BUILD FAILED" "$PROJECT_NAME" "Build falló (exit $BUILD_EXIT)"
  exit 1
}

agent_log "Build OK"

# ── Paso 2: Validaciones por stack (agente Claude) ─────────────
START=$(date +%s)

case "$STACK" in
  astro)
    PROMPT="Eres un agente de testing para $PROJECT_NAME (Astro 6, blog estático).
El build ya pasó OK. Tu trabajo:

1. CONSISTENCIA i18n:
   - Lee src/content/blog/ y src/content/blog/es/
   - Cada post EN debe tener contraparte ES con translationOf apuntando al slug EN (o viceversa)
   - Lee src/i18n/translations.ts — toda clave debe tener valor no-vacío en en y es
   - Lee src/pages/ y src/pages/es/ — cada página EN debe tener espejo ES

2. LINKS INTERNOS:
   - Busca href= en archivos .astro
   - Verifica que las rutas internas apunten a páginas que existen
   - Links a /es/* deben tener página correspondiente

3. FRONTMATTER de posts:
   - Todos los posts deben tener: title, description, pubDate
   - Posts con translationOf deben apuntar a un slug que exista

Genera $PROJECT_DIR/TEST_REPORT.md con resultados.
Usa este header: $(agent_report_header 'TEST')
No edites código — solo reporta."
    ;;

  next)
    PROMPT="Eres un agente de testing para $PROJECT_NAME (Next.js).
El build ya pasó OK. Tu trabajo:

1. Correr tests unitarios: cd $PROJECT_DIR && npx vitest run --reporter=verbose
2. Correr tests E2E: cd $PROJECT_DIR && npx playwright test --reporter=list
3. Analizar resultados: pasos, fallos, flaky, regresiones
4. Si un test falla, leer el test y el código que testea para diagnosticar causa raíz

Genera $PROJECT_DIR/TEST_REPORT.md con resultados.
Usa este header: $(agent_report_header 'TEST')
No edites código de producción. Puedes reescribir tests mal escritos."
    ;;

  *)
    agent_log "Stack '$STACK' no tiene validaciones de test definidas. Skip."
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

agent_log "Duración: ${DURATION}s ($((DURATION / 60))m $((DURATION % 60))s)"
agent_log "Consumo: $TOKENS tokens, \$$COST USD"

# ── Notificación ───────────────────────────────────────────────
SUMMARY="auto-test — $PROJECT_NAME
Commit: $COMMIT_HASH
Build: OK
Duración: $((DURATION / 60))m $((DURATION % 60))s
Consumo: $TOKENS tokens, \$$COST USD"

if [ $AGENT_EXIT -eq 0 ]; then
  agent_notify "auto-test — OK" "$((DURATION / 60))m" "$SUMMARY"
else
  agent_notify "auto-test — ERROR" "Exit $AGENT_EXIT" "$SUMMARY"
fi
