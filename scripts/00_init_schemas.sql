-- ============================================================
-- SCRIPT 00 : Nettoyage + Création des schémas modernes (26ai)
-- ------------------------------------------------------------
-- Idempotent : peut être ré-exécuté sans erreur.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 100
SET FEEDBACK ON
SET DEFINE OFF

PROMPT ═══════════════════════════════════════════════════════
PROMPT   INITIALISATION — Schémas modernes
PROMPT ═══════════════════════════════════════════════════════

-- ------------------------------------------------------------------
-- [0] Bascule vers FREEPDB1 (tolérant : ne casse pas si déjà dedans)
-- ------------------------------------------------------------------
DECLARE
  v_container VARCHAR2(128);
BEGIN
  SELECT SYS_CONTEXT('USERENV','CON_NAME') INTO v_container FROM dual;
  IF v_container <> 'FREEPDB1' THEN
    BEGIN
      EXECUTE IMMEDIATE 'ALTER SESSION SET CONTAINER = FREEPDB1';
      DBMS_OUTPUT.PUT_LINE('  → Bascule vers FREEPDB1 effectuée.');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  ⚠ Impossible de basculer vers FREEPDB1 : ' || SQLERRM);
      DBMS_OUTPUT.PUT_LINE('    Poursuite dans ' || v_container);
    END;
  ELSE
    DBMS_OUTPUT.PUT_LINE('  → Déjà connecté à FREEPDB1.');
  END IF;
END;
/

-- ------------------------------------------------------------------
-- [1] Suppression dynamique de TOUS les schémas applicatifs
-- ------------------------------------------------------------------
PROMPT
PROMPT [1] Suppression des anciens schémas
DECLARE
  v_count NUMBER := 0;
  v_fail  NUMBER := 0;
BEGIN
  FOR u IN (SELECT username
              FROM dba_users
             WHERE username LIKE 'APP\_%' ESCAPE '\'
               AND oracle_maintained = 'N'
             ORDER BY username) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP USER ' || u.username || ' CASCADE';
      DBMS_OUTPUT.PUT_LINE('  Drop ' || u.username);
      v_count := v_count + 1;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      DBMS_OUTPUT.PUT_LINE('  ⚠ Échec drop ' || u.username || ' : ' || SQLERRM);
    END;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_count || ' schéma(s) supprimé(s), ' ||
                       v_fail || ' échec(s).');
END;
/

-- ------------------------------------------------------------------
-- [2] Création des 17 schémas applicatifs (idempotent)
-- ------------------------------------------------------------------
PROMPT
PROMPT [2] Création des 17 schémas
DECLARE
  TYPE t_rec IS RECORD (usr VARCHAR2(30), pwd VARCHAR2(100));
  TYPE t_tab IS TABLE OF t_rec INDEX BY PLS_INTEGER;
  v_schemas t_tab;
  v_sql     VARCHAR2(500);
  v_ok      NUMBER := 0;
  v_skip    NUMBER := 0;
  v_fail    NUMBER := 0;

  PROCEDURE add(p_usr VARCHAR2, p_pwd VARCHAR2) IS
  BEGIN
    v_schemas(v_schemas.COUNT + 1).usr := p_usr;
    v_schemas(v_schemas.COUNT).pwd     := p_pwd;
  END;
BEGIN
  add('APP_SYS',      'AppSys#2026');
  add('APP_ORG',      'AppOrg#2026');
  add('APP_PRODUCT',  'AppProduct#2026');
  add('APP_PARTY',    'AppParty#2026');
  add('APP_INV',      'AppInv#2026');
  add('APP_DOC',      'AppDoc#2026');
  add('APP_POS',      'AppPos#2026');
  add('APP_SALES',    'AppSales#2026');
  add('APP_GL',       'AppGl#2026');
  add('APP_CASH',     'AppCash#2026');
  add('APP_HIST',     'AppHist#2026');
  add('APP_API',      'AppApi#2026');
  add('APP_AR',       'AppAr#2026');
  add('APP_SHIP',     'AppShip#2026');
  add('APP_PURCHASE', 'AppPurchase#2026');
  add('APP_HR',       'AppHr#2026');
  add('APP_AUDIT',    'AppAudit#2026');

  FOR i IN 1 .. v_schemas.COUNT LOOP
    v_sql := 'CREATE USER ' || v_schemas(i).usr ||
             ' IDENTIFIED BY "' || v_schemas(i).pwd || '" ' ||
             ' DEFAULT TABLESPACE USERS QUOTA UNLIMITED ON USERS';
    BEGIN
      EXECUTE IMMEDIATE v_sql;
      DBMS_OUTPUT.PUT_LINE('  Créé  : ' || v_schemas(i).usr);
      v_ok := v_ok + 1;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE = -1920 THEN
          DBMS_OUTPUT.PUT_LINE('  ⚠ Existe déjà : ' || v_schemas(i).usr);
          v_skip := v_skip + 1;
        ELSE
          DBMS_OUTPUT.PUT_LINE('  ✗ Échec ' || v_schemas(i).usr || ' : ' || SQLERRM);
          v_fail := v_fail + 1;
        END IF;
    END;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('  → ' || v_ok || ' créé(s), ' ||
                       v_skip || ' déjà présent(s), ' ||
                       v_fail || ' échec(s).');
