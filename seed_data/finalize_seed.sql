-- ============================================================
-- finalize_seed.sql — Finalisation du seed SUPER SONIC
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET LINESIZE 200

PROMPT ═══════════════════════════════════════════════════════
PROMPT   FINALISATION DU SEED
PROMPT ═══════════════════════════════════════════════════════

-- 1. Réparer les objets invalides
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA
EXEC UTL_RECOMP.RECOMP_SERIAL('APP_SALES');
EXEC UTL_RECOMP.RECOMP_SERIAL('APP_API');

-- 2. Recompiler le trigger
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1
ALTER TRIGGER trg_ticket_audit COMPILE;

-- 3. Rafraîchir les MV
CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1
BEGIN
  DBMS_MVIEW.REFRESH('MV_STOCK_SUMMARY', 'C');
  DBMS_MVIEW.REFRESH('MV_PRODUCT_SALES', 'C');
  DBMS_MVIEW.REFRESH('MV_DAILY_SALES', 'C');
END;
/

-- 4. Ajouter clients manquants
CONNECT app_party/AppParty#2026@localhost:1521/FREEPDB1
INSERT INTO party (party_code, party_name, nature_id, currency_code, is_misc, status, created_by)
SELECT 'CL0005', 'TIMBRE ELECTRONIQUE CGO', nature_id, 'XAF', TRUE, 'ACTIVE', 'ADMIN'
  FROM party_nature WHERE nature_code = 'CPO'
  AND NOT EXISTS (SELECT 1 FROM party WHERE party_code = 'CL0005');
COMMIT;

-- 5. Validation finale
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

PROMPT
PROMPT [A] Objets invalides (doit être vide)
SELECT owner, object_type, object_name
  FROM all_objects
 WHERE status = 'INVALID'
   AND owner LIKE 'APP\_%' ESCAPE '\';

PROMPT
PROMPT [B] Volumétrie finale
SELECT 'app_product.product'    AS tbl, COUNT(*) AS nb FROM app_product.product
UNION ALL SELECT 'app_party.party',     COUNT(*) FROM app_party.party
UNION ALL SELECT 'app_inv.inv_stock',   COUNT(*) FROM app_inv.inv_stock
UNION ALL SELECT 'app_gl.gl_account',   COUNT(*) FROM app_gl.gl_account
UNION ALL SELECT 'app_pos.pos_terminal',COUNT(*) FROM app_pos.pos_terminal
UNION ALL SELECT 'app_sales.ticket',    COUNT(*) FROM app_sales.ticket
UNION ALL SELECT 'app_cash.cash_register', COUNT(*) FROM app_cash.cash_register;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ FINALISATION TERMINÉE
PROMPT ═══════════════════════════════════════════════════════

EXIT;