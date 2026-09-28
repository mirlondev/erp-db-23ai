-- ============================================================
-- SCRIPT : Correction complète (privilèges + recompilation)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT system/oracle@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   Attribution privilèges cross-schéma
PROMPT ===============================================================

PROMPT
PROMPT [APP_SALES] privilèges croisés
BEGIN
  FOR g IN (
    SELECT 'GRANT ' || privilege || ' ON ' || obj_owner || '.' || table_name ||
           ' TO app_sales' AS stmt
      FROM (
        SELECT 'INSERT, SELECT, UPDATE' AS privilege, 'APP_SYS'    AS obj_owner, 'ALERT_INSTANCE'   AS table_name FROM dual
        UNION ALL SELECT 'INSERT, SELECT',           'APP_SYS',    'SYS_AUDIT_TRAIL'    FROM dual
        UNION ALL SELECT 'SELECT, UPDATE',           'APP_PARTY',  'LOYALTY_CARD'       FROM dual
        UNION ALL SELECT 'SELECT',                   'APP_PRODUCT','PROMO_POS_CONFIG'  FROM dual
        UNION ALL SELECT 'SELECT',                   'APP_PRODUCT','PROMO_POS_PRODUCT' FROM dual
        UNION ALL SELECT 'SELECT',                   'APP_PRODUCT','PRODUCT'           FROM dual
        UNION ALL SELECT 'SELECT',                   'APP_PARTY',  'PARTY'             FROM dual
      )
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE g.stmt;
      DBMS_OUTPUT.PUT_LINE('  [OK] ' || g.stmt);
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  [KO] ' || g.stmt || ' -- ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT
PROMPT [APP_INV] privilèges croisés
BEGIN
  FOR g IN (
    SELECT 'GRANT ' || privilege || ' ON ' || obj_owner || '.' || table_name ||
           ' TO app_inv' AS stmt
      FROM (
        SELECT 'SELECT' AS privilege, 'APP_ORG',    'ORG_WAREHOUSE' AS table_name FROM dual
        UNION ALL SELECT 'SELECT',    'APP_POS',    'POS_TERMINAL'   FROM dual
        UNION ALL SELECT 'SELECT',    'APP_PRODUCT','PRODUCT'        FROM dual
        UNION ALL SELECT 'SELECT',    'APP_PRODUCT','PRODUCT_UNIT'   FROM dual
        UNION ALL SELECT 'SELECT',    'APP_PARTY',  'PARTY'          FROM dual
        UNION ALL SELECT 'INSERT, SELECT', 'APP_SYS','SYS_AUDIT_TRAIL' FROM dual
      )
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE g.stmt;
      DBMS_OUTPUT.PUT_LINE('  [OK] ' || g.stmt);
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  [KO] ' || g.stmt || ' -- ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT
PROMPT [APP_DOC] privilèges croisés
BEGIN
  FOR g IN (
    SELECT 'GRANT ' || privilege || ' ON ' || obj_owner || '.' || table_name ||
           ' TO app_doc' AS stmt
      FROM (
        SELECT 'SELECT' AS privilege, 'APP_INV',    'INV_STOCK'       AS table_name FROM dual
        UNION ALL SELECT 'SELECT',    'APP_INV',    'INV_PRODUCT_LOT'  FROM dual
        UNION ALL SELECT 'SELECT',    'APP_PRODUCT','PRODUCT'          FROM dual
        UNION ALL SELECT 'SELECT',    'APP_PARTY',  'PARTY'            FROM dual
        UNION ALL SELECT 'SELECT',    'APP_ORG',    'ORG_WAREHOUSE'    FROM dual
        UNION ALL SELECT 'INSERT, SELECT', 'APP_SYS','SYS_AUDIT_TRAIL' FROM dual
      )
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE g.stmt;
      DBMS_OUTPUT.PUT_LINE('  [OK] ' || g.stmt);
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  [KO] ' || g.stmt || ' -- ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT
PROMPT [APP_API] privilèges croisés
BEGIN
  FOR g IN (
    SELECT 'GRANT ' || privilege || ' ON ' || obj_owner || '.' || table_name ||
           ' TO app_api' AS stmt
      FROM (
        SELECT 'SELECT' AS privilege, 'APP_PRODUCT', 'PRODUCT'        AS table_name FROM dual
        UNION ALL SELECT 'SELECT',    'APP_PARTY',   'PARTY'           FROM dual
        UNION ALL SELECT 'SELECT',    'APP_INV',     'INV_STOCK'       FROM dual
        UNION ALL SELECT 'SELECT',    'APP_ORG',     'ORG_COMPANY'     FROM dual
        UNION ALL SELECT 'SELECT',    'APP_ORG',     'ORG_WAREHOUSE'   FROM dual
      )
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE g.stmt;
      DBMS_OUTPUT.PUT_LINE('  [OK] ' || g.stmt);
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  [KO] ' || g.stmt || ' -- ' || SQLERRM);
    END;
  END LOOP;
END;
/

PROMPT
PROMPT ===============================================================
PROMPT   Recompilation — NOTE : ne compile QUE ce qui est VALIDE
PROMPT ===============================================================

BEGIN
  FOR u IN (SELECT owner, object_name, object_type
              FROM dba_objects
             WHERE status = 'INVALID'
               AND owner LIKE 'APP\_%' ESCAPE '\'
               AND object_type IN ('PACKAGE BODY','TRIGGER','VIEW')
             ORDER BY owner, object_name) LOOP
    DECLARE
      v_sql VARCHAR2(500);
      v_status VARCHAR2(10);
    BEGIN
      IF u.object_type = 'PACKAGE BODY' THEN
        v_sql := 'ALTER PACKAGE ' || u.owner || '.' || u.object_name || ' COMPILE BODY';
      ELSIF u.object_type = 'TRIGGER' THEN
        v_sql := 'ALTER TRIGGER ' || u.owner || '.' || u.object_name || ' COMPILE';
      ELSE
        v_sql := 'ALTER VIEW ' || u.owner || '.' || u.object_name || ' COMPILE';
      END IF;

      EXECUTE IMMEDIATE v_sql;

      SELECT status INTO v_status FROM dba_objects
       WHERE owner = u.owner AND object_name = u.object_name
         AND object_type = u.object_type AND ROWNUM = 1;

      DBMS_OUTPUT.PUT_LINE('  [' || v_status || '] ' || u.owner || '.' || u.object_name);
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  [KO] ' || u.owner || '.' || u.object_name || ' -- ' || SQLERRM);
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

EXIT;