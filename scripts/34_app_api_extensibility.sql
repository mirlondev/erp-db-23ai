-- ============================================================
-- SCRIPT 34 : Duality Views additionnelles + Vue Dashboard Exécutif
-- ============================================================
-- 1. dv_invoice : JSON Duality View sur app_ar.invoice (PK simple)
-- 2. dv_payment : JSON Duality View sur app_ar.payment (PK simple)
-- 3. v_dashboard_executive : Vue agrégée KPI pour direction
-- 4. dv_customer_credit : exposition encours client
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT system/oracle@localhost:1521/FREEPDB1

-- Privilèges pour que app_api puisse lire
GRANT SELECT ON app_ar.invoice          TO app_api;
GRANT SELECT ON app_ar.invoice_line     TO app_api;
GRANT SELECT ON app_ar.payment          TO app_api;
GRANT SELECT ON app_ar.credit_note      TO app_api;
GRANT SELECT ON app_ar.customer_credit  TO app_api;
GRANT SELECT ON app_gl.gl_account       TO app_api;
GRANT SELECT ON app_gl.gl_journal       TO app_api;
GRANT SELECT ON app_inv.inv_stock       TO app_api;

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   DUPLICITY VIEWS + DASHBOARD VIEW
PROMPT ══════════════════════════════════════════════════════════

WHENEVER SQLERROR CONTINUE
PROMPT
PROMPT [1] Duality View : dv_invoice
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW dv_invoice AS
  SELECT JSON {
    '_id'         : i.invoice_id,
    'number'      : i.invoice_number,
    'date'        : i.invoice_date,
    'dueDate'     : i.due_date,
    'company'     : i.company_code,
    'partyCode'   : i.party_code,
    'partyName'   : i.party_name,
    'currency'    : i.currency_code,
    'totalHT'     : i.total_ht,
    'totalTax'    : i.total_tax,
    'totalTTC'    : i.total_ttc,
    'totalPaid'   : i.total_paid,
    'balance'     : i.balance,
    'status'      : i.status,
    'lines'       : [ JSON {
      'lineNo'      : il.line_no,
      'product'     : il.product_code,
      'description' : il.description,
      'quantity'    : il.quantity,
      'unitPrice'   : il.unit_price,
      'amount'      : il.amount,
      'taxRate'     : il.tax_rate,
      'amountHT'    : il.amount_ht,
      'amountTTC'   : il.amount_ttc
    } FOR il IN
      (SELECT * FROM app_ar.invoice_line
        WHERE invoice_id = i.invoice_id) ]
  }
  FROM app_ar.invoice i
 WHERE i.status != 'CANCELLED'
 WITH CHECK OPTION;

PROMPT [2] Duality View : dv_payment
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW dv_payment AS
  SELECT JSON {
    '_id'        : p.payment_id,
    'number'     : p.payment_number,
    'date'       : p.payment_date,
    'partyCode'  : p.party_code,
    'partyName'  : p.party_name,
    'method'     : p.payment_method,
    'reference'  : p.reference,
    'amount'     : p.amount,
    'allocated'  : p.amount_allocated,
    'status'     : p.status,
    'memo'       : p.memo,
    'createdAt'  : p.created_at
  }
  FROM app_ar.payment p
 WHERE p.status != 'CANCELLED';

PROMPT [3] Duality View : dv_customer_credit
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW dv_customer_credit AS
  SELECT JSON {
    '_id'           : party_code || '-' || company_code,
    'partyCode'     : cc.party_code,
    'companyCode'   : cc.company_code,
    'creditLimit'   : cc.credit_limit,
    'creditDays'    : cc.credit_days,
    'currentBalance': cc.current_balance,
    'overdueBalance': cc.overdue_balance,
    'lastInvoice'   : cc.last_invoice_date,
    'lastPayment'   : cc.last_payment_date,
    'blocked'       : cc.is_blocked,
    'blockedReason' : cc.blocked_reason
  }
  FROM app_ar.customer_credit cc;

