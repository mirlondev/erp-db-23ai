-- ============================================================
-- APEX SETUP 04 : Vues & PL/SQL partagés pour toutes les apps
-- ============================================================
-- Crée les vues « métier » réutilisables par les apps APEX 100→500.
-- Source unique : schéma APP_API (visible des apps en cross-schema).
--
-- Tables existantes référencées (toutes déjà créées par scripts 00-57) :
--   app_inv.transfer_header, transfer_line, inv_stock, inv_product_lot,
--                inv_count_header, inv_count_line
--   app_sales.ticket, ticket_line, ticket_line_v2 (script 56)
--   app_gl.gl_entry, gl_entry_line_v2 (script 56), tax_declaration,
--                tax_payment, imm_asset, imm_depreciation, fn_cg_irpp
--   app_purchase.purchase_order, purchase_order_line, supplier_product
--   app_party.party, app_product.product
--   app_sys.outbox_event, site_master, v_tt_pending, pkg_apex_auth
--
-- Idempotent : CREATE OR REPLACE partout.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 04 — Vues & PL/SQL partagés (toutes apps)
PROMPT ══════════════════════════════════════════════════════════

-- =================================================================
-- BLOC 1 : Vues métier stock (app 200)
-- =================================================================
PROMPT
PROMPT [1/12] v_inv_stock_kpi — Dashboard stock multi-sites
CREATE OR REPLACE VIEW v_inv_stock_kpi AS
SELECT ws.site_code,
       ws.site_name,
       ws.city,
       ws.site_type,
       COUNT(DISTINCT s.product_code)        AS nb_references,
       SUM(s.stock_qty)                      AS total_units,
       SUM(s.stock_qty * p.standard_price)    AS total_value_xaf,
      SUM(CASE WHEN s.stock_qty <= p.min_stock_qty THEN 1 ELSE 0 END) AS nb_low_stock,
       MAX(s.last_in_at)                      AS last_movement_at
  FROM app_inv.inv_stock s
  JOIN app_product.product  p ON p.product_code = s.product_code
  JOIN app_org.org_warehouse w ON w.warehouse_code = s.warehouse_code
  JOIN app_sys.site_master   ws ON ws.site_code = w.warehouse_code
 GROUP BY ws.site_code, ws.site_name, ws.city, ws.site_type;

PROMPT
PROMPT [2/12] v_transfer_pipeline — Transferts en cours par étape
CREATE OR REPLACE VIEW v_transfer_pipeline AS
SELECT t.transfer_id, t.transfer_number, t.transfer_date,
       t.source_warehouse, t.target_warehouse,
       t.status,
       COUNT(l.line_no)             AS nb_lines,
       SUM(l.requested_qty)         AS total_requested_qty,
       SUM(l.sent_qty)              AS total_sent_qty,
       SUM(l.received_qty)          AS total_received_qty,
       CASE
         WHEN t.status = 'RECEIVED' THEN NULL
         ELSE SYSDATE - t.transfer_date
       END AS days_in_process,
       -- Estimation de la valeur (XAF), calculée sans dépendance au package
       (SELECT NVL(SUM(tl.requested_qty * p.standard_price), 0)
          FROM app_inv.transfer_line tl
          JOIN app_product.product p ON p.product_code = tl.product_code
         WHERE tl.transfer_id = t.transfer_id) AS estimated_value_xaf
  FROM app_inv.transfer_header t
  LEFT JOIN app_inv.transfer_line l ON l.transfer_id = t.transfer_id
 WHERE t.status NOT IN ('CLOSED','CANCELLED')
 GROUP BY t.transfer_id, t.transfer_number, t.transfer_date,
          t.source_warehouse, t.target_warehouse, t.status;


-- =================================================================
-- BLOC 2 : Vues POS / Ventes (app 100)
-- =================================================================
PROMPT
PROMPT [3/12] v_pos_session_kpi — Sessions de caisse actives
CREATE OR REPLACE VIEW v_pos_session_kpi AS
SELECT s.session_id, s.terminal_id,
       t.terminal_name, t.city AS site_city,
       s.user_code, s.opened_at,
       -- CA session
       (SELECT NVL(SUM(total_ttc), 0)
          FROM app_sales.ticket tk
         WHERE tk.session_id = s.session_id) AS ca_session_xaf,
       (SELECT COUNT(*) FROM app_sales.ticket tk
         WHERE tk.session_id = s.session_id) AS nb_tickets,
       -- Durée
       ROUND((SYSDATE - s.opened_at) * 24, 1) AS hours_open,
       s.status
  FROM app_pos.pos_session s
  JOIN app_pos.pos_terminal t ON t.terminal_id = s.terminal_id
 WHERE s.status = 'OPEN';

