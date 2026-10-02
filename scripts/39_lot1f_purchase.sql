-- ============================================================
-- SCRIPT 39 : LOT 1F — Achats / Demandes de prix
-- Migration Oracle 11g (GCPTIE*) → 23ai/26ai (nouveau app_purchase)
-- ============================================================
-- 4 nouvelles tables dans un NOUVEAU schéma app_purchase.
-- Le schéma est créé dans 00_init_schemas.sql.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_purchase/AppPurchase#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT 1F : 4 tables ACHATS / DEMANDES DE PRIX (app_purchase)
PROMPT ══════════════════════════════════════════════════════════


PROMPT [1/4] purchase_request  — demande de prix
CREATE TABLE purchase_request (
  request_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  request_number      VARCHAR2(20)  NOT NULL,
  request_date        DATE          NOT NULL,
  requester_code      VARCHAR2(20)  NOT NULL,
  request_type        VARCHAR2(2)   NOT NULL,             -- 'QT' devis, 'PR' proposition, 'RF' appel d'offres
  priority            NUMBER(1)     DEFAULT 3,             -- 1=urgent, 5=basse
  expected_date       DATE,
  destination_warehouse VARCHAR2(5),
  currency_code       VARCHAR2(3)   DEFAULT 'XOF',
  status              VARCHAR2(20)  DEFAULT 'OPEN',       -- OPEN | QUOTED | ORDERED | CLOSED | CANCELLED
  notes               VARCHAR2(1000),
  approved_by         VARCHAR2(20),
  approved_at         TIMESTAMP,
  closed_at           TIMESTAMP,
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_purchase_request         PRIMARY KEY (request_id),
  CONSTRAINT uk_purchase_request_no      UNIQUE (request_number),
  CONSTRAINT ck_purchase_request_type    CHECK (request_type IN ('QT','PR','RF','SP','CN')),
  CONSTRAINT ck_purchase_request_status  CHECK (status IN ('OPEN','QUOTED','ORDERED','PARTIAL','CLOSED','CANCELLED')),
  CONSTRAINT ck_purchase_request_prio    CHECK (priority BETWEEN 1 AND 5)
);

CREATE INDEX ix_purchase_request_status   ON purchase_request(status);
CREATE INDEX ix_purchase_request_date     ON purchase_request(request_date);
CREATE INDEX ix_purchase_request_requester ON purchase_request(requester_code);

PROMPT [2/4] purchase_request_line  — articles demandés
CREATE TABLE purchase_request_line (
  request_id          NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  product_code        VARCHAR2(80)  NOT NULL,
  description         VARCHAR2(120),
  quantity            NUMBER(16,4)  NOT NULL,
  unit_code           VARCHAR2(12)  DEFAULT 'UNIT',
  target_price        NUMBER(16,4),                        -- prix cible indicatif
  preferred_supplier  VARCHAR2(32),
  notes               VARCHAR2(500),
  CONSTRAINT pk_purchase_request_line      PRIMARY KEY (request_id, line_no),
  CONSTRAINT fk_purchase_request_line_hdr  FOREIGN KEY (request_id)
    REFERENCES purchase_request(request_id) ON DELETE CASCADE,
  CONSTRAINT ck_purchase_request_line_qty  CHECK (quantity > 0)
);

CREATE INDEX ix_purchase_request_line_prod ON purchase_request_line(product_code);

PROMPT [3/4] supplier_quote  — devis fournisseurs reçus
CREATE TABLE supplier_quote (
  quote_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  quote_number        VARCHAR2(20)  NOT NULL,
  quote_date          DATE          NOT NULL,
  supplier_code       VARCHAR2(32)  NOT NULL,
  supplier_name       VARCHAR2(120),
  request_id          NUMBER,                              -- demande source
  currency_code       VARCHAR2(3)   DEFAULT 'XOF',
  exchange_rate       NUMBER(10,5)  DEFAULT 1,
  payment_terms       VARCHAR2(120),
  delivery_lead_days  NUMBER(5),
  validity_date       DATE,                                 -- date limite d'acceptation
  total_ht            NUMBER(16,4)  DEFAULT 0,
  total_tax           NUMBER(16,4)  DEFAULT 0,
  total_ttc           NUMBER(16,4)  DEFAULT 0,
  status              VARCHAR2(20)  DEFAULT 'RECEIVED',    -- RECEIVED | ACCEPTED | REJECTED | EXPIRED
  rejection_reason    VARCHAR2(500),
  accepted_by         VARCHAR2(20),
  accepted_at         TIMESTAMP,
  converted_to_po     BOOLEAN       DEFAULT FALSE,
  po_id               NUMBER,                              -- FK logique vers app_inv.purchase_order_header
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_supplier_quote            PRIMARY KEY (quote_id),
  CONSTRAINT uk_supplier_quote_no         UNIQUE (quote_number),
  CONSTRAINT fk_supplier_quote_request    FOREIGN KEY (request_id)
    REFERENCES purchase_request(request_id),
  CONSTRAINT ck_supplier_quote_status     CHECK (status IN ('RECEIVED','ACCEPTED','REJECTED','EXPIRED','WITHDRAWN'))
);

CREATE INDEX ix_supplier_quote_supplier   ON supplier_quote(supplier_code);
CREATE INDEX ix_supplier_quote_status     ON supplier_quote(status);

PROMPT [4/4] supplier_quote_line  — lignes de devis
CREATE TABLE supplier_quote_line (
  quote_id            NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  product_code        VARCHAR2(80)  NOT NULL,
  description         VARCHAR2(120),
  quantity            NUMBER(16,4)  NOT NULL,
  unit_price          NUMBER(16,4)  NOT NULL,
  unit_price_ht       NUMBER(16,4),
  tax_rate            NUMBER(5,2),
  discount_rate       NUMBER(5,2),
  amount_ttc          NUMBER(16,4),
  amount_ht           NUMBER(16,4),
  lead_time_days      NUMBER(5),
  notes               VARCHAR2(500),
  CONSTRAINT pk_supplier_quote_line        PRIMARY KEY (quote_id, line_no),
  CONSTRAINT fk_supplier_quote_line_hdr    FOREIGN KEY (quote_id)
    REFERENCES supplier_quote(quote_id) ON DELETE CASCADE,
  CONSTRAINT ck_supplier_quote_line_qty    CHECK (quantity > 0),
  CONSTRAINT ck_supplier_quote_line_price  CHECK (unit_price >= 0)
);

CREATE INDEX ix_supplier_quote_line_prod   ON supplier_quote_line(product_code);


PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

GRANT SELECT ON app_purchase.purchase_request      TO app_api;
GRANT SELECT ON app_purchase.purchase_request_line TO app_api;
GRANT SELECT ON app_purchase.supplier_quote        TO app_api;
GRANT SELECT ON app_purchase.supplier_quote_line   TO app_api;

GRANT SELECT ON app_purchase.purchase_request      TO app_inv;
GRANT SELECT ON app_purchase.purchase_request_line TO app_inv;
GRANT SELECT ON app_purchase.supplier_quote        TO app_inv;
GRANT SELECT ON app_purchase.supplier_quote_line   TO app_inv;

GRANT SELECT, INSERT, UPDATE ON app_purchase.purchase_request      TO app_doc;
GRANT SELECT, INSERT, UPDATE ON app_purchase.supplier_quote        TO app_doc;

PROMPT
PROMPT ═══ Validation — Tables ═══
CONNECT app_purchase/AppPurchase#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT 1F TERMINÉ (4 tables dans nouveau schéma app_purchase)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
