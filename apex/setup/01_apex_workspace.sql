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
  SELECT COUNT(*) INTO v_cnt
    FROM all_users
   WHERE username LIKE 'APEX\_%' ESCAPE '\'
     AND LENGTH(username) = 11;
  IF v_cnt = 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'APEX non installé dans ce PDB — jouer apexins.sql d''abord');
  END IF;
  DBMS_OUTPUT.PUT_LINE('APEX détecté ('||v_cnt||' schéma(s) APEX_*).');
END;
/

-- Création du workspace REGAL (schéma principal APP_API,
-- + schemas secondaires pour les apps par module)
BEGIN
  APEX_INSTANCE_ADMIN.ADD_WORKSPACE(
     p_workspace           => 'REGAL',
     p_primary_schema      => 'APP_API',
     p_additional_schemas  => 'APP_SALES,APP_INV,APP_GL,APP_SYS,APP_PURCHASE,APP_POS');
  DBMS_OUTPUT.PUT_LINE('Workspace REGAL créé.');
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE = -20901 OR UPPER(SQLERRM) LIKE '%ALREADY EXISTS%' THEN
      DBMS_OUTPUT.PUT_LINE('Workspace REGAL déjà présent — skip.');
    ELSE
      RAISE;
    END IF;
END;
/

COMMIT;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT ✅ Workspace REGAL prêt. URL IDE :
PROMPT    http://<host>:8080/apex/apex_admin  (workspace REGAL / admin)
PROMPT ══════════════════════════════════════════════════════════
