-- ============================================================
-- SCRIPT 15 : Vues matérialisées
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DES VUES MATÉRIALISÉES
PROMPT ═══════════════════════════════════════════════════════

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT [1] MV : mv_stock_summary
CREATE MATERIALIZED VIEW mv_stock_summary
  TABLESPACE USERS
  ROW STORE COMPRESS ADVANCED
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS
SELECT s.warehouse_code,
       s.product_code,
       p.product_name,
       p.standard_price,
       s.stock_qty,
       s.stock_qty * NVL(p.average_cost, 0) AS stock_value,
       s.last_in_at,
       s.last_out_at
  FROM app_inv.inv_stock s
  JOIN app_product.product p ON p.product_code = s.product_code;

CREATE INDEX ix_mv_stock_summary_wh ON mv_stock_summary(warehouse_code);
CREATE INDEX ix_mv_stock_summary_pr ON mv_stock_summary(product_code);

PROMPT ✅ mv_stock_summary créée

PROMPT [2] MV : mv_daily_sales
CREATE MATERIALIZED VIEW mv_daily_sales
  TABLESPACE USERS
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS
SELECT TRUNC(t.ticket_date) AS sale_date,
       t.terminal_id,
       COUNT(*)            AS nb_tickets,
       SUM(t.total_ht)     AS total_ht,
       SUM(t.total_ttc)    AS total_ttc,
       SUM(t.total_ttc - t.total_ht) AS total_tax
  FROM app_sales.ticket t
 WHERE t.status = 'V'
 GROUP BY TRUNC(t.ticket_date), t.terminal_id;

CREATE INDEX ix_mv_daily_sales_date ON mv_daily_sales(sale_date);

PROMPT ✅ mv_daily_sales créée

PROMPT [3] MV : mv_product_sales
CREATE MATERIALIZED VIEW mv_product_sales
  TABLESPACE USERS
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS
SELECT l.product_code,
       p.product_name,
       COUNT(DISTINCT l.ticket_no) AS nb_tickets,
       SUM(l.quantity)             AS total_qty,
       SUM(l.quantity * l.unit_price) AS total_amount
  FROM app_sales.ticket_line l
  JOIN app_sales.ticket t ON t.terminal_id = l.terminal_id AND t.ticket_no = l.ticket_no
  JOIN app_product.product p ON p.product_code = l.product_code
 WHERE t.status = 'V'
 GROUP BY l.product_code, p.product_name;

CREATE INDEX ix_mv_product_sales_code ON mv_product_sales(product_code);

PROMPT ✅ mv_product_sales créée

PROMPT
PROMPT [Validation]
SELECT mview_name, refresh_mode, refresh_method, staleness
  FROM user_mviews
 ORDER BY mview_name;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ VUES MATÉRIALISÉES TERMINÉES
PROMPT ═══════════════════════════════════════════════════════