-- ============================================================
-- SCRIPT 14 : Packages PL/SQL
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DES PACKAGES
PROMPT ═══════════════════════════════════════════════════════

-- ============================================================
-- Package : pkg_pricing (Calcul des prix)
-- ============================================================
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE pkg_pricing AS
  FUNCTION get_price(
    p_product_code  IN VARCHAR2,
    p_price_list_id IN NUMBER DEFAULT 1
  ) RETURN NUMBER;
  
  FUNCTION get_price_ht(
    p_product_code  IN VARCHAR2,
    p_price_list_id IN NUMBER DEFAULT 1
  ) RETURN NUMBER;
  
  FUNCTION calc_tax(
    p_amount  IN NUMBER,
    p_tax_rate IN NUMBER
  ) RETURN NUMBER;
END pkg_pricing;
/

CREATE OR REPLACE PACKAGE BODY pkg_pricing AS

  FUNCTION get_price(
    p_product_code  IN VARCHAR2,
    p_price_list_id IN NUMBER DEFAULT 1
  ) RETURN NUMBER IS
    v_price NUMBER(16,4);
  BEGIN
    SELECT pp.price INTO v_price
      FROM product_price pp
      JOIN product p ON p.product_id = pp.product_id
     WHERE p.product_code = p_product_code
       AND pp.price_list_id = p_price_list_id;
    RETURN v_price;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      SELECT standard_price INTO v_price
        FROM product
       WHERE product_code = p_product_code;
      RETURN v_price;
  END get_price;

  FUNCTION get_price_ht(
    p_product_code  IN VARCHAR2,
    p_price_list_id IN NUMBER DEFAULT 1
  ) RETURN NUMBER IS
    v_price NUMBER(16,4);
  BEGIN
    SELECT pp.price_ht INTO v_price
      FROM product_price pp
      JOIN product p ON p.product_id = pp.product_id
     WHERE p.product_code = p_product_code
       AND pp.price_list_id = p_price_list_id;
    RETURN v_price;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      SELECT standard_price_ht INTO v_price
        FROM product
       WHERE product_code = p_product_code;
      RETURN v_price;
  END get_price_ht;

  FUNCTION calc_tax(
    p_amount  IN NUMBER,
    p_tax_rate IN NUMBER
  ) RETURN NUMBER IS
  BEGIN
    RETURN ROUND(p_amount * p_tax_rate / 100, 2);
  END calc_tax;

END pkg_pricing;
/

PROMPT ✅ pkg_pricing créé

-- ============================================================
-- Package : pkg_inventory (Gestion du stock)
-- ============================================================
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE pkg_inventory AS
  FUNCTION get_stock(
    p_product_code   IN VARCHAR2,
    p_warehouse_code IN VARCHAR2
  ) RETURN NUMBER;
  
  PROCEDURE update_stock(
    p_product_code   IN VARCHAR2,
    p_warehouse_code IN VARCHAR2,
    p_quantity       IN NUMBER,
    p_direction      IN VARCHAR2  -- 'IN' or 'OUT'
  );
  
  FUNCTION check_availability(
    p_product_code   IN VARCHAR2,
    p_warehouse_code IN VARCHAR2,
    p_quantity       IN NUMBER
  ) RETURN BOOLEAN;
END pkg_inventory;
/

CREATE OR REPLACE PACKAGE BODY pkg_inventory AS

  FUNCTION get_stock(
    p_product_code   IN VARCHAR2,
    p_warehouse_code IN VARCHAR2
  ) RETURN NUMBER IS
    v_qty NUMBER(16,4);
  BEGIN
    SELECT stock_qty INTO v_qty
      FROM inv_stock
     WHERE product_code = p_product_code
       AND warehouse_code = p_warehouse_code;
    RETURN NVL(v_qty, 0);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 0;
  END get_stock;

  PROCEDURE update_stock(
    p_product_code   IN VARCHAR2,
    p_warehouse_code IN VARCHAR2,
    p_quantity       IN NUMBER,
    p_direction      IN VARCHAR2
  ) IS
    v_existing NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_existing
      FROM inv_stock
     WHERE product_code = p_product_code
       AND warehouse_code = p_warehouse_code;
    
    IF v_existing = 0 THEN
      INSERT INTO inv_stock (product_code, warehouse_code, stock_qty)
      VALUES (p_product_code, p_warehouse_code, 0);
    END IF;
    
    IF p_direction = 'IN' THEN
      UPDATE inv_stock
         SET stock_qty = stock_qty + p_quantity,
             last_in_at = SYSDATE,
             updated_at = SYSTIMESTAMP
       WHERE product_code = p_product_code
         AND warehouse_code = p_warehouse_code;
    ELSE
      UPDATE inv_stock
         SET stock_qty = stock_qty - p_quantity,
             last_out_at = SYSDATE,
             updated_at = SYSTIMESTAMP
       WHERE product_code = p_product_code
         AND warehouse_code = p_warehouse_code;
    END IF;
    COMMIT;
  END update_stock;

  FUNCTION check_availability(
    p_product_code   IN VARCHAR2,
    p_warehouse_code IN VARCHAR2,
    p_quantity       IN NUMBER
  ) RETURN BOOLEAN IS
    v_stock NUMBER;
  BEGIN
    v_stock := get_stock(p_product_code, p_warehouse_code);
    RETURN (v_stock >= p_quantity);
  END check_availability;

