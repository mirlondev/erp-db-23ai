-- ============================================================
-- SCRIPT 10 : Schéma app_cash
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_cash/AppCash#2026@localhost:1521/FREEPDB1

PROMPT [1] Table cash_register
CREATE TABLE cash_register (
  register_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  register_code     VARCHAR2(5)   NOT NULL,
  register_name     VARCHAR2(30),
  manager_name      VARCHAR2(30),
  voucher_counter   NUMBER(8)     DEFAULT 0,
  access_key        VARCHAR2(10),
  currency_code     VARCHAR2(3),
  journal_code      VARCHAR2(5),
  balance           NUMBER(16,4)  DEFAULT 0,
  created_at        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_cash_register      PRIMARY KEY (register_id),
  CONSTRAINT uk_cash_register_code UNIQUE (register_code)
);

PROMPT [2] Table cash_movement_type
CREATE TABLE cash_movement_type (
  movement_type_code VARCHAR2(3)  NOT NULL,
  movement_type_name VARCHAR2(40),
  direction          VARCHAR2(1),
  is_active          BOOLEAN      DEFAULT TRUE,
  created_at         TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_cash_mvt_type PRIMARY KEY (movement_type_code),
  CONSTRAINT ck_cash_mvt_dir CHECK (direction IN ('R','D'))
);

PROMPT [3] Table cash_journal
CREATE TABLE cash_journal (
  register_id       NUMBER        NOT NULL,
  journal_no        NUMBER(5)     NOT NULL,
  opened_by         VARCHAR2(5)   NOT NULL,
  opened_at         DATE          NOT NULL,
  opening_balance   NUMBER(16,4),
  total_receipts    NUMBER(16,4)  DEFAULT 0,
  total_payments    NUMBER(16,4)  DEFAULT 0,
  closed_by         VARCHAR2(5),
  closed_at         DATE,
  CONSTRAINT pk_cash_journal PRIMARY KEY (register_id, journal_no),
  CONSTRAINT fk_cash_journal_register FOREIGN KEY (register_id) 
    REFERENCES cash_register(register_id)
);

PROMPT [4] Table cash_movement
CREATE TABLE cash_movement (
  movement_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  register_id       NUMBER        NOT NULL,
  movement_date     DATE          NOT NULL,
  movement_type_code VARCHAR2(3)  NOT NULL,
  journal_no        NUMBER(4)     NOT NULL,
  person_name       VARCHAR2(40),
  amount            NUMBER(16,4),
  label             VARCHAR2(60),
  notes           VARCHAR2(1000),
  status            VARCHAR2(1)   DEFAULT 'V' NOT NULL,
  created_at        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  created_by        VARCHAR2(5)   NOT NULL,
  updated_at        TIMESTAMP,
  updated_by        VARCHAR2(5),
  CONSTRAINT pk_cash_movement PRIMARY KEY (movement_id),
  CONSTRAINT fk_cash_mvt_register FOREIGN KEY (register_id) 
    REFERENCES cash_register(register_id),
  CONSTRAINT fk_cash_mvt_type FOREIGN KEY (movement_type_code) 
    REFERENCES cash_movement_type(movement_type_code),
  CONSTRAINT ck_cash_mvt_status CHECK (status IN ('E','J','C','A','V'))
);

PROMPT
PROMPT [5] Insertion des données

INSERT INTO cash_register (register_code, register_name, manager_name, currency_code, balance)
VALUES ('C01', 'Caisse principale', 'Caissier 1', 'XOF', 0);

INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active)
VALUES ('REC', 'Recette', 'R', TRUE);
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active)
VALUES ('PAY', 'Dépense', 'D', TRUE);
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active)
VALUES ('TRF', 'Virement', 'D', TRUE);

INSERT INTO cash_journal (register_id, journal_no, opened_by, opened_at, opening_balance)
VALUES (1, 1, 'ADMIN', SYSDATE, 0);

INSERT INTO cash_movement (register_id, movement_date, movement_type_code, 
                           journal_no, person_name, amount, label, status, created_by)
VALUES (1, SYSDATE, 'REC', 1, 'Client Test', 5000, 'Vente comptoir', 'V', 'ADMIN');

UPDATE cash_register SET balance = balance + 5000 WHERE register_id = 1;

COMMIT;

PROMPT
PROMPT [6] Validation
SELECT register_code, register_name, balance FROM cash_register;
SELECT movement_id, person_name, amount, label, status FROM cash_movement;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_cash TERMINÉ
PROMPT ═══════════════════════════════════════════════════════