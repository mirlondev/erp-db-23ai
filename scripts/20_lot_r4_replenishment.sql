-- ============================================================
-- SCRIPT 20 : LOT R4 — Réapprovisionnements & Transferts
-- Migration Oracle 11g (transferts inter-dépôts, bons de commande)
--                  → Oracle 23ai/26ai (app_inv)
-- ============================================================
-- 6 nouvelles tables dans app_inv :
--   transfer_header, transfer_line, replenishment_suggestion,
--   purchase_order_header, purchase_order_line, stock_valuation
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * VARCHAR2(20) pour user_code (vs 5 trop court)
--  * BOOLEAN pour is_validated/is_received/is_complete (là où applicable)
--  * CHECK cohérents : qty >= 0, status énuméré
--  * Index ciblés (po_date, supplier_code, status, warehouse)
--  * FK ON DELETE CASCADE sur lignes enfants
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R4 : RÉAPPRO & TRANSFERTS (6 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/6] transfer_header  — entête transfert inter-dépôts
CREATE TABLE transfer_header (
  transfer_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  transfer_number     VARCHAR2(20)  NOT NULL,
  transfer_date       DATE          NOT NULL,
  source_warehouse    VARCHAR2(5)   NOT NULL,
  target_warehouse    VARCHAR2(5)   NOT NULL,
  status              VARCHAR2(20)  DEFAULT 'DRAFT',      -- DRAFT | VALID | SENT | RECEIVED | CANCELLED
  total_qty           NUMBER(16,4)  DEFAULT 0,
  memo                VARCHAR2(255),
  carrier_name        VARCHAR2(60),                       -- transporteur
  tracking_number     VARCHAR2(40),                       -- n° de suivi
  expected_arrival    DATE,
  received_at         TIMESTAMP,
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  validated_by        VARCHAR2(20),
  validated_at        TIMESTAMP,
  CONSTRAINT pk_transfer_header       PRIMARY KEY (transfer_id),
  CONSTRAINT uk_transfer_number        UNIQUE (transfer_number),
  CONSTRAINT ck_transfer_status       CHECK (status IN ('DRAFT','VALID','SENT','RECEIVED','CANCELLED')),
  CONSTRAINT ck_transfer_diff_wh      CHECK (source_warehouse <> target_warehouse),
  CONSTRAINT ck_transfer_total_qty    CHECK (total_qty >= 0)
);

CREATE INDEX ix_transfer_date   ON transfer_header(transfer_date);
CREATE INDEX ix_transfer_status ON transfer_header(status);
CREATE INDEX ix_transfer_src    ON transfer_header(source_warehouse);
CREATE INDEX ix_transfer_dst    ON transfer_header(target_warehouse);

PROMPT
PROMPT [2/6] transfer_line  — lignes de transfert
CREATE TABLE transfer_line (
  transfer_id         NUMBER        NOT NULL,
  line_no             NUMBER(5)     NOT NULL,
  product_code        VARCHAR2(80)  NOT NULL,
  description         VARCHAR2(120),
  requested_qty       NUMBER(16,4),
  sent_qty            NUMBER(16,4)  DEFAULT 0,
  received_qty        NUMBER(16,4)  DEFAULT 0,
  unit_code           VARCHAR2(12),
  unit_cost           NUMBER(16,4),
  lot_number          VARCHAR2(20),
  status              VARCHAR2(20)  DEFAULT 'PENDING',    -- PENDING | SENT | RECEIVED | SHORT
  CONSTRAINT pk_transfer_line            PRIMARY KEY (transfer_id, line_no),
  CONSTRAINT fk_transfer_line_hdr        FOREIGN KEY (transfer_id)
    REFERENCES transfer_header(transfer_id) ON DELETE CASCADE,
  CONSTRAINT ck_transfer_line_qtys       CHECK (NVL(requested_qty, 0) >= 0
                                                AND NVL(sent_qty, 0) >= 0
                                                AND NVL(received_qty, 0) >= 0),
  CONSTRAINT ck_transfer_line_status     CHECK (status IN ('PENDING','SENT','RECEIVED','SHORT','CANCELLED'))
);

