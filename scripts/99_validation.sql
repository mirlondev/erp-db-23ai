-- ============================================================
-- SCRIPT 99 : Validation finale
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200

CONNECT system/oracle@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   VALIDATION FINALE — Base moderne 26ai
PROMPT ═══════════════════════════════════════════════════════

PROMPT
PROMPT [1] Version
SELECT banner_full FROM v$version;

PROMPT
PROMPT [2] Schémas
SELECT username, default_tablespace, account_status
  FROM dba_users
 WHERE username LIKE 'APP\_%' ESCAPE '\'
   AND oracle_maintained = 'N'
 ORDER BY username;

PROMPT
PROMPT [3] Nombre de tables par schéma
SELECT owner, COUNT(*) AS nb_tables
  FROM dba_tables
 WHERE owner LIKE 'APP\_%' ESCAPE '\'
 GROUP BY owner
 ORDER BY owner;

PROMPT
PROMPT [4] Nombre d'index par schéma
SELECT owner, COUNT(*) AS nb_indexes
  FROM dba_indexes
 WHERE owner LIKE 'APP\_%' ESCAPE '\'
   AND index_name NOT LIKE 'SYS_%'
 GROUP BY owner
 ORDER BY owner;

PROMPT
PROMPT [5] Objets invalides (doit être vide)
SELECT owner, object_type, object_name, status
  FROM dba_objects
 WHERE status = 'INVALID'
   AND owner LIKE 'APP\_%' ESCAPE '\';

PROMPT
PROMPT [6] Contraintes désactivées
SELECT owner, table_name, constraint_name, constraint_type, status
  FROM dba_constraints
 WHERE status = 'DISABLED'
   AND owner LIKE 'APP\_%' ESCAPE '\';

PROMPT
PROMPT [7] Triggers
SELECT owner, trigger_name, status
  FROM dba_triggers
 WHERE owner LIKE 'APP\_%' ESCAPE '\'
 ORDER BY owner, trigger_name;

PROMPT
PROMPT [8] Packages
SELECT owner, object_name, object_type, status
  FROM dba_objects
 WHERE object_name LIKE 'PKG\_%' ESCAPE '\'
   AND owner LIKE 'APP\_%' ESCAPE '\'
   AND object_type IN ('PACKAGE','PACKAGE BODY','FUNCTION','PROCEDURE')
 ORDER BY owner, object_name;

PROMPT
PROMPT [9] JSON Duality Views
SELECT owner, view_name
  FROM dba_views
 WHERE owner = 'APP_API'
   AND view_name LIKE 'DV\_%' ESCAPE '\'
 ORDER BY view_name;

PROMPT
PROMPT [10] Vues matérialisées
SELECT owner, mview_name, refresh_mode, staleness
  FROM dba_mviews
 WHERE owner LIKE 'APP\_%' ESCAPE '\';

PROMPT
PROMPT [11] Jobs
SELECT owner, job_name, enabled, state
  FROM dba_scheduler_jobs
 WHERE owner LIKE 'APP\_%' ESCAPE '\'
 ORDER BY owner, job_name;

PROMPT
PROMPT [12] Volumétrie clé
SELECT 'app_product.product'        AS tbl, COUNT(*) AS nb FROM app_product.product
UNION ALL SELECT 'app_product.promo_header',   COUNT(*) FROM app_product.promo_header
UNION ALL SELECT 'app_product.price_tier',     COUNT(*) FROM app_product.price_tier
UNION ALL SELECT 'app_party.party',          COUNT(*) FROM app_party.party
UNION ALL SELECT 'app_party.loyalty_card',     COUNT(*) FROM app_party.loyalty_card
UNION ALL SELECT 'app_party.loyalty_operation',COUNT(*) FROM app_party.loyalty_operation
UNION ALL SELECT 'app_inv.inv_stock',        COUNT(*) FROM app_inv.inv_stock
UNION ALL SELECT 'app_doc.doc_header',       COUNT(*) FROM app_doc.doc_header
UNION ALL SELECT 'app_doc.doc_line',         COUNT(*) FROM app_doc.doc_line
UNION ALL SELECT 'app_pos.pos_terminal',     COUNT(*) FROM app_pos.pos_terminal
UNION ALL SELECT 'app_pos.pos_session',      COUNT(*) FROM app_pos.pos_session
UNION ALL SELECT 'app_sales.ticket',         COUNT(*) FROM app_sales.ticket
UNION ALL SELECT 'app_sales.ticket_line',    COUNT(*) FROM app_sales.ticket_line
UNION ALL SELECT 'app_sales.ticket_payment', COUNT(*) FROM app_sales.ticket_payment
UNION ALL SELECT 'app_gl.gl_entry',          COUNT(*) FROM app_gl.gl_entry
UNION ALL SELECT 'app_gl.gl_entry_line',     COUNT(*) FROM app_gl.gl_entry_line
UNION ALL SELECT 'app_cash.cash_register',   COUNT(*) FROM app_cash.cash_register
UNION ALL SELECT 'app_cash.cash_movement',   COUNT(*) FROM app_cash.cash_movement;

PROMPT
PROMPT [13] Espace utilisé
SELECT owner,
       ROUND(SUM(bytes)/1024/1024, 2) AS used_mb
  FROM dba_segments
 WHERE owner LIKE 'APP\_%' ESCAPE '\'
 GROUP BY owner
 ORDER BY owner;

PROMPT
PROMPT [14] Test BOOLEAN natif (app_product)
SELECT product_code, product_name, is_stock_managed, is_promo
  FROM app_product.product
 WHERE is_stock_managed = TRUE
   AND is_promo = FALSE;

PROMPT
PROMPT [15] Test JSON Duality View (dv_product)
SELECT JSON_SERIALIZE(data PRETTY)
  FROM app_api.dv_product
 FETCH FIRST 1 ROWS ONLY;

PROMPT
PROMPT [16] Test JSON Duality View (dv_ticket)
SELECT JSON_SERIALIZE(data PRETTY)
  FROM app_api.dv_ticket
 WHERE JSON_VALUE(data, '$._id') = '1';

PROMPT
PROMPT [17] Test package pkg_pricing
SELECT app_product.pkg_pricing.get_price('ART001', 1) AS prix
  FROM DUAL;

PROMPT
PROMPT [18] Test package pkg_inventory
SELECT app_inv.pkg_inventory.get_stock('ART001', 'DEP01') AS stock
  FROM DUAL;

PROMPT
PROMPT [19] Test package pkg_gl
SELECT app_gl.pkg_gl.get_account_balance('01', '530000') AS solde_caisse
  FROM DUAL;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ VALIDATION FINALE TERMINÉE
PROMPT ═══════════════════════════════════════════════════════
