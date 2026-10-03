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

CONN="sys/oracle@localhost:1521/FREEPDB1 as sysdba"
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
  14_bootstrap_users.sql \
  07_apex_lovs.sql \
  08_apex_authorizations.sql \
  09_apex_nav_menus.sql \
  10_apex_pdf_reports.sql \
  11_apex_congo_locale.sql \
  12_apex_health_check.sql
do
    echo ""
    echo "▶ APEX : $script"
    echo "───────────────────────────────────────────────────────────"

    sql "$CONN" <<EOF
  WHENEVER SQLERROR EXIT SQL.SQLCODE
  WHENEVER OSERROR EXIT FAILURE
@${SCRIPTS_DIR}/${script}
EXIT
EOF

    echo "✅ $script terminé"
done

# Étape 2 : installer les 5 apps APEX (programmatique via wwv_flow_api)
APPS_DIR="$(cd "$(dirname "$0")/.." && pwd)/apex/apps"
echo ""
echo "▶ Apps APEX : installation programmatique (wwv_flow_api)"
echo "───────────────────────────────────────────────────────────"

sql "$CONN" <<EOF
  WHENEVER SQLERROR EXIT SQL.SQLCODE
@${APPS_DIR}/install_app100_pos.sql
EXIT
EOF
echo "✅ install_app100_pos.sql terminé"

sql "$CONN" <<EOF
  WHENEVER SQLERROR EXIT SQL.SQLCODE
@${APPS_DIR}/install_app200_300_400_500.sql
EXIT
EOF
echo "✅ install_app200_300_400_500.sql terminé"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ APEX 26.1 SETUP TERMINÉ (12 scripts setup + 5 apps)"
echo ""
echo "  URLs d'accès (après démarrage ORDS) :"
echo "    App 100 POS      : http://localhost:8080/apex/f?p=100:10"
echo "    App 200 Stock    : http://localhost:8080/apex/f?p=200:10"
echo "    App 300 Achats   : http://localhost:8080/apex/f?p=300:10"
echo "    App 400 Compta   : http://localhost:8080/apex/f?p=400:10"
echo "    App 500 Admin    : http://localhost:8080/apex/f?p=500:10"
echo "═══════════════════════════════════════════════════════════"
