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
  21_lot_r5_invoicing.sql \
  22_lot_r6_payments_advanced.sql \
  23_lot_r7_pos_advanced.sql \
  24_lot_r8_promo_pos.sql \
  25_lot_r9_inventory_count.sql \
  26_lot_r10_vouchers.sql \
  27_lot_r11_alerts.sql \
  28_lot_r12_reporting.sql \
  29_lot_r13_security.sql \
  30_lot_r14_interfaces.sql \
  31_pkg_pos_sales.sql \
  32_pkg_pos_sales_body.sql \
  33_trg_invoice_overdue.sql \
  34_app_api_extensibility.sql \
  35_lot1ab_doc_complement.sql \
  36_lot1cd_costs_doc_commercial.sql \
  37_lot1e_expeditions.sql \
  38_ohada_skeleton.sql \
  39_lot1f_purchase.sql \
  40_pkg_doc.sql \
  41_pkg_doc_body.sql \
  42_etl_legacy_to_modern.sql \
  43_pkg_transfer_stock.sql \
  44_pkg_transfer_stock_body.sql \
  45_lot1g_invoicing.sql \
  46_ohada_immobilisations.sql \
  47_ohada_declarations.sql \
  48_app_hr.sql \
  49_congo_fiscal.sql \
  50_grants_cross_schema.sql \
  51_hub_spoke_topology.sql \
  52_sync_framework.sql \
  53_legacy_gap_filler.sql \
  54_partition_tables_volumineuses.sql \
  55_pkg_etl_legacy_v2.sql
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