CREATE INDEX ix_transfer_line_prod       ON transfer_line(product_code);

PROMPT
PROMPT [3/6] replenishment_suggestion  — suggestions automatiques
CREATE TABLE replenishment_suggestion (
  suggestion_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  product_code        VARCHAR2(80)  NOT NULL,
  warehouse_code      VARCHAR2(5)   NOT NULL,
  current_stock       NUMBER(16,4),
  min_stock           NUMBER(16,4),
  max_stock           NUMBER(16,4),
  avg_consumption     NUMBER(16,4),                       -- moyenne journalière
  days_of_cover       NUMBER(8,2),                        -- stock actuel / conso (jours restants)
  suggested_qty       NUMBER(16,4),
  supplier_code       VARCHAR2(32),
  lead_time_days      NUMBER(5),
  status              VARCHAR2(20)  DEFAULT 'NEW',        -- NEW | APPROVED | REJECTED | CONVERTED
  priority_score      NUMBER(8,2),                       -- tri (urgence)
  generated_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  decided_by          VARCHAR2(20),
  decided_at          TIMESTAMP,
  CONSTRAINT pk_replenishment_sugg       PRIMARY KEY (suggestion_id),
  CONSTRAINT ck_replenish_status         CHECK (status IN ('NEW','APPROVED','REJECTED','CONVERTED')),
  CONSTRAINT ck_replenish_qtys           CHECK (NVL(current_stock, 0) >= 0
                                              AND NVL(min_stock, 0) >= 0
                                              AND NVL(suggested_qty, 0) >= 0)
);

CREATE INDEX ix_replenish_prod           ON replenishment_suggestion(product_code, warehouse_code);
CREATE INDEX ix_replenish_status         ON replenishment_suggestion(status);
CREATE INDEX ix_replenish_priority       ON replenishment_suggestion(priority_score DESC);

PROMPT
PROMPT [4/6] purchase_order_header  — entête bon de commande fournisseur
CREATE TABLE purchase_order_header (
  po_id               NUMBER GENERATED ALWAYS AS IDENTITY,
  po_number           VARCHAR2(20)  NOT NULL,
  po_date             DATE          NOT NULL,
  supplier_code       VARCHAR2(32)  NOT NULL,
  supplier_name       VARCHAR2(120),
  warehouse_code      VARCHAR2(5),
  expected_date       DATE,
  status              VARCHAR2(20)  DEFAULT 'DRAFT',      -- DRAFT | SENT | CONFIRMED | PARTIAL | RECEIVED | CLOSED | CANCELLED
  currency_code       VARCHAR2(3)   DEFAULT 'XOF',
  exchange_rate       NUMBER(10,5)  DEFAULT 1,
  total_ht            NUMBER(16,4)  DEFAULT 0,
  total_tax           NUMBER(16,4)  DEFAULT 0,
  total_ttc           NUMBER(16,4)  DEFAULT 0,
  memo                VARCHAR2(500),
  payment_terms       VARCHAR2(60),
  incoterm            VARCHAR2(10),                       -- FOB | CIF | EXW | DAP
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  sent_at             TIMESTAMP,
  confirmed_at        TIMESTAMP,
  closed_at           TIMESTAMP,
  CONSTRAINT pk_purchase_order_hdr       PRIMARY KEY (po_id),
  CONSTRAINT uk_po_number                UNIQUE (po_number),
  CONSTRAINT ck_po_status                CHECK (status IN ('DRAFT','SENT','CONFIRMED','PARTIAL','RECEIVED','CLOSED','CANCELLED')),
  CONSTRAINT ck_po_totals                CHECK (total_ht >= 0 AND total_tax >= 0 AND total_ttc >= 0)
);

CREATE INDEX ix_po_date                 ON purchase_order_header(po_date);
CREATE INDEX ix_po_supplier             ON purchase_order_header(supplier_code);
CREATE INDEX ix_po_status               ON purchase_order_header(status);
CREATE INDEX ix_po_expected             ON purchase_order_header(expected_date);