END pkg_inventory;
/

PROMPT ✅ pkg_inventory créé

-- ============================================================
-- Package : pkg_sales (Ventes)
-- ============================================================
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE pkg_sales AS
  FUNCTION create_ticket(
    p_terminal_id  IN VARCHAR2,
    p_session_no   IN NUMBER,
    p_customer_code IN VARCHAR2,
    p_user_code    IN VARCHAR2
  ) RETURN NUMBER;
  
  FUNCTION get_ticket_total(
    p_terminal_id IN VARCHAR2,
    p_ticket_no   IN NUMBER
  ) RETURN NUMBER;
END pkg_sales;
/

CREATE OR REPLACE PACKAGE BODY pkg_sales AS

  FUNCTION create_ticket(
    p_terminal_id   IN VARCHAR2,
    p_session_no    IN NUMBER,
    p_customer_code IN VARCHAR2,
    p_user_code     IN VARCHAR2
  ) RETURN NUMBER IS
    v_ticket_no NUMBER(8);
    v_customer_name VARCHAR2(120);
  BEGIN
    -- Récupérer le nom du client
    BEGIN
      SELECT party_name INTO v_customer_name
        FROM app_party.party
       WHERE party_code = p_customer_code;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN v_customer_name := NULL;
    END;
    
    -- Numéro du ticket
    SELECT NVL(MAX(ticket_no), 0) + 1 INTO v_ticket_no
      FROM ticket
     WHERE terminal_id = p_terminal_id;
    
    -- Créer le ticket
    INSERT INTO ticket (
      terminal_id, ticket_no, ticket_date, session_no,
      customer_code, customer_name, user_code,
      total_ttc, total_ht, ticket_total, status
    ) VALUES (
      p_terminal_id, v_ticket_no, SYSDATE, p_session_no,
      p_customer_code, v_customer_name, p_user_code,
      0, 0, 0, 'V'
    );
    
    RETURN v_ticket_no;
  END create_ticket;

  FUNCTION get_ticket_total(
    p_terminal_id IN VARCHAR2,
    p_ticket_no   IN NUMBER
  ) RETURN NUMBER IS
    v_total NUMBER(16,4);
  BEGIN
    SELECT NVL(SUM(quantity * unit_price), 0) INTO v_total
      FROM ticket_line
     WHERE terminal_id = p_terminal_id
       AND ticket_no = p_ticket_no;
    RETURN v_total;
  END get_ticket_total;

END pkg_sales;
/

PROMPT ✅ pkg_sales créé

-- ============================================================
-- Package : pkg_gl (Comptabilité)
-- ============================================================
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE pkg_gl AS
  FUNCTION get_account_balance(
    p_company_code IN VARCHAR2,
    p_account_code IN VARCHAR2
  ) RETURN NUMBER;
  
  FUNCTION get_party_balance(
    p_company_code IN VARCHAR2,
    p_party_code   IN VARCHAR2,
    p_account_code IN VARCHAR2
  ) RETURN NUMBER;
END pkg_gl;
/

CREATE OR REPLACE PACKAGE BODY pkg_gl AS

  FUNCTION get_account_balance(
    p_company_code IN VARCHAR2,
    p_account_code IN VARCHAR2
  ) RETURN NUMBER IS
    v_debit  NUMBER(16,4);
    v_credit NUMBER(16,4);
  BEGIN
    SELECT NVL(SUM(company_debit), 0), NVL(SUM(company_credit), 0)
      INTO v_debit, v_credit
      FROM gl_entry_line
     WHERE company_code = p_company_code
       AND account_code = p_account_code;
    RETURN v_debit - v_credit;
  END get_account_balance;

  FUNCTION get_party_balance(
    p_company_code IN VARCHAR2,
    p_party_code   IN VARCHAR2,
    p_account_code IN VARCHAR2
  ) RETURN NUMBER IS
    v_debit  NUMBER(16,4);
    v_credit NUMBER(16,4);
  BEGIN
    SELECT NVL(SUM(company_debit), 0), NVL(SUM(company_credit), 0)
      INTO v_debit, v_credit
      FROM gl_entry_line
     WHERE company_code = p_company_code
       AND account_code = p_account_code
       AND party_code   = p_party_code;
    RETURN v_debit - v_credit;
  END get_party_balance;

END pkg_gl;
/

PROMPT
PROMPT [Validation]
SELECT owner, object_name, object_type, status
  FROM all_objects
 WHERE object_name LIKE 'PKG\_%' ESCAPE '\'
   AND owner LIKE 'APP\_%' ESCAPE '\'
   AND object_type IN ('PACKAGE','PACKAGE BODY','FUNCTION','PROCEDURE')
 ORDER BY owner, object_name;

-- Erreurs de compilation éventuelles
PROMPT
PROMPT Erreurs de compilation
SELECT owner, name, type, line, text
  FROM all_errors
 WHERE owner LIKE 'APP\_%' ESCAPE '\'
 ORDER BY owner, name, sequence;
 
PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ PACKAGES TERMINÉS
PROMPT ═══════════════════════════════════════════════════════
