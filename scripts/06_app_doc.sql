-- ============================================================
-- SCRIPT 06 : Schéma app_doc (Documents / Bordereaux)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_doc/AppDoc#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DU SCHÉMA app_doc
PROMPT ═══════════════════════════════════════════════════════

PROMPT [1] Table doc_type (Types de documents)
CREATE TABLE doc_type (
  doc_type_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  doc_type_code     VARCHAR2(20)  NOT NULL,
  doc_type_name     VARCHAR2(120) NOT NULL,
  doc_category      VARCHAR2(12),
  direction         VARCHAR2(4),
  updates_stock     BOOLEAN       DEFAULT FALSE,
  is_transfer       BOOLEAN       DEFAULT FALSE,
  counter_type_code VARCHAR2(20),
  is_active         BOOLEAN       DEFAULT TRUE,
  entry_mode        VARCHAR2(20),
  created_at        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_doc_type      PRIMARY KEY (doc_type_id),
  CONSTRAINT uk_doc_type_code UNIQUE (doc_type_code)
);

PROMPT [2] Table doc_header (Entêtes documents)
CREATE TABLE doc_header (
  doc_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  doc_type_code     VARCHAR2(20)  NOT NULL,
  doc_no            NUMBER(8)     NOT NULL,
  company_code      VARCHAR2(12)  NOT NULL,
  doc_date          DATE          NOT NULL,
  warehouse_code    VARCHAR2(5),
  destination_warehouse VARCHAR2(5),
  counter_type_code VARCHAR2(20),
  document_ref      VARCHAR2(120),
  notes           VARCHAR2(50),
  memo              VARCHAR2(4000),
  party_code        VARCHAR2(32),
  party_name        VARCHAR2(50),
  party_address_1   VARCHAR2(120),
  party_address_2   VARCHAR2(120),
  party_address_3   VARCHAR2(120),
  currency_code     VARCHAR2(12),
  exchange_rate     NUMBER(10,5)  DEFAULT 1,
  invoice_no        NUMBER(8),
  invoice_date      DATE,
  discount_rate     NUMBER(5,2),
  price_list_code   VARCHAR2(8),
  due_date          DATE,
  payment_method    VARCHAR2(12),
  status            VARCHAR2(20)  DEFAULT 'DRAFT',
  created_by        VARCHAR2(20),
  updated_by        VARCHAR2(20),
  created_at        DATE,
  updated_at        DATE,
  total_ht          NUMBER(16,4)  DEFAULT 0,
  total_tax_1       NUMBER(16,4)  DEFAULT 0,
  total_tax_2       NUMBER(16,4)  DEFAULT 0,
  total_ttc         NUMBER(16,4)  DEFAULT 0,
  total_paid        NUMBER(16,4)  DEFAULT 0,
  point_of_sale_code VARCHAR2(3),
  CONSTRAINT pk_doc_header      PRIMARY KEY (doc_id),
  CONSTRAINT uk_doc_header_no   UNIQUE (doc_type_code, doc_no),
  CONSTRAINT fk_doc_header_type FOREIGN KEY (doc_type_code) 
    REFERENCES doc_type(doc_type_code),
  CONSTRAINT ck_doc_header_status CHECK (status IN ('DRAFT','VALID','CANCELLED','CLOSED'))
);

CREATE INDEX ix_doc_header_date   ON doc_header(doc_date);
CREATE INDEX ix_doc_header_party  ON doc_header(party_code);
CREATE INDEX ix_doc_header_type   ON doc_header(doc_type_code);
CREATE INDEX ix_doc_header_status ON doc_header(status);

PROMPT [3] Table doc_line (Lignes documents)
CREATE TABLE doc_line (
  doc_id            NUMBER        NOT NULL,
  line_no           NUMBER(5)     NOT NULL,
  order_no          NUMBER(5)     NOT NULL,
  doc_type_code     VARCHAR2(20)  NOT NULL,
  warehouse_code    VARCHAR2(5),
  product_code      VARCHAR2(80)  NOT NULL,
  description_1     VARCHAR2(60),
  description_2     VARCHAR2(120),
  quantity          NUMBER(16,4),
  unit_code         VARCHAR2(12),
  unit_price        NUMBER(16,4),
  amount            NUMBER(16,4),
  discount_rate     NUMBER(5,2),
  sale_price        NUMBER(16,4),
  line_type         VARCHAR2(10),
  unit_price_ht     NUMBER(16,4),
  amount_ht         NUMBER(16,4),
  source_line_no    NUMBER(4),
  transferred_qty   NUMBER(16,4),
  coefficient       NUMBER(10,5),
  delivery_delay    NUMBER(3),
  deducted_qty      NUMBER(15,3),
  is_line_closed    VARCHAR2(4)   DEFAULT 'N',
  cost_price        NUMBER(16,4),
  cost_amount       NUMBER(16,4),
  is_exempt         VARCHAR2(4)   DEFAULT 'N',
  nb_packages       NUMBER(3),
  free_text_1       VARCHAR2(255),
  free_amount_1     NUMBER(16,4),
  source_doc_id     NUMBER,
  source_option     VARCHAR2(1),
  validated_qty     NUMBER(15,3),
  tax_rate          NUMBER(5,2),
  tax_amount        NUMBER(15,3),
  stat_code         VARCHAR2(3),
  is_promo          VARCHAR2(1),
  is_dlv            VARCHAR2(1),
  CONSTRAINT pk_doc_line PRIMARY KEY (doc_id, line_no),
  CONSTRAINT fk_doc_line_header FOREIGN KEY (doc_id) 
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT ck_doc_line_closed CHECK (is_line_closed IN ('O','N'))
);

