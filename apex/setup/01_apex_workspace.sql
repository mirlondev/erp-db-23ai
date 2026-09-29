-- ============================================================
-- APEX SETUP 01 : Workspace REGAL pour l'ERP (Oracle APEX 26.1)
-- ============================================================
-- À jouer en SYS as sysdba sur FREEPDB1, APRÈS installation APEX.
-- Idempotent : ré-exécutable sans erreur (pattern des scripts 52-56).
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT ══════════════════════════════════════════════════════════
PROMPT APEX SETUP 01 — Workspace REGAL + schémas de workspaces
PROMPT ══════════════════════════════════════════════════════════

-- Vérifie qu'au moins un schéma APEX_xxxxxxx existe dans ce PDB
DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username LIKE 'APEX_%' AND LENGTH(username)=13;
  IF v_cnt = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'APEX non installé dans ce PDB — jouer apexins.sql d''abord');
  END IF;
  DBMS_OUTPUT.PUT_LINE('APEX détecté ('||v_cnt||' schéma(s) APEX_*).');
END;
/

-- Tablespace dédié aux objets workspace (optionnel mais propre)
DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM dba_tablespaces WHERE tablespace_name='REGAL_APEX';
  IF v_cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE TABLESPACE regal_apex DATAFILE ''regal_apex01.dbf'' SIZE 200M AUTOEXTEND ON MAXSIZE 4G';
    DBMS_OUTPUT.PUT_LINE('Tablespace REGAL_APEX créé.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('Tablespace REGAL_APEX existant — skip.');
  END IF;
END;
/

-- Création du workspace REGAL (schéma principal APP_API,
-- + schemas secondaires pour les apps par module)
BEGIN
  APEX_INSTANCE_ADMIN.ADD_WORKSPACE(
     p_workspace           => 'REGAL',
     p_primary_schema      => 'APP_API',
     p_additional_schemas  => 'APP_SALES,APP_INV,APP_GL,APP_SYS,APP_PURCHASE,APP_POS',
     p_tablespace          => 'REGAL_APEX',
     p_max_storage         => '500_MBS');
  DBMS_OUTPUT.PUT_LINE('Workspace REGAL créé.');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20901 OR SQLERRM LIKE '%already exists%' THEN
      DBMS_OUTPUT.PUT_LINE('Workspace REGAL déjà présent — skip.');
    ELSE
      RAISE;
    END IF;
END;
/

-- Quotas sur les tablespaces pour chaque schéma applicatif
BEGIN
  FOR r IN (SELECT username FROM all_users
            WHERE username IN ('APP_API','APP_SALES','APP_INV','APP_GL','APP_SYS','APP_PURCHASE','APP_POS')) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'ALTER USER '||r.username||' QUOTA UNLIMITED ON REGAL_APEX';
    EXCEPTION WHEN OTHERS THEN NULL; -- tablespace pas utilisé par ce user : sans gravité
    END;
END;
/

COMMIT;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT ✅ Workspace REGAL prêt. URL IDE :
PROMPT    http://<host>:8080/apex/apex_admin  (workspace REGAL / admin)
PROMPT ══════════════════════════════════════════════════════════
