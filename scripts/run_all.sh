#!/bin/bash

set -e

CONN="system/oracle@localhost:1521/FREEPDB1"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "═══════════════════════════════════════════════════════════"
echo "  DÉPLOIEMENT COMPLET — Base moderne 26ai"
echo "═══════════════════════════════════════════════════════════"

for script in \
  00_init_schemas.sql \
  01_app_sys.sql \
  02_app_org.sql \
  03_app_product.sql \
  04_app_party.sql \
  05_app_inv.sql \
  06_app_doc.sql \
  07_app_pos.sql \
  08_app_sales.sql \
  09_app_gl.sql \
  10_app_cash.sql \
  11_app_hist.sql \
  12_app_api.sql \
  13_triggers.sql \
  14_packages.sql \
  15_mviews.sql \
  16_jobs.sql \
  17_lot_r1_promotions.sql \
  18_lot_r2_loyalty.sql \
  19_lot_r3_stock_avance.sql \
  20_lot_r4_replenishment.sql \
  21_lot_r5_invoicing.sql
do
    echo ""
    echo "▶ Exécution : $script"
    echo "───────────────────────────────────────────────────────────"

    sqlplus -S "$CONN" <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

@${SCRIPTS_DIR}/${script}

EXIT
EOF

    echo "✅ $script terminé"
done

echo ""
echo "▶ Validation finale"
echo "───────────────────────────────────────────────────────────"

sqlplus -S "$CONN" <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

@${SCRIPTS_DIR}/99_validation.sql

EXIT
EOF

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ✅ DÉPLOIEMENT COMPLET TERMINÉ"
echo "═══════════════════════════════════════════════════════════"
