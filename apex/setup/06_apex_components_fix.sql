-- ============================================================
-- APEX SETUP 06 : FIX des vues 04 (colonnes réelles vs legacy)
-- ============================================================
-- Les vues de apex/setup/04_apex_components.sql utilisent des noms
-- de colonnes inventés. Ce script les recrée avec les VRAIES colonnes :
--
--   pos_session : PK (terminal_id, session_no), pas session_id, pas status
--   pos_terminal : pas de colonne city, mais pos_code
--   ticket       : PK (terminal_id, ticket_no), pas ticket_id
--   party        : pas is_active, mais status ('ACTIVE'/'INACTIVE')
--   product      : pas company_code
--   product_price: PK (price_list_id, product_id), pas valid_from
--
-- Idempotent : DROP VIEW IF EXISTS + CREATE OR REPLACE
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   FIX apex/setup/04 — Vues avec colonnes RÉELLES
PROMPT ══════════════════════════════════════════════════════════

-- ═══ 1) v_pos_session_kpi (PK composite, pas status) ═══
PROMPT
PROMPT [1/7] v_pos_session_kpi — colonnes réelles pos_session
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW v_pos_session_kpi';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE VIEW v_pos_session_kpi AS
SELECT s.terminal_id, s.session_no,
       t.terminal_code, t.terminal_name,
       -- site_code déduit du terminal_code (1er char) ou warehouse_code
       NVL(SUBSTR(t.terminal_code, 1, 3), t.warehouse_code) AS site_code,
       s.user_code, s.opened_at, s.closed_at,
       -- CA session (ticketTTC agrégé)
       (SELECT NVL(SUM(tk.total_ttc), 0)
          FROM app_sales.ticket tk
         WHERE tk.terminal_id = t.terminal_code
           AND tk.session_no = s.session_no) AS ca_session_xaf,
       (SELECT COUNT(*) FROM app_sales.ticket tk
         WHERE tk.terminal_id = t.terminal_code
           AND tk.session_no = s.session_no) AS nb_tickets,
       -- Durée
       ROUND((NVL(s.closed_at, SYSDATE) - s.opened_at) * 24, 1) AS hours_open,
       -- État déduit
       CASE WHEN s.closed_at IS NULL THEN 'OPEN' ELSE 'CLOSED' END AS status
  FROM app_pos.pos_session s
  JOIN app_pos.pos_terminal t ON t.terminal_id = s.terminal_id;

-- ═══ 2) v_today_sales — par terminal ═══
PROMPT
PROMPT [2/7] v_today_sales — ventes du jour
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW v_today_sales';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE VIEW v_today_sales AS
SELECT t.terminal_code, t.terminal_name,
       t.warehouse_code,
       NVL(SUBSTR(t.terminal_code, 1, 3), t.warehouse_code) AS site_code,
       COUNT(DISTINCT tk.ticket_no)    AS nb_tickets,
       SUM(tk.total_ht)               AS total_ht,
       SUM(tk.total_ttc)              AS total_ttc,
       SUM(tk.tax_amount_1)           AS total_tva,
       ROUND(AVG(tk.total_ttc), 0)    AS avg_basket,
       MAX(tk.ticket_date)            AS last_ticket_at
  FROM app_sales.ticket tk
  JOIN app_pos.pos_terminal t ON t.terminal_code = tk.terminal_id
 WHERE TRUNC(tk.ticket_date) = TRUNC(SYSDATE)
   AND tk.status = 'V'
 GROUP BY t.terminal_code, t.terminal_name, t.warehouse_code;

-- ═══ 3) v_transfer_pipeline — utilise transfer_header existant ═══
PROMPT
PROMPT [3/7] v_transfer_pipeline — pipeline transferts
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW v_transfer_pipeline';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE VIEW v_transfer_pipeline AS
SELECT t.transfer_id, t.transfer_number, t.transfer_date,
       t.source_warehouse, t.target_warehouse,
       t.status,
       COUNT(l.line_no)             AS nb_lines,
       SUM(l.requested_qty)         AS total_requested_qty,
       SUM(l.sent_qty)              AS total_sent_qty,
       SUM(l.received_qty)          AS total_received_qty,
       ROUND(SYSDATE - t.transfer_date, 1) AS days_in_process
  FROM app_inv.transfer_header t
  LEFT JOIN app_inv.transfer_line l ON l.transfer_id = t.transfer_id
 WHERE t.status NOT IN ('CLOSED','CANCELLED')
 GROUP BY t.transfer_id, t.transfer_number, t.transfer_date,
          t.source_warehouse, t.target_warehouse, t.status;

-- ═══ 4) v_inv_stock_kpi — ajout jointure correcte ═══
PROMPT
PROMPT [4/7] v_inv_stock_kpi — compatible w/o site_master
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW v_inv_stock_kpi';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE VIEW v_inv_stock_kpi AS
SELECT w.warehouse_code AS site_code,
       w.warehouse_name AS site_name,
       NULL AS city,
       'WAREHOUSE' AS site_type,
       COUNT(DISTINCT s.product_code)        AS nb_references,
       SUM(s.stock_qty)                      AS total_units,
       SUM(s.stock_qty * p.standard_price)    AS total_value_xaf,
       SUM(CASE WHEN s.stock_qty <= NVL(p.min_stock_qty, 0) THEN 1 ELSE 0 END) AS nb_low_stock,
       MAX(s.last_in_at)                     AS last_movement_at
  FROM app_inv.inv_stock s
  JOIN app_product.product  p ON p.product_code = s.product_code
  JOIN app_org.org_warehouse w ON w.warehouse_code = s.warehouse_code
 GROUP BY w.warehouse_code, w.warehouse_name;

