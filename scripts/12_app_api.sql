-- ============================================================
-- SCRIPT 12 : Schéma app_api — VERSION FINALE QUI MARCHE
-- ============================================================
-- NOTE : Oracle 23ai/26ai Free ne supporte PAS les JSON Duality
-- Views sur les tables à PK COMPOSITE (ORA-40607).
-- Tables à PK composite : TICKET, TICKET_LINE, TICKET_PAYMENT, INV_STOCK.
-- → On utilise des VUES CLASSIQUES pour ces tables.
-- Tables à PK simple    : PRODUCT, PARTY.
-- → On utilise des DUALITY VIEWS pour ces tables.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT system/oracle@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   ATTRIBUTION DES PRIVILEGES A app_api
PROMPT ===============================================================

GRANT SELECT ON app_product.product           TO app_api;
GRANT SELECT ON app_product.product_price     TO app_api;
GRANT SELECT ON app_product.prod_category     TO app_api;
GRANT SELECT ON app_product.prod_subcategory  TO app_api;
GRANT SELECT ON app_product.prod_brand        TO app_api;
GRANT SELECT ON app_product.prod_nature       TO app_api;
GRANT SELECT ON app_party.party               TO app_api;
GRANT SELECT ON app_party.party_nature        TO app_api;
GRANT SELECT ON app_party.party_address       TO app_api;
GRANT SELECT ON app_party.party_bank          TO app_api;
GRANT SELECT ON app_sales.ticket              TO app_api;
GRANT SELECT ON app_sales.ticket_line         TO app_api;
GRANT SELECT ON app_sales.ticket_payment      TO app_api;
GRANT SELECT ON app_pos.pos_terminal          TO app_api;
GRANT SELECT ON app_pos.pos_session           TO app_api;
GRANT SELECT ON app_inv.inv_stock             TO app_api;
GRANT SELECT ON app_inv.inv_stock_alert       TO app_api;
GRANT SELECT ON app_gl.gl_entry               TO app_api;
GRANT SELECT ON app_gl.gl_entry_line          TO app_api;
GRANT SELECT ON app_gl.gl_account             TO app_api;
GRANT SELECT ON app_gl.gl_company             TO app_api;

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ===============================================================
PROMPT   NETTOYAGE
PROMPT ===============================================================
BEGIN
  FOR v IN (SELECT view_name FROM user_views 
             WHERE view_name LIKE 'DV\_%' ESCAPE '\'
                OR view_name LIKE 'V\_%' ESCAPE '\') LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP VIEW '||v.view_name;
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

PROMPT ===============================================================
PROMPT   VUES CLASSIQUES (PK simple OU composite)
PROMPT ===============================================================

PROMPT [1] v_product
CREATE OR REPLACE VIEW v_product AS
SELECT p.product_code, p.product_name, p.short_name,
       pc.category_name, ps.subcategory_name, pb.brand_name,
       p.standard_price, p.standard_price_ht, p.barcode, p.status,
       CASE WHEN p.is_stock_managed THEN 'YES' ELSE 'NO' END AS stock_managed,
       CASE WHEN p.is_promo         THEN 'YES' ELSE 'NO' END AS promo_active
  FROM app_product.product p
  JOIN app_product.prod_category    pc ON pc.category_id    = p.category_id
  JOIN app_product.prod_subcategory ps ON ps.subcategory_id = p.subcategory_id
  LEFT JOIN app_product.prod_brand  pb ON pb.brand_id       = p.brand_id
 WHERE p.status = 'ACTIVE';

PROMPT [2] v_customer
CREATE OR REPLACE VIEW v_customer AS
SELECT p.party_code, p.party_name, p.phone, p.email,
       p.address_1, p.city_code, p.credit_limit, p.status
  FROM app_party.party p
  JOIN app_party.party_nature pn ON pn.nature_id = p.nature_id
 WHERE pn.nature_type = 'CUSTOMER' AND p.status = 'ACTIVE';

PROMPT [3] v_supplier
CREATE OR REPLACE VIEW v_supplier AS
SELECT p.party_code, p.party_name, p.phone, p.email,
       p.address_1, p.status
  FROM app_party.party p
  JOIN app_party.party_nature pn ON pn.nature_id = p.nature_id
 WHERE pn.nature_type = 'SUPPLIER' AND p.status = 'ACTIVE';

PROMPT [4] v_ticket
CREATE OR REPLACE VIEW v_ticket AS
SELECT t.terminal_id, t.ticket_no, t.ticket_date,
       t.customer_code, t.customer_name,
       t.total_ttc, t.total_ht, t.status
  FROM app_sales.ticket t;

PROMPT [5] v_ticket_line
CREATE OR REPLACE VIEW v_ticket_line AS
SELECT l.terminal_id, l.ticket_no, l.line_no, l.product_code,
       p.product_name, l.description, l.quantity, l.unit_price,
       l.quantity * l.unit_price AS line_amount
  FROM app_sales.ticket_line l
  LEFT JOIN app_product.product p ON p.product_code = l.product_code;

PROMPT [6] v_stock
CREATE OR REPLACE VIEW v_stock AS
SELECT s.warehouse_code, s.product_code, p.product_name,
       s.stock_qty, s.reserved_qty, s.ordered_qty,
       s.last_in_at, s.last_out_at
  FROM app_inv.inv_stock s
  LEFT JOIN app_product.product p ON p.product_code = s.product_code;

PROMPT [7] v_party (vue unifiée)
CREATE OR REPLACE VIEW v_party AS
SELECT p.party_id, p.party_code, p.party_name,
       pn.nature_type, p.phone, p.email, p.status
  FROM app_party.party p
  JOIN app_party.party_nature pn ON pn.nature_id = p.nature_id
 WHERE p.status = 'ACTIVE';

PROMPT
PROMPT ===============================================================
PROMPT   JSON DUALITY VIEWS (uniquement PK simple)
PROMPT ===============================================================

WHENEVER SQLERROR CONTINUE

-- ============================================================
-- dv_product — PK simple (product_id)
-- ============================================================
PROMPT [8] Duality View : dv_product
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
  FROM app_product.product p
 WHERE p.status = 'ACTIVE'
 WITH CHECK OPTION;

-- ============================================================
-- dv_party — PK simple (party_id)
-- ============================================================
PROMPT [9] Duality View : dv_party
CREATE OR REPLACE JSON RELATIONAL DUALITY VIEW dv_party AS
  SELECT JSON {
    '_id'       : p.party_id,
    'partyCode' : p.party_code,
    'name'      : p.party_name,
    'natureId'  : p.nature_id,
    'phone'     : p.phone,
    'email'     : p.email,
    'address'   : p.address_1,
    'status'    : p.status,
    'blocked'   : p.is_blocked
  }
  FROM app_party.party p;

-- ============================================================
-- dv_ticket_json — Vue classique exposant un JSON complet
-- (Alternative à la Duality View, pour PK composite)
-- ============================================================
PROMPT [10] Vue JSON : v_ticket_json
CREATE OR REPLACE VIEW v_ticket_json AS
SELECT JSON_OBJECT(
         '_id'          VALUE TO_CHAR(t.ticket_no),
         'terminal'     VALUE t.terminal_id,
         'date'         VALUE t.ticket_date,
         'session'      VALUE t.session_no,
         'customer'     VALUE t.customer_code,
         'customerName' VALUE t.customer_name,
         'totalTTC'     VALUE t.total_ttc,
         'totalHT'      VALUE t.total_ht,
         'status'       VALUE t.status,
         'lines'        VALUE (
           SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                      'lineNo'      VALUE l.line_no,
                      'product'     VALUE l.product_code,
                      'description' VALUE l.description,
                      'quantity'    VALUE l.quantity,
                      'unitPrice'   VALUE l.unit_price,
                      'amount'      VALUE l.quantity * l.unit_price
                    )
                  )
             FROM app_sales.ticket_line l
            WHERE l.terminal_id = t.terminal_id 
              AND l.ticket_no   = t.ticket_no
         ),
         'payments'     VALUE (
           SELECT JSON_ARRAYAGG(
                    JSON_OBJECT(
                      'method' VALUE p.payment_method,
                      'type'   VALUE p.payment_type,
                      'amount' VALUE p.amount
                    )
                  )
             FROM app_sales.ticket_payment p
            WHERE p.terminal_id = t.terminal_id 
              AND p.ticket_no   = t.ticket_no
         )
       ) AS data
  FROM app_sales.ticket t;

