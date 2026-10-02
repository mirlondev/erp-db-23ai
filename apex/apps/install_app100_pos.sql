-- ============================================================
-- APEX APP 100 — POS / Ventes LITOKO — Installation programmatique
-- ============================================================
-- Crée l'application 100 « POS / Ventes » dans Oracle APEX 26.1
-- via l'API wwv_flow_api. Ce script est idempotent.
--
-- Prérequis :
--   - APEX 26.1+ installé (health check : 12_apex_health_check.sql)
--   - Workspace REGAL créé (setup/01_apex_workspace.sql)
--   - setup/02-11 joués (auth, views, LOVs, roles, menus, locale)
--
-- Connexion : sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba
-- ============================================================
SET VERIFY OFF
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APP 100 — POS / Ventes LITOKO — Installation
PROMPT ══════════════════════════════════════════════════════════

-- ═══ 0) Workspace ID ═══
PROMPT
PROMPT [0] Workspace REGAL
DECLARE
  v_ws_id NUMBER;
BEGIN
  SELECT workspace_id INTO v_ws_id FROM apex_workspaces WHERE workspace = 'REGAL';
  apex_application_install.set_workspace_id(v_ws_id);
  DBMS_OUTPUT.PUT_LINE('  → Workspace REGAL : id=' || v_ws_id);
END;
/

-- ═══ 1) Drop si existe ═══
PROMPT
PROMPT [1] Drop application 100 si existe
BEGIN
  FOR r IN (SELECT application_id FROM apex_applications
             WHERE workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
               AND application_id = 100) LOOP
    APEX_APPLICATION_INSTALL.SET_APPLICATION_ID(100);
    WWV_FLOW_API.REMOVE_FLOW(100);
    DBMS_OUTPUT.PUT_LINE('  → App 100 supprimée');
  END LOOP;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  → Pas d''app 100 à supprimer');
END;
/

-- ═══ 2) Définition application ═══
PROMPT
PROMPT [2] Définition App 100
BEGIN
  APEX_APPLICATION_INSTALL.SET_APPLICATION_ID(100);
  APEX_APPLICATION_INSTALL.SET_APPLICATION_NAME('POS / Ventes LITOKO');
  APEX_APPLICATION_INSTALL.SET_APPLICATION_ALIAS('POS');
  APEX_APPLICATION_INSTALL.SET_SCHEMA('APP_API');
  APEX_APPLICATION_INSTALL.SET_AUTO_INSTALL_SUP_OBJ(FALSE);
  APEX_APPLICATION_INSTALL.SET_FLOW_STATUS('AVAILABLE');
  APEX_APPLICATION_INSTALL.SET_AUTHENTICATION_SCHEME(
    p_name                  => 'REGAL_AUTH',
    p_scheme_type           => 'PLSQL',
    p_plsql_code            => 'return app_sys.pkg_apex_auth.authenticate(:APP_USER, :APP_PASSWORD);'
  );
  DBMS_OUTPUT.PUT_LINE('  → Contexte application installé');
END;
/

-- ═══ 3) Création flow + structure ═══
PROMPT
PROMPT [3] Création flow
BEGIN
  WWV_FLOW_API.CREATE_FLOW (
    p_id                          => 100
    ,p_display_id                  => 100
    ,p_owner                       => 'APP_API'
    ,p_name                        => 'POS / Ventes LITOKO'
    ,p_alias                       => 'POS'
    ,p_application_tab_set         => 1
    ,p_is_locked                   => FALSE
    ,p_default_page_template       => 102
    ,p_default_region_template     => 26
    ,p_default_label_template      => 17
    ,p_default_list_template       => 8
    ,p_default_report_template     => 10
    ,p_default_form_template       => 7
    ,p_default_button_template     => 5
    ,p_default_menu_template       => 9
    ,p_default_option_template     => 4
    ,p_default_header_template     => 7
    ,p_default_footer_template     => 7
    ,p_default_nav_list_position    => 'TOP'
    ,p_default_help_text           => 'RIGHT'
    ,p_page_view_logging           => 'YES'
    ,p_csv_encoding                => 'Y'
    ,p_auto_time_zone              => 'Y'
    ,p_default_time_zone           => 'Africa/Brazzaville'
    ,p_flow_language               => 'fr'
    ,p_flow_language_derived_from  => 'SESSION'
    ,p_substitution_string_01      => 'APP_NAME'
    ,p_substitution_value_01        => 'POS / Ventes LITOKO'
    ,p_substitution_string_02      => 'REGAL_COMPANY'
    ,p_substitution_value_02        => 'LITOKO SARL — Pointe-Noire (Congo Brazzaville)'
    ,p_last_updated_by             => 'SYS'
    ,p_created_on                  => SYSDATE
    ,p_updated_on                  => SYSDATE
    );
