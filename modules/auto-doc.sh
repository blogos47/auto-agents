#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# auto-agents — módulo auto-doc
# Evalúa drift entre código y documentación tras cada commit.
# Lee doc-map.md del proyecto para saber qué docs revisar.
# ═══════════════════════════════════════════════════════════════

# ── Lock ───────────────────────────────────────────────────────
agent_lock "${PROJECT_NAME}-doc"

# ── Pre-filtro ─────────────────────────────────────────────────
# Si solo cambiaron .md, es edición manual de docs → skip
if agent_prefilter "docs/*.md" "docs/**/*.md" "*.md" ".claude/**"; then
  agent_log "Solo docs/md cambiados (edición manual). Skip."
  exit 0
fi

# ── Commit info ────────────────────────────────────────────────
COMMIT_INFO=$(agent_git_last_commit)
COMMIT_HASH=$(agent_git_last_hash)
CHANGED_FILES=$(agent_git_changed_files)
DIFF_CONTENT=$(git -C "$PROJECT_DIR" diff HEAD~1..HEAD 2>/dev/null || echo "")

agent_log "Commit: $COMMIT_INFO"
agent_log "Archivos cambiados: $(echo "$CHANGED_FILES" | wc -l)"

# ── Leer doc-map ───────────────────────────────────────────────
DOC_MAP=""
[ -f "$PROJECT_DIR/docs/doc-map.md" ] && DOC_MAP=$(cat "$PROJECT_DIR/docs/doc-map.md")

if [ -z "$DOC_MAP" ]; then
  agent_log "Sin doc-map.md — no hay mapeo de archivos a docs. Skip."
  exit 0
fi

# ── Notificar inicio ───────────────────────────────────────────
agent_notify "auto-doc — Analizando" "${COMMIT_HASH}: ${COMMIT_INFO#*|}"

# ── Construir prompt ───────────────────────────────────────────
REPORT_FILE="$PROJECT_DIR/docs/DOC_REPORT.md"

PROMPT="Eres un agente de documentación automatizado para el proyecto $PROJECT_NAME.
Stack: $STACK | Directorio: $PROJECT_DIR

## Commit que disparó este run

- Hash: $COMMIT_HASH
- Mensaje: ${COMMIT_INFO#*|}
- Archivos cambiados:
$CHANGED_FILES

## Diff completo

\`\`\`
$DIFF_CONTENT
\`\`\`

## Mapa de documentación

$DOC_MAP

## Instrucciones

### Fase 1: Identificar docs afectados
Usando el doc-map, determina qué docs están relacionados con los archivos cambiados.
Lee esos docs completos. Lee también el código relevante (no solo el diff).

### Fase 2: Evaluar drift
Para cada doc afectado, clasifica:
- **BAJO**: Info correcta pero incompleta, falta mencionar algo nuevo, typos.
  → Aplica el fix automáticamente.
- **MEDIO**: Info ambigua o potencialmente incorrecta. Investiga leyendo el código.
  → Si confirmas drift, aplica el fix. Si no puedes confirmar, reporta.
- **ALTO**: Info contradictoria con el código, features que ya no existen,
  cambios en docs críticos (CLAUDE.md, doc-map.md).
  → NO apliques fixes. Solo reporta.

### Fase 3: Aplicar fixes (BAJO y MEDIO confirmados)
1. Edita el doc con la info correcta.
2. Actualiza frontmatter (updated, updated_human) con la hora actual.
   Obtener hora: date '+%Y-%m-%dT%H:%M:%S'
   Formato human: 'Día-semana DD de mes, YYYY — HH:MM' (español, hora Chile).

### Fase 4: Actualizar DOC_REPORT.md
Actualiza $REPORT_FILE con los resultados.
Si no existe, créalo. Si existe, léelo y agrega nueva sección al inicio del historial.

Formato por run:
### Run — YYYY-MM-DD HH:MM
| Campo | Valor |
|---|---|
| Commit | \`$COMMIT_HASH\` — \"mensaje\" |
| Duración | (pendiente) |
| Tokens | (pendiente) |

**Docs evaluados**: N | **Actualizados**: N

| Doc | Drift | Acción |
|---|---|---|
| path/doc.md | BAJO/MEDIO/ALTO — descripción | Actualizado / Reportado / Sin drift |

NUNCA borres runs anteriores. Solo agrega al inicio.

### Fase 5: Commitear
Si modificaste docs:
1. git add los docs que cambiaste (solo docs, no código)
2. git commit -m \"docs(auto): actualizar tras $COMMIT_HASH\"

## Reglas
- NUNCA borres docs. Marca como ARCHIVADO si ya no aplican.
- NUNCA edites código fuente.
- NUNCA edites CLAUDE.md ni doc-map.md. Solo reporta si están desactualizados."

# ── Lanzar agente ──────────────────────────────────────────────
START=$(date +%s)

agent_run "$PROMPT"
AGENT_EXIT=$?

END=$(date +%s)
DURATION=$((END - START))

# ── Stats ──────────────────────────────────────────────────────
STATS=$(agent_parse_stats)
TOKENS="${STATS%%|*}"
COST="${STATS#*|}"

agent_log "Duración: ${DURATION}s ($((DURATION / 60))m $((DURATION % 60))s)"
agent_log "Consumo: $TOKENS tokens, \$$COST USD"

# ── Notificación final ─────────────────────────────────────────
SUMMARY="auto-doc — $PROJECT_NAME
Commit: $COMMIT_HASH
Duración: $((DURATION / 60))m $((DURATION % 60))s
Consumo: $TOKENS tokens, \$$COST USD"

if [ $AGENT_EXIT -eq 0 ]; then
  agent_notify "auto-doc — OK" "$((DURATION / 60))m" "$SUMMARY"
elif [ $AGENT_EXIT -eq 124 ]; then
  agent_notify "auto-doc — TIMEOUT" "${TIMEOUT}s" "$SUMMARY"
else
  agent_notify "auto-doc — ERROR" "Exit $AGENT_EXIT" "$SUMMARY"
fi
