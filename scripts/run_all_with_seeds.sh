#!/bin/bash
# ============================================================
# run_all_with_seeds.sh
# Pipeline complet : DDL → validation → reset → seeds → validation seed
# Usage : ./run_all_with_seeds.sh
# ============================================================
set -e

CONN="system/oracle@localhost:1521/FREEPDB1"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SEEDS_DIR="${SCRIPTS_DIR}/../seed_data"

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  PIPELINE COMPLET — Schéma + Seeds + Validation"
echo "════════════════════════════════════════════════════════════"

# 1. Déploiement DDL complet
echo ""
echo "▶ Étape 1/3 : Déploiement DDL (00 → 17)"
bash "${SCRIPTS_DIR}/run_all.sh"

# 2. Reset + Seeds
echo ""
echo "▶ Étape 2/3 : Reset et Seeds"
for seed in \
  S00_reset.sql \
  S01_seed_app_sys.sql \
  S02_seed_app_org.sql \
  S03_seed_app_product.sql \
  S04_seed_app_party.sql \
  S05_seed_app_inv.sql \
  S06_seed_app_gl.sql \
  S07_seed_app_pos_sales.sql \
  S08_seed_app_cash.sql \
  S09_seed_lot_r1_promotions.sql \
  S10_seed_lot_r2_loyalty.sql \
  S11_seed_lot_r3_stock_avance.sql \
  S12_seed_lot_r4_replenishment.sql \
  S13_seed_lot_r5_invoicing.sql \
  S14_seed_lot_r6_payments_advanced.sql \
  S15_seed_lot_r7_pos_advanced.sql \
  S16_seed_lot_r8_promo_pos.sql \
  S17_seed_lot_r9_inventory_count.sql \
  S18_seed_lot_r10_vouchers.sql \
  S19_seed_lot_r11_alerts.sql \
  S20_seed_lot_r12_reporting.sql \
  S21_seed_lot_r13_security.sql \
  S22_seed_lot_r14_interfaces.sql \
  S23_seed_transfer_stock.sql \
  S24_seed_immobilisations.sql \
  S25_seed_declarations_fiscales.sql \
  S26_seed_payroll.sql \
  S27_seed_congo_pni.sql \
  S28_seed_payroll_congo.sql \
  S29_seed_tva_congo.sql \
  S30_seed_regal_topology.sql
do
    echo ""
    echo "▶ Seed : $seed"
    echo "───────────────────────────────────────────────────────────"
    sqlplus -S "$CONN" <<EOF
@${SEEDS_DIR}/${seed}
EXIT
EOF
    echo "✅ $seed terminé"
done

# 3. Validation finale post-seed
echo ""
echo "▶ Étape 3/3 : Validation post-seed"
echo "───────────────────────────────────────────────────────────"
sqlplus -S "$CONN" <<EOF
@${SEEDS_DIR}/validate_seed.sql
EXIT
EOF

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ PIPELINE COMPLET TERMINÉ"
echo "════════════════════════════════════════════════════════════"
