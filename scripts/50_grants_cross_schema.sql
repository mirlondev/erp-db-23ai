-- ============================================================
-- SCRIPT 50 : Correction des GRANT cross-schéma + fix erreurs
-- ============================================================
-- Objectif : faire compiler TOUS les packages PL/SQL qui référencent
-- des tables d'autres schémas (pkg_transfer_stock, pkg_doc, pkg_pos_sales,
-- pkg_etl_legacy) + le trigger TRG_TICKET_AUDIT.
--
-- Pattern : GRANT SELECT/INSERT/UPDATE sur tables APP_X.Y TO APP_Z
-- Applique systématiquement par schéma destinataire.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

PROMPT ══════════════════════════════════════════════════════════
PROMPT   CORRECTION GRANTS CROSS-SCHÉMA
PROMPT ══════════════════════════════════════════════════════════

DECLARE
  v_ok  NUMBER := 0;
  v_ko  NUMBER := 0;

  -- Matrice : destinataire → liste (schema_src, table, privs)
  TYPE t_grant IS RECORD (
    grantee VARCHAR2(30),
    owner   VARCHAR2(30),
    table_name VARCHAR2(30),
    privs   VARCHAR2(100)
  );
  TYPE t_grants IS TABLE OF t_grant;

  v_grants t_grants := t_grants();

  PROCEDURE add(p_grantee VARCHAR2, p_owner VARCHAR2, p_tbl VARCHAR2, p_privs VARCHAR2) IS
  BEGIN
    v_grants.EXTEND;
    v_grants(v_grants.LAST).grantee   := p_grantee;
    v_grants(v_grants.LAST).owner     := p_owner;
    v_grants(v_grants.LAST).table_name := p_tbl;
    v_grants(v_grants.LAST).privs     := p_privs;
  END;

BEGIN

  -- ═══ APP_INV (pkg_transfer_stock) ═══
  add('APP_INV',  'APP_ORG',     'ORG_WAREHOUSE',    'SELECT');
  add('APP_INV',  'APP_POS',     'POS_TERMINAL',     'SELECT');
  add('APP_INV',  'APP_PRODUCT', 'PRODUCT',          'SELECT');
  add('APP_INV',  'APP_PRODUCT', 'PRODUCT_UNIT',     'SELECT');
  add('APP_INV',  'APP_PARTY',   'PARTY',            'SELECT');
  add('APP_INV',  'APP_SYS',     'SYS_AUDIT_TRAIL',  'INSERT, SELECT');

  -- ═══ APP_DOC (pkg_doc) ═══
  add('APP_DOC',  'APP_INV',     'INV_STOCK',         'SELECT');
  add('APP_DOC',  'APP_INV',     'INV_PRODUCT_LOT',   'SELECT');
  add('APP_DOC',  'APP_PRODUCT', 'PRODUCT',           'SELECT');
  add('APP_DOC',  'APP_PARTY',   'PARTY',             'SELECT');
  add('APP_DOC',  'APP_ORG',     'ORG_WAREHOUSE',     'SELECT');
  add('APP_DOC',  'APP_ORG',     'ORG_COMPANY',       'SELECT');
  add('APP_DOC',  'APP_SYS',     'SYS_AUDIT_TRAIL',   'INSERT, SELECT');

  -- ═══ APP_SALES (pkg_pos_sales + trg_ticket_audit) ═══
  add('APP_SALES','APP_PARTY',   'LOYALTY_CARD',     'SELECT, UPDATE');
  add('APP_SALES','APP_POS',     'POS_SESSION',      'SELECT');
  add('APP_SALES','APP_PRODUCT', 'PRODUCT',          'SELECT');
  add('APP_SALES','APP_PRODUCT', 'PROMO_POS_CONFIG', 'SELECT');
  add('APP_SALES','APP_PRODUCT', 'PROMO_POS_PRODUCT','SELECT');
  add('APP_SALES','APP_PARTY',   'PARTY',            'SELECT');
  add('APP_SALES','APP_SYS',     'ALERT_INSTANCE',   'INSERT, SELECT, UPDATE');
  add('APP_SALES','APP_SYS',     'SYS_AUDIT_TRAIL',  'INSERT, SELECT');

  -- ═══ APP_API (pkg_etl_legacy, dv_product, dv_party, ...) ═══
  add('APP_API',  'APP_PRODUCT', 'PRODUCT',         'SELECT');
  add('APP_API',  'APP_PARTY',   'PARTY',           'SELECT');
  add('APP_API',  'APP_INV',     'INV_STOCK',       'SELECT');
  add('APP_API',  'APP_ORG',     'ORG_COMPANY',     'SELECT');
  add('APP_API',  'APP_ORG',     'ORG_WAREHOUSE',   'SELECT');
  add('APP_API',  'APP_POS',     'POS_TERMINAL',    'SELECT');
  add('APP_API',  'APP_SYS',     'SYS_AUDIT_TRAIL', 'SELECT');
  add('APP_API',  'APP_SYS',     'SITE_MASTER',     'SELECT');
  add('APP_API',  'APP_SYS',     'SYS_COUNTRY',     'SELECT');
  add('APP_API',  'APP_SYS',     'CG_IRPP_BRACKET', 'SELECT');
  add('APP_API',  'APP_SYS',     'SYS_MESSAGE',     'SELECT');
  add('APP_API',  'APP_SYS',     'SYS_MESSAGE_LANG','SELECT');
  add('APP_API',  'APP_GL',      'GL_ACCOUNT_OHADA', 'SELECT');
  add('APP_API',  'APP_GL',      'GL_ACCOUNT',       'SELECT');
  add('APP_API',  'APP_GL',      'GL_ENTRY',        'SELECT');
  add('APP_API',  'APP_GL',      'GL_ENTRY_LINE',   'SELECT');
  add('APP_API',  'APP_GL',      'GL_JOURNAL',      'SELECT');
  add('APP_API',  'APP_GL',      'TAX_FORM_TYPE',   'SELECT');

  -- ═══ Seeds / promotions cross-schema ═══
  add('APP_PRODUCT', 'APP_ORG', 'ORG_POS', 'SELECT');

  -- ═══ APP_GL (déclarations fiscales + OHADA) ═══
  add('APP_GL',   'APP_AR',      'INVOICE',           'SELECT');
  add('APP_GL',   'APP_AR',      'INVOICE_INSTALLMENT','SELECT');
  add('APP_GL',   'APP_AR',      'INVOICE_DISPUTE',   'SELECT');
  add('APP_GL',   'APP_HR',      'PAYROLL_SLIP',      'SELECT');
  add('APP_GL',   'APP_HR',      'PAYROLL_RUN',       'SELECT');
  add('APP_GL',   'APP_PARTY',   'PARTY',             'SELECT');

  -- ═══ APP_AR (invoicing) ═══
  add('APP_AR',   'APP_PARTY',   'PARTY',             'SELECT');
  add('APP_AR',   'APP_PRODUCT', 'PRODUCT',           'SELECT');
  add('APP_AR',   'APP_DOC',     'DOC_HEADER',        'SELECT');
  add('APP_AR',   'APP_DOC',     'DOC_LINE',          'SELECT');
  add('APP_AR',   'APP_SYS',     'SYS_AUDIT_TRAIL',   'INSERT, SELECT');

  -- ═══ APP_HR (paie) ═══
  add('APP_HR',   'APP_PARTY',   'PARTY',             'SELECT');
  add('APP_HR',   'APP_ORG',     'ORG_COMPANY',       'SELECT');
  add('APP_HR',   'APP_ORG',     'ORG_POS',           'SELECT');
  add('APP_HR',   'APP_GL',      'GL_ACCOUNT',        'SELECT');
  add('APP_HR',   'APP_SYS',     'SYS_AUDIT_TRAIL',   'INSERT, SELECT');
  add('APP_HR',   'APP_SYS',     'FN_CG_IRPP',        'EXECUTE');

  -- ═══ APP_AUDIT (audit consolidé) ═══
  add('APP_AUDIT','APP_SYS',     'SYS_AUDIT_TRAIL',   'SELECT, INSERT, UPDATE, DELETE');

  -- ═══ Application des grants ═══
  FOR g IN 1..v_grants.COUNT LOOP
    BEGIN
      EXECUTE IMMEDIATE 'GRANT ' || v_grants(g).privs || ' ON ' ||
                        v_grants(g).owner || '.' || v_grants(g).table_name ||
                        ' TO ' || v_grants(g).grantee;
      v_ok := v_ok + 1;
    EXCEPTION WHEN OTHERS THEN
      v_ko := v_ko + 1;
      DBMS_OUTPUT.PUT_LINE('  ⚠ ' || v_grants(g).grantee || ' ← ' ||
                           v_grants(g).owner || '.' || v_grants(g).table_name ||
                           ' : ' || SQLERRM);
    END;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('  → ' || v_ok || ' GRANT(s) appliqué(s), ' || v_ko || ' échec(s)');
