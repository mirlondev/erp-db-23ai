#!/bin/bash
# validate_and_save.sh
# Run this from YOUR terminal (where docker works)
# It validates both apps and saves output to validate_output.txt

CONTAINER=oracle_ai_database_26ai_free
APPS_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$APPS_DIR/validate_output.txt"

echo "=== Copying zips into container ===" | tee "$OUT"
docker cp "$APPS_DIR/app-pos.zip"   "$CONTAINER":/tmp/app-pos.zip
docker cp "$APPS_DIR/app-stock.zip" "$CONTAINER":/tmp/app-stock.zip

echo "" | tee -a "$OUT"
echo "=== apex validate  app-pos ===" | tee -a "$OUT"
# Utiliser /nolog pour valider sans connexion à la base de données
docker exec -i "$CONTAINER" /opt/oracle/product/26ai/dbhomeFree/sqlcl/bin/sql /nolog 2>&1 <<'SQL' | tee -a "$OUT"
apex validate -input /tmp/app-pos.zip
exit
SQL

echo "" | tee -a "$OUT"
echo "=== apex validate  app-stock ===" | tee -a "$OUT"
docker exec -i "$CONTAINER" /opt/oracle/product/26ai/dbhomeFree/sqlcl/bin/sql /nolog 2>&1 <<'SQL' | tee -a "$OUT"
apex validate -input /tmp/app-stock.zip
exit
SQL

echo "" | tee -a "$OUT"
echo "=== DONE ===" | tee -a "$OUT"
echo ""
echo "Results saved to: $OUT"