-- ============================================================
-- APEX Apps 200, 300, 400, 500 — Installation programmatique
-- ============================================================
-- Crée les 4 applications restantes (Stock, Achats, Compta, Admin)
-- via l'API wwv_flow_api. Idempotent.
-- ============================================================
SET VERIFY OFF
SET DEFINE OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
WHENEVER SQLERROR EXIT SQL.SQLCODE

PROMPT ══════════════════════════════════════════════════════════
PROMPT   Apps 200, 300, 400, 500 — Installation
PROMPT ══════════════════════════════════════════════════════════

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

-- ═══ HELPER : install app generique ═══
CREATE OR REPLACE PROCEDURE install_app(
  p_app_id       NUMBER,
  p_app_name     VARCHAR2,
  p_app_alias    VARCHAR2,
  p_app_schema   VARCHAR2 DEFAULT 'APP_API'
) IS
  v_exists NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_exists FROM apex_applications
   WHERE workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
     AND application_id = p_app_id;
  IF v_exists > 0 THEN
    WWV_FLOW_API.REMOVE_FLOW(p_app_id);
    DBMS_OUTPUT.PUT_LINE('  → App ' || p_app_id || ' supprimée');
  END IF;

  APEX_APPLICATION_INSTALL.SET_APPLICATION_ID(p_app_id);
  APEX_APPLICATION_INSTALL.SET_APPLICATION_NAME(p_app_name);
  APEX_APPLICATION_INSTALL.SET_APPLICATION_ALIAS(p_app_alias);
  APEX_APPLICATION_INSTALL.SET_SCHEMA(p_app_schema);
  APEX_APPLICATION_INSTALL.SET_AUTO_INSTALL_SUP_OBJ(FALSE);
  APEX_APPLICATION_INSTALL.SET_FLOW_STATUS('AVAILABLE');
  APEX_APPLICATION_INSTALL.SET_AUTHENTICATION_SCHEME(
    p_name        => 'REGAL_AUTH',
    p_scheme_type => 'PLSQL',
    p_plsql_code  => 'return app_sys.pkg_apex_auth.authenticate(:APP_USER, :APP_PASSWORD);'
  );

  WWV_FLOW_API.CREATE_FLOW(
    p_id                          => p_app_id
    ,p_display_id                  => p_app_id
    ,p_owner                       => p_app_schema
    ,p_name                        => p_app_name
    ,p_alias                       => p_app_alias
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
    ,p_substitution_value_01        => p_app_name
    ,p_substitution_string_02      => 'REGAL_COMPANY'
    ,p_substitution_value_02        => 'LITOKO SARL — Pointe-Noire'
    ,p_last_updated_by             => 'SYS'
    ,p_created_on                  => SYSDATE
    ,p_updated_on                  => SYSDATE
  );
  DBMS_OUTPUT.PUT_LINE('  → App ' || p_app_id || ' « ' || p_app_name || ' » créée');
END install_app;
/

-- ═══ HELPER : ajout page basique ═══
CREATE OR REPLACE PROCEDURE add_page(
  p_app_id      NUMBER,
  p_page_id     NUMBER,
  p_page_name   VARCHAR2,
  p_page_alias  VARCHAR2,
  p_query       CLOB
) IS
  v_pg_id NUMBER := p_app_id * 1000 + p_page_id;