END;
/

-- ------------------------------------------------------------------
-- [3] Attribution des privilèges (un par un → robuste)
-- ------------------------------------------------------------------
PROMPT
PROMPT [3] Attribution des privilèges
DECLARE
  -- Privilèges système valides en 23ai / 26ai.
  -- La liste est volontairement exhaustive : un privilège invalide
  -- n'interrompra plus le script, il sera simplement journalisé.
  v_privs SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
    'CREATE SESSION',
    'CREATE TABLE',
    'CREATE VIEW',
    'CREATE SEQUENCE',
    'CREATE PROCEDURE',
    'CREATE TRIGGER',
    'CREATE SYNONYM',
    'CREATE TYPE',
    'CREATE MATERIALIZED VIEW',
    'CREATE JOB',
    'CREATE INDEX',
    'CREATE ATTRIBUTE DIMENSION',
    'CREATE DOMAIN'            -- 23ai+ (SQL Domains) — testé individuellement
  );
  v_ok  NUMBER;
  v_ko  NUMBER;
BEGIN
  FOR u IN (SELECT username
              FROM dba_users
             WHERE username LIKE 'APP\_%' ESCAPE '\'
               AND oracle_maintained = 'N'
             ORDER BY username) LOOP

    v_ok := 0;
    v_ko := 0;

    -- 3.a — Privilèges système, testés un par un
    FOR i IN 1 .. v_privs.COUNT LOOP
      BEGIN
        EXECUTE IMMEDIATE 'GRANT ' || v_privs(i) || ' TO ' || u.username;
        v_ok := v_ok + 1;
      EXCEPTION WHEN OTHERS THEN
        v_ko := v_ko + 1;
        DBMS_OUTPUT.PUT_LINE('  ⚠ ' || RPAD(u.username, 14) ||
                             ' ← ' || RPAD(v_privs(i), 28) ||
                             ' refusé : ' || SQLERRM);
      END;
    END LOOP;

    -- 3.b — Rôle CTXAPP (requis pour DBMS_SEARCH / index de recherche JSON)
    BEGIN
      EXECUTE IMMEDIATE 'GRANT CTXAPP TO ' || u.username;
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  ⚠ ' || RPAD(u.username, 14) ||
                           ' ← CTXAPP refusé : ' || SQLERRM);
    END;

    DBMS_OUTPUT.PUT_LINE('  ' || RPAD(u.username, 14) ||
                         ' → ' || v_ok || ' privilège(s) accordé(s), ' ||
                         v_ko || ' refusé(s)');
  END LOOP;
END;
/

-- ------------------------------------------------------------------
-- [4] Validation — Schémas créés
-- ------------------------------------------------------------------
PROMPT
PROMPT [4] Validation — Schémas créés
SELECT username,
       default_tablespace,
       account_status
  FROM dba_users
 WHERE username LIKE 'APP\_%' ESCAPE '\'
   AND oracle_maintained = 'N'
 ORDER BY username;

PROMPT
PROMPT [4b] Validation — Privilèges système attribués
SELECT grantee, COUNT(*) AS nb_privs
  FROM dba_sys_privs
 WHERE grantee LIKE 'APP\_%' ESCAPE '\'
 GROUP BY grantee
 ORDER BY grantee;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ INITIALISATION TERMINÉE
PROMPT ═══════════════════════════════════════════════════════