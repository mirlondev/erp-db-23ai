#!/bin/bash
# ============================================================
# run_all_with_seeds.sh
# Pipeline complet : DDL → validation → reset → seeds → validation seed
# Usage : ./run_all_with_seeds.sh
# ============================================================
set -euo pipefail

CONN="${ORACLE_CONNECT:-sys/oracle@localhost:1521/FREEPDB1 as sysdba}"
SQLCLI="${SQLCLI:-sql}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SEEDS_DIR="${SCRIPTS_DIR}/../seed_data"
DOCS_DIR="${SCRIPTS_DIR}/../docs"

if [[ "${ALLOW_DESTRUCTIVE_RESET:-NO}" != "YES" ]]; then
  printf 'Refus: ce pipeline reconstruit APP_* puis efface les données de seed.\n' >&2
  printf 'Relance avec ALLOW_DESTRUCTIVE_RESET=YES après sauvegarde.\n' >&2
  exit 2
fi

if ! command -v "$SQLCLI" >/dev/null 2>&1; then
  printf 'Erreur: SQLcl introuvable (%s).\n' "$SQLCLI" >&2
  exit 127
fi

SEEDS=(
  S00_reset.sql
  S01_seed_app_sys.sql
  S02_seed_app_org.sql
  S03_seed_app_product.sql
  S04_seed_app_party.sql
  S05_seed_app_inv.sql
  S06_seed_app_gl.sql
  S07_seed_app_pos_sales.sql
  S08_seed_app_cash.sql
  S09_seed_lot_r1_promotions.sql
  S10_seed_lot_r2_loyalty.sql
  S11_seed_lot_r3_stock_avance.sql
  S12_seed_lot_r4_replenishment.sql
  S13_seed_lot_r5_invoicing.sql
  S14_seed_lot_r6_payments_advanced.sql
  S15_seed_lot_r7_pos_advanced.sql
  S16_seed_lot_r8_promo_pos.sql
  S17_seed_lot_r9_inventory_count.sql
  S18_seed_lot_r10_vouchers.sql
  S19_seed_lot_r11_alerts.sql
  S20_seed_lot_r12_reporting.sql
  S21_seed_lot_r13_security.sql
  S22_seed_lot_r14_interfaces.sql
  S24_seed_immobilisations.sql
  S25_seed_declarations_fiscales.sql
  S26_seed_payroll.sql
  S27_seed_congo_pni.sql
  S28_seed_payroll_congo.sql
  S29_seed_tva_congo.sql
  S32_re_seed_real_codes.sql
  S23_seed_transfer_stock.sql
  S30_seed_regal_topology.sql
  S31_seed_legacy_gap.sql
)

CSV_FILES=(
  GCPART_20260612d1759-articles.csv
  GCSTOCK_202606121810.csv
  GCPTARIF_202606121806.csv
  GCPTARIF_ART_202606121807-prix.csv
  GCPTIE_202606121809.csv
  GCPTBRD_202606121808.csv
  GCPRTAX_202606121806.csv
)

for seed in "${SEEDS[@]}" validate_seed.sql; do
  if [[ ! -f "${SEEDS_DIR}/${seed}" ]]; then
    printf 'Erreur: fichier seed absent: %s\n' "$seed" >&2
    exit 1
  fi
done

for csv_file in "${CSV_FILES[@]}"; do
  if [[ ! -f "${DOCS_DIR}/${csv_file}" ]]; then
    printf 'Erreur: CSV legacy absent: %s\n' "$csv_file" >&2
    exit 1
  fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  PIPELINE COMPLET — Schéma + Seeds + Validation"
echo "════════════════════════════════════════════════════════════"

# 1. Déploiement DDL complet
echo ""
echo "▶ Étape 1/4 : Déploiement DDL"
bash "${SCRIPTS_DIR}/run_all.sh"

# 2. Reset + Seeds
echo ""
echo "▶ Étape 2/4 : Reset et Seeds"
for seed in "${SEEDS[@]}"
do
    echo ""
    echo "▶ Seed : $seed"
    echo "───────────────────────────────────────────────────────────"
    "$SQLCLI" -S "$CONN" <<EOF
  WHENEVER SQLERROR EXIT SQL.SQLCODE
  WHENEVER OSERROR EXIT FAILURE
@${SEEDS_DIR}/${seed}
EXIT
EOF
    echo "✅ $seed terminé"
done

# 3. Import legacy depuis CSV après le reset et les seeds
echo ""
echo "▶ Étape 3/4 : Import CSV legacy"
echo "───────────────────────────────────────────────────────────"
"$SQLCLI" -S "$CONN" <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE
@${SCRIPTS_DIR}/57b_etl_legacy_csv_fix.sql
EXIT
EOF

# 4. Validation finale post-seed et post-import
echo ""
echo "▶ Étape 4/4 : Validation post-import"
echo "───────────────────────────────────────────────────────────"
"$SQLCLI" -S "$CONN" <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE
@${SEEDS_DIR}/validate_seed.sql
EXIT
EOF

echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ PIPELINE COMPLET TERMINÉ"
echo "════════════════════════════════════════════════════════════"
