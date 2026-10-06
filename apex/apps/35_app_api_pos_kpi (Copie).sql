-- ============================================================
-- SCRIPT 35 : Fonctions APP_API manquantes (POS Quick Billing + KPI stock)
-- ============================================================
-- Appelées par les pages APEX p00020 (app 100) et p00010 (app 200).
-- HYPOTHESES (a verifier) :
--   * prix panier = STANDARD_PRICE_HT ; TVA = 18,9 %
--   * vente comptoir = facture APP_AR.INVOICE payee comptant
--   * company '01', client comptoir 'COMPTOIR'  (voir constantes)
--   * le stock n'est PAS decremente a la vente (regle a definir)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

PROMPT === Privileges ===
GRANT SELECT ON app_product.product      TO app_api;
GRANT SELECT ON app_inv.inv_stock        TO app_api;
GRANT INSERT ON app_ar.invoice           TO app_api;
GRANT INSERT ON app_ar.invoice_line      TO app_api;

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT === Sequence numerotation tickets POS ===
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM user_sequences WHERE sequence_name = 'SEQ_POS_INVOICE';
  IF n = 0 THEN
    EXECUTE IMMEDIATE 'CREATE SEQUENCE seq_pos_invoice START WITH 1 INCREMENT BY 1 NOCACHE';
  END IF;
END;
/

PROMPT === Totaux panier ===
CREATE OR REPLACE FUNCTION apex_pos_cart_total_ht RETURN NUMBER IS
  l_total NUMBER;
BEGIN
  SELECT NVL(SUM(TO_NUMBER(c003) * TO_NUMBER(c004)), 0)
    INTO l_total
    FROM apex_collections
   WHERE collection_name = 'CART';
  RETURN ROUND(l_total, 0);
END;
/

CREATE OR REPLACE FUNCTION apex_pos_cart_total_tva RETURN NUMBER IS
BEGIN
  RETURN ROUND(apex_pos_cart_total_ht * 0.189, 0);
END;
/

CREATE OR REPLACE FUNCTION apex_pos_cart_total_ttc RETURN NUMBER IS
BEGIN
  RETURN apex_pos_cart_total_ht + apex_pos_cart_total_tva;
END;
/

CREATE OR REPLACE PROCEDURE apex_pos_cart_clear IS
BEGIN
  IF apex_collection.collection_exists('CART') THEN
    apex_collection.delete_collection('CART');
  END IF;
END;
/

PROMPT === Ajout au panier ===
CREATE OR REPLACE PROCEDURE apex_pos_cart_add (
  p_barcode  IN VARCHAR2,
  p_quantity IN NUMBER DEFAULT 1
) IS
  l_code   app_product.product.product_code%TYPE;
  l_name   app_product.product.product_name%TYPE;
  l_price  app_product.product.standard_price_ht%TYPE;
  l_qty    NUMBER := NVL(p_quantity, 1);
  l_seq    NUMBER;
  l_old    NUMBER;
BEGIN
  IF p_barcode IS NULL THEN
    RAISE_APPLICATION_ERROR(-20001, 'Scannez ou saisissez un code-barres.');
  END IF;
  IF l_qty <= 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'La quantite doit etre superieure a zero.');
  END IF;

  BEGIN
    SELECT product_code, product_name, standard_price_ht
      INTO l_code, l_name, l_price
      FROM app_product.product
     WHERE barcode = TRIM(p_barcode)
        OR product_code = TRIM(p_barcode)
     FETCH FIRST 1 ROW ONLY;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(-20003, 'Produit introuvable : ' || p_barcode);
  END;

  IF l_price IS NULL THEN
    RAISE_APPLICATION_ERROR(-20004, 'Prix HT manquant pour ' || l_code);
  END IF;

  IF NOT apex_collection.collection_exists('CART') THEN
    apex_collection.create_collection('CART');
  END IF;

  BEGIN
    SELECT seq_id, TO_NUMBER(c004)
      INTO l_seq, l_old
      FROM apex_collections
     WHERE collection_name = 'CART' AND c001 = l_code
     FETCH FIRST 1 ROW ONLY;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN l_seq := NULL;
  END;

  IF l_seq IS NOT NULL THEN
    apex_collection.update_member(
      p_collection_name => 'CART', p_seq => l_seq,
      p_c001 => l_code, p_c002 => l_name,
      p_c003 => TO_CHAR(l_price),
      p_c004 => TO_CHAR(l_old + l_qty),
      p_c005 => TO_CHAR(l_price * (l_old + l_qty)));
  ELSE
    apex_collection.add_member(
      p_collection_name => 'CART',
      p_c001 => l_code, p_c002 => l_name,
      p_c003 => TO_CHAR(l_price),
      p_c004 => TO_CHAR(l_qty),
      p_c005 => TO_CHAR(l_price * l_qty));
  END IF;
END;
/

PROMPT === Encaissement : cree la facture comptant ===
CREATE OR REPLACE FUNCTION apex_pos_cart_settle (p_user IN VARCHAR2)
  RETURN VARCHAR2 IS
  c_company   CONSTANT VARCHAR2(12)  := '01';
  c_party     CONSTANT VARCHAR2(32)  := 'COMPTOIR';
  c_party_nm  CONSTANT VARCHAR2(120) := 'Client comptoir';
  c_tax_rate  CONSTANT NUMBER        := 18.9;
  l_ht      NUMBER;
  l_tva     NUMBER;
  l_ttc     NUMBER;
  l_inv_id  NUMBER;
  l_number  VARCHAR2(20);
  l_line    NUMBER := 0;
