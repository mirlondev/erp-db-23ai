-- ============================================================
-- SCRIPT 34 : Vues JSON + Duality Views + Dashboard (FINAL)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
SET SQLBLANKLINES ON

CONNECT system/oracle@localhost:1521/FREEPDB1

-- Privileges
GRANT SELECT ON app_ar.invoice          TO app_api;
GRANT SELECT ON app_ar.invoice_line     TO app_api;
GRANT SELECT ON app_ar.payment          TO app_api;
GRANT SELECT ON app_ar.credit_note      TO app_api;
GRANT SELECT ON app_ar.customer_credit  TO app_api;
GRANT SELECT ON app_inv.inv_stock       TO app_api;
GRANT SELECT ON app_inv.inv_product_lot TO app_api;
GRANT SELECT ON app_party.loyalty_card  TO app_api;
GRANT SELECT ON app_party.loyalty_operation TO app_api;
GRANT SELECT ON app_product.promo_header TO app_api;
GRANT SELECT ON app_sys.alert_instance  TO app_api;
GRANT SELECT ON app_sys.interface_log   TO app_api;

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

-- Synonymes pour Duality View simple
CREATE OR REPLACE SYNONYM payment_hdr FOR app_ar.payment;

PROMPT ==============================================================
PROMPT   VUES JSON + DUALITY VIEW + DASHBOARD
PROMPT ==============================================================

WHENEVER SQLERROR CONTINUE

-- ============================================================
-- [1] v_invoice_json - Vue JSON classique (relation maitre-detail)
-- Pattern identique a v_ticket_json (12_app_api.sql) qui fonctionne
-- ============================================================
PROMPT
PROMPT [1] Vue JSON : v_invoice_json
CREATE OR REPLACE VIEW v_invoice_json AS
SELECT JSON_OBJECT(
         '_id'         VALUE i.invoice_id,
         'number'      VALUE i.invoice_number,
         'date'        VALUE i.invoice_date,
         'dueDate'     VALUE i.due_date,
         'company'     VALUE i.company_code,
         'partyCode'   VALUE i.party_code,
         'partyName'   VALUE i.party_name,
         'currency'    VALUE i.currency_code,
         'totalHT'     VALUE i.total_ht,
         'totalTax'    VALUE i.total_tax,
         'totalTTC'    VALUE i.total_ttc,
         'totalPaid'   VALUE i.total_paid,
         'balance'     VALUE i.balance,
         'status'      VALUE i.status,
         'lines'       VALUE (
           SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                      'lineNo'      VALUE il.line_no,
                      'product'     VALUE il.product_code,
                      'description' VALUE il.description,
                      'quantity'    VALUE il.quantity,
                      'unitPrice'   VALUE il.unit_price,
                      'amount'      VALUE il.amount,
                      'taxRate'     VALUE il.tax_rate,
                      'amountHT'    VALUE il.amount_ht,
                      'amountTTC'   VALUE il.amount_ttc
                    )
                  )
             FROM app_ar.invoice_line il
            WHERE il.invoice_id = i.invoice_id
         )
       ) AS data
  FROM app_ar.invoice i;

-- ============================================================
-- [2] dv_payment - Duality View (fonctionne deja)
-- ============================================================
PROMPT
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
  FROM payment_hdr p;

-- ============================================================
-- [3] v_customer_credit_json (PK composite)
-- ============================================================
PROMPT
PROMPT [3] Vue JSON : v_customer_credit_json
CREATE OR REPLACE VIEW v_customer_credit_json AS
SELECT JSON_OBJECT(
         '_id'            VALUE cc.party_code || '-' || cc.company_code,
         'partyCode'      VALUE cc.party_code,
         'companyCode'    VALUE cc.company_code,
         'creditLimit'    VALUE cc.credit_limit,
         'creditDays'     VALUE cc.credit_days,
         'currentBalance' VALUE cc.current_balance,
         'overdueBalance' VALUE cc.overdue_balance,
         'lastInvoice'    VALUE cc.last_invoice_date,
         'lastPayment'    VALUE cc.last_payment_date,
         'blocked'        VALUE cc.is_blocked,
         'blockedReason'  VALUE cc.blocked_reason
       ) AS data
  FROM app_ar.customer_credit cc;

