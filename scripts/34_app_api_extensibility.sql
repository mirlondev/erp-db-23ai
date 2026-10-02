-- ============================================================
-- SCRIPT 34 : Vues JSON + Duality Views + Dashboard (CORRIGÉ)
-- ============================================================
-- Corrections vs version précédente :
--   * dv_ticket utilise les VRAIES colonnes de ticket/ticket_line
--     (USER_CODE au lieu de CASHIER_CODE, pas de TOTAL_TAX)
--   * dv_payment est bien créée (elle avait été remplacée par erreur)
--   * GRANTs individuels (pas de boucle PL/SQL avec "owner" réservé)
--   * Tests de validation complets
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
SET SQLBLANKLINES ON

-- ============================================================
-- PHASE 1 : Privilèges cross-schéma (en SYSTEM)
-- ============================================================
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

PROMPT ==============================================================
PROMPT   PHASE 1 : Attribution des privilèges
PROMPT ==============================================================

-- app_ar → app_api
GRANT SELECT ON app_ar.invoice          TO app_api;
GRANT SELECT ON app_ar.invoice_line     TO app_api;
GRANT SELECT ON app_ar.payment          TO app_api;
GRANT SELECT ON app_ar.credit_note      TO app_api;
GRANT SELECT ON app_ar.customer_credit  TO app_api;

-- app_inv → app_api
GRANT SELECT ON app_inv.inv_stock       TO app_api;
GRANT SELECT ON app_inv.inv_product_lot TO app_api;

-- app_party → app_api
GRANT SELECT ON app_party.loyalty_card      TO app_api;
GRANT SELECT ON app_party.loyalty_operation TO app_api;

-- app_product → app_api
GRANT SELECT ON app_product.promo_header TO app_api;

-- app_sys → app_api
GRANT SELECT ON app_sys.alert_instance TO app_api;
GRANT SELECT ON app_sys.interface_log  TO app_api;

-- app_sales → app_api (pour dv_ticket)
GRANT SELECT ON app_sales.ticket      TO app_api;
GRANT SELECT ON app_sales.ticket_line TO app_api;

PROMPT Privilèges accordés.

-- ============================================================
-- PHASE 2 : Création des objets dans app_api
-- ============================================================
CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ==============================================================
PROMPT   PHASE 2 : Vues JSON + Duality Views + Dashboard
PROMPT ==============================================================

-- Synonymes (nécessaires pour les Duality Views)
CREATE OR REPLACE SYNONYM payment_hdr FOR app_ar.payment;
CREATE OR REPLACE SYNONYM ticket      FOR app_sales.ticket;
CREATE OR REPLACE SYNONYM ticket_line FOR app_sales.ticket_line;

PROMPT Synonymes créés.

WHENEVER SQLERROR EXIT SQL.SQLCODE