BEGIN
  l_ht  := apex_pos_cart_total_ht;
  l_tva := apex_pos_cart_total_tva;
  l_ttc := apex_pos_cart_total_ttc;

  IF l_ht <= 0 THEN
    RAISE_APPLICATION_ERROR(-20010, 'Le panier est vide.');
  END IF;

  l_number := 'POS-' || TO_CHAR(SYSDATE, 'YYYY') || '-'
              || LPAD(seq_pos_invoice.NEXTVAL, 6, '0');

  -- le trigger trg_invoice_overdue recalcule balance et statut
  INSERT INTO app_ar.invoice (
    invoice_number, invoice_date, company_code, party_code, party_name,
    currency_code, due_date, payment_method,
    total_ht, total_tax, total_ttc, total_paid, balance, status,
    memo, created_by)
  VALUES (
    l_number, TRUNC(SYSDATE), c_company, c_party, c_party_nm,
    'XOF', TRUNC(SYSDATE), 'CASH',
    l_ht, l_tva, l_ttc, l_ttc, 0, 'PAID',
    'Vente comptoir (APEX Quick Billing)', SUBSTR(p_user, 1, 20))
  RETURNING invoice_id INTO l_inv_id;

  FOR r IN (
    SELECT c.c001 AS code, c.c002 AS name,
           TO_NUMBER(c.c003) AS price, TO_NUMBER(c.c004) AS qty,
           p.sale_unit
      FROM apex_collections c
      LEFT JOIN app_product.product p ON p.product_code = c.c001
     WHERE c.collection_name = 'CART'
     ORDER BY c.seq_id
  ) LOOP
    l_line := l_line + 1;
    INSERT INTO app_ar.invoice_line (
      invoice_id, line_no, product_code, description, quantity, unit_code,
      unit_price, amount, discount_rate, tax_rate, tax_amount,
      amount_ht, amount_ttc)
    VALUES (
      l_inv_id, l_line, r.code, SUBSTR(r.name, 1, 120), r.qty,
      SUBSTR(r.sale_unit, 1, 12),
      r.price, r.price * r.qty, 0, c_tax_rate,
      r.price * r.qty * c_tax_rate / 100,
      r.price * r.qty,
      r.price * r.qty * (1 + c_tax_rate / 100));
  END LOOP;

  RETURN l_number;   -- pas de COMMIT : APEX valide en fin de traitement
END;
/

PROMPT === KPI stock (page 10) ===
CREATE OR REPLACE FUNCTION apex_kpi_stock_refs RETURN NUMBER IS
  l_n NUMBER;
BEGIN
  SELECT COUNT(DISTINCT s.product_code) INTO l_n
    FROM app_inv.inv_stock s WHERE s.stock_qty > 0;
  RETURN l_n;
END;
/

CREATE OR REPLACE FUNCTION apex_kpi_stock_units RETURN NUMBER IS
  l_n NUMBER;
BEGIN
  SELECT NVL(SUM(s.stock_qty), 0) INTO l_n FROM app_inv.inv_stock s;
  RETURN l_n;
END;
/

CREATE OR REPLACE FUNCTION apex_kpi_stock_value_xaf RETURN NUMBER IS
  l_n NUMBER;
BEGIN
  SELECT ROUND(NVL(SUM(s.stock_qty * NVL(p.standard_price, 0)), 0), 0) INTO l_n
    FROM app_inv.inv_stock s
    JOIN app_product.product p ON p.product_code = s.product_code;
  RETURN l_n;
END;
/

CREATE OR REPLACE FUNCTION apex_kpi_stock_low_count RETURN NUMBER IS
  l_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO l_n
    FROM app_inv.inv_stock s
    JOIN app_product.product p ON p.product_code = s.product_code
   WHERE s.stock_qty > 0
     AND s.stock_qty <= NVL(p.min_stock_qty, 0);
  RETURN l_n;
END;
/

PROMPT === Droits pour l'application stock (parsing schema APP_INV) ===
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA
GRANT EXECUTE ON app_api.apex_kpi_stock_refs      TO app_inv;
GRANT EXECUTE ON app_api.apex_kpi_stock_units     TO app_inv;
GRANT EXECUTE ON app_api.apex_kpi_stock_value_xaf TO app_inv;
GRANT EXECUTE ON app_api.apex_kpi_stock_low_count TO app_inv;

PROMPT === Validation : doit etre vide ===
SELECT owner, object_name, object_type
  FROM dba_objects
 WHERE owner = 'APP_API' AND status = 'INVALID';

SELECT owner, name, line, text
  FROM dba_errors
 WHERE owner = 'APP_API'
 ORDER BY name, sequence;

SELECT object_name, object_type, status
  FROM dba_objects
 WHERE owner = 'APP_API'
   AND (object_name LIKE 'APEX\_POS\_CART%' ESCAPE '\'
     OR object_name LIKE 'APEX\_KPI\_STOCK%' ESCAPE '\')
 ORDER BY object_name;

EXIT;
