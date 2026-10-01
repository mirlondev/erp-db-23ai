#!/bin/bash
# ============================================================
# APEX 26.1 Setup — REGAL (workspace REGAL)
# ============================================================
# Exécute dans l'ordre tous les scripts de configuration APEX :
#   01 → 03 : workspace, ORDS, auth
#   04-06   : vues partagées + branding LITOKO + fix
#   07-11   : LOVs, auth schemes, menus, PDF, locale
#
# Usage :  ./scripts/run_apex_setup.sh
# ============================================================
set -e

CONN="system/oracle@localhost:1521/FREEPDB1"
SCRIPTS_DIR="$(cd "$(dirname "$0")/.." && pwd)/apex/setup"

echo "═══════════════════════════════════════════════════════════"
echo "  APEX 26.1 SETUP — Workspace REGAL"
echo "═══════════════════════════════════════════════════════════"

for script in \
  01_apex_workspace.sql \
  02_ords_enable_parsers.sql \
  03_apex_auth_setup.sql \
  04_apex_components.sql \
  05_apex_litoko_branding.sql \
  06_apex_components_fix.sql \
  07_apex_lovs.sql \
  08_apex_authorizations.sql \
  09_apex_nav_menus.sql \
  10_apex_pdf_reports.sql \
  11_apex_congo_locale.sql
do
    echo ""
    echo "▶ APEX : $script"
    echo "───────────────────────────────────────────────────────────"

    sqlplus -S "$CONN" <<EOF
WHENEVER SQLERROR CONTINUE
@${SCRIPTS_DIR}/${script}
EXIT
EOF

    echo "✅ $script terminé"
done

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ APEX 26.1 SETUP TERMINÉ (11 scripts)"
echo ""
echo "  Prochaines étapes (IDE APEX) :"
echo "    1. http://localhost:8080/apex/f?p=4550:1 (admin)"
echo "    2. Workspace REGAL → App Builder → Create Application"
echo "    3. Importer apex/apps/SPEC_*.md comme templates pages"
echo "═══════════════════════════════════════════════════════════"