BEGIN
  WWV_FLOW_API.CREATE_PAGE(
    p_id                          => p_page_id
    ,p_flow_id                      => p_app_id
    ,p_user_interface_id           => 1
    ,p_name                        => p_page_name
    ,p_alias                       => p_page_alias
    ,p_step_title                  => p_page_name
    ,p_autocomplete_on_off         => 'OFF'
    ,p_step_template               => 102
    ,p_page_is_protected           => 'Y'
    ,p_page_template_options       => '#DEFAULT#'
    ,p_last_updated_by             => 'SYS'
    ,p_created_on                  => SYSDATE
    ,p_updated_on                  => SYSDATE
  );
  WWV_FLOW_API.CREATE_PAGE_PLUG(
    p_id                          => v_pg_id
    ,p_flow_id                     => p_app_id
    ,p_page_id                     => p_page_id
    ,p_plug_name                   => p_page_name
    ,p_region_template_options     => '#DEFAULT#'
    ,p_plug_template               => 149
    ,p_plug_display_sequence       => 10
    ,p_plug_display_point          => 'BODY'
    ,p_plug_source_type            => 'SQL_QUERY'
    ,p_plug_query                  => p_query
    ,p_last_updated_by             => 'SYS'
  );
  DBMS_OUTPUT.PUT_LINE('  → Page ' || p_page_id || ' « ' || p_page_name || ' » ajoutée');
END add_page;
/

-- ══════════════════════════════════════════════════════════
-- 1) App 200 — Stock / Transferts / Inventaires
-- ══════════════════════════════════════════════════════════
PROMPT
PROMPT ═══ App 200 — Stock / Transferts ═══
BEGIN
  install_app(200, 'Stock / Transferts LITOKO', 'STOCK');
END;
/

BEGIN
  add_page(200, 10, 'Tableau de bord',    'DASHBOARD', q'[
    SELECT site_code, site_name, nb_references, total_units,
           total_value_xaf, nb_low_stock, last_movement_at
      FROM app_api.v_inv_stock_kpi
     ORDER BY total_value_xaf DESC]');
  add_page(200, 20, 'Transferts en cours', 'TRANSFERS', q'[
    SELECT transfer_id, transfer_number, transfer_date,
           source_warehouse, target_warehouse, status,
           nb_lines, total_requested_qty, total_sent_qty,
           total_received_qty, days_in_process
      FROM app_api.v_transfer_pipeline]');
  add_page(200, 30, 'Mouvements stock',   'MOVEMENTS', q'[
    SELECT s.warehouse_code, s.product_code, p.product_name,
           s.stock_qty, p.standard_price,
           ROUND(s.stock_qty * p.standard_price, 0) AS valeur_xaf,
           s.last_in_at, s.last_out_at
      FROM app_inv.inv_stock s
      JOIN app_product.product p ON p.product_code = s.product_code
     WHERE s.stock_qty > 0
     ORDER BY s.stock_qty DESC
     FETCH FIRST 100 ROWS ONLY]');
  add_page(200, 40, 'Alertes stock bas',  'ALERTS',    q'[
    SELECT s.warehouse_code, s.product_code, p.product_name,
           s.stock_qty, p.min_stock_qty, p.max_stock_qty,
           CASE WHEN s.stock_qty = 0 THEN 'RUPTURE'
                WHEN s.stock_qty <= p.min_stock_qty THEN 'BAS'
                ELSE 'OK'
           END AS alert_level
      FROM app_inv.inv_stock s
      JOIN app_product.product p ON p.product_code = s.product_code
     WHERE s.stock_qty <= NVL(p.min_stock_qty, 0)
     ORDER BY s.stock_qty ASC]');
END;
/

-- ══════════════════════════════════════════════════════════
-- 2) App 300 — Achats / Fournisseurs
-- ══════════════════════════════════════════════════════════
PROMPT
PROMPT ═══ App 300 — Achats / Fournisseurs ═══
BEGIN
  install_app(300, 'Achats / Fournisseurs', 'ACHATS');
END;
/

