-- ============================================================
-- APEX SETUP 12 : Health Check — vérification installation
-- ============================================================
-- A jouer en premier pour diagnostiquer l'environnement APEX :
--   - Version APEX installée
--   - ORDS disponible
--   - Workspace REGAL existe
--   - Schémas APP_* accessibles
--   - 5 apps REGAL présentes
--   - 11 LOVs / 6 rôles / 5 menus
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX 26.1 — Health Check
PROMPT ══════════════════════════════════════════════════════════

-- ═══ 1) Version APEX ═══
PROMPT
PROMPT [1/8] Version APEX
DECLARE
  v_version VARCHAR2(20);
  v_api_schema VARCHAR2(30);
BEGIN
  SELECT version, owner INTO v_version, v_api_schema
    FROM (SELECT version, owner FROM all_synonyms WHERE synonym_name = 'APEX' ORDER BY owner) WHERE ROWNUM = 1;
  DBMS_OUTPUT.PUT_LINE('  ✓ APEX version : ' || v_version || ' (schéma ' || v_api_schema || ')');
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('  ✗ APEX NON INSTALLÉ — installer avec apexins.sql');
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  ⚠ ' || SQLERRM);
END;
/

-- ═══ 2) ORDS ═══
PROMPT
PROMPT [2/8] ORDS (Oracle REST Data Services)
DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM all_users WHERE username = 'ORDS_METADATA';
  IF v_cnt = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  ⚠ Schéma ORDS_METADATA absent (ORDS non installé ou non configuré)');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  ✓ Schéma ORDS_METADATA présent');
  END IF;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ ' || SQLERRM);
END;
/

-- ═══ 3) Workspace REGAL ═══
PROMPT
PROMPT [3/8] Workspace REGAL
DECLARE
  v_ws_id NUMBER;
BEGIN
  SELECT workspace_id INTO v_ws_id FROM apex_workspaces WHERE workspace = 'REGAL';
  DBMS_OUTPUT.PUT_LINE('  ✓ Workspace REGAL : id=' || v_ws_id);
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    DBMS_OUTPUT.PUT_LINE('  ✗ Workspace REGAL INTROUVABLE — jouer setup/01_apex_workspace.sql');
END;
/

-- ═══ 4) Schémas APP_* accessibles ═══
PROMPT
PROMPT [4/8] Schémas APP_* (17 attendus)
DECLARE
  v_app_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_app_count
    FROM all_users
   WHERE username IN ('APP_SYS','APP_ORG','APP_PRODUCT','APP_PARTY','APP_INV','APP_DOC',
                       'APP_POS','APP_SALES','APP_GL','APP_CASH','APP_HIST','APP_API',
                       'APP_AR','APP_SHIP','APP_PURCHASE','APP_HR','APP_AUDIT');
  DBMS_OUTPUT.PUT_LINE('  → ' || v_app_count || '/17 schémas APP_* présents');
END;
/

-- ═══ 5) Apps REGAL installées ═══
PROMPT
PROMPT [5/8] Apps REGAL (5 attendues : 100, 200, 300, 400, 500)
SELECT application_id, application_name, alias
  FROM apex_applications
 WHERE workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
   AND application_id BETWEEN 100 AND 599
 ORDER BY application_id;

-- ═══ 6) LOVs ═══
PROMPT
PROMPT [6/8] LOVs (11 attendues)
SELECT lov_id, lov_code, lov_name FROM app_api.apex_lov ORDER BY lov_id;

-- ═══ 7) Rôles REGAL ═══
PROMPT
PROMPT [7/8] Rôles REGAL (6 attendus)
SELECT role_id, role_code, role_name, role_level
  FROM app_sys.sys_role
 WHERE role_code LIKE 'REGAL_%'
 ORDER BY role_level;

-- ═══ 8) Menus / Templates / Locale ═══
PROMPT
PROMPT [8/8] Menus, PDF templates, Locale
SELECT 'menus' AS component, COUNT(*) AS nb FROM app_api.apex_nav_menu
UNION ALL SELECT 'PDF templates', COUNT(*) FROM app_api.apex_report_template
UNION ALL SELECT 'Locale config', COUNT(*) FROM app_api.apex_locale_config
UNION ALL SELECT 'Static files',  COUNT(*) FROM app_api.apex_static_file
UNION ALL SELECT 'Static files LITOKO', COUNT(*) FROM app_api.apex_static_file WHERE file_name LIKE '%litoko%'
UNION ALL SELECT 'Static files REGAL mobile', COUNT(*) FROM app_api.apex_static_file WHERE file_name LIKE '%regal%'
 ORDER BY 1;

PROMPT
PROMPT ═══ Résumé ═══
DECLARE
  v_apex VARCHAR2(20);
  v_workspace NUMBER;
  v_apps NUMBER;
  v_schemas NUMBER;
BEGIN
  BEGIN
    SELECT version INTO v_apex FROM (SELECT version FROM all_synonyms WHERE synonym_name = 'APEX' ORDER BY owner) WHERE ROWNUM = 1;
  EXCEPTION WHEN OTHERS THEN v_apex := 'ABSENT'; END;

  BEGIN
    SELECT workspace_id INTO v_workspace FROM apex_workspaces WHERE workspace = 'REGAL';
  EXCEPTION WHEN OTHERS THEN v_workspace := NULL; END;

  SELECT COUNT(*) INTO v_apps FROM apex_applications
   WHERE workspace = v_workspace AND application_id BETWEEN 100 AND 599;

  SELECT COUNT(*) INTO v_schemas FROM all_users
   WHERE username IN ('APP_SYS','APP_ORG','APP_PRODUCT','APP_PARTY','APP_INV','APP_DOC',
                       'APP_POS','APP_SALES','APP_GL','APP_CASH','APP_HIST','APP_API',
                       'APP_AR','APP_SHIP','APP_PURCHASE','APP_HR','APP_AUDIT');

  DBMS_OUTPUT.PUT_LINE('  APEX version : ' || v_apex);
  DBMS_OUTPUT.PUT_LINE('  Workspace REGAL : ' || CASE WHEN v_workspace IS NULL THEN 'ABSENT' ELSE 'OK (#' || v_workspace || ')' END);
  DBMS_OUTPUT.PUT_LINE('  Schémas APP_* : ' || v_schemas || '/17');
  DBMS_OUTPUT.PUT_LINE('  Apps REGAL : ' || v_apps || '/5');
END;
/

PROMPT
PROMPT ═══ Actions à mener si KO ═══
PROMPT
PROMPT [Si APEX absent]
PROMPT   cd $ORACLE_HOME/apex
PROMPT   sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba @apexins.sql SYSAUX SYSAUX TEMP /i/
PROMPT   sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba @apxchpwd.sql
PROMPT
PROMPT [Si workspace REGAL absent]
PROMPT   @apex/setup/01_apex_workspace.sql
PROMPT
PROMPT [Si apps REGAL absentes]
PROMPT   @apex/apps/install_all_apps.sql
PROMPT
PROMPT [Si ORDS pas démarré]
PROMPT   java -jar ords.war simple --db-hostname localhost --db-port 1521 --db-servicename FREEPDB1 --repository-user ORDS --port 8080
PROMPT
PROMPT ══════════════════════════════════════════════════════════
EXIT;
