-- ============================================================
-- enrich_demo.sql — Enrichissement des données
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ENRICHISSEMENT DES DONNÉES SUPER SONIC
PROMPT ═══════════════════════════════════════════════════════

-- [1] Prix des articles Tefal
PROMPT
PROMPT [1] Prix articles Tefal
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

INSERT INTO product_price (price_list_id, product_id, price, price_ht, updated_by)
SELECT 2, product_id, 25000, 21026.07, 'KAMAL'
  FROM product WHERE product_code = '31274'
  AND NOT EXISTS (SELECT 1 FROM product_price pp WHERE pp.product_id = product.product_id AND pp.price_list_id = 2);

INSERT INTO product_price (price_list_id, product_id, price, price_ht, updated_by)
SELECT 2, product_id, 27500, 23128.68, 'KAMAL'
  FROM product WHERE product_code = '31275'
  AND NOT EXISTS (SELECT 1 FROM product_price pp WHERE pp.product_id = product.product_id AND pp.price_list_id = 2);

INSERT INTO product_price (price_list_id, product_id, price, price_ht, updated_by)
SELECT 2, product_id, 22000, 18502.94, 'KAMAL'
  FROM product WHERE product_code = '31276'
  AND NOT EXISTS (SELECT 1 FROM product_price pp WHERE pp.product_id = product.product_id AND pp.price_list_id = 2);

-- Prix pour articles Colgate
INSERT INTO product_price (price_list_id, product_id, price, price_ht, updated_by)
SELECT 1, product_id, 2950, 2481.07, 'KAMAL'
  FROM product WHERE product_code = '19889'
  AND NOT EXISTS (SELECT 1 FROM product_price pp WHERE pp.product_id = product.product_id AND pp.price_list_id = 1);

INSERT INTO product_price (price_list_id, product_id, price, price_ht, updated_by)
SELECT 1, product_id, 4500, 3784.69, 'KAMAL'
  FROM product WHERE product_code = '19890'
  AND NOT EXISTS (SELECT 1 FROM product_price pp WHERE pp.product_id = product.product_id AND pp.price_list_id = 1);

COMMIT;
SELECT 'PRIX AJOUTES' AS info, COUNT(*) AS nb FROM product_price;

-- [2] Lignes de tickets (pour les 9 tickets)
PROMPT
PROMPT [2] Lignes de tickets
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

-- Ticket 1011578 : 1 ligne
INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011578, 1, product_code, product_name, 1, 'PCS', 10000, 8411, 18.9
  FROM app_product.product WHERE product_code = '19889'
  AND NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011578);

-- Ticket 1011579 : 1 ligne
INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011579, 1, product_code, product_name, 1, 'PCS', 233000, 221378, 18.9
  FROM app_product.product WHERE product_code = '31275'
  AND NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011579);

-- Ticket 1011576
INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011576, 1, product_code, product_name, 1, 'PCS', 113000, 95038, 18.9
  FROM app_product.product WHERE product_code = '31276'
  AND NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011576);

-- Ticket 1011577
INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011577, 1, product_code, product_name, 1, 'PCS', 240000, 228029, 18.9
  FROM app_product.product WHERE product_code = '31274'
  AND NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011577);

-- Ticket 1011566
INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011566, 1, product_code, product_name, 1, 'PCS', 213750, 179773, 18.9
  FROM app_product.product WHERE product_code = '19890'
  AND NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011566);

-- Ticket 1011568
INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011568, 1, product_code, product_name, 1, 'PCS', 138500, 116484, 18.9
  FROM app_product.product WHERE product_code = '19891'
  AND NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011568);

-- Ticket 1011574
INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011574, 1, product_code, product_name, 1, 'PCS', 165500, 139193, 18.9
  FROM app_product.product WHERE product_code = '19896'
  AND NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011574);

-- Ticket 1011580
INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011580, 1, product_code, product_name, 1, 'PCS', 3000, 2523, 18.9
  FROM app_product.product WHERE product_code = '19900'
  AND NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011580);

-- Ticket 1011565
INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011565, 1, product_code, product_name, 1, 'PCS', 80000, 67283, 18.9
  FROM app_product.product WHERE product_code = '31274'
  AND NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011565);

COMMIT;
SELECT 'LIGNES' AS info, COUNT(*) AS nb FROM ticket_line;

-- [3] Paiements pour chaque ticket
PROMPT
PROMPT [3] Paiements
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

INSERT INTO ticket_payment (terminal_id, ticket_no, payment_method, payment_type, amount)
SELECT terminal_id, ticket_no, 'ESP', 'Espèces', total_ttc FROM ticket
 WHERE NOT EXISTS (SELECT 1 FROM ticket_payment WHERE terminal_id=ticket.terminal_id AND ticket_no=ticket.ticket_no);

COMMIT;
SELECT 'PAIEMENTS' AS info, COUNT(*) AS nb FROM ticket_payment;

-- [4] Rafraîchir les MV
PROMPT
PROMPT [4] Rafraîchissement des vues matérialisées
CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

BEGIN
  DBMS_MVIEW.REFRESH('MV_STOCK_SUMMARY', 'C');
  DBMS_MVIEW.REFRESH('MV_DAILY_SALES', 'C');
  DBMS_MVIEW.REFRESH('MV_PRODUCT_SALES', 'C');
END;
/

-- [5] Test complet
PROMPT
PROMPT [5] Test ticket complet
SELECT JSON_SERIALIZE(data PRETTY)
  FROM v_ticket_json
 WHERE JSON_VALUE(data, '$._id') = '1011578';

PROMPT
PROMPT [6] Test dv_product
SELECT JSON_SERIALIZE(data PRETTY)
  FROM dv_product
 WHERE JSON_VALUE(data, '$.productCode') = '31274';

EXIT;