BEGIN
  add_page(300, 10, 'Tableau de bord',    'DASHBOARD', q'[
    SELECT party_code, party_name, total_orders, closed_orders, total_ytd
      FROM app_api.v_supplier_otd
     ORDER BY total_ytd DESC NULLS LAST
     FETCH FIRST 20 ROWS ONLY]');
  add_page(300, 20, 'Bons de commande',   'PO',        q'[
    SELECT po.po_id, po.po_number, po.po_date, po.supplier_code,
           s.party_name AS supplier_name, po.status, po.total_ht,
           po.total_tva, po.total_ttc, po.delivery_date, po.created_at
      FROM app_purchase.purchase_order po
      LEFT JOIN app_party.party s ON s.party_code = po.supplier_code
     ORDER BY po.po_date DESC
     FETCH FIRST 100 ROWS ONLY]');
  add_page(300, 30, 'Fournisseurs',       'SUPPLIERS', q'[
    SELECT p.party_code, p.party_name, p.nature_id, p.country,
           p.city, p.tax_regime, p.payment_terms, p.credit_days,
           p.is_blocked
      FROM app_party.party p
     WHERE p.is_blocked = 'N'
     ORDER BY p.party_name]');
  add_page(300, 40, 'Catalogue articles', 'CATALOG',   q'[
    SELECT p.product_code, p.product_name, p.short_name, p.stock_unit,
           p.standard_price, p.standard_price_ht, p.average_cost,
           p.is_stock_managed, p.is_promo, p.promo_price,
           p.status
      FROM app_product.product p
     WHERE p.status = 'ACTIVE'
     ORDER BY p.product_name
     FETCH FIRST 100 ROWS ONLY]');
END;
/

-- ══════════════════════════════════════════════════════════
-- 3) App 400 — Comptabilité OHADA + Fiscal CG
-- ══════════════════════════════════════════════════════════
PROMPT
PROMPT ═══ App 400 — Comptabilité OHADA ═══
BEGIN
  install_app(400, 'Comptabilité OHADA / Fiscal CG', 'COMPTA');
END;
/

BEGIN
  add_page(400, 10, 'Tableau de bord',    'DASHBOARD', q'[
    SELECT account_code, account_name, account_class, normal_balance,
           mvt_debit, mvt_credit, solde
      FROM app_api.v_gl_account_balance
     WHERE ABS(solde) > 0
     ORDER BY ABS(solde) DESC
     FETCH FIRST 30 ROWS ONLY]');
  add_page(400, 20, 'Plan comptable OHADA', 'CHART',    q'[
    SELECT account_code, account_name, account_class, account_type,
           normal_balance, is_active
      FROM app_gl.gl_account_ohada
     WHERE is_active = 'Y'
     ORDER BY account_code]');
  add_page(400, 30, 'Écritures',          'ENTRIES',   q'[
    SELECT entry_no, entry_date, journal_code, document_no,
           currency_code, company_total, is_posted,
           entry_label, created_by
      FROM app_gl.gl_entry
     WHERE entry_date >= ADD_MONTHS(SYSDATE, -3)
     ORDER BY entry_date DESC, entry_no DESC
     FETCH FIRST 100 ROWS ONLY]');
  add_page(400, 40, 'Déclarations fiscales CG', 'TAX', q'[
    SELECT d.declaration_ref, d.period_start, d.period_end,
           d.jurisdiction, d.company_code,
           d.base_amount, d.tax_due, d.amount_payable,
           d.status, f.form_code, f.form_label
      FROM app_gl.tax_declaration d
      JOIN app_gl.tax_form_type f ON f.form_type_id = d.form_type_id
     ORDER BY d.period_end DESC
     FETCH FIRST 50 ROWS ONLY]');
  add_page(400, 50, 'Immobilisations',    'ASSETS',    q'[
    SELECT asset_code, company_code, asset_name, category,
           acquisition_date, acquisition_value, residual_value,
           useful_life_months, depreciation_method, status,
           accumulated_dep, net_book_value
      FROM app_gl.imm_asset
     ORDER BY acquisition_date DESC
     FETCH FIRST 50 ROWS ONLY]');
END;
/

-- ══════════════════════════════════════════════════════════
-- 4) App 500 — Administration
-- ══════════════════════════════════════════════════════════
PROMPT
PROMPT ═══ App 500 — Administration ═══
BEGIN
  install_app(500, 'Administration REGAL', 'ADMIN');
END;
/