END;
/

-- ═══ 4) Page 10 : Dashboard ═══
PROMPT
PROMPT [4] Page 10 — Dashboard POS
BEGIN
  WWV_FLOW_API.CREATE_PAGE (
    p_id                          => 10
    ,p_flow_id                      => 100
    ,p_user_interface_id           => 1
    ,p_name                        => 'Tableau de bord'
    ,p_alias                       => 'DASHBOARD'
    ,p_step_title                  => 'Tableau de bord POS'
    ,p_autocomplete_on_off         => 'OFF'
    ,p_step_template               => 102
    ,p_page_is_protected           => 'Y'
    ,p_page_template_options       => '#DEFAULT#'
    ,p_last_updated_by             => 'SYS'
    ,p_created_on                  => SYSDATE
    ,p_updated_on                  => SYSDATE
    );

  WWV_FLOW_API.CREATE_PAGE_PLUG (
    p_id                          => 1001001
    ,p_flow_id                     => 100
    ,p_page_id                     => 10
    ,p_plug_name                   => 'Sessions actives'
    ,p_region_template_options     => '#DEFAULT#'
    ,p_plug_template               => 149
    ,p_plug_display_sequence       => 10
    ,p_plug_display_point          => 'BODY'
    ,p_plug_source_type            => 'SQL_QUERY'
    ,p_plug_query                  => 'SELECT terminal_code, terminal_name, status, hours_open, nb_tickets, ca_session_xaf FROM app_api.v_pos_session_kpi ORDER BY opened_at DESC'
    ,p_last_updated_by             => 'SYS'
    );

  WWV_FLOW_API.CREATE_PAGE_PLUG (
    p_id                          => 1001002
    ,p_flow_id                     => 100
    ,p_page_id                     => 10
    ,p_plug_name                   => 'CA du jour'
    ,p_region_template_options     => '#DEFAULT#'
    ,p_plug_template               => 149
    ,p_plug_display_sequence       => 20
    ,p_plug_display_point          => 'BODY'
    ,p_plug_source_type            => 'SQL_QUERY'
    ,p_plug_query                  => 'SELECT terminal_code, terminal_name, nb_tickets, total_ht, total_ttc, total_tva, avg_basket, last_ticket_at FROM app_api.v_today_sales ORDER BY total_ttc DESC'
    ,p_last_updated_by             => 'SYS'
    );
END;
/

-- ═══ 5) Page 20 : Sessions de caisse ═══
PROMPT
PROMPT [5] Page 20 — Sessions de caisse
BEGIN
  WWV_FLOW_API.CREATE_PAGE (
    p_id                          => 20
    ,p_flow_id                      => 100
    ,p_user_interface_id           => 1
    ,p_name                        => 'Sessions de caisse'
    ,p_alias                       => 'SESSIONS'
    ,p_step_title                  => 'Sessions de caisse'
    ,p_autocomplete_on_off         => 'OFF'
    ,p_step_template               => 102
    ,p_page_is_protected           => 'Y'
    ,p_last_updated_by             => 'SYS'
    ,p_created_on                  => SYSDATE
    ,p_updated_on                  => SYSDATE
    );

  WWV_FLOW_API.CREATE_PAGE_PLUG (
    p_id                          => 1002001
    ,p_flow_id                     => 100
    ,p_page_id                     => 20
    ,p_plug_name                   => 'Sessions (Z de caisse)'
    ,p_region_template_options     => '#DEFAULT#'
    ,p_plug_template               => 149
    ,p_plug_display_sequence       => 10
    ,p_plug_display_point          => 'BODY'
    ,p_plug_source_type            => 'SQL_QUERY'
    ,p_plug_query                  => q'[
      SELECT s.terminal_id, s.session_no, s.user_code,
             t.terminal_name, t.warehouse_code,
             TO_CHAR(s.opened_at, 'DD/MM/YYYY HH24:MI') AS opened,
             TO_CHAR(s.closed_at, 'DD/MM/YYYY HH24:MI') AS closed,
             CASE WHEN s.closed_at IS NULL THEN 'OUVERTE' ELSE 'FERMÉE' END AS status,
             s.opening_balance, s.closing_balance,
             (SELECT COUNT(*) FROM app_sales.ticket tk
               WHERE tk.terminal_id = t.terminal_code AND tk.session_no = s.session_no) AS nb_tickets,
             ROUND((NVL(s.closed_at, SYSDATE) - s.opened_at) * 24, 1) AS hours
        FROM app_pos.pos_session s
        JOIN app_pos.pos_terminal t ON t.terminal_id = s.terminal_id
       ORDER BY s.opened_at DESC
    ]'
    ,p_last_updated_by             => 'SYS'
    );
