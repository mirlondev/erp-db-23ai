-- ============================================================
-- SCRIPT : Attribution privilèges cross-schéma + recompilation
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

PROMPT ===============================================================
PROMPT   Attribution des privilèges cross-schéma
PROMPT ===============================================================

-- ------------------------------------------------------------
-- [1] APP_SALES (PKG_POS_SALES + TRG_TICKET_AUDIT)
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- [2] APP_INV (PKG_TRANSFER_STOCK)
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- [3] APP_DOC (PKG_DOC)
-- ------------------------------------------------------------
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

-- ------------------------------------------------------------
-- [4] APP_API (PKG_ETL_LEGACY)
-- ------------------------------------------------------------
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

-- ============================================================
-- [5] Recompilation des objets invalides — SYNTAXE CORRIGÉE
-- ============================================================
PROMPT
PROMPT ===============================================================
PROMPT   Recompilation des objets invalides
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
    BEGIN
      -- Syntaxe correcte pour chaque type
      IF u.object_type = 'PACKAGE BODY' THEN
        v_sql := 'ALTER PACKAGE ' || u.owner || '.' || u.object_name || ' COMPILE BODY';
      ELSIF u.object_type = 'TRIGGER' THEN
        v_sql := 'ALTER TRIGGER ' || u.owner || '.' || u.object_name || ' COMPILE';
      ELSIF u.object_type = 'VIEW' THEN
        v_sql := 'ALTER VIEW ' || u.owner || '.' || u.object_name || ' COMPILE';
      END IF;

      EXECUTE IMMEDIATE v_sql;

      -- Vérifier si c'est devenu VALID
      DECLARE
        v_status VARCHAR2(10);
      BEGIN
        SELECT status INTO v_status
          FROM dba_objects
         WHERE owner = u.owner
           AND object_name = u.object_name
           AND object_type = u.object_type
           AND ROWNUM = 1;

        IF v_status = 'VALID' THEN
          DBMS_OUTPUT.PUT_LINE('  [OK] ' || u.owner || '.' || u.object_name);
        ELSE
          DBMS_OUTPUT.PUT_LINE('  [KO] ' || u.owner || '.' || u.object_name ||
                               ' -- toujours INVALID');
        END IF;
      END;
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  [KO] ' || u.owner || '.' || u.object_name ||
                           ' -- ' || SQLERRM);
    END;
  END LOOP;
END;
/

-- ============================================================
-- [6] État final
-- ============================================================
PROMPT
PROMPT ===============================================================
PROMPT   État final — objets invalides restants
PROMPT ===============================================================
SELECT owner, object_type, object_name, status
  FROM dba_objects
 WHERE status = 'INVALID'
   AND owner LIKE 'APP\_%' ESCAPE '\'
 ORDER BY owner, object_type, object_name;

EXIT;