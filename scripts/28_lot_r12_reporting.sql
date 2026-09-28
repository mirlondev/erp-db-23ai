-- ============================================================
-- PATCH script 28 : suppression ix_kpi_snap_achieved (ORA-54034)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET SQLBLANKLINES ON

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT Patch : le CREATE TABLE a reussi jusqu'a l'index fautif
PROMPT On supprime la tentative d'index sur colonne virtuelle
PROMPT et on continue le script a partir de sales_target

PROMPT
PROMPT [3/5] sales_target
CREATE TABLE sales_target (
  target_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  target_year          NUMBER(4)     NOT NULL,
  target_month         NUMBER(2),
  entity_type          VARCHAR2(30)  DEFAULT 'GLOBAL',
  entity_code          VARCHAR2(30)  DEFAULT 'ALL',
  target_amount        NUMBER(16,4)  NOT NULL,
  target_margin        NUMBER(16,4),
  target_tickets       NUMBER(8),
  target_new_customers NUMBER(6),
  notes                VARCHAR2(500),
  is_active            BOOLEAN       DEFAULT TRUE,
  created_by           VARCHAR2(20),
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by           VARCHAR2(20),
  updated_at           TIMESTAMP,
  CONSTRAINT pk_sales_target        PRIMARY KEY (target_id),
  CONSTRAINT uk_sales_target        UNIQUE (target_year, target_month, entity_type, entity_code),
  CONSTRAINT ck_sales_target_year   CHECK (target_year BETWEEN 2020 AND 2099),
  CONSTRAINT ck_sales_target_month  CHECK (target_month IS NULL OR target_month BETWEEN 1 AND 12),
  CONSTRAINT ck_sales_target_amount CHECK (target_amount >= 0)
);

CREATE INDEX ix_sales_target_year ON sales_target(target_year, target_month);

PROMPT
PROMPT [4/5] report_definition
CREATE TABLE report_definition (
  report_code        VARCHAR2(30)  NOT NULL,
  report_name        VARCHAR2(120) NOT NULL,
  category           VARCHAR2(30),
  description        VARCHAR2(1000),
  sql_query          CLOB,
  parameters_schema  JSON,
  default_format     VARCHAR2(10)  DEFAULT 'PDF',
  is_scheduled       BOOLEAN       DEFAULT FALSE,
  schedule_cron      VARCHAR2(100),
  allowed_roles      VARCHAR2(500),
  is_active          BOOLEAN       DEFAULT TRUE,
  created_by         VARCHAR2(20),
  created_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by         VARCHAR2(20),
  updated_at         TIMESTAMP,
  CONSTRAINT pk_report_definition  PRIMARY KEY (report_code)
);

PROMPT
PROMPT [5/5] report_execution
CREATE TABLE report_execution (
  execution_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  report_code        VARCHAR2(30)  NOT NULL,
  parameters_json    JSON,
  output_format      VARCHAR2(10)  DEFAULT 'PDF',
  output_path        VARCHAR2(500),
  row_count          NUMBER(10),
  size_bytes         NUMBER(12),
  duration_ms        NUMBER(10),
  status             VARCHAR2(20)  DEFAULT 'RUNNING',
  started_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  completed_at       TIMESTAMP,
  executed_by        VARCHAR2(20),
  ip_address         VARCHAR2(45),
  error_message      VARCHAR2(2000),
  CONSTRAINT pk_report_execution    PRIMARY KEY (execution_id),
  CONSTRAINT fk_report_exec_def     FOREIGN KEY (report_code)
    REFERENCES report_definition(report_code),
  CONSTRAINT ck_report_exec_status  CHECK (status IN ('RUNNING','SUCCESS','FAILED','CANCELLED')),
  CONSTRAINT ck_report_exec_format  CHECK (output_format IN ('PDF','CSV','XLSX','HTML','JSON','TXT'))
);