PROMPT
PROMPT [5/6] purchase_order_line  — lignes de commande fournisseur
CREATE TABLE purchase_order_line (
  po_id               NUMBER        NOT NULL,
  line_no             NUMBER(5)     NOT NULL,
  product_code        VARCHAR2(80)  NOT NULL,
  description         VARCHAR2(120),
  ordered_qty         NUMBER(16,4),
  received_qty        NUMBER(16,4)  DEFAULT 0,
  invoiced_qty        NUMBER(16,4)  DEFAULT 0,
  unit_code           VARCHAR2(12),
  unit_price          NUMBER(16,4),
  unit_price_ht       NUMBER(16,4),
  discount_rate       NUMBER(5,2),
  tax_rate            NUMBER(5,2),
  amount_ht           NUMBER(16,4),
  amount_ttc          NUMBER(16,4),
  expected_date       DATE,
  status              VARCHAR2(20)  DEFAULT 'OPEN',       -- OPEN | PARTIAL | RECEIVED | CLOSED | CANCELLED
  CONSTRAINT pk_purchase_order_line      PRIMARY KEY (po_id, line_no),
  CONSTRAINT fk_po_line_hdr              FOREIGN KEY (po_id)
    REFERENCES purchase_order_header(po_id) ON DELETE CASCADE,
  CONSTRAINT ck_po_line_qtys             CHECK (NVL(ordered_qty, 0) >= 0
                                              AND NVL(received_qty, 0) >= 0
                                              AND NVL(invoiced_qty, 0) >= 0),
  CONSTRAINT ck_po_line_status           CHECK (status IN ('OPEN','PARTIAL','RECEIVED','CLOSED','CANCELLED'))
);

CREATE INDEX ix_po_line_prod             ON purchase_order_line(product_code);

PROMPT
PROMPT [6/6] stock_valuation  — valorisation stock (snapshot périodique)
CREATE TABLE stock_valuation (
  valuation_date      DATE          NOT NULL,
  warehouse_code      VARCHAR2(5)   NOT NULL,
  product_code        VARCHAR2(80)  NOT NULL,
  quantity            NUMBER(16,4),
  avg_cost            NUMBER(16,4),
  total_value         NUMBER(16,4),
  valuation_method    VARCHAR2(10)  DEFAULT 'PRMP',      -- PRMP | FIFO | LIFO | STANDARD
  currency_code       VARCHAR2(3)   DEFAULT 'XOF',
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_stock_valuation          PRIMARY KEY (valuation_date, warehouse_code, product_code),
  CONSTRAINT ck_stock_val_method         CHECK (valuation_method IN ('PRMP','FIFO','LIFO','STANDARD')),
  CONSTRAINT ck_stock_val_qty            CHECK (quantity IS NULL OR quantity >= 0),
  CONSTRAINT ck_stock_val_total          CHECK (total_value IS NULL OR total_value >= 0)
);

CREATE INDEX ix_stock_val_wh             ON stock_valuation(warehouse_code);
CREATE INDEX ix_stock_val_prod           ON stock_valuation(product_code);
CREATE INDEX ix_stock_val_date           ON stock_valuation(valuation_date);

PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA
GRANT SELECT ON app_inv.transfer_header             TO app_api;
GRANT SELECT ON app_inv.transfer_line               TO app_api;
GRANT SELECT ON app_inv.replenishment_suggestion    TO app_api;
GRANT SELECT ON app_inv.purchase_order_header       TO app_api;
GRANT SELECT ON app_inv.purchase_order_line         TO app_api;
GRANT SELECT ON app_inv.stock_valuation             TO app_api;

-- app_product peut lire les suggestions pour les intégrer au catalogue
GRANT SELECT ON app_inv.replenishment_suggestion    TO app_product;

PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('TRANSFER_HEADER','TRANSFER_LINE','REPLENISHMENT_SUGGESTION',
                      'PURCHASE_ORDER_HEADER','PURCHASE_ORDER_LINE','STOCK_VALUATION')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('TRANSFER_HEADER','TRANSFER_LINE','REPLENISHMENT_SUGGESTION',
                      'PURCHASE_ORDER_HEADER','PURCHASE_ORDER_LINE','STOCK_VALUATION')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R4 TERMINÉ (6 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
