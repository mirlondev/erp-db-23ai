-- ============================================================
-- Import des applications APEX REGAL (workspace REGAL)
-- ============================================================
-- Usage :
--   @apex/apps/import_app.sql <id_app> <fichier_export.sql>
--
-- Prérequis : workspace REGAL créé et export SQL généré depuis APEX.
-- ============================================================
SET DEFINE ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

DEFINE APP_ID    = &1
DEFINE APP_FILE  = &2

PROMPT ══════════════════════════════════════════════════════════
PROMPT Import APEX : app &APP_ID ← &APP_FILE (workspace REGAL)
PROMPT ══════════════════════════════════════════════════════════

DECLARE
  v_workspace_id NUMBER;
  v_application_id NUMBER := TO_NUMBER('&APP_ID');
BEGIN
  IF v_application_id NOT IN (100, 200, 300, 400, 500) THEN
    RAISE_APPLICATION_ERROR(-20602, 'ID application attendu : 100, 200, 300, 400 ou 500.');
  END IF;

  SELECT workspace_id INTO v_workspace_id
    FROM apex_workspaces WHERE workspace = UPPER('REGAL');
  APEX_APPLICATION_INSTALL.SET_WORKSPACE('REGAL');
  APEX_APPLICATION_INSTALL.SET_WORKSPACE_ID(v_workspace_id);
  APEX_APPLICATION_INSTALL.SET_APPLICATION_ID(v_application_id);
  DBMS_OUTPUT.PUT_LINE('Workspace REGAL résolu (id='||v_workspace_id||').');
EXCEPTION WHEN NO_DATA_FOUND THEN
  RAISE_APPLICATION_ERROR(-20601, 'Workspace REGAL introuvable — jouer setup/01_apex_workspace.sql');
END;
/

-- Exécute le fichier d'export APEX fourni en argument.
@&APP_FILE

COMMIT;

DECLARE
  v_workspace_id NUMBER;
  v_application_count NUMBER;
BEGIN
  SELECT workspace_id INTO v_workspace_id
    FROM apex_workspaces WHERE workspace = UPPER('REGAL');
  SELECT COUNT(*) INTO v_application_count
    FROM apex_applications
   WHERE workspace_id = v_workspace_id
     AND application_id = TO_NUMBER('&APP_ID');
  IF v_application_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20603, 'Application absente du workspace REGAL après import.');
  END IF;
END;
/

PROMPT
PROMPT Application &APP_ID importée et vérifiée dans REGAL.
PROMPT URL :
PROMPT   http://<host>:8080/apex/f?p=&APP_ID:1:::REGAL