CREATE INDEX ix_doc_line_product ON doc_line(product_code);
CREATE INDEX ix_doc_line_warehouse ON doc_line(warehouse_code);

PROMPT [4] Table doc_log
CREATE TABLE doc_log (
  doc_id            NUMBER        NOT NULL,
  operation_at      DATE          NOT NULL,
  user_code         VARCHAR2(20),
  operation_label   VARCHAR2(255),
  CONSTRAINT pk_doc_log PRIMARY KEY (doc_id, operation_at)
);

PROMPT [5] Table doc_promo
CREATE TABLE doc_promo (
  doc_id            NUMBER        NOT NULL,
  line_no           NUMBER(4)     NOT NULL,
  promo_code        VARCHAR2(5)   NOT NULL,
  promo_qty         NUMBER(16,3),
  base_qty          NUMBER(16,3),
  CONSTRAINT pk_doc_promo PRIMARY KEY (doc_id, line_no, promo_code),
  CONSTRAINT fk_doc_promo_line FOREIGN KEY (doc_id, line_no) 
    REFERENCES doc_line(doc_id, line_no) ON DELETE CASCADE
);

PROMPT
PROMPT [6] Insertion des types de documents

INSERT INTO doc_type (doc_type_code, doc_type_name, doc_category, direction, updates_stock, is_transfer, entry_mode)
VALUES ('SALE', 'Vente comptoir', 'SALES', 'OUT', TRUE, FALSE, 'QTY+PU');
INSERT INTO doc_type (doc_type_code, doc_type_name, doc_category, direction, updates_stock, is_transfer, entry_mode)
VALUES ('PURCHASE', 'Achat fournisseur', 'PURCHASE', 'IN', TRUE, FALSE, 'QTY+PU');
INSERT INTO doc_type (doc_type_code, doc_type_name, doc_category, direction, updates_stock, is_transfer, entry_mode)
VALUES ('TRANSFER', 'Transfert', 'STOCK', 'OUT', TRUE, TRUE, 'QTY');
INSERT INTO doc_type (doc_type_code, doc_type_name, doc_category, direction, updates_stock, is_transfer, entry_mode)
VALUES ('INVENTORY', 'Inventaire', 'STOCK', 'IN', TRUE, FALSE, 'QTY');
INSERT INTO doc_type (doc_type_code, doc_type_name, doc_category, direction, updates_stock, entry_mode)
VALUES ('QUOTE', 'Devis', 'SALES', 'OUT', FALSE, 'QTY+PU');
INSERT INTO doc_type (doc_type_code, doc_type_name, doc_category, direction, updates_stock, entry_mode)
VALUES ('RETURN', 'Retour', 'SALES', 'IN', TRUE, 'QTY+PU');

COMMIT;

PROMPT
PROMPT [7] Insertion d'un document de test
INSERT INTO doc_header (doc_type_code, doc_no, company_code, doc_date, 
                        warehouse_code, party_code, party_name, 
                        currency_code, status, created_by, created_at)
VALUES ('SALE', 1, 'COMP01', SYSDATE, 'DEP01', 
        'CLI001', 'Client Dupont',
        'XOF', 'VALID', 'ADMIN', SYSDATE);

INSERT INTO doc_line (doc_id, line_no, order_no, doc_type_code, warehouse_code,
                      product_code, description_1, quantity, unit_code,
                      unit_price, amount, sale_price, line_type, unit_price_ht,
                      amount_ht, is_line_closed)
VALUES (1, 1, 1, 'SALE', 'DEP01',
        'ART001', 'Cahier 200p', 2, 'UNIT',
        2500, 5000, 2500, 'STD', 2118.64,
        4237.28, 'N');

INSERT INTO doc_line (doc_id, line_no, order_no, doc_type_code, warehouse_code,
                      product_code, description_1, quantity, unit_code,
                      unit_price, amount, sale_price, line_type, unit_price_ht,
                      amount_ht, is_line_closed)
VALUES (1, 2, 2, 'SALE', 'DEP01',
        'ART002', 'Stylo bleu', 10, 'UNIT',
        500, 5000, 500, 'STD', 423.73,
        4237.30, 'N');

-- Mise à jour des totaux
UPDATE doc_header 
   SET total_ht  = (SELECT SUM(amount_ht) FROM doc_line WHERE doc_id = 1),
       total_ttc = (SELECT SUM(amount) FROM doc_line WHERE doc_id = 1)
 WHERE doc_id = 1;

COMMIT;

PROMPT
PROMPT [8] Validation
SELECT doc_id, doc_type_code, doc_no, party_name, total_ht, total_ttc, status
  FROM doc_header;

SELECT doc_id, line_no, product_code, quantity, unit_price, amount
  FROM doc_line
 WHERE doc_id = 1;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_doc TERMINÉ
PROMPT ═══════════════════════════════════════════════════════