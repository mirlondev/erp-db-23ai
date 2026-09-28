-- ============================================================
-- SCRIPT 07 : Schéma app_pos (Point of Sale)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_pos/AppPos#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DU SCHÉMA app_pos
PROMPT ═══════════════════════════════════════════════════════

PROMPT [1] Table pos_terminal
CREATE TABLE pos_terminal (
  terminal_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  terminal_code     VARCHAR2(12)  NOT NULL,
  terminal_name     VARCHAR2(120) NOT NULL,
  currency_code     VARCHAR2(12)  NOT NULL,
  last_ticket_no    NUMBER(8)     DEFAULT 0,
  access_key        VARCHAR2(40)  NOT NULL,
  last_session_balance NUMBER(16,4) DEFAULT 0,
  last_invoice_no   NUMBER(8)     DEFAULT 0,
  warehouse_code    VARCHAR2(5),
  display_type      VARCHAR2(20),
  price_list_code   VARCHAR2(12),
  pos_code          VARCHAR2(5),
  is_active         BOOLEAN       DEFAULT TRUE,
  created_at        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_pos_terminal      PRIMARY KEY (terminal_id),
  CONSTRAINT uk_pos_terminal_code UNIQUE (terminal_code)
);

PROMPT [2] Table pos_session
CREATE TABLE pos_session (
  terminal_id       NUMBER        NOT NULL,
  session_no        NUMBER(8)     NOT NULL,
  user_code         VARCHAR2(20)  NOT NULL,
  opened_at         DATE,
  closed_at         DATE,
  opening_balance   NUMBER(16,4)  DEFAULT 0 NOT NULL,
  closing_balance   NUMBER(16,4)  DEFAULT 0,
  theoretical_balance NUMBER(16,4),
  transfer_amount   NUMBER(16,4)  DEFAULT 0,
  drawer_open_count NUMBER(8)     DEFAULT 0,
  is_data_exported  BOOLEAN       DEFAULT FALSE,
  document_id       NUMBER,
  entry_no          NUMBER(8),
  is_interfaced     BOOLEAN       DEFAULT FALSE,
  CONSTRAINT pk_pos_session PRIMARY KEY (terminal_id, session_no),
  CONSTRAINT fk_pos_session_terminal FOREIGN KEY (terminal_id) 
    REFERENCES pos_terminal(terminal_id)
);

PROMPT [3] Table pos_cash_movement
CREATE TABLE pos_cash_movement (
  terminal_id       NUMBER        NOT NULL,
  session_no        NUMBER(8)     NOT NULL,
  movement_at       DATE          NOT NULL,
  movement_type     VARCHAR2(20)  NOT NULL,
  direction         VARCHAR2(4)   NOT NULL,
  amount            NUMBER(16,4)  NOT NULL,
  notes           VARCHAR2(120),
  order_no          NUMBER(4)     NOT NULL,
  CONSTRAINT pk_pos_cash_movement PRIMARY KEY (terminal_id, session_no, order_no),
  CONSTRAINT fk_pos_cash_mvt_session FOREIGN KEY (terminal_id, session_no) 
    REFERENCES pos_session(terminal_id, session_no) ON DELETE CASCADE,
  CONSTRAINT ck_pos_cash_dir CHECK (direction IN ('IN','OUT'))
);

PROMPT [4] Table pos_session_log
CREATE TABLE pos_session_log (
  log_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  terminal_id       VARCHAR2(12)  NOT NULL,
  operation_at      DATE          NOT NULL,
  user_code         VARCHAR2(20)  NOT NULL,
  operation_label   VARCHAR2(400),
  ticket_no         NUMBER(8),
  product_code      VARCHAR2(80),
  value_num_1       NUMBER(16,4),
  value_num_2       NUMBER(16,4),
  CONSTRAINT pk_pos_session_log PRIMARY KEY (log_id)
);

CREATE INDEX ix_pos_session_log_date ON pos_session_log(operation_at);

PROMPT [5] Table pos_session_bill
CREATE TABLE pos_session_bill (
  terminal_id       VARCHAR2(12)  NOT NULL,
  session_no        NUMBER(8)     NOT NULL,
  bill_type         VARCHAR2(20)  NOT NULL,
  quantity          NUMBER(8)     NOT NULL,
  amount            NUMBER(16,4),
  CONSTRAINT pk_pos_session_bill PRIMARY KEY (terminal_id, session_no, bill_type)
);

PROMPT
PROMPT [6] Insertion des données

INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, 
                          access_key, warehouse_code, price_list_code, pos_code)
VALUES ('CAI01', 'Caisse principale', 'XOF', 'POS_ACCESS', 'DEP01', 'STANDARD', '01');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, 
                          access_key, warehouse_code, price_list_code, pos_code)
VALUES ('CAI02', 'Caisse secondaire', 'XOF', 'POS_ACCESS', 'DEP02', 'STANDARD', '02');

INSERT INTO pos_session (terminal_id, session_no, user_code, opened_at, 
                         opening_balance, closing_balance)
VALUES (1, 1, 'ADMIN', SYSDATE, 0, 0);

INSERT INTO pos_cash_movement (terminal_id, session_no, movement_at, 
                                movement_type, direction, amount, notes, order_no)
VALUES (1, 1, SYSDATE, 'CASH_IN', 'IN', 50000, 'Fond de caisse initial', 1);

COMMIT;

PROMPT
PROMPT [7] Validation
SELECT terminal_id, terminal_code, terminal_name, is_active 
  FROM pos_terminal;
SELECT terminal_id, session_no, user_code, opening_balance 
  FROM pos_session;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_pos TERMINÉ
PROMPT ═══════════════════════════════════════════════════════