PROMPT
PROMPT [4/12] v_today_sales — Ventes du jour par site
CREATE OR REPLACE VIEW v_today_sales AS
SELECT ws.site_code,
       ws.site_name,
       ws.city,
       COUNT(DISTINCT tk.ticket_id)     AS nb_tickets,
       SUM(tk.total_ht)                 AS total_ht,
       SUM(tk.total_ttc)                AS total_ttc,
       SUM(tk.total_tva)                AS total_tva,
       ROUND(AVG(tk.total_ttc), 0)      AS avg_basket,
       MAX(tk.ticket_date)              AS last_ticket_at
  FROM app_sales.ticket tk
  JOIN app_pos.pos_terminal pt ON pt.terminal_id = tk.terminal_id
  JOIN app_sys.site_master    ws ON ws.site_code = pt.terminal_code
 WHERE TRUNC(tk.ticket_date) = TRUNC(SYSDATE)
   AND tk.status IN ('V','PAID')
 GROUP BY ws.site_code, ws.site_name, ws.city;

-- =================================================================
-- BLOC 3 : Vues Compta OHADA (app 400)
-- =================================================================
PROMPT
PROMPT [5/12] v_gl_account_balance — Soldes par compte (CEMAC)
CREATE OR REPLACE VIEW v_gl_account_balance AS
SELECT a.account_code,
       a.account_name,
       a.account_class,
       a.normal_balance,
       a.is_receivable, a.is_payable, a.is_cash,
       fp.fiscal_year,
       fp.period_no,
       -- Mouvements
       NVL(SUM(CASE WHEN el.debit > 0 THEN el.debit ELSE 0 END), 0)  AS mvt_debit,
       NVL(SUM(CASE WHEN el.credit > 0 THEN el.credit ELSE 0 END), 0) AS mvt_credit,
       -- Solde selon sens normal
       CASE a.normal_balance
         WHEN 'DEBIT' THEN
           NVL(SUM(el.debit), 0) - NVL(SUM(el.credit), 0)
         WHEN 'CREDIT' THEN
           NVL(SUM(el.credit), 0) - NVL(SUM(el.debit), 0)
         ELSE 0
       END AS solde
  FROM app_gl.gl_account_ohada a
  LEFT JOIN app_gl.gl_entry_line_v2 el ON el.account_code = a.account_code
  LEFT JOIN app_gl.gl_entry e         ON e.entry_id = el.entry_id
  LEFT JOIN app_gl.gl_fiscal_period fp ON fp.period_id = e.period_id
 GROUP BY a.account_code, a.account_name, a.account_class, a.normal_balance,
          a.is_receivable, a.is_payable, a.is_cash,
          fp.fiscal_year, fp.period_no;

PROMPT
PROMPT [6/12] v_general_ledger — Grand livre OHADA
CREATE OR REPLACE VIEW v_general_ledger AS
SELECT e.entry_no, e.entry_date, e.fiscal_year, e.period_no,
       j.journal_code, j.journal_label,
       e.doc_ref,
       el.account_code, a.account_name,
       el.debit, el.credit,
       el.description,
       el.cost_center_code,
       el.partner_code,
       e.created_by, e.validated_by
  FROM app_gl.gl_entry e
  JOIN app_gl.gl_entry_line_v2 el ON el.entry_id = e.entry_id
  JOIN app_gl.gl_account_ohada a ON a.account_code = el.account_code
  JOIN app_gl.gl_journal j        ON j.journal_id = e.journal_id
 ORDER BY e.entry_date DESC, e.entry_no DESC, el.line_no;

PROMPT
PROMPT [7/12] v_trial_balance — Balance générale (SYSCOHADA)
CREATE OR REPLACE VIEW v_trial_balance AS
SELECT account_code,
       MAX(account_name) AS account_name,
       MAX(account_class) AS account_class,
       MAX(normal_balance) AS normal_balance,
       SUM(mvt_debit) AS total_debit,
       SUM(mvt_credit) AS total_credit,
       SUM(CASE MAX(normal_balance)
             WHEN 'DEBIT'  THEN SUM(mvt_debit) - SUM(mvt_credit)
             WHEN 'CREDIT' THEN SUM(mvt_credit) - SUM(mvt_debit)
           END) AS solde
  FROM v_gl_account_balance
 GROUP BY account_code
 ORDER BY account_code;

