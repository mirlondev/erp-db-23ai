-- ============================================================
-- S05 : Seed app_inv — Stock SUPER SONIC
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   SEED app_inv
PROMPT ===============================================================

DELETE FROM inv_movement;
DELETE FROM inv_count_line;
DELETE FROM inv_count_header;
DELETE FROM inv_stock;
COMMIT;

PROMPT [1] Stocks initiaux (extraits du fichier réel W90)
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', '31274', 5, DATE '2016-02-06', NULL, DATE '2026-01-11');
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', '31275', 8, DATE '2016-02-06', NULL, DATE '2026-01-11');
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', '31276', 3, DATE '2016-02-06', NULL, DATE '2026-01-11');
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', '19889', 174, DATE '2026-04-17', DATE '2026-04-17', DATE '2026-01-11');
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', '19890', 96, DATE '2026-02-12', NULL, DATE '2026-01-11');
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', '19891', 80, DATE '2026-02-26', NULL, DATE '2026-01-11');
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', '19896', 180, DATE '2026-04-17', DATE '2026-04-17', DATE '2026-01-11');
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', '19900', 80, DATE '2026-02-12', NULL, DATE '2026-01-11');
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', 'MOBILE_A17', 50, SYSDATE, NULL, SYSDATE);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', 'SCREEN_GUARD_A17', 200, SYSDATE, NULL, SYSDATE);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', 'COVER_A17', 150, SYSDATE, NULL, SYSDATE);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_in_at, last_out_at, last_count_at)
VALUES ('W90', 'ADAPTER_USB_C', 100, SYSDATE, NULL, SYSDATE);

-- Stock secondaire PNR
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_count_at)
VALUES ('PNR', '31274', 20, SYSDATE);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_count_at)
VALUES ('PNR', '19889', 300, SYSDATE);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_count_at)
VALUES ('PNR', '19890', 200, SYSDATE);

-- Stock BZV
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_count_at)
VALUES ('BZV', '19889', 250, SYSDATE);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty, last_count_at)
VALUES ('BZV', '19890', 180, SYSDATE);

COMMIT;

PROMPT [2] Validation
SELECT warehouse_code, COUNT(*) AS nb_products, SUM(stock_qty) AS total_qty
  FROM inv_stock GROUP BY warehouse_code ORDER BY warehouse_code;

PROMPT ✅ S05 terminé
EXIT;