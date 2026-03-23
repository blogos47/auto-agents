#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — módulo auto-sec
# Auditoría de seguridad automatizada por stack.
# ═══════════════════════════════════════════════════════════════

# ── Lock ───────────────────────────────────────────────────────
agent_lock "${PROJECT_NAME}-sec"

# ── Pre-filtro por stack ───────────────────────────────────────
case "$STACK" in
  astro)
    if agent_prefilter "src/content/blog/**" "src/content/blog/es/**" "docs/**" "*.md" "src/assets/**" "public/images/**"; then
      agent_log "Solo posts/docs/assets cambiados. Skip."
      exit 0
    fi
    ;;
  next)
    # NO skip CSS (puede tener CSP implications)
    if agent_prefilter "docs/**" "*.md" "src/assets/**" "public/images/**" "*.txt" "*.log"; then
      agent_log "Solo docs/assets cambiados. Skip."
      exit 0
    fi
    ;;
esac

# ── Commit info ────────────────────────────────────────────────
COMMIT_INFO=$(agent_git_last_commit)
COMMIT_HASH=$(agent_git_last_hash)
CHANGED_FILES=$(agent_git_changed_files)

agent_log "Commit: $COMMIT_INFO"
agent_notify "auto-sec — Auditando" "${COMMIT_HASH}: ${COMMIT_INFO#*|}"

# ── Paso 1: npm audit (bash, sin agente) ───────────────────────
NPM_AUDIT_OUTPUT=""
if [ -f "$PROJECT_DIR/package.json" ]; then
  agent_log "Paso 1: npm audit..."
  NPM_AUDIT_OUTPUT=$(cd "$PROJECT_DIR" && npm audit 2>&1 || true)
  agent_log "npm audit completado"
fi

# ── Paso 2: Auditoría por stack (agente Claude) ────────────────
START=$(date +%s)

case "$STACK" in
  astro)
    PROMPT="Eres un agente de seguridad para $PROJECT_NAME (Astro 6, blog estático SSG).
Superficie de ataque: MÍNIMA (sin auth, sin API, sin DB, sin server-side).

## Commit auditado
- Hash: $COMMIT_HASH
- Archivos cambiados:
$CHANGED_FILES

## npm audit
\`\`\`
$NPM_AUDIT_OUTPUT
\`\`\`

## Qué auditar

1. Scripts inline en archivos .astro — buscar eval(), innerHTML con variables, fetch sin validar
2. Meta tags en componentes head — no exponer info sensible
3. Archivos sensibles en git: git -C $PROJECT_DIR ls-files | grep -iE 'env|key|secret|token|credential'
4. _headers file para Cloudflare Pages — CSP, X-Frame-Options, etc.
5. Dependencias npm: analizar el output de npm audit arriba

## Generar reporte

Genera $PROJECT_DIR/SECURITY_REPORT.md con formato:

$(agent_report_header 'SECURITY')

## Hallazgos
| # | Severidad | Descripción | Archivo | Estado |
|---|-----------|-------------|---------|--------|

## npm audit
[Resumen del output]

No edites código — solo reporta."
    ;;

  next)
    PROMPT="Eres un agente de seguridad para $PROJECT_NAME (Next.js, producción).
CPA25 está en producción (Vercel), los usuarios lo usan activamente.

## Commit auditado
- Hash: $COMMIT_HASH
- Archivos cambiados:
$CHANGED_FILES

## Diff
\`\`\`
$(git -C "$PROJECT_DIR" diff HEAD~1..HEAD 2>/dev/null || echo "")
\`\`\`

## npm audit
\`\`\`
$NPM_AUDIT_OUTPUT
\`\`\`

## Qué auditar

Para cada archivo cambiado, analizar desde perspectiva de atacante:
1. Auth bypass, escalación de privilegios
2. Inyecciones (SQL, XSS, command, path traversal)
3. Exposición de datos, secrets, tokens, PII
4. CSP, CORS, headers de seguridad
5. Rate limiting, validación de input
6. Deserialización insegura (eval, Function(), JSON.parse sin validar)

## Clasificar hallazgos
- CRITICO: explotable sin auth, impacto alto
- ALTO: explotable con auth o cadena de exploits
- MEDIO: riesgo teórico, requiere condiciones específicas
- BAJO: best practice, hardening

Genera $PROJECT_DIR/SECURITY_REPORT.md con resultados.
Usa este header: $(agent_report_header 'SECURITY')
Si existe un SECURITY_REPORT.md previo, léelo para contexto de hallazgos anteriores.
No edites código — solo reporta."
    ;;

  *)
    agent_log "Stack '$STACK' no tiene auditoría de seguridad definida. Skip."
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
ALTO_COUNT=0
[ -f "$PROJECT_DIR/SECURITY_REPORT.md" ] && \
  ALTO_COUNT=$(grep -cE 'CRITICO|ALTO' "$PROJECT_DIR/SECURITY_REPORT.md" 2>/dev/null || echo 0)

SUMMARY="auto-sec — $PROJECT_NAME
Commit: $COMMIT_HASH
Duración: $((DURATION / 60))m $((DURATION % 60))s
Consumo: $TOKENS tokens, \$$COST USD
Hallazgos CRITICO/ALTO: $ALTO_COUNT"

if [ $AGENT_EXIT -eq 0 ]; then
  if [ "$ALTO_COUNT" -gt 0 ] 2>/dev/null; then
    agent_notify "auto-sec — ATENCIÓN" "$ALTO_COUNT hallazgos CRITICO/ALTO" "$SUMMARY"
  else
    agent_notify "auto-sec — OK" "$((DURATION / 60))m" "$SUMMARY"
  fi
else
  agent_notify "auto-sec — ERROR" "Exit $AGENT_EXIT" "$SUMMARY"
fi
