#!/bin/bash
# run_validate.sh — copies zips into Oracle container and runs apex validate
set -e

CONTAINER=oracle_ai_database_26ai_free
APPS_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$APPS_DIR/validate_output.txt"
SQLCL="/opt/oracle/product/26ai/dbhomeFree/sqlcl/bin/sql"
CONN="sys/oracle@localhost:1521/FREEPDB1 as sysdba"

echo "=== Copying zip files into container ===" | tee "$OUT"
docker cp "$APPS_DIR/app-pos.zip"   "$CONTAINER":/tmp/app-pos.zip
docker cp "$APPS_DIR/app-stock.zip" "$CONTAINER":/tmp/app-stock.zip
echo "Done." | tee -a "$OUT"

echo "" | tee -a "$OUT"
echo "=== Validating app-pos ===" | tee -a "$OUT"
docker exec -i "$CONTAINER" "$SQLCL" -S "$CONN" <<'SQLEOF' 2>&1 | tee -a "$OUT"
apex validate -workspace REGAL -input /tmp/app-pos.zip
exit
SQLEOF

echo "" | tee -a "$OUT"
echo "=== Validating app-stock ===" | tee -a "$OUT"
docker exec -i "$CONTAINER" "$SQLCL" -S "$CONN" <<'SQLEOF' 2>&1 | tee -a "$OUT"
apex validate -workspace REGAL -input /tmp/app-stock.zip
exit
SQLEOF

echo "" | tee -a "$OUT"
echo "=== Done. Results in $OUT ===" | tee -a "$OUT"
