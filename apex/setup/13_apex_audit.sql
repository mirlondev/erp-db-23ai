-- ============================================================
-- APEX SETUP 13 : Audit qualité automatique des apps APEX
-- ============================================================
-- Exécute après installation de chaque app pour détecter les
-- bugs potentiels dans les SQL des Interactive Reports / Classic Reports.
--
-- Cible : zéro bug sur les données financières.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 300
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX 26.1 — AUDIT QUALITÉ AUTOMATIQUE
PROMPT ══════════════════════════════════════════════════════════

-- ═══ 1) Compteur apps/pages ═══
PROMPT
PROMPT [1/8] Inventaire apps APEX REGAL
SELECT application_id, application_name, alias,
       (SELECT COUNT(*) FROM apex_application_pages
         WHERE application_id = a.application_id) AS nb_pages
  FROM apex_applications a
 WHERE workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
   AND application_id IN (100, 200, 300, 400, 500)
 ORDER BY application_id;

-- ═══ 2) Détection SUM/AVG sur colonnes nullable ═══
PROMPT
PROMPT [2/8] Risques NULL dans les sommes monétaires
DECLARE
  v_count NUMBER := 0;
  v_app_id NUMBER;
  v_page_id NUMBER;
  v_sql CLOB;
  v_warning VARCHAR2(4000);
BEGIN
  FOR r IN (
    SELECT p.application_id, p.page_id, p.plug_name, p.plug_source
      FROM apex_application_page_plugs p
     WHERE p.application_id IN (100, 200, 300, 400, 500)
       AND p.plug_source_type = 'SQL_QUERY'
       AND p.plug_source IS NOT NULL
  ) LOOP
    v_warning := NULL;
    -- Détecter SUM sans NVL sur colonnes monétaires
    IF REGEXP_LIKE(r.plug_source, 'SUM\(total_(ht|ttc|tax)\)', 'i')
       AND NOT REGEXP_LIKE(r.plug_source, 'SUM\(NVL\(total_', 'i') THEN
      v_warning := v_warning || '  → SUM(total_*) SANS NVL : ';
    END IF;
    -- Détecter ROUND(<expr>*<col>, n) sans NVL
    IF REGEXP_LIKE(r.plug_source, 'stock_qty\s*\*\s*[a-z_.]+\s*[^NVL]', 'i')
       AND NOT REGEXP_LIKE(r.plug_source, 'stock_qty\s*\*\s*NVL\(', 'i') THEN
      v_warning := v_warning || '  → multiplication par col NULLABLE ';
    END IF;
    IF v_warning IS NOT NULL THEN
      v_count := v_count + 1;
      DBMS_OUTPUT.PUT_LINE('  ⚠ App ' || r.application_id || ' Page ' || r.page_id ||
                           ' « ' || r.plug_name || ' » :');
      DBMS_OUTPUT.PUT_LINE(v_warning);
    END IF;
  END LOOP;
  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ Aucun SUM/multiplication dangereuse détectée');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  → ' || v_count || ' pages à risque');
  END IF;
END;
/

-- ═══ 3) Détection comparaisons NULL ═══
PROMPT
PROMPT [3/8] Risques comparaisons NULL (alertes manquantes)
DECLARE
  v_count NUMBER := 0;
  v_app_id NUMBER;
  v_page_id NUMBER;
  v_sql CLOB;
BEGIN
  FOR r IN (
    SELECT p.application_id, p.page_id, p.plug_name, p.plug_source
      FROM apex_application_page_plugs p
     WHERE p.application_id IN (100, 200, 300, 400, 500)
      AND p.plug_source_type = 'SQL_QUERY'
      AND p.plug_source IS NOT NULL
  ) LOOP
    -- Détecter "col_min <= col_stock" sans NVL (alerte silencieuse)
    IF REGEXP_LIKE(r.plug_source, 'min_stock_qty\)', 'i')
       AND NOT REGEXP_LIKE(r.plug_source, 'NVL\(p\.min_', 'i')
       AND NOT REGEXP_LIKE(r.plug_source, 'NVL\(min_', 'i') THEN
      v_count := v_count + 1;
      DBMS_OUTPUT.PUT_LINE('  ⚠ App ' || r.application_id || ' Page ' || r.page_id ||
                           ' « ' || r.plug_name || ' » :');
      DBMS_OUTPUT.PUT_LINE('    → Comparaison sur min_stock_qty sans NVL');
      DBMS_OUTPUT.PUT_LINE('    → Article sans seuil = pas d''alerte (silencieux)');
    END IF;
  END LOOP;
  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ Aucun risque de comparaison NULL');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  → ' || v_count || ' pages à risque');
  END IF;
END;
/