END;
/

-- ═══ 6) Page 30 : Historique tickets ═══
PROMPT
PROMPT [6] Page 30 — Historique tickets
BEGIN
  WWV_FLOW_API.CREATE_PAGE (
    p_id                          => 30
    ,p_flow_id                      => 100
    ,p_user_interface_id           => 1
    ,p_name                        => 'Historique tickets'
    ,p_alias                       => 'TICKETS'
    ,p_step_title                  => 'Historique des tickets'
    ,p_autocomplete_on_off         => 'OFF'
    ,p_step_template               => 102
    ,p_page_is_protected           => 'Y'
    ,p_last_updated_by             => 'SYS'
    ,p_created_on                  => SYSDATE
    ,p_updated_on                  => SYSDATE
    );

  WWV_FLOW_API.CREATE_PAGE_PLUG (
    p_id                          => 1003001
    ,p_flow_id                     => 100
    ,p_page_id                     => 30
    ,p_plug_name                   => 'Tickets des 30 derniers jours'
    ,p_region_template_options     => '#DEFAULT#'
    ,p_plug_template               => 149
    ,p_plug_display_sequence       => 10
    ,p_plug_display_point          => 'BODY'
    ,p_plug_source_type            => 'SQL_QUERY'
    ,p_plug_query                  => q'[
      SELECT t.terminal_id, t.ticket_no, t.ticket_date,
             t.invoice_no, t.customer_name,
             t.user_code,
             t.total_ht, t.total_ttc, t.tax_amount_1 AS total_tva,
             t.status
        FROM app_sales.ticket t
       WHERE TRUNC(t.ticket_date) >= TRUNC(SYSDATE) - 30
       ORDER BY t.ticket_date DESC, t.ticket_no DESC
    ]'
    ,p_last_updated_by             => 'SYS'
    );
END;
/

-- ═══ 7) Page 40 : Z de caisse ═══
PROMPT
PROMPT [7] Page 40 — Z de caisse / Clôture
BEGIN
  WWV_FLOW_API.CREATE_PAGE (
    p_id                          => 40
    ,p_flow_id                      => 100
    ,p_user_interface_id           => 1
    ,p_name                        => 'Z de caisse'
    ,p_alias                       => 'Z_CAISSE'
    ,p_step_title                  => 'Z de caisse / Clôture'
    ,p_autocomplete_on_off         => 'OFF'
    ,p_step_template               => 102
    ,p_page_is_protected           => 'Y'
    ,p_last_updated_by             => 'SYS'
    ,p_created_on                  => SYSDATE
    ,p_updated_on                  => SYSDATE
    );

  WWV_FLOW_API.CREATE_PAGE_PLUG (
    p_id                          => 1004001
    ,p_flow_id                     => 100
    ,p_page_id                     => 40
    ,p_plug_name                   => 'Sélection session'
    ,p_region_template_options     => '#DEFAULT#'
    ,p_plug_template               => 149
    ,p_plug_display_sequence       => 10
    ,p_plug_display_point          => 'BODY'
    ,p_plug_source_type            => 'SQL_QUERY'
    ,p_plug_query                  => 'SELECT 1 AS d, ''Sélectionner terminal + n° session puis Imprimer'' AS r FROM DUAL'
    ,p_last_updated_by             => 'SYS'
    );

  WWV_FLOW_API.CREATE_PAGE_ITEM (
    p_id                          => 10040001
    ,p_flow_id                     => 100
    ,p_page_id                     => 40
    ,p_name                        => 'P40_TERMINAL_ID'
    ,p_label                       => 'Terminal'
    ,p_item_sequence               => 10
    ,p_prompt                      => 'Terminal'
    ,p_source_type                 => 'STATIC'
    ,p_display_as                  => 'NATIVE_SELECT_LIST'
    ,p_lov                         => 'SELECT terminal_id d, terminal_name || '' ('' || terminal_code || '')'' r FROM app_pos.pos_terminal WHERE is_active = ''Y'' ORDER BY terminal_code'
    ,p_lov_display_null            => 'YES'
    ,p_lov_null_text               => '-- Choisir un terminal --'
    ,p_field_template              => 17
    ,p_item_template_options       => '#DEFAULT#'
    ,p_is_required                 => 'Y'
    );

  WWV_FLOW_API.CREATE_PAGE_ITEM (
    p_id                          => 10040002
    ,p_flow_id                     => 100
    ,p_page_id                     => 40
    ,p_name                        => 'P40_SESSION_NO'
    ,p_label                       => 'Numéro session'
    ,p_item_sequence               => 20
    ,p_prompt                      => 'N° session'
    ,p_source_type                 => 'STATIC'
    ,p_display_as                  => 'NATIVE_NUMBER_FIELD'
    ,p_field_template              => 17
    ,p_item_template_options       => '#DEFAULT#'
    );

  WWV_FLOW_API.CREATE_PAGE_BUTTON (
    p_id                          => 10040003
    ,p_flow_id                     => 100
    ,p_page_id                     => 40
    ,p_button_sequence             => 10
    ,p_button_name                 => 'PRINT_Z'
    ,p_button_action               => 'SUBMIT'
    ,p_button_is_hot               => 'Y'
    ,p_button_image_alt            => 'Imprimer Z'
    ,p_button_position             => 'CREATE'
    ,p_button_css_classes          => 'fa-print'
    );
