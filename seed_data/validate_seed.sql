-- ============================================================
-- validate_seed.sql — Validation complète du seed
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100

CONNECT system/oracle@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   VALIDATION DU SEED SUPER SONIC
PROMPT ═══════════════════════════════════════════════════════

PROMPT
PROMPT [1] Volumétrie par schéma
SELECT 'app_sys'     AS schema, 'sys_user'        AS table_name, COUNT(*) AS nb FROM app_sys.sys_user
UNION ALL SELECT 'app_sys', 'sys_parameter',       COUNT(*) FROM app_sys.sys_parameter
UNION ALL SELECT 'app_sys', 'sys_access_key',      COUNT(*) FROM app_sys.sys_access_key
UNION ALL SELECT 'app_org', 'org_company',         COUNT(*) FROM app_org.org_company
UNION ALL SELECT 'app_org', 'org_warehouse',       COUNT(*) FROM app_org.org_warehouse
UNION ALL SELECT 'app_org', 'org_pos',             COUNT(*) FROM app_org.org_pos
UNION ALL SELECT 'app_product', 'product',         COUNT(*) FROM app_product.product
UNION ALL SELECT 'app_product', 'prod_category',   COUNT(*) FROM app_product.prod_category
UNION ALL SELECT 'app_product', 'prod_brand',      COUNT(*) FROM app_product.prod_brand
UNION ALL SELECT 'app_party', 'party',             COUNT(*) FROM app_party.party
UNION ALL SELECT 'app_inv', 'inv_stock',           COUNT(*) FROM app_inv.inv_stock
UNION ALL SELECT 'app_gl', 'gl_account',           COUNT(*) FROM app_gl.gl_account
UNION ALL SELECT 'app_pos', 'pos_terminal',        COUNT(*) FROM app_pos.pos_terminal
UNION ALL SELECT 'app_sales', 'ticket',            COUNT(*) FROM app_sales.ticket
UNION ALL SELECT 'app_cash', 'cash_register',      COUNT(*) FROM app_cash.cash_register
UNION ALL SELECT 'app_cash', 'cash_movement_type', COUNT(*) FROM app_cash.cash_movement_type
 ORDER BY 1, 2;

PROMPT
PROMPT [2] Objets invalides (doit être vide)
SELECT owner, object_type, object_name
  FROM all_objects
 WHERE status = 'INVALID'
   AND owner LIKE 'APP\_%' ESCAPE '\';

EXIT;