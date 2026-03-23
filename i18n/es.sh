#!/bin/bash
# auto-agents — Strings en español

# Lock
MSG_LOCK_ACTIVE="Lock activo: %s — otra instancia corriendo. Saliendo."

# Pre-filtro
MSG_SKIP_DOCS_ONLY="Solo docs/md cambiados (edición manual). Skip."
MSG_SKIP_POSTS_ONLY="Solo posts/docs/assets cambiados. Skip."
MSG_SKIP_NO_VALIDATIONS="Stack '%s' no tiene validaciones definidas. Skip."
MSG_SKIP_NO_DOC_MAP="Sin doc-map.md — no hay mapeo de archivos a docs. Skip."

# Git
MSG_COMMIT_INFO="Commit: %s"
MSG_FILES_CHANGED="Archivos cambiados: %s"

# Build
MSG_BUILD_START="Paso 1: npm run build..."
MSG_BUILD_OK="Build OK"
MSG_BUILD_FAILED="BUILD FAILED (exit %s)"

# Agente
MSG_AGENT_LAUNCHING="Lanzando agente (%s, timeout %ss)..."
MSG_AGENT_OK="Agente completado OK"
MSG_AGENT_TIMEOUT="TIMEOUT (%ss)"
MSG_AGENT_ERROR="Agente terminó con error (exit %s)"

# Stats
MSG_DURATION="Duración: %ss (%sm %ss)"
MSG_CONSUMPTION="Consumo: %s tokens, \$%s USD"

# Notificar
MSG_NOTIFY_ANALYZING="Analizando"
MSG_NOTIFY_AUDITING="Auditando"
MSG_NOTIFY_BUILD="Build"
MSG_NOTIFY_OK="OK"
MSG_NOTIFY_TIMEOUT="TIMEOUT"
MSG_NOTIFY_ERROR="ERROR"
MSG_NOTIFY_BUILD_FAILED="BUILD FAILED"
MSG_NOTIFY_ATTENTION="ATENCIÓN"
MSG_NOTIFY_FINDINGS="Hallazgos CRITICO/ALTO: %s"

# Install
MSG_INSTALL_HEADER="Instalando en %s"
MSG_INSTALL_GIT_OK="Repo git detectado"
MSG_INSTALL_GIT_FAIL="ERROR: %s no es un repositorio git."
MSG_INSTALL_HOOK_EXISTS="Hook %s ya existe — respaldado como %s.bak"
MSG_INSTALL_HOOK_OK="Hook instalado: %s → %s"
MSG_INSTALL_LOGS_OK="Directorio logs/ci/ creado"
MSG_INSTALL_GITIGNORE_OK=".gitignore actualizado"
MSG_INSTALL_ENV_CREATED=".env creado con defaults (editar STACK si no es astro)"
MSG_INSTALL_ENV_EXISTS=".env ya existe — no se modificó"
MSG_INSTALL_COMPLETE="Instalación completa"
MSG_INSTALL_NEXT_STEPS="Próximos pasos:"
MSG_INSTALL_STEP_1="  1. Editar .env (verificar STACK, MODEL, paths)"
MSG_INSTALL_STEP_2="  2. Crear docs/doc-map.md (mapeo archivos → docs)"
MSG_INSTALL_STEP_3="  3. Hacer un commit para probar auto-doc"
MSG_INSTALL_STEP_4="  4. Hacer un push para probar auto-test + auto-sec"

# npm audit
MSG_NPM_AUDIT_START="Paso 1: npm audit..."
MSG_NPM_AUDIT_DONE="npm audit completado"

# Reporte
MSG_REPORT_BUILD_FAILED="Build falló con exit code %s. No se ejecutaron validaciones adicionales."
