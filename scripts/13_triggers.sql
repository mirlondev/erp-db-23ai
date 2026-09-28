-- ============================================================
-- SCRIPT 13 : Triggers — VERSION FINALE
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT system/oracle@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   PRIVILEGES POUR LES TRIGGERS
PROMPT ===============================================================
GRANT SELECT, UPDATE ON app_inv.inv_stock       TO app_sales;
GRANT SELECT, UPDATE ON app_inv.inv_stock_alert TO app_sales;
GRANT SELECT          ON app_pos.pos_terminal   TO app_sales;
GRANT SELECT          ON app_product.product    TO app_sales;
GRANT SELECT          ON app_party.party        TO app_sales;

PROMPT ===============================================================
PROMPT   TRIGGERS
PROMPT ===============================================================

-- Trigger 1 : Stock après vente
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_ticket_line_after_insert'; 
      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_ticket_audit'; 
      EXCEPTION WHEN OTHERS THEN NULL; END;
/

CREATE OR REPLACE TRIGGER trg_ticket_line_after_insert
AFTER INSERT ON ticket_line
FOR EACH ROW
DECLARE
  v_warehouse VARCHAR2(5);
BEGIN
  SELECT pt.warehouse_code INTO v_warehouse
    FROM app_pos.pos_terminal pt
   WHERE pt.terminal_code = :NEW.terminal_id;

  UPDATE app_inv.inv_stock
     SET stock_qty   = stock_qty - :NEW.quantity,
         last_out_at = SYSDATE,
         updated_at  = SYSTIMESTAMP
   WHERE warehouse_code = v_warehouse
     AND product_code   = :NEW.product_code;
EXCEPTION
  WHEN NO_DATA_FOUND THEN NULL;
  WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE TRIGGER trg_ticket_audit
AFTER INSERT ON ticket
FOR EACH ROW
BEGIN
  UPDATE app_pos.pos_terminal
     SET last_ticket_no = :NEW.ticket_no
   WHERE terminal_code = :NEW.terminal_id
     AND (last_ticket_no IS NULL OR last_ticket_no < :NEW.ticket_no);
END;
/

-- Trigger 2 : Audit produit
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE TRIGGER trg_product_audit
BEFORE UPDATE ON product
FOR EACH ROW
BEGIN
  :NEW.updated_at := SYSTIMESTAMP;
  :NEW.updated_by := SYS_CONTEXT('USERENV', 'SESSION_USER');
END;
/

-- Trigger 3 : Alerte stock négatif
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE TRIGGER trg_inv_stock_alert
AFTER INSERT OR UPDATE OF stock_qty ON inv_stock
FOR EACH ROW
BEGIN
  IF :NEW.stock_qty < 0 THEN
    MERGE INTO inv_stock_alert a
    USING (SELECT :NEW.product_code   AS product_code,
                  :NEW.warehouse_code AS warehouse_code,
                  :NEW.stock_qty      AS quantity,
                  TRUNC(SYSDATE)      AS alert_date
             FROM DUAL) src
    ON (a.product_code = src.product_code 
        AND a.warehouse_code = src.warehouse_code)
    WHEN MATCHED THEN
      UPDATE SET a.quantity = src.quantity, a.alert_date = src.alert_date
    WHEN NOT MATCHED THEN
      INSERT (product_code, warehouse_code, quantity, alert_date)
      VALUES (src.product_code, src.warehouse_code, src.quantity, src.alert_date);
  ELSE
    DELETE FROM inv_stock_alert
     WHERE product_code   = :NEW.product_code
       AND warehouse_code = :NEW.warehouse_code;
  END IF;
END;
/

-- Trigger 4 : Audit document
CONNECT app_doc/AppDoc#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE TRIGGER trg_doc_header_audit
AFTER INSERT ON doc_header
FOR EACH ROW
BEGIN
  INSERT INTO doc_log (doc_id, operation_at, user_code, operation_label)
  VALUES (:NEW.doc_id, SYSDATE, 
          NVL(:NEW.created_by, USER), 'Document cree');
END;
/

-- Validation
CONNECT system/oracle@localhost:1521/FREEPDB1

PROMPT
PROMPT [Validation]
SELECT owner, trigger_name, status
  FROM all_triggers
 WHERE owner LIKE 'APP\_%' ESCAPE '\'
 ORDER BY owner, trigger_name;

EXIT;