-- ═══ 4) Détection RLS (multi-tenant) ═══
PROMPT
PROMPT [4/8] Filtre multi-tenant (RLS)
DECLARE
  v_count_total NUMBER := 0;
  v_count_ok    NUMBER := 0;
BEGIN
  SELECT COUNT(*) INTO v_count_total
    FROM apex_application_page_plugs
   WHERE application_id IN (100, 200, 300, 400, 500)
     AND plug_source_type = 'SQL_QUERY'
     AND plug_source IS NOT NULL;

  SELECT COUNT(*) INTO v_count_ok
    FROM apex_application_page_plugs
   WHERE application_id IN (100, 200, 300, 400, 500)
     AND plug_source_type = 'SQL_QUERY'
     AND plug_source IS NOT NULL
     AND (REGEXP_LIKE(plug_source, 'pkg_apex_auth_v2\.|:APP_USER|user_sites', 'i')
          OR plug_source LIKE '%REGAL_SUPERADMIN%');

  DBMS_OUTPUT.PUT_LINE('  → ' || v_count_ok || '/' || v_count_total ||
                       ' pages ont un filtre RLS');
  IF v_count_ok < v_count_total THEN
    DBMS_OUTPUT.PUT_LINE('  ⚠ ATTENTION : multi-tenant non garanti !');
    DBMS_OUTPUT.PUT_LINE('    → voir AUDIT_REPORT.md §8');
  END IF;
END;
/

-- ═══ 5) Vérification auth scheme ═══
PROMPT
PROMPT [5/8] Authentification par app
SELECT a.application_id, a.application_name,
       a.authentication_scheme_type AS scheme_type,
       SUBSTR(a.authentication_scheme, 1, 60) AS scheme_name
  FROM apex_applications a
 WHERE a.application_id IN (100, 200, 300, 400, 500)
 ORDER BY a.application_id;

-- ═══ 6) Pages sans protection ═══
PROMPT
PROMPT [6/8] Pages publiques (à protéger !)
DECLARE
  v_count NUMBER := 0;
BEGIN
  FOR r IN (
    SELECT application_id, page_id, page_name, page_is_protected
      FROM apex_application_pages
     WHERE application_id IN (100, 200, 300, 400, 500)
       AND page_id > 1   -- Page 1 = login
  ) LOOP
    IF r.page_is_protected = 'N' THEN
      v_count := v_count + 1;
      DBMS_OUTPUT.PUT_LINE('  ⚠ App ' || r.application_id || ' Page ' || r.page_id ||
                           ' « ' || r.page_name || ' » NON PROTÉGÉE');
    END IF;
  END LOOP;
  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  ✓ Toutes les pages (sauf Login) sont protégées');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  → ' || v_count || ' pages à protéger');
  END IF;
END;
/

-- ═══ 7) Vérification LOVs ═══
PROMPT
PROMPT [7/8] Listes de valeurs (LOVs) actives
SELECT COUNT(*) AS nb_lovs FROM app_api.apex_lov;
SELECT lov_code, lov_name FROM app_api.apex_lov ORDER BY lov_id;

-- ═══ 8) Vérification Authorization schemes ═══
PROMPT
PROMPT [8/8] Rôles APEX
SELECT COUNT(*) AS nb_roles FROM app_sys.sys_role WHERE role_code LIKE 'REGAL_%';
SELECT role_code, role_name, role_level FROM app_sys.sys_role WHERE role_code LIKE 'REGAL_%' ORDER BY role_level;

PROMPT
PROMPT ═══ Résumé final ═══
SELECT 'Apps APEX REGAL' AS component, COUNT(*) AS nb
  FROM apex_applications WHERE application_id BETWEEN 100 AND 599
  AND workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
UNION ALL SELECT 'Pages APEX',         COUNT(*) FROM apex_application_pages p
  JOIN apex_applications a ON a.application_id = p.application_id
  WHERE a.workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
UNION ALL SELECT 'LOVs APEX',          COUNT(*) FROM app_api.apex_lov
UNION ALL SELECT 'Rôles REGAL',        COUNT(*) FROM app_sys.sys_role WHERE role_code LIKE 'REGAL_%'
UNION ALL SELECT 'Users affectés',     COUNT(*) FROM app_sys.sys_user_role
UNION ALL SELECT 'Menus',              COUNT(*) FROM app_api.apex_nav_menu
UNION ALL SELECT 'Templates PDF',      COUNT(*) FROM app_api.apex_report_template
UNION ALL SELECT 'Messages i18n',      COUNT(*) FROM app_sys.sys_message
 ORDER BY 1;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   FIN AUDIT — corriger les ⚠ avant mise en prod
PROMPT ══════════════════════════════════════════════════════════
EXIT;