END;
/

-- ═══ Synonymes publics pour faciliter les accès ═══
PROMPT
PROMPT ═══ Synonymes ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

BEGIN
  FOR u IN (SELECT username FROM dba_users
             WHERE username LIKE 'APP\_%' ESCAPE '\'
               AND oracle_maintained = 'N') LOOP
    BEGIN
      EXECUTE IMMEDIATE 'GRANT CREATE SYNONYM TO ' || u.username;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

PROMPT
PROMPT ═══ Recompilation des objets invalides ═══
DECLARE
  v_status VARCHAR2(10);
BEGIN
  FOR u IN (SELECT owner, object_name, object_type
              FROM dba_objects
             WHERE status = 'INVALID'
               AND owner LIKE 'APP\_%' ESCAPE '\'
               AND object_type IN ('PACKAGE BODY','TRIGGER','VIEW','PROCEDURE')
             ORDER BY owner, object_name) LOOP
    DECLARE
      v_sql VARCHAR2(500);
    BEGIN
      IF u.object_type = 'PACKAGE BODY' THEN
        v_sql := 'ALTER PACKAGE ' || u.owner || '.' || u.object_name || ' COMPILE BODY';
      ELSIF u.object_type = 'TRIGGER' THEN
        v_sql := 'ALTER TRIGGER ' || u.owner || '.' || u.object_name || ' COMPILE';
      ELSE
        v_sql := 'ALTER ' || u.object_type || ' ' || u.owner || '.' || u.object_name || ' COMPILE';
      END IF;

      EXECUTE IMMEDIATE v_sql;

      SELECT status INTO v_status FROM dba_objects
       WHERE owner = u.owner AND object_name = u.object_name
         AND object_type = u.object_type AND ROWNUM = 1;

      DBMS_OUTPUT.PUT_LINE('  [' || v_status || '] ' || u.owner || '.' || u.object_name);
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  [KO]  ' || u.owner || '.' || u.object_name || ' — ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT
PROMPT ═══ État final ═══
SELECT owner, object_type, object_name, status
  FROM dba_objects
 WHERE status = 'INVALID'
   AND owner LIKE 'APP\_%' ESCAPE '\'
 ORDER BY owner, object_type, object_name;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ GRANTS CORRIGÉS + RECOMPILATION
PROMPT ══════════════════════════════════════════════════════════
EXIT;