-- ============================================================
-- [1] v_invoice_json — Vue JSON facture + lignes
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
-- [2a] dv_payment — Duality View paiements
-- Colonnes réelles confirmées : PAYMENT_ID, PAYMENT_NUMBER,
-- PAYMENT_DATE, COMPANY_CODE, PARTY_CODE, PARTY_NAME,
-- PAYMENT_METHOD, REFERENCE, BANK_CODE, CURRENCY_CODE,
-- EXCHANGE_RATE, AMOUNT, AMOUNT_ALLOCATED, STATUS, MEMO,
-- CREATED_BY, CREATED_AT
-- ============================================================
PROMPT
PROMPT [2a] Duality View : dv_payment
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW dv_payment AS
  SELECT JSON {
    '_id'        : p.payment_id,
    'number'     : p.payment_number,
    'date'       : p.payment_date,
    'company'    : p.company_code,
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
-- [2b] dv_ticket — Duality View tickets
-- Colonnes TICKET confirmées :
--   TERMINAL_ID, TICKET_NO, TICKET_DATE, SESSION_NO, INVOICE_NO,
--   CUSTOMER_CODE, CUSTOMER_NAME, USER_CODE, TOTAL_HT, TOTAL_TTC,
--   CASH_RECEIVED, OTHER_RECEIVED, CHANGE_GIVEN, STATUS
-- Colonnes TICKET_LINE confirmées :
--   TERMINAL_ID, TICKET_NO, LINE_NO, PRODUCT_CODE, DESCRIPTION,
--   QUANTITY, UNIT_PRICE, UNIT_PRICE_HT, DISCOUNT_RATE, TAX_RATE
-- ============================================================
-- ============================================================
-- [2b] dv_ticket — Duality View tickets (PK composite)
-- La table TICKET a une PK composite : (TERMINAL_ID, TICKET_NO)
-- → Le bloc '_id' doit inclure TOUS les composants de la PK.
-- ============================================================
PROMPT
PROMPT [2b] Duality View : dv_ticket
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW dv_ticket AS
  SELECT JSON {
    '_id' : {
      'terminal' : t.terminal_id,
      'ticketNo' : t.ticket_no
    },
    'session'      : t.session_no,
    'date'         : t.ticket_date,
    'customer'     : t.customer_code,
    'customerName' : t.customer_name,
    'cashier'      : t.user_code,
    'totalHT'      : t.total_ht,
    'totalTTC'     : t.total_ttc,
    'cashReceived' : t.cash_received,
    'changeGiven'  : t.change_given,
    'status'       : t.status,
    'lines'        : [
      SELECT JSON {
        'lineNo'      : l.line_no,
        'product'     : l.product_code,
        'description' : l.description,
        'quantity'    : l.quantity,
        'unitPrice'   : l.unit_price,
        'unitPriceHT' : l.unit_price_ht,
        'discount'    : l.discount_rate,
        'taxRate'     : l.tax_rate
      }
      FROM ticket_line l
      WHERE l.terminal_id = t.terminal_id
        AND l.ticket_no   = t.ticket_no
    ]
  }
  FROM ticket t;

-- ============================================================
-- [3] v_customer_credit_json — Vue JSON encours client
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
-- [4] v_dashboard_executive — Tableau de bord KPI
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
-- [5] v_top_kpi_dashboard — KPI synthétiques
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

-- ============================================================
-- VALIDATION
-- ============================================================
PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   Validation — Objets créés
PROMPT ══════════════════════════════════════════════════════════
SELECT object_name, object_type, status
  FROM user_objects
 WHERE object_name IN ('DV_PAYMENT', 'DV_TICKET',
                       'V_INVOICE_JSON', 'V_CUSTOMER_CREDIT_JSON',
                       'V_DASHBOARD_EXECUTIVE', 'V_TOP_KPI_DASHBOARD')
 ORDER BY object_type, object_name;

PROMPT
PROMPT Test v_dashboard_executive
SELECT tickets_today, revenue_today, avg_ticket_today,
       invoices_open, balance_total, ruptures, alerts_critical
  FROM v_dashboard_executive;

PROMPT
PROMPT Test v_invoice_json
SELECT JSON_SERIALIZE(data PRETTY)
  FROM v_invoice_json
 FETCH FIRST 1 ROW ONLY;

PROMPT
PROMPT Test dv_payment (3 premiers)
SELECT JSON_VALUE(data, '$._id')    AS id,
       JSON_VALUE(data, '$.number') AS num,
       JSON_VALUE(data, '$.amount') AS amount
  FROM dv_payment
 FETCH FIRST 3 ROWS ONLY;

PROMPT
PROMPT Test dv_ticket (3 premiers)
SELECT JSON_VALUE(data, '$._id')      AS id,
       JSON_VALUE(data, '$.terminal') AS terminal,
       JSON_VALUE(data, '$.totalTTC') AS total_ttc,
       JSON_VALUE(data, '$.cashier')  AS cashier
  FROM dv_ticket
 FETCH FIRST 3 ROWS ONLY;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SCRIPT 34 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