CREATE INDEX ix_report_exec_code   ON report_execution(report_code, started_at DESC);
CREATE INDEX ix_report_exec_status ON report_execution(status, started_at DESC);
CREATE INDEX ix_report_exec_user   ON report_execution(executed_by, started_at DESC);

PROMPT
PROMPT [MV1] mv_hourly_sales
CREATE MATERIALIZED VIEW mv_hourly_sales
  TABLESPACE USERS
  ROW STORE COMPRESS ADVANCED
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS
SELECT TRUNC(t.ticket_date, 'HH24') AS sale_hour,
       t.terminal_id,
       COUNT(*)                      AS ticket_count,
       SUM(NVL(t.total_ht, 0))       AS total_ht,
       SUM(NVL(t.total_ttc, 0))      AS total_ttc,
       SUM(NVL(t.total_ttc, 0) - NVL(t.total_ht, 0)) AS total_tax,
       COUNT(DISTINCT t.customer_code) AS unique_customers
  FROM app_sales.ticket t
 WHERE t.status = 'V'
 GROUP BY TRUNC(t.ticket_date, 'HH24'), t.terminal_id;

CREATE INDEX ix_mv_hourly_sales ON mv_hourly_sales(sale_hour, terminal_id);

PROMPT
PROMPT [MV2] mv_monthly_top_products
CREATE MATERIALIZED VIEW mv_monthly_top_products
  TABLESPACE USERS
  ROW STORE COMPRESS ADVANCED
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS
SELECT TRUNC(t.ticket_date, 'MM') AS sale_month,
       l.product_code,
       MAX(p.product_name)        AS product_name,
       SUM(l.quantity)            AS total_qty,
       SUM(l.quantity * l.unit_price) AS total_amount,
       COUNT(DISTINCT t.ticket_no) AS ticket_count,
       COUNT(DISTINCT t.customer_code) AS unique_buyers
  FROM app_sales.ticket_line l
  JOIN app_sales.ticket t
    ON t.terminal_id = l.terminal_id AND t.ticket_no = l.ticket_no
  LEFT JOIN app_product.product p ON p.product_code = l.product_code
 WHERE t.status = 'V'
 GROUP BY TRUNC(t.ticket_date, 'MM'), l.product_code;

CREATE INDEX ix_mv_monthly_top      ON mv_monthly_top_products(sale_month, total_amount DESC);
CREATE INDEX ix_mv_monthly_top_prod ON mv_monthly_top_products(product_code, sale_month DESC);

PROMPT
PROMPT [MV3] mv_customer_performance
CREATE MATERIALIZED VIEW mv_customer_performance
  TABLESPACE USERS
  ROW STORE COMPRESS ADVANCED
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS
SELECT t.customer_code,
       MAX(t.customer_name)        AS customer_name,
       COUNT(*)                    AS ticket_count,
       MIN(t.ticket_date)          AS first_purchase,
       MAX(t.ticket_date)          AS last_purchase,
       SUM(NVL(t.total_ttc, 0))    AS total_revenue,
       AVG(NVL(t.total_ttc, 0))    AS avg_ticket,
       COUNT(DISTINCT TRUNC(t.ticket_date, 'MM')) AS active_months,
       MAX(t.loyalty_base_amount)  AS last_loyalty_base
  FROM app_sales.ticket t
 WHERE t.status = 'V'
 GROUP BY t.customer_code;

CREATE INDEX ix_mv_cust_perf    ON mv_customer_performance(customer_code);
CREATE INDEX ix_mv_cust_revenue ON mv_customer_performance(total_revenue DESC);
CREATE INDEX ix_mv_cust_recency ON mv_customer_performance(last_purchase DESC);

PROMPT
PROMPT [V1] v_kpi_today
CREATE OR REPLACE VIEW v_kpi_today AS
SELECT TRUNC(SYSDATE)                             AS report_date,
       COUNT(*)                                    AS tickets_count,
       SUM(NVL(total_ttc, 0))                      AS total_revenue,
       SUM(NVL(total_ht, 0))                       AS total_ht,
       SUM(NVL(total_ttc, 0) - NVL(total_ht, 0))   AS total_tax,
       AVG(NVL(total_ttc, 0))                      AS avg_ticket,
       COUNT(DISTINCT customer_code)               AS unique_customers,
       COUNT(DISTINCT terminal_id)                 AS active_terminals
  FROM app_sales.ticket
 WHERE TRUNC(ticket_date) = TRUNC(SYSDATE)
   AND status = 'V';