BEGIN
  add_page(500, 10, 'Tableau de bord',    'DASHBOARD', q'[
    SELECT 'Utilisateurs' AS component, COUNT(*) AS total,
           SUM(CASE WHEN is_active = 'Y' THEN 1 ELSE 0 END) AS actifs
      FROM app_sys.sys_user
    UNION ALL
    SELECT 'Rôles REGAL',     COUNT(*), 0 FROM app_sys.sys_role WHERE role_code LIKE 'REGAL_%'
    UNION ALL
    SELECT 'Sites REGAL',     COUNT(*), 0 FROM app_sys.site_master
    UNION ALL
    SELECT 'Events outbox',   COUNT(*), 0 FROM app_sys.outbox_event
    UNION ALL
    SELECT 'Events pending',  COUNT(*), 0 FROM app_sys.outbox_event WHERE status = 'PENDING'
    UNION ALL
    SELECT 'Sys messages',    COUNT(*), 0 FROM app_sys.sys_message
    UNION ALL
    SELECT 'APEX apps REGAL', COUNT(*), 0 FROM apex_applications
      WHERE workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
      AND application_id BETWEEN 100 AND 599]');
  add_page(500, 20, 'Utilisateurs',       'USERS',     q'[
    SELECT user_id, user_code, user_name, email, language_code,
           is_active, password_changed_at, created_at
      FROM app_sys.sys_user
     ORDER BY user_code]');
  add_page(500, 30, 'Rôles REGAL',        'ROLES',     q'[
    SELECT r.role_id, r.role_code, r.role_name, r.role_level, r.description
      FROM app_sys.sys_role r
     ORDER BY r.role_level]');
  add_page(500, 40, 'Sites REGAL',        'SITES',     q'[
    SELECT site_code, site_name, site_type, site_address, site_city,
           is_active, sync_priority
      FROM app_sys.site_master
     ORDER BY site_type, site_code]');
  add_page(500, 50, 'ETL Legacy',         'ETL',       q'[
    SELECT etl_id, source_table, target_table, rows_processed,
           status, started_at, finished_at, error_message
      FROM app_api.etl_run_progress
     ORDER BY started_at DESC
     FETCH FIRST 50 ROWS ONLY]');
  add_page(500, 60, 'Outbox CDC',         'OUTBOX',    q'[
    SELECT event_id, object_owner, object_name, primary_key_value,
           operation, status, site_code_origin, created_at, published_at
      FROM app_sys.outbox_event
     ORDER BY event_id DESC
     FETCH FIRST 50 ROWS ONLY]');
END;
/

-- ═══ 5) Compile ═══
PROMPT
PROMPT [5] Compilation des 4 apps
BEGIN
  FOR a IN 200..500 LOOP
    BEGIN
      EXECUTE IMMEDIATE 'ALTER APPLICATION ' || a || ' COMPILE';
      DBMS_OUTPUT.PUT_LINE('  ✓ App ' || a || ' compilée');
    EXCEPTION WHEN OTHERS THEN
      DBMS_OUTPUT.PUT_LINE('  ⚠ App ' || a || ' : ' || SQLERRM);
    END;
  END LOOP;
END;
/

-- ═══ 6) Validation ═══
PROMPT
PROMPT ═══ Validation finale ═══
SELECT application_id, application_name, alias, last_updated_on
  FROM apex_applications
 WHERE workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
   AND application_id IN (200, 300, 400, 500)
 ORDER BY application_id;

SELECT application_id, COUNT(*) AS nb_pages
  FROM apex_application_pages
 WHERE application_id IN (200, 300, 400, 500)
 GROUP BY application_id
 ORDER BY application_id;

BEGIN
  EXECUTE IMMEDIATE 'DROP PROCEDURE install_app';
  EXECUTE IMMEDIATE 'DROP PROCEDURE add_page';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ Apps 200, 300, 400, 500 installées
PROMPT   - 200 Stock    : 4 pages
PROMPT   - 300 Achats   : 4 pages
PROMPT   - 400 Compta   : 5 pages
PROMPT   - 500 Admin    : 6 pages
PROMPT ══════════════════════════════════════════════════════════
EXIT;
