-- ============================================================
-- SCRIPT 08 : Schéma app_sales (Ventes / Tickets)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DU SCHÉMA app_sales
PROMPT ═══════════════════════════════════════════════════════

PROMPT [1] Table ticket
CREATE TABLE ticket (
  terminal_id       VARCHAR2(12)  NOT NULL,
  ticket_no         NUMBER(8)     NOT NULL,
  ticket_date       DATE,
  session_no        NUMBER(8)     NOT NULL,
  invoice_no        NUMBER(8),
  customer_code     VARCHAR2(32)  NOT NULL,
  customer_name     VARCHAR2(120),
  customer_addr_1   VARCHAR2(120),
  customer_addr_2   VARCHAR2(120),
  customer_addr_3   VARCHAR2(120),
  user_code         VARCHAR2(20)  NOT NULL,
  discount_rate     NUMBER(5,2),
  tax_code_1        VARCHAR2(4),
  tax_code_2        VARCHAR2(4),
  tax_code_3        VARCHAR2(4),
  tax_code_4        VARCHAR2(4),
  tax_amount_1      NUMBER(16,4),
  tax_amount_2      NUMBER(16,4),
  tax_amount_3      NUMBER(16,4),
  tax_amount_4      NUMBER(16,4),
  total_ttc         NUMBER(16,4),
  total_ht          NUMBER(16,4),
  ticket_total      NUMBER(16,4),
  cash_received     NUMBER(16,4),
  other_received    NUMBER(16,4),
  change_given      NUMBER(16,4),
  ticket_type       VARCHAR2(4),
  status            VARCHAR2(4) DEFAULT 'V',
  loyalty_base_amount NUMBER(16,3),
  loyalty_customer_id VARCHAR2(30),
  CONSTRAINT pk_ticket PRIMARY KEY (terminal_id, ticket_no),
  CONSTRAINT ck_ticket_status CHECK (status IN ('V','A','R'))
);

CREATE INDEX ix_ticket_date     ON ticket(ticket_date);
CREATE INDEX ix_ticket_customer ON ticket(customer_code);

PROMPT [2] Table ticket_line
CREATE TABLE ticket_line (
  terminal_id       VARCHAR2(12)  NOT NULL,
  ticket_no         NUMBER(8)     NOT NULL,
  line_no           NUMBER(3)     NOT NULL,
  product_code      VARCHAR2(80)  NOT NULL,
  description       VARCHAR2(120),
  quantity          NUMBER(16,4),
  unit_code         VARCHAR2(12),
  unit_price        NUMBER(16,4),
  discount_rate     NUMBER(5,2),
  unit_price_ht     NUMBER(16,4),
  doc_line_no       NUMBER(4),
  initial_unit_price NUMBER(16,4),
  coefficient       NUMBER(8,4),
  tax_rate          NUMBER(5,2),
  is_dlv            VARCHAR2(1),
  is_promo          VARCHAR2(1),
  unit_tax_code     VARCHAR2(1),
  unit_tax_rate     NUMBER(5,2),
  CONSTRAINT pk_ticket_line PRIMARY KEY (terminal_id, ticket_no, line_no),
  CONSTRAINT fk_ticket_line_ticket FOREIGN KEY (terminal_id, ticket_no) 
    REFERENCES ticket(terminal_id, ticket_no) ON DELETE CASCADE
);

CREATE INDEX ix_ticket_line_product ON ticket_line(product_code);

PROMPT [3] Table ticket_payment
CREATE TABLE ticket_payment (
  terminal_id       VARCHAR2(12)  NOT NULL,
  ticket_no         NUMBER(8)     NOT NULL,
  payment_method    VARCHAR2(12)  NOT NULL,
  payment_type      VARCHAR2(40),
  payment_ref       VARCHAR2(80),
  notes           VARCHAR2(200),
  amount            NUMBER(16,4),
  entry_no          NUMBER(8),
  CONSTRAINT pk_ticket_payment PRIMARY KEY (terminal_id, ticket_no, payment_method),
  CONSTRAINT fk_ticket_payment_ticket FOREIGN KEY (terminal_id, ticket_no) 
    REFERENCES ticket(terminal_id, ticket_no) ON DELETE CASCADE
);

PROMPT [4] Table ticket_arch (Archives)
CREATE TABLE ticket_arch (
  terminal_id       VARCHAR2(12)  NOT NULL,
  ticket_no         NUMBER(8)     NOT NULL,
  ticket_date       DATE,
  session_no        NUMBER(8),
  customer_code     VARCHAR2(32),
  customer_name     VARCHAR2(120),
  total_ttc         NUMBER(16,4),
  total_ht          NUMBER(16,4),
  status            VARCHAR2(4),
  archived_at       TIMESTAMP DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_ticket_arch PRIMARY KEY (terminal_id, ticket_no)
);

PROMPT [5] Table ticket_promo
CREATE TABLE ticket_promo (
  terminal_id       VARCHAR2(3)   NOT NULL,
  ticket_no         NUMBER(8)     NOT NULL,
  product_code      VARCHAR2(20)  NOT NULL,
  promo_code        VARCHAR2(5)   NOT NULL,
  promo_qty         NUMBER(16,3)  NOT NULL,
  CONSTRAINT pk_ticket_promo PRIMARY KEY (terminal_id, ticket_no, product_code, promo_code)
);

PROMPT
PROMPT [6] Insertion des tickets de test

INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, 
                    customer_code, customer_name, user_code, 
                    total_ttc, total_ht, ticket_total, status)
VALUES ('CAI01', 1, SYSDATE, 1, 'CLI001', 'Client Dupont', 'ADMIN',
        5000, 4237.29, 5000, 'V');

INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, 
                         description, quantity, unit_code, unit_price, 
                         unit_price_ht, tax_rate)
VALUES ('CAI01', 1, 1, 'ART001', 'Cahier 200 pages',
        2, 'UNIT', 2500, 2118.64, 18);

INSERT INTO ticket_payment (terminal_id, ticket_no, payment_method, 
                            payment_type, amount)
VALUES ('CAI01', 1, 'CASH', 'Espèces', 5000);

-- Ticket 2
INSERT INTO ticket (terminal_id, ticket_no, ticket_date, session_no, 
                    customer_code, customer_name, user_code, 
                    total_ttc, total_ht, ticket_total, status)
VALUES ('CAI01', 2, SYSDATE, 1, 'CLI002', 'Client Martin', 'ADMIN',
        15000, 12711.86, 15000, 'V');

INSERT INTO ticket_line (terminal_id, ticket_no, line_no, product_code, 
                         description, quantity, unit_code, unit_price, 
                         unit_price_ht, tax_rate)
VALUES ('CAI01', 2, 1, 'ART003', 'Clé USB 32 Go',
        1, 'UNIT', 15000, 12711.86, 18);

INSERT INTO ticket_payment (terminal_id, ticket_no, payment_method, 
                            payment_type, amount)
VALUES ('CAI01', 2, 'CARD', 'Carte bancaire', 15000);

COMMIT;

PROMPT
PROMPT [7] Validation
SELECT terminal_id, ticket_no, customer_name, total_ttc, status
  FROM ticket;

SELECT t.ticket_no, l.line_no, l.product_code, l.quantity, l.unit_price,
       l.quantity * l.unit_price AS montant
  FROM ticket t
  JOIN ticket_line l ON l.terminal_id = t.terminal_id AND l.ticket_no = t.ticket_no;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_sales TERMINÉ
PROMPT ═══════════════════════════════════════════════════════