-- ═══ 5) v_gl_account_balance — adapter à gl_entry_line (pas v2) ═══
PROMPT
PROMPT [5/7] v_gl_account_balance — adapter à gl_entry_line (PK composite)
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW v_gl_account_balance';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE VIEW v_gl_account_balance AS
SELECT a.account_code,
       a.account_name,
       a.account_class,
       a.normal_balance,
       SUM(NVL(el.company_debit, 0))  AS mvt_debit,
       SUM(NVL(el.company_credit, 0)) AS mvt_credit,
       CASE a.normal_balance
         WHEN 'DEBIT'  THEN SUM(NVL(el.company_debit, 0)) - SUM(NVL(el.company_credit, 0))
         WHEN 'CREDIT' THEN SUM(NVL(el.company_credit, 0)) - SUM(NVL(el.company_debit, 0))
         ELSE 0
       END AS solde
  FROM app_gl.gl_account_ohada a
  LEFT JOIN app_gl.gl_entry_line el ON el.account_code = a.account_code
 GROUP BY a.account_code, a.account_name, a.account_class, a.normal_balance;

-- ═══ 6) v_general_ledger — adapter à PK composite gl_entry_line ═══
PROMPT
PROMPT [6/7] v_general_ledger — jointure composite gl_entry_line
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW v_general_ledger';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE VIEW v_general_ledger AS
SELECT e.entry_no, e.entry_date,
       j.journal_code, j.journal_label,
       e.doc_ref,
       el.account_code, a.account_name,
       el.company_debit AS debit, el.company_credit AS credit,
       el.line_label AS description,
       e.created_by, e.validated_by
  FROM app_gl.gl_entry e
  JOIN app_gl.gl_entry_line el ON el.company_code = e.company_code
                              AND el.entity_code  = e.entity_code
                              AND el.entry_no     = e.entry_no
  LEFT JOIN app_gl.gl_account_ohada a ON a.account_code = el.account_code
  LEFT JOIN app_gl.gl_journal j        ON j.journal_code = e.journal_code
 ORDER BY e.entry_date DESC, e.entry_no DESC, el.line_no;

-- ═══ 7) v_supplier_otd — vue simplifiée ═══
PROMPT
PROMPT [7/7] v_supplier_otd — vue fournisseurs
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW v_supplier_otd';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE VIEW v_supplier_otd AS
SELECT s.party_code, s.party_name, s.country,
       COUNT(DISTINCT po.po_id) AS total_orders,
       SUM(CASE WHEN po.status IN ('CLOSED','RECEIVED') THEN 1 ELSE 0 END) AS closed_orders,
       SUM(po.total_ttc) AS total_ytd
  FROM app_purchase.purchase_order po
  JOIN app_party.party s ON s.party_code = po.supplier_code
 GROUP BY s.party_code, s.party_name, s.country;

PROMPT
PROMPT ═══ Validation ═══
SELECT object_name, status FROM user_objects
 WHERE object_type = 'VIEW'
   AND object_name IN ('V_INV_STOCK_KPI','V_TRANSFER_PIPELINE','V_POS_SESSION_KPI',
                       'V_TODAY_SALES','V_GL_ACCOUNT_BALANCE','V_GENERAL_LEDGER',
                       'V_SUPPLIER_OTD')
 ORDER BY object_name;

PROMPT
PROMPT ═══ Tests ═══

PROMPT [T1] v_pos_session_kpi
SELECT terminal_code, terminal_name, status, nb_tickets, ca_session_xaf, hours_open
  FROM v_pos_session_kpi
 FETCH FIRST 5 ROWS ONLY;

PROMPT [T2] v_today_sales
SELECT terminal_code, nb_tickets, total_ttc, total_tva FROM v_today_sales;

PROMPT [T3] v_inv_stock_kpi
SELECT site_code, nb_references, total_units, total_value_xaf, nb_low_stock
  FROM v_inv_stock_kpi
 ORDER BY total_value_xaf DESC;

PROMPT [T4] v_gl_account_balance (top 5 soldes)
SELECT account_code, account_name, mvt_debit, mvt_credit, solde
  FROM v_gl_account_balance
 ORDER BY ABS(solde) DESC
 FETCH FIRST 5 ROWS ONLY;

PROMPT [T5] v_general_ledger (5 dernières écritures)
SELECT entry_date, journal_code, account_code, debit, credit, description
  FROM v_general_ledger
 FETCH FIRST 5 ROWS ONLY;

PROMPT [T6] v_supplier_otd
SELECT party_code, party_name, total_orders, total_ytd FROM v_supplier_otd;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ FIX 04 — 7 vues recréées avec colonnes réelles
PROMPT ══════════════════════════════════════════════════════════
EXIT;
