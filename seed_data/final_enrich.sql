-- ============================================================
-- final_enrich.sql — Finalisation de l'enrichissement
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

PROMPT ═══════════════════════════════════════════════════════
PROMPT   FINALISATION
PROMPT ═══════════════════════════════════════════════════════

-- [1] Prix
PROMPT [1] Prix articles
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

INSERT INTO product_price (price_list_id, product_id, price, price_ht, updated_by)
SELECT pl.price_list_id, p.product_id, 25000, 21026.07, 'KAMAL'
  FROM prod_price_list pl, product p
 WHERE pl.price_list_code = '2' AND p.product_code = '31274'
   AND NOT EXISTS (SELECT 1 FROM product_price pp 
                    WHERE pp.product_id = p.product_id AND pp.price_list_id = pl.price_list_id);

INSERT INTO product_price (price_list_id, product_id, price, price_ht, updated_by)
SELECT pl.price_list_id, p.product_id, 2950, 2481.07, 'KAMAL'
  FROM prod_price_list pl, product p
 WHERE pl.price_list_code = '1' AND p.product_code = '19889'
   AND NOT EXISTS (SELECT 1 FROM product_price pp 
                    WHERE pp.product_id = p.product_id AND pp.price_list_id = pl.price_list_id);

COMMIT;

-- [2] Lignes manquantes
PROMPT [2] Lignes tickets manquantes
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011577, 1, 'MOBILE_A17', 'MOBILE SAMSUNG SM-A175F/DS BLACK',
       1, 'PCS', 240000, 228029, 18.9 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011577);

INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, description,
                         quantity, unit_code, unit_price, unit_price_ht, tax_rate)
SELECT 'FP1', 1011565, 1, '31274', 'TEFAL PRIMA FRYPAN WOK',
       1, 'PCS', 80000, 67283, 18.9 FROM DUAL
WHERE NOT EXISTS (SELECT 1 FROM ticket_line WHERE terminal_id='FP1' AND ticket_no=1011565);

COMMIT;

-- [3] Recréer dv_product sans filtre
PROMPT [3] Recréation dv_product
CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

BEGIN EXECUTE IMMEDIATE 'DROP VIEW dv_product'; EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW dv_product AS
  SELECT JSON {
    '_id'           : p.product_id,
    'productCode'   : p.product_code,
    'name'          : p.product_name,
    'shortName'     : p.short_name,
    'standardPrice' : p.standard_price,
    'barcode'       : p.barcode,
    'status'        : p.status,
    'stockManaged'  : p.is_stock_managed,
    'promoActive'   : p.is_promo,
    'categoryId'    : p.category_id,
    'subcategoryId' : p.subcategory_id,
    'brandId'       : p.brand_id
  }
  FROM app_product.product p;

-- [4] Validation finale
PROMPT
PROMPT [4] Validation finale
CONNECT system/oracle@localhost:1521/FREEPDB1

SELECT 'PRODUCT_PRICE'  AS tbl, COUNT(*) AS nb FROM app_product.product_price
UNION ALL SELECT 'TICKET_LINE',      COUNT(*) FROM app_sales.ticket_line
UNION ALL SELECT 'TICKET_PAYMENT',   COUNT(*) FROM app_sales.ticket_payment
UNION ALL SELECT 'TICKETS',          COUNT(*) FROM app_sales.ticket;

PROMPT
PROMPT [5] Test dv_product
CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

SELECT JSON_VALUE(data, '$.productCode') AS code,
       JSON_VALUE(data, '$.name')        AS name,
       JSON_VALUE(data, '$.standardPrice') AS prix
  FROM dv_product
 WHERE JSON_VALUE(data, '$.productCode') = '31274';

PROMPT
PROMPT [6] Test ticket complet
SELECT JSON_SERIALIZE(data PRETTY)
  FROM v_ticket_json
 WHERE JSON_VALUE(data, '$._id') = '1011577';

EXIT;