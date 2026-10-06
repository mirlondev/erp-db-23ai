#!/bin/bash
CONTAINER=oracle_ai_database_26ai_free
APPS_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$APPS_DIR/validate_output.txt"
SQLCL="/opt/oracle/product/26ai/dbhomeFree/sqlcl/bin/sql"

echo "=== Copying zips into container ===" | tee "$OUT"
docker cp "$APPS_DIR/app-pos.zip"   "$CONTAINER":/tmp/app-pos.zip
docker cp "$APPS_DIR/app-stock.zip" "$CONTAINER":/tmp/app-stock.zip

echo "" | tee -a "$OUT"
echo "=== apex validate  app-pos ===" | tee -a "$OUT"
docker exec -i "$CONTAINER" "$SQLCL" /nolog 2>&1 <<'SQL' | tee -a "$OUT"
apex validate -input /tmp/app-pos.zip
exit
SQL

echo "" | tee -a "$OUT"
echo "=== apex validate  app-stock ===" | tee -a "$OUT"
docker exec -i "$CONTAINER" "$SQLCL" /nolog 2>&1 <<'SQL' | tee -a "$OUT"
apex validate -input /tmp/app-stock.zip
exit
SQL

echo "" | tee -a "$OUT"
echo "=== DONE ===" | tee -a "$OUT"
echo ""
echo "Results saved to: $OUT"