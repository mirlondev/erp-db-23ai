-- ============================================================
-- test_avances.sql — Tests avancés
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200

PROMPT ═══════════════════════════════════════════════════════
PROMPT   TESTS AVANCÉS SUR DONNÉES RÉELLES
PROMPT ═══════════════════════════════════════════════════════

PROMPT
PROMPT [1] Package pricing — Prix Tefal
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

SELECT '31274' AS product_code,
       app_product.pkg_pricing.get_price('31274', 2) AS prix_gros,
       app_product.pkg_pricing.get_price_ht('31274', 2) AS prix_ht
  FROM DUAL;

PROMPT
PROMPT [2] Package inventory — Stock par dépôt
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

SELECT '19889' AS product_code,
       app_inv.pkg_inventory.get_stock('19889', 'W90') AS w90,
       app_inv.pkg_inventory.get_stock('19889', 'PNR') AS pnr,
       app_inv.pkg_inventory.get_stock('19889', 'BZV') AS bzv
  FROM DUAL;

PROMPT
PROMPT [3] Package GL — Soldes comptables
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

SELECT '411270' AS compte, 'STAR FOODS CLIENTS' AS libelle,
       app_gl.pkg_gl.get_account_balance('01', '411270') AS solde
  FROM DUAL;

PROMPT
PROMPT [4] Vue matérialisée — Stock valorisé
CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

SELECT warehouse_code, product_code, product_name, stock_qty
  FROM mv_stock_summary
 WHERE ROWNUM <= 10
 ORDER BY warehouse_code, product_code;

PROMPT
PROMPT [5] Analyse ventes par jour
SELECT sale_date, terminal_id, nb_tickets, total_ttc
  FROM mv_daily_sales
 ORDER BY sale_date DESC;

EXIT;