-- ============================================================
-- [4] v_dashboard_executive
-- ============================================================
PROMPT
PROMPT [4] Vue : v_dashboard_executive
CREATE OR REPLACE VIEW v_dashboard_executive AS
WITH
v_sales_today AS (
  SELECT COUNT(*)                       AS tickets_today,
         NVL(SUM(total_ttc), 0)         AS revenue_today,
         NVL(AVG(total_ttc), 0)         AS avg_ticket_today,
         COUNT(DISTINCT customer_code)  AS unique_customers_today
    FROM app_sales.ticket
   WHERE TRUNC(ticket_date) = TRUNC(SYSDATE)
     AND status = 'V'
),
v_sales_mtd AS (
  SELECT COUNT(*)                       AS tickets_mtd,
         NVL(SUM(total_ttc), 0)         AS revenue_mtd
    FROM app_sales.ticket
   WHERE TRUNC(ticket_date, 'MM') = TRUNC(SYSDATE, 'MM')
     AND status = 'V'
),
v_invoice AS (
  SELECT COUNT(*)                                              AS invoices_open,
         NVL(SUM(balance), 0)                                  AS balance_total,
         NVL(SUM(CASE WHEN status = 'OVERDUE'
                      THEN balance ELSE 0 END), 0)             AS balance_overdue
    FROM app_ar.invoice
   WHERE status IN ('VALID','PARTIAL','OVERDUE')
),
v_stock AS (
  SELECT
    (SELECT COUNT(*) FROM app_inv.inv_stock WHERE stock_qty <= 0) AS ruptures,
    (SELECT COUNT(*) FROM app_inv.inv_product_lot
      WHERE expiry_date BETWEEN SYSDATE AND SYSDATE+30)           AS lots_expire_soon,
    (SELECT COUNT(*) FROM app_inv.inv_product_lot
      WHERE expiry_date < SYSDATE)                                AS lots_expired
    FROM DUAL
),
v_loyalty AS (
  SELECT
    (SELECT COUNT(*) FROM app_party.loyalty_card WHERE status = 'A') AS loyalty_members,
    (SELECT NVL(SUM(points), 0) FROM app_party.loyalty_operation
      WHERE TRUNC(operation_date) = TRUNC(SYSDATE))                AS points_today
    FROM DUAL
),
v_alerts AS (
  SELECT COUNT(*)                                                     AS alerts_open,
         COUNT(CASE WHEN severity IN ('HIGH','CRITICAL') THEN 1 END) AS alerts_critical
    FROM app_sys.alert_instance
   WHERE status = 'OPEN'
),
v_interfaces AS (
  SELECT COUNT(*) AS api_errors_24h
    FROM app_sys.interface_log
   WHERE created_at > SYSDATE - 1/24
     AND status IN ('ERROR','TIMEOUT','SERVER_ERROR')
)
SELECT
  TRUNC(SYSDATE) AS report_date,
  s.tickets_today, s.revenue_today, s.avg_ticket_today, s.unique_customers_today,
  m.tickets_mtd, m.revenue_mtd,
  i.invoices_open, i.balance_total, i.balance_overdue,
  st.ruptures, st.lots_expire_soon, st.lots_expired,
  l.loyalty_members, l.points_today,
  a.alerts_open, a.alerts_critical,
  n.api_errors_24h
FROM v_sales_today s, v_sales_mtd m, v_invoice i,
     v_stock st, v_loyalty l, v_alerts a, v_interfaces n;

-- ============================================================
-- [5] v_top_kpi_dashboard
-- ============================================================
PROMPT
PROMPT [5] Vue : v_top_kpi_dashboard
CREATE OR REPLACE VIEW v_top_kpi_dashboard AS
SELECT 'CA jour'           AS label, 'XOF'   AS unit, revenue_today   AS valeur, 200000 AS cible FROM v_dashboard_executive
UNION ALL SELECT 'Tickets jour',      'COUNT', tickets_today,                  50              FROM v_dashboard_executive
UNION ALL SELECT 'Panier moyen',      'XOF',   avg_ticket_today,               8000            FROM v_dashboard_executive
UNION ALL SELECT 'CA MTD',            'XOF',   revenue_mtd,                    5000000         FROM v_dashboard_executive
UNION ALL SELECT 'Encours total',     'XOF',   balance_total,                  NULL            FROM v_dashboard_executive
UNION ALL SELECT 'Encours echu',      'XOF',   balance_overdue,                NULL            FROM v_dashboard_executive
UNION ALL SELECT 'Ruptures stock',    'COUNT', ruptures,                       0               FROM v_dashboard_executive
UNION ALL SELECT 'Lots < 30j',        'COUNT', lots_expire_soon,               0               FROM v_dashboard_executive
UNION ALL SELECT 'Alertes critiques', 'COUNT', alerts_critical,                0               FROM v_dashboard_executive;

WHENEVER SQLERROR EXIT FAILURE

PROMPT
PROMPT === Validation ===
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('DV_PAYMENT',
                       'V_INVOICE_JSON',
                       'V_CUSTOMER_CREDIT_JSON',
                       'V_DASHBOARD_EXECUTIVE',
                       'V_TOP_KPI_DASHBOARD')
 ORDER BY object_type, object_name;

PROMPT
PROMPT Test v_dashboard_executive
SELECT tickets_today, revenue_today, avg_ticket_today,
       invoices_open, balance_total, ruptures, alerts_critical
  FROM v_dashboard_executive;

PROMPT
PROMPT Test v_invoice_json (premiere facture)
SELECT JSON_SERIALIZE(data PRETTY)
  FROM v_invoice_json
 FETCH FIRST 1 ROW ONLY;

PROMPT
PROMPT Test dv_payment
SELECT JSON_VALUE(data, '$._id')    AS id,
       JSON_VALUE(data, '$.number') AS num,
       JSON_VALUE(data, '$.amount') AS amount
  FROM dv_payment
 FETCH FIRST 3 ROWS ONLY;

PROMPT ==============================================================
PROMPT   VUES JSON + DV_PAYMENT + DASHBOARD INSTALLES
PROMPT ==============================================================
EXIT;