-- ============================================================
-- v_stock_json — Vue classique JSON pour PK composite
-- ============================================================
PROMPT [11] Vue JSON : v_stock_json
CREATE OR REPLACE VIEW v_stock_json AS
SELECT JSON_OBJECT(
         '_id'         VALUE s.product_code,
         'warehouse'   VALUE s.warehouse_code,
         'product'     VALUE s.product_code,
         'stockQty'    VALUE s.stock_qty,
         'reservedQty' VALUE s.reserved_qty,
         'orderedQty'  VALUE s.ordered_qty,
         'lastIn'      VALUE s.last_in_at,
         'lastOut'     VALUE s.last_out_at
       ) AS data
  FROM app_inv.inv_stock s;

WHENEVER SQLERROR EXIT FAILURE

PROMPT
PROMPT ===============================================================
PROMPT   VALIDATION
PROMPT ===============================================================
SELECT view_name FROM user_views ORDER BY view_name;

PROMPT
PROMPT Tests Duality Views
PROMPT Test dv_product
SELECT JSON_VALUE(data, '$._id')          AS id,
       JSON_VALUE(data, '$.productCode')  AS code,
       JSON_VALUE(data, '$.name')         AS name
  FROM dv_product FETCH FIRST 3 ROWS ONLY;

PROMPT Test dv_party
SELECT JSON_VALUE(data, '$._id')          AS id,
       JSON_VALUE(data, '$.partyCode')    AS code,
       JSON_VALUE(data, '$.natureId')     AS nature
  FROM dv_party FETCH FIRST 5 ROWS ONLY;

PROMPT Tests vues JSON
PROMPT Test v_ticket_json
SELECT JSON_VALUE(data, '$._id')          AS ticket,
       JSON_VALUE(data, '$.terminal')     AS terminal,
       JSON_VALUE(data, '$.totalTTC')     AS total
  FROM v_ticket_json FETCH FIRST 3 ROWS ONLY;

PROMPT Test v_stock_json
SELECT JSON_VALUE(data, '$._id')            AS product,
       JSON_VALUE(data, '$.warehouse')      AS warehouse,
       JSON_VALUE(data, '$.stockQty')       AS qty
  FROM v_stock_json FETCH FIRST 5 ROWS ONLY;

PROMPT
PROMPT Test ticket complet en JSON
SELECT JSON_SERIALIZE(data PRETTY)
  FROM v_ticket_json
 WHERE JSON_VALUE(data, '$._id') = '1';

PROMPT ===============================================================
PROMPT   OK - SCHEMA app_api TERMINE
PROMPT ===============================================================
EXIT;
