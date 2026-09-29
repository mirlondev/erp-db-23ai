-- ============================================================
-- Import des applications APEX REGAL (workspace REGAL)
-- ============================================================
-- Usage :
--   sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba \
--     @import_app.sql <id_app> <fichier_export.sql>
-- Exemples :
--   @import_app.sql 100 app-100-pos.sql
--   @import_app.sql 500 app-500-admin.sql
--
-- Prérequis : apex/setup/01→03 joués, exports générés depuis l'IDE
-- (App Builder → Export Application, format "Database application").
-- ============================================================
SET DEFINE ON
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE

DEFINE APP_ID    = &1
DEFINE APP_FILE  = &2

PROMPT ══════════════════════════════════════════════════════════
PROMPT Import APEX : app &APP_ID ← &APP_FILE (workspace REGAL)
PROMPT ══════════════════════════════════════════════════════════

DECLARE
  v_ws_id NUMBER;
BEGIN
  SELECT workspace_id INTO v_ws_id
    FROM apex_workspaces WHERE workspace = UPPER('REGAL');
  APEX_INSTANCE_ADMIN.SET_WORKSPACE('REGAL'); -- contexte workspace pour l'import
  DBMS_OUTPUT.PUT_LINE('Workspace REGAL résolu (id='||v_ws_id||').');
EXCEPTION WHEN NO_DATA_FOUND THEN
  RAISE_APPLICATION_ERROR(-20601, 'Workspace REGAL introuvable — jouer setup/01_apex_workspace.sql');
END;
/

-- La commande d'import SQLPlus standard (disponible avec le kit APEX) :
@&APP_FILE

COMMIT;

PROMPT
PROMPT ✅ Application &APP_ID importée. Vérifier :
PROMPT   SELECT application_id, application_name FROM apex_applications
PROMPT    WHERE workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace='REGAL');
PROMPT puis courir les pages via :
PROMPT   http://<host>:8080/apex/f?p=&APP_ID:1:::REGAL