PROMPT
PROMPT [8/12] v_cg_tax_due — TVA nette due (Congo CEMAC)
CREATE OR REPLACE VIEW v_cg_tax_due AS
SELECT d.declaration_id,
       d.declaration_ref,
       d.period_start, d.period_end,
       d.jurisdiction,
       ft.form_label,
       d.tax_due, d.credit_applied, d.amount_payable,
       d.status,
       d.submitted_at, d.acked_at, d.paid_at,
       -- Détail par taux
       (SELECT LISTAGG(l.rate_type || '@' || l.rate || '=' || l.tax_amount, ' | ')
                WITHIN GROUP (ORDER BY l.line_no)
          FROM app_gl.tax_declaration_line l
         WHERE l.declaration_id = d.declaration_id) AS detail_by_rate
  FROM app_gl.tax_declaration d
  JOIN app_gl.tax_form_type ft ON ft.form_type_id = d.form_type_id
 WHERE d.jurisdiction = 'CG'
 ORDER BY d.period_end DESC;

-- =================================================================
-- BLOC 4 : Vues fournisseurs & achats (app 300)
-- =================================================================
PROMPT
PROMPT [9/12] v_supplier_otd — On-Time Delivery fournisseur
CREATE OR REPLACE VIEW v_supplier_otd AS
SELECT s.party_code,
       s.party_name,
       s.country_code,
       COUNT(DISTINCT po.po_id)         AS total_orders,
       SUM(CASE WHEN po.expected_date >= po.received_at THEN 1 ELSE 0 END) AS on_time_orders,
       ROUND(100 * SUM(CASE WHEN po.expected_date >= po.received_at THEN 1 ELSE 0 END)
                  / NULLIF(COUNT(DISTINCT po.po_id), 0), 2) AS otd_pct,
       AVG(po.received_at - po.po_date) AS avg_lead_time_days,
       SUM(po.total_ttc)               AS total_achats_ytd
  FROM app_purchase.purchase_order po
  JOIN app_party.party s ON s.party_code = po.supplier_code
 WHERE po.status IN ('RECEIVED','CLOSED')
   AND EXTRACT(YEAR FROM po.po_date) = EXTRACT(YEAR FROM SYSDATE)
 GROUP BY s.party_code, s.party_name, s.country_code;

PROMPT
PROMPT [10/12] v_three_way_match — Rapprochement 3-way (BL/Cmd/Fact)
CREATE OR REPLACE VIEW v_three_way_match AS
SELECT po.po_id, po.po_number, po.po_date,
       po.supplier_code, s.party_name AS supplier_name,
       po.total_ht  AS po_amount,
       bl.total_ht  AS bl_amount,
       inv.amount   AS invoice_amount,
       CASE
         WHEN po.total_ht = NVL(bl.total_ht, 0)
          AND NVL(bl.total_ht, 0) = NVL(inv.amount, 0) THEN 'MATCHED'
         WHEN ABS(po.total_ht - NVL(inv.amount, 0)) / NULLIF(po.total_ht,0) < 0.05
           THEN 'TOLERATED'
         WHEN po.total_ht > NVL(inv.amount, 0) THEN 'SHORT'
         ELSE 'OVER'
       END AS match_status
  FROM app_purchase.purchase_order po
  JOIN app_party.party s ON s.party_code = po.supplier_code
  LEFT JOIN app_doc.doc_header bl ON bl.source_doc_id = po.po_id
                                  AND bl.doc_type_code = 'BL_PURCHASE'
  LEFT JOIN app_ar.invoice inv    ON inv.po_id = po.po_id
 WHERE po.status IN ('VALIDATED','RECEIVED','CLOSED');

-- =================================================================
-- BLOC 5 : Vues Immobilisations + CNSS (app 400 + 500)
-- =================================================================
PROMPT
PROMPT [11/12] v_imm_progress — Suivi amortissement
CREATE OR REPLACE VIEW v_imm_progress AS
SELECT a.asset_id, a.asset_code, a.asset_name, a.category,
       a.acquisition_value,
       a.accumulated_dep, a.net_book_value,
       a.useful_life_months,
       ROUND(100 * a.accumulated_dep / NULLIF(a.acquisition_value,0), 2) AS progress_pct,
       a.status,
       a.company_code
  FROM app_gl.imm_asset a;

PROMPT
PROMPT [12/12] v_cnss_charges — Charges CNSS mensuelles LITOKO
CREATE OR REPLACE VIEW v_cnss_charges AS
SELECT TO_CHAR(ps.paid_at, 'YYYY-MM')     AS mois,
       SUM(ps.cnps_employee)              AS cnss_employe,    -- CNSS employé
       SUM(ps.cnps_employer)              AS cnss_employeur,  -- CNSS patronal
       SUM(ps.irpp)                       AS irpp_total,
       SUM(ps.net)                        AS net_a_payer,
       SUM(ps.cnps_employer + ps.cnps_employee) AS total_cnss
  FROM app_hr.payroll_slip ps
  JOIN app_hr.mpf_employee e ON e.employee_id = ps.employee_id
 WHERE e.company_code = 'LITOKO'
 GROUP BY TO_CHAR(ps.paid_at, 'YYYY-MM')
 ORDER BY 1 DESC;

