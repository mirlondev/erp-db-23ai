-- ============================================================
-- DIAGNOSTIC — Erreurs de compilation
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
SET PAGESIZE 500
COL text FOR A140
COL owner FOR A12
COL name FOR A25

PROMPT ================================================================
PROMPT   ERREURS PKG_POS_SALES (APP_SALES)
PROMPT ================================================================
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1
SELECT line, position, text
  FROM user_errors
 WHERE name = 'PKG_POS_SALES' AND type = 'PACKAGE BODY'
 ORDER BY sequence;

PROMPT
PROMPT ================================================================
PROMPT   ERREURS PKG_TRANSFER_STOCK (APP_INV)
PROMPT ================================================================
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1
SELECT line, position, text
  FROM user_errors
 WHERE name = 'PKG_TRANSFER_STOCK' AND type = 'PACKAGE BODY'
 ORDER BY sequence;

PROMPT
PROMPT ================================================================
PROMPT   ERREURS PKG_DOC (APP_DOC)
PROMPT ================================================================
CONNECT app_doc/AppDoc#2026@localhost:1521/FREEPDB1
SELECT line, position, text
  FROM user_errors
 WHERE name = 'PKG_DOC' AND type = 'PACKAGE BODY'
 ORDER BY sequence;

PROMPT
PROMPT ================================================================
PROMPT   ERREURS PKG_ETL_LEGACY (APP_API)
PROMPT ================================================================
CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1
SELECT line, position, text
  FROM user_errors
 WHERE name = 'PKG_ETL_LEGACY' AND type = 'PACKAGE BODY'
 ORDER BY sequence;

PROMPT
PROMPT ================================================================
PROMPT   ERREURS TRG_TICKET_AUDIT (APP_SALES)
PROMPT ================================================================
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1
SELECT line, position, text
  FROM user_errors
 WHERE name = 'TRG_TICKET_AUDIT' AND type = 'TRIGGER'
 ORDER BY sequence;

PROMPT
PROMPT ================================================================
PROMPT   DUALITY VIEWS EXISTANTES (APP_API)
PROMPT ================================================================
CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1
SELECT view_name FROM user_views WHERE view_name LIKE 'DV\_%' ESCAPE '\';
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name LIKE 'DV\_%' ESCAPE '\';

PROMPT
PROMPT ================================================================
PROMPT   RECHERCHE DV_TICKET AILLEURS
PROMPT ================================================================
CONNECT system/oracle@localhost:1521/FREEPDB1
SELECT owner, view_name
  FROM dba_views
 WHERE view_name LIKE 'DV\_%' ESCAPE '\'
 ORDER BY owner, view_name;

EXIT;
