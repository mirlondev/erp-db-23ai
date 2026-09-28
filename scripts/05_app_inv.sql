-- ============================================================
-- SCRIPT 05 : Schéma app_inv (Stock / Inventaire) — VERSION CORRIGÉE
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DU SCHÉMA app_inv
PROMPT ═══════════════════════════════════════════════════════

-- Supprimer les tables si elles existent (relance propre)
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
             WHERE table_name IN ('INV_STOCK','INV_STOCK_ALERT',
                                  'INV_COUNT_HEADER','INV_COUNT_LINE','INV_MOVEMENT')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE '||t.table_name||' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

PROMPT [1] Table inv_stock
CREATE TABLE inv_stock (
  warehouse_code    VARCHAR2(5)   NOT NULL,
  product_code      VARCHAR2(80)  NOT NULL,
  stock_qty         NUMBER(16,4)  DEFAULT 0,
  ordered_qty       NUMBER(16,4)  DEFAULT 0,
  reserved_qty      NUMBER(16,4)  DEFAULT 0,
  loaned_qty        NUMBER(16,4)  DEFAULT 0,
  last_out_at       DATE,
  last_in_at        DATE,
  last_count_qty    NUMBER(16,4),
  last_count_at     DATE,
  location          VARCHAR2(40),
  pending_qty       NUMBER(16,4)  DEFAULT 0,
  updated_at        TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_inv_stock PRIMARY KEY (warehouse_code, product_code)
);

CREATE INDEX ix_inv_stock_product ON inv_stock(product_code);

PROMPT [2] Table inv_stock_alert
CREATE TABLE inv_stock_alert (
  product_code      VARCHAR2(80) NOT NULL,
  warehouse_code    VARCHAR2(5)  NOT NULL,
  quantity          NUMBER(16,3) NOT NULL,
  alert_date        DATE         NOT NULL,
  CONSTRAINT pk_inv_stock_alert PRIMARY KEY (product_code, warehouse_code)
);

PROMPT [3] Table inv_count_header (Inventaire)
CREATE TABLE inv_count_header (
  count_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  count_date      DATE         NOT NULL,
  company_code    VARCHAR2(12) NOT NULL,
  warehouse_code  VARCHAR2(5),
  release_date    DATE,
  notes           VARCHAR2(120),                    -- ✅ CORRIGÉ (était "comment")
  document_id     NUMBER,
  status          VARCHAR2(20) DEFAULT 'IN_PROGRESS',
  created_by      VARCHAR2(20),
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_inv_count_header PRIMARY KEY (count_id),
  CONSTRAINT ck_inv_count_status CHECK (status IN ('IN_PROGRESS','VALIDATED','CANCELLED'))
);

PROMPT [4] Table inv_count_line
CREATE TABLE inv_count_line (
  count_id        NUMBER        NOT NULL,
  product_code    VARCHAR2(80)  NOT NULL,
  count_date      DATE,
  warehouse_code  VARCHAR2(5)   NOT NULL,
  theoretical_qty NUMBER(16,4),
  counted_qty     NUMBER(16,4),
  variance_qty    NUMBER(16,4),
  status          VARCHAR2(4),
  validated_by    VARCHAR2(20),
  validated_at    DATE,
  line_no         NUMBER(5),
  order_no        NUMBER(5),
  cost_price      NUMBER(16,4),
  CONSTRAINT pk_inv_count_line PRIMARY KEY (count_id, product_code, warehouse_code),
  CONSTRAINT fk_inv_count_line_hdr FOREIGN KEY (count_id) 
    REFERENCES inv_count_header(count_id) ON DELETE CASCADE
);

CREATE INDEX ix_inv_count_line_prod ON inv_count_line(product_code);

PROMPT [5] Table inv_movement (Mouvements de stock)
CREATE TABLE inv_movement (
  movement_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  movement_date   DATE          NOT NULL,
  warehouse_code  VARCHAR2(5)   NOT NULL,
  product_code    VARCHAR2(80)  NOT NULL,
  movement_type   VARCHAR2(10)  NOT NULL,
  direction       VARCHAR2(1)   NOT NULL,
  quantity        NUMBER(16,4)  NOT NULL,
  unit_cost       NUMBER(16,4),
  document_type   VARCHAR2(20),
  document_id     NUMBER,
  line_no         NUMBER(5),
  notes           VARCHAR2(255),                    -- ✅ notes au lieu de comment
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  created_by      VARCHAR2(20),
  CONSTRAINT pk_inv_movement PRIMARY KEY (movement_id),
  CONSTRAINT ck_inv_mvt_dir CHECK (direction IN ('I','O'))
);

CREATE INDEX ix_inv_mvt_product_date ON inv_movement(product_code, movement_date);
CREATE INDEX ix_inv_mvt_warehouse    ON inv_movement(warehouse_code);

PROMPT
PROMPT [6] Insertion des stocks initiaux

INSERT INTO inv_stock (warehouse_code, product_code, stock_qty)
VALUES ('DEP01', 'ART001', 100);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty)
VALUES ('DEP01', 'ART002', 500);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty)
VALUES ('DEP01', 'ART003', 50);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty)
VALUES ('DEP02', 'ART001', 200);
INSERT INTO inv_stock (warehouse_code, product_code, stock_qty)
VALUES ('DEP02', 'ART004', 150);

COMMIT;

PROMPT
PROMPT [7] Validation
SELECT table_name FROM user_tables ORDER BY table_name;
SELECT warehouse_code, product_code, stock_qty FROM inv_stock;
SELECT COUNT(*) AS nb_stock FROM inv_stock;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_inv TERMINÉ
PROMPT ═══════════════════════════════════════════════════════