PROMPT
PROMPT [V2] v_critical_stock
CREATE OR REPLACE VIEW v_critical_stock AS
SELECT s.warehouse_code,
       s.product_code,
       p.product_name,
       s.stock_qty,
       p.min_stock_qty,
       p.safety_stock_qty,
       p.max_stock_qty,
       CASE
         WHEN s.stock_qty <= 0 THEN 'RUPTURE'
         WHEN s.stock_qty <= NVL(p.safety_stock_qty, 0) THEN 'CRITIQUE'
         WHEN s.stock_qty <= NVL(p.min_stock_qty, 0) THEN 'ALERTE'
         ELSE 'OK'
       END AS stock_status,
       GREATEST(0, NVL(p.min_stock_qty, 0) - s.stock_qty) AS qty_to_reorder
  FROM app_inv.inv_stock s
  JOIN app_product.product p ON p.product_code = s.product_code
 WHERE s.stock_qty <= NVL(p.min_stock_qty, 0) * 1.2;

PROMPT
PROMPT [V3] v_customer_balance
CREATE OR REPLACE VIEW v_customer_balance AS
SELECT p.party_code,
       p.party_name,
       p.phone,
       p.email,
       p.credit_limit,
       NVL(inv.outstanding, 0)                     AS outstanding,
       NVL(tk.total_purchases, 0)                  AS total_purchases,
       CASE
         WHEN p.credit_limit > 0 THEN
           ROUND(NVL(inv.outstanding, 0) * 100 / p.credit_limit, 2)
         ELSE 0
       END AS utilization_pct,
       CASE
         WHEN p.credit_limit > 0 AND NVL(inv.outstanding, 0) > p.credit_limit THEN 'OVER_LIMIT'
         WHEN p.credit_limit > 0 AND NVL(inv.outstanding, 0) > p.credit_limit * 0.8 THEN 'WARNING'
         ELSE 'OK'
       END AS credit_status
  FROM app_party.party p
  LEFT JOIN (SELECT party_code, SUM(balance) AS outstanding
               FROM app_ar.invoice
              WHERE status IN ('VALID','PARTIAL','OVERDUE')
              GROUP BY party_code) inv ON inv.party_code = p.party_code
  LEFT JOIN (SELECT customer_code, SUM(total_ttc) AS total_purchases
               FROM app_sales.ticket
              WHERE status = 'V'
              GROUP BY customer_code) tk ON tk.customer_code = p.party_code
 WHERE p.status = 'ACTIVE';

PROMPT
PROMPT Collecte stats
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS('APP_API', cascade => TRUE);
END;
/

PROMPT
PROMPT Validation - Tables
SELECT table_name, num_rows FROM user_tables
 WHERE table_name IN ('KPI_DEFINITION','KPI_DAILY_SNAPSHOT','SALES_TARGET',
                      'REPORT_DEFINITION','REPORT_EXECUTION')
 ORDER BY table_name;

PROMPT
PROMPT Validation - MV
SELECT mview_name, refresh_mode, staleness FROM user_mviews
 WHERE mview_name LIKE 'MV\_%' ESCAPE '\'
 ORDER BY mview_name;

PROMPT
PROMPT Validation - Vues
SELECT view_name FROM user_views
 WHERE view_name LIKE 'V\_%' ESCAPE '\'
 ORDER BY view_name;

PROMPT
PROMPT Validation - Objets invalides
SELECT object_name, object_type, status FROM user_objects WHERE status = 'INVALID';

PROMPT ==============================================================
PROMPT   LOT R12 TERMINE
PROMPT ==============================================================
EXIT;