END;
/

-- ═══ 8) Liste de navigation App 100 ═══
PROMPT
PROMPT [8] Liste de navigation App 100
BEGIN
  WWV_FLOW_API.CREATE_SHARED_LIST (
    p_id                          => 100100
    ,p_flow_id                     => 100
    ,p_list_name                   => 'POS_Navigation'
    ,p_list_type                   => 'STATIC'
    ,p_list_query                  => ''
    ,p_required_patch              => NULL
    );

  WWV_FLOW_API.CREATE_SHARED_LIST_ITEM (
    p_id                          => 1001001
    ,p_list_id                     => 100100
    ,p_parent_list_item_id         => NULL
    ,p_list_item_display_sequence  => 10
    ,p_list_item_link_type         => 'TARGET_PAGE'
    ,p_list_item_link_text         => 'Tableau de bord'
    ,p_list_item_link_target       => 'f?p=&APP_ID.:10:&SESSION.'
    ,p_list_item_icon              => 'fa-tachometer-alt'
    );

  WWV_FLOW_API.CREATE_SHARED_LIST_ITEM (
    p_id                          => 1001002
    ,p_list_id                     => 100100
    ,p_parent_list_item_id         => NULL
    ,p_list_item_display_sequence  => 20
    ,p_list_item_link_type         => 'TARGET_PAGE'
    ,p_list_item_link_text         => 'Sessions de caisse'
    ,p_list_item_link_target       => 'f?p=&APP_ID.:20:&SESSION.'
    ,p_list_item_icon              => 'fa-clock'
    );

  WWV_FLOW_API.CREATE_SHARED_LIST_ITEM (
    p_id                          => 1001003
    ,p_list_id                     => 100100
    ,p_parent_list_item_id         => NULL
    ,p_list_item_display_sequence  => 30
    ,p_list_item_link_type         => 'TARGET_PAGE'
    ,p_list_item_link_text         => 'Historique tickets'
    ,p_list_item_link_target       => 'f?p=&APP_ID.:30:&SESSION.'
    ,p_list_item_icon              => 'fa-receipt'
    );

  WWV_FLOW_API.CREATE_SHARED_LIST_ITEM (
    p_id                          => 1001004
    ,p_list_id                     => 100100
    ,p_parent_list_item_id         => NULL
    ,p_list_item_display_sequence  => 40
    ,p_list_item_link_type         => 'TARGET_PAGE'
    ,p_list_item_link_text         => 'Z de caisse'
    ,p_list_item_link_target       => 'f?p=&APP_ID.:40:&SESSION.'
    ,p_list_item_icon              => 'fa-file-invoice'
    );
END;
/

-- ═══ 9) Compilation ═══
PROMPT
PROMPT [9] Compilation App 100
ALTER APPLICATION 100 COMPILE;

PROMPT
PROMPT ═══ Validation ═══
SELECT application_id, application_name, alias, workspace, last_updated_by
  FROM apex_applications
 WHERE application_id = 100
   AND workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL');

SELECT page_id, page_name, page_alias
  FROM apex_application_pages
 WHERE application_id = 100
 ORDER BY page_id;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ APP 100 (POS) installée — 4 pages, navigation, auth
PROMPT   - Page 10  : Dashboard (sessions actives + CA jour)
PROMPT   - Page 20  : Sessions de caisse
PROMPT   - Page 30  : Historique tickets (30j)
PROMPT   - Page 40  : Z de caisse (form + report)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