PROMPT
PROMPT [4] Vue : v_dashboard_executive — KPI globaux temps réel
CREATE OR REPLACE VIEW v_dashboard_executive AS
SELECT
  -- Période
  TRUNC(SYSDATE) AS report_date,

  -- VENTES DU JOUR
  (SELECT COUNT(*) FROM app_sales.ticket WHERE TRUNC(ticket_date) = TRUNC(SYSDATE) AND status = 'V') AS tickets_today,
  (SELECT NVL(SUM(total_ttc), 0) FROM app_sales.ticket WHERE TRUNC(ticket_date) = TRUNC(SYSDATE) AND status = 'V') AS revenue_today,
  (SELECT NVL(AVG(total_ttc), 0) FROM app_sales.ticket WHERE TRUNC(ticket_date) = TRUNC(SYSDATE) AND status = 'V') AS avg_ticket_today,
  (SELECT COUNT(DISTINCT customer_code) FROM app_sales.ticket WHERE TRUNC(ticket_date) = TRUNC(SYSDATE) AND status = 'V') AS unique_customers_today,

  -- VENTES MOIS EN COURS
  (SELECT COUNT(*) FROM app_sales.ticket WHERE TRUNC(ticket_date, 'MM') = TRUNC(SYSDATE, 'MM') AND status = 'V') AS tickets_mtd,
  (SELECT NVL(SUM(total_ttc), 0) FROM app_sales.ticket WHERE TRUNC(ticket_date, 'MM') = TRUNC(SYSDATE, 'MM') AND status = 'V') AS revenue_mtd,

  -- FACTURES EN ATTENTE
  (SELECT COUNT(*) FROM app_ar.invoice WHERE status IN ('VALID','PARTIAL','OVERDUE')) AS invoices_open,
  (SELECT NVL(SUM(balance), 0) FROM app_ar.invoice WHERE status IN ('VALID','PARTIAL','OVERDUE')) AS balance_total,
  (SELECT NVL(SUM(balance), 0) FROM app_ar.invoice WHERE status = 'OVERDUE') AS balance_overdue,

  -- STOCK
  (SELECT COUNT(*) FROM app_inv.inv_stock WHERE stock_qty <= 0) AS ruptures,
  (SELECT COUNT(*) FROM app_inv.inv_product_lot WHERE expiry_date BETWEEN SYSDATE AND SYSDATE+30) AS lots_expire_soon,
  (SELECT COUNT(*) FROM app_inv.inv_product_lot WHERE expiry_date < SYSDATE) AS lots_expired,

  -- FIDÉLITÉ
  (SELECT COUNT(*) FROM app_party.loyalty_card WHERE status = 'A') AS loyalty_active_members,
  (SELECT NVL(SUM(points_earned), 0) FROM app_party.loyalty_operation WHERE TRUNC(operation_date) = TRUNC(SYSDATE)) AS points_earned_today,
  (SELECT NVL(SUM(points_used), 0) FROM app_party.loyalty_operation WHERE TRUNC(operation_date) = TRUNC(SYSDATE) AND sign = '-') AS points_used_today,

  -- ALERTES OUVERTES
  (SELECT COUNT(*) FROM app_sys.alert_instance WHERE status = 'OPEN') AS alerts_open,
  (SELECT COUNT(*) FROM app_sys.alert_instance WHERE status = 'OPEN' AND severity IN ('HIGH','CRITICAL')) AS alerts_critical,

  -- INTERFACES (santé)
  (SELECT COUNT(*) FROM app_sys.interface_log WHERE created_at > SYSDATE - 1/24 AND status IN ('ERROR','TIMEOUT','SERVER_ERROR')) AS api_errors_24h,

  -- PROMO ACTIVES
  (SELECT COUNT(*) FROM app_product.promo_header WHERE status = 'A' AND SYSDATE BETWEEN start_date AND end_date) AS active_promos
FROM DUAL;

PROMPT
PROMPT [5] Vue : v_top_kpi_dashboard — Top KPIs pour executive
CREATE OR REPLACE VIEW v_top_kpi_dashboard AS
SELECT
  'CA jour'            AS label, 'XOF' AS unit, v.revenue_today AS valeur, 200000 AS cible
  FROM v_dashboard_executive v
UNION ALL SELECT 'Tickets jour',     'COUNT', v.tickets_today,        50
  FROM v_dashboard_executive v
UNION ALL SELECT 'Panier moyen jour', 'XOF',   v.avg_ticket_today,     8000
  FROM v_dashboard_executive v
UNION ALL SELECT 'CA MTD',           'XOF',   v.revenue_mtd,           5000000
  FROM v_dashboard_executive v
UNION ALL SELECT 'Encours total',     'XOF',   v.balance_total,         NULL
  FROM v_dashboard_executive v
UNION ALL SELECT 'Encours échu',     'XOF',   v.balance_overdue,       NULL
  FROM v_dashboard_executive v
UNION ALL SELECT 'Ruptures stock',    'COUNT', v.ruptures,              0
  FROM v_dashboard_executive v
UNION ALL SELECT 'Lots < 30j',      'COUNT', v.lots_expire_soon,      0
  FROM v_dashboard_executive v
UNION ALL SELECT 'Alertes critiques', 'COUNT', v.alerts_critical,      0
  FROM v_dashboard_executive v;

WHENEVER SQLERROR EXIT FAILURE

PROMPT
PROMPT ═══ Validation ═══
SELECT mview_name, NULL AS json FROM user_mviews WHERE mview_name = 'DUMMY'
UNION ALL
SELECT view_name AS mview_name, 'view' FROM user_views
 WHERE view_name LIKE 'DV\_%' ESCAPE '\' OR view_name LIKE 'V\_%' ESCAPE '\'
   AND view_name NOT LIKE 'DV\_%' ESCAPE '\';

PROMPT Duality Views créées :
SELECT view_name FROM user_views WHERE view_name LIKE 'DV\_%' ESCAPE '\' ORDER BY view_name;

PROMPT Vues classiques :
SELECT view_name FROM user_views
 WHERE view_name IN ('V_DASHBOARD_EXECUTIVE', 'V_TOP_KPI_DASHBOARD')
 ORDER BY view_name;

PROMPT
PROMPT Tests :
PROMPT dv_invoice (1 résultat)
SELECT JSON_SERIALIZE(data PRETTY)
  FROM dv_invoice
 FETCH FIRST 1 ROW ONLY;

PROMPT v_dashboard_executive
COLUMN report_date        FORMAT A12
COLUMN revenue_today      FORMAT '999,999'
COLUMN tickets_today      FORMAT '999'
COLUMN balance_total      FORMAT '999,999,999'
SELECT tickets_today, revenue_today, avg_ticket_today, invoices_open,
       balance_total, ruptures, alerts_critical
  FROM v_dashboard_executive;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ DV_INVOICE / DV_PAYMENT / DASHBOARD INSTALLÉS
PROMPT ══════════════════════════════════════════════════════════
EXIT;