-- =================================================================
-- BLOC 6 : Function utilitaire pour multi-sites
-- =================================================================
PROMPT
PROMPT [BONUS] regal_split — Convertir CSV sites en table (pour filtres APEX)
CREATE OR REPLACE TYPE regal_site_tab IS TABLE OF VARCHAR2(20);
/

CREATE OR REPLACE FUNCTION regal_split(p_csv IN VARCHAR2) RETURN regal_site_tab PIPELINED IS
  v_start PLS_INTEGER := 1;
  v_idx   PLS_INTEGER;
  v_val   VARCHAR2(20);
BEGIN
  IF p_csv IS NULL THEN
    RETURN;
  END IF;
  LOOP
    v_idx := INSTR(p_csv, ',', v_start);
    IF v_idx = 0 THEN
      v_val := SUBSTR(p_csv, v_start);
      PIPE ROW(TRIM(v_val));
      EXIT;
    ELSE
      v_val := SUBSTR(p_csv, v_start, v_idx - v_start);
      PIPE ROW(TRIM(v_val));
      v_start := v_idx + 1;
    END IF;
  END LOOP;
END regal_split;
/

-- =================================================================
-- BLOC 7 : Privilèges APP_API (visible des apps APEX)
-- =================================================================
PROMPT
PROMPT [GRANTS] Vues partagées vers APP_API
GRANT SELECT ON v_inv_stock_kpi      TO app_sales, app_pos;
GRANT SELECT ON v_transfer_pipeline  TO app_sales, app_pos;
GRANT SELECT ON v_pos_session_kpi    TO app_sales;
GRANT SELECT ON v_today_sales        TO app_pos;
GRANT SELECT ON v_gl_account_balance TO app_api, app_ar;
GRANT SELECT ON v_general_ledger     TO app_api, app_ar;
GRANT SELECT ON v_trial_balance      TO app_api, app_ar;
GRANT SELECT ON v_cg_tax_due         TO app_api, app_ar;
GRANT SELECT ON v_supplier_otd       TO app_api;
GRANT SELECT ON v_three_way_match    TO app_api;
GRANT SELECT ON v_imm_progress       TO app_api;
GRANT SELECT ON v_cnss_charges       TO app_api;

-- Function regal_split : à exécuter dans la session APEX
GRANT EXECUTE ON regal_split TO app_sales, app_inv, app_pos, app_gl, app_ar, app_purchase;

-- =================================================================
-- BLOC 8 : Validation
-- =================================================================
PROMPT
PROMPT ═══ Validation ═══
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN (
    'V_INV_STOCK_KPI','V_TRANSFER_PIPELINE','V_POS_SESSION_KPI',
    'V_TODAY_SALES','V_GL_ACCOUNT_BALANCE','V_GENERAL_LEDGER',
    'V_TRIAL_BALANCE','V_CG_TAX_DUE','V_SUPPLIER_OTD',
    'V_THREE_WAY_MATCH','V_IMM_PROGRESS','V_CNSS_CHARGES','REGAL_SPLIT'
   )
 ORDER BY object_type, object_name;

PROMPT
PROMPT ═══ Test rapide ═══
SELECT 'Stock LITOKO' AS kpi,
       (SELECT SUM(total_value_xaf) FROM v_inv_stock_kpi) AS total_xaf,
       (SELECT SUM(total_units) FROM v_inv_stock_kpi) AS total_units
  FROM dual;

SELECT 'IRPP Congo 8M XAF/an, 2 enfants' AS cas,
       app_gl.fn_cg_irpp(8000000, 2) AS irpp_annuel,
       ROUND(app_gl.fn_cg_irpp(8000000, 2) / 12, 0) AS irpp_mensuel
  FROM dual;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ APEX SETUP 04 — 12 vues + 1 type + 1 fonction installés
PROMPT   - Stock : v_inv_stock_kpi, v_transfer_pipeline
PROMPT   - POS : v_pos_session_kpi, v_today_sales
PROMPT   - Compta : v_gl_account_balance, v_general_ledger, v_trial_balance
PROMPT   - Fiscal CG : v_cg_tax_due
PROMPT   - Achats : v_supplier_otd, v_three_way_match
PROMPT   - Immo + CNSS : v_imm_progress, v_cnss_charges
PROMPT   - Util : regal_split (CSV -> table)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
