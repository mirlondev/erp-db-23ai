-- ============================================================
-- SCRIPT 18 : LOT R2 — Fidélité client
-- Migration Oracle 11g (CEPCFTYPCARTE, CEPCFCARTE, CECFOPER, etc.)
--                  → Oracle 23ai/26ai (app_party)
-- ============================================================
-- 7 nouvelles tables dans app_party :
--   loyalty_card_type, loyalty_card, loyalty_operation_type,
--   loyalty_operation, loyalty_lot, loyalty_app, loyalty_log
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * Types d'opération: operation_type_code passe à VARCHAR2(8) (vs 3/4 incohérents)
--  * BOOLEAN pour is_entry_allowed (legacy 'Y'/'N')
--  * BOOLEAN pour environment_type_is_production (legacy 'P'/'T')
--  * user_code VARCHAR2(20) (vs VARCHAR2(5) legacy trop court)
--  * 1 INDEX unique sur loyalty_lot pour idempotence ticket
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_party/AppParty#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R2 : FIDÉLITÉ CLIENT (7 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/7] loyalty_card_type  (← CEPCFTYPCARTE)
CREATE TABLE loyalty_card_type (
  card_type_code        VARCHAR2(8)   NOT NULL,
  card_type_name        VARCHAR2(120) NOT NULL,
  point_value           NUMBER(12,4),                          -- valeur d'1 point en devise
  point_threshold       NUMBER(12),                            -- seuil pour upgrade
  bonus_rate            NUMBER(5,2),                           -- % bonus à l'upgrade
  inactive_reset_days   NUMBER(5),                             -- reset après N jours d'inactivité
  is_active             BOOLEAN       DEFAULT TRUE,
  memo                  VARCHAR2(255),
  created_by            VARCHAR2(20)  NOT NULL,
  created_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by            VARCHAR2(20),
  updated_at            TIMESTAMP,
  CONSTRAINT pk_loyalty_card_type        PRIMARY KEY (card_type_code),
  CONSTRAINT ck_loyalty_card_bonus       CHECK (bonus_rate IS NULL OR (bonus_rate >= 0 AND bonus_rate <= 100))
);

PROMPT [2/7] loyalty_card  (← CEPCFCARTE)
CREATE TABLE loyalty_card (
  card_id               NUMBER GENERATED ALWAYS AS IDENTITY,
  card_number           VARCHAR2(20)  NOT NULL,
  card_type_code        VARCHAR2(8)   NOT NULL,
  status                VARCHAR2(2)   DEFAULT 'A',             -- A=Active, I=Inactive, B=Blocked, L=Locked
  title                 VARCHAR2(10),
  last_name             VARCHAR2(60),
  first_name            VARCHAR2(60),
  mobile_phone_1        VARCHAR2(20),
  mobile_phone_2        VARCHAR2(20),
  office_phone          VARCHAR2(20),
  home_phone            VARCHAR2(20),
  personal_email        VARCHAR2(120),
  pro_email             VARCHAR2(120),
  po_box                VARCHAR2(20),
  city_code             VARCHAR2(3),
  address               VARCHAR2(255),
  country_code          VARCHAR2(3),
  points_balance        NUMBER(12)    DEFAULT 0 NOT NULL,
  total_earned_points   NUMBER(12)    DEFAULT 0 NOT NULL,
  total_used_points     NUMBER(12)    DEFAULT 0 NOT NULL,
  last_used_at          DATE,
  issue_date            DATE          DEFAULT SYSDATE,
  expiry_date           DATE,
  party_id              NUMBER,                                -- FK vers app_party.party (lien client)
  created_by            VARCHAR2(20),
  created_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by            VARCHAR2(20),
  updated_at            TIMESTAMP,
  CONSTRAINT pk_loyalty_card             PRIMARY KEY (card_id),
  CONSTRAINT uk_loyalty_card_number      UNIQUE (card_number),
  CONSTRAINT fk_loyalty_card_type        FOREIGN KEY (card_type_code)
    REFERENCES loyalty_card_type(card_type_code),
  CONSTRAINT ck_loyalty_card_status      CHECK (status IN ('A','I','B','L')),
  CONSTRAINT ck_loyalty_card_points      CHECK (points_balance >= 0)
);

CREATE INDEX ix_loyalty_card_party ON loyalty_card(party_id);
CREATE INDEX ix_loyalty_card_status ON loyalty_card(status);

PROMPT [3/7] loyalty_operation_type  (← CEPCFTYPOPER)
CREATE TABLE loyalty_operation_type (
  operation_type_code   VARCHAR2(8)   NOT NULL,
  operation_type_name   VARCHAR2(60)  NOT NULL,
  is_entry_allowed      BOOLEAN       DEFAULT TRUE,             -- l'opération est-elle autorisée en saisie
  sign                  VARCHAR2(1)   NOT NULL,                 -- '+' crédit, '-' débit
  description           VARCHAR2(255),
  is_active             BOOLEAN       DEFAULT TRUE,
  created_by            VARCHAR2(20)  NOT NULL,
  created_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_loyalty_operation_type  PRIMARY KEY (operation_type_code),
  CONSTRAINT ck_loyalty_op_sign         CHECK (sign IN ('+','-'))
);

PROMPT [4/7] loyalty_operation  (← CECFOPER)
CREATE TABLE loyalty_operation (
  operation_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  card_id               NUMBER        NOT NULL,
  operation_type_code   VARCHAR2(8)   NOT NULL,
  operation_date        DATE          NOT NULL,
  terminal_code         VARCHAR2(12),                          -- ex. 'CAI01'
  ticket_no             NUMBER(8),
  points                NUMBER(12)    NOT NULL,                 -- valeur signée
  amount                NUMBER(16,4),                          -- montant achat sous-jacent
  label                 VARCHAR2(255),
  expiry_date           DATE,                                  -- date d'expiration des points (si applicable)
  document_ref          VARCHAR2(120),
  created_by            VARCHAR2(20)  NOT NULL,
  created_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_loyalty_operation        PRIMARY KEY (operation_id),
  CONSTRAINT fk_loyalty_operation_card   FOREIGN KEY (card_id)
    REFERENCES loyalty_card(card_id) ON DELETE CASCADE,
  CONSTRAINT fk_loyalty_operation_type  FOREIGN KEY (operation_type_code)
    REFERENCES loyalty_operation_type(operation_type_code),
  CONSTRAINT ck_loyalty_op_notzero       CHECK (points <> 0)
);

CREATE INDEX ix_loyalty_operation_card  ON loyalty_operation(card_id, operation_date);
CREATE INDEX ix_loyalty_operation_date  ON loyalty_operation(operation_date);
CREATE INDEX ix_loyalty_operation_ticket ON loyalty_operation(terminal_code, ticket_no);

PROMPT [5/7] loyalty_lot  (← CECFLOT) — cumul par ticket (idempotence)
CREATE TABLE loyalty_lot (
  lot_line_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  customer_id           NUMBER        NOT NULL,
  last_name             VARCHAR2(60),
  first_name            VARCHAR2(60),
  mobile_phone          VARCHAR2(20),
  lot_id                NUMBER(8),
  amount                NUMBER(16,4),
  warehouse_id          NUMBER(8),
  terminal_code         VARCHAR2(12)  NOT NULL,
  ticket_no             NUMBER(8)     NOT NULL,
  order_id              NUMBER(8)     NOT NULL,
  points                NUMBER(12),
  created_by            VARCHAR2(20)  NOT NULL,
  created_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_loyalty_lot             PRIMARY KEY (lot_line_id),
  CONSTRAINT uk_loyalty_lot_ticket      UNIQUE (terminal_code, ticket_no, order_id)
);

CREATE INDEX ix_loyalty_lot_customer ON loyalty_lot(customer_id);

PROMPT [6/7] loyalty_app  (← CFID_APP) — configuration API fidélité externe
CREATE TABLE loyalty_app (
  app_code              VARCHAR2(8)   NOT NULL,
  app_name              VARCHAR2(120) NOT NULL,
  is_production         BOOLEAN       DEFAULT FALSE,           -- T=Production, P=Production (legacy inverse) → BOOLEAN clair
  app_key               VARCHAR2(64)  NOT NULL,
  value_purchase_1pt    NUMBER(12,4)  NOT NULL,                -- 1 point gagné pour N XOF d'achat
  value_conversion_1pt  NUMBER(12,4)  NOT NULL,                -- 1 point vaut N XOF
  base_url              VARCHAR2(255) NOT NULL,
  cust_detail_api       VARCHAR2(255) NOT NULL,
  cust_wallet_api       VARCHAR2(255) NOT NULL,
  debit_wallet_api      VARCHAR2(255) NOT NULL,
  recharge_wallet_api   VARCHAR2(255) NOT NULL,
  cust_type_api         VARCHAR2(255) NOT NULL,
  cancel_receipt_api    VARCHAR2(255),
  is_active             BOOLEAN       DEFAULT TRUE,
  created_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_loyalty_app             PRIMARY KEY (app_code)
);

PROMPT [7/7] loyalty_log  (← CFID_LOG) — journal d'appels API
CREATE TABLE loyalty_log (
  log_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  claim_option          VARCHAR2(4),
  ticket_no             NUMBER(8),
  terminal_code         VARCHAR2(12),
  loyalty_customer_id   VARCHAR2(30),
  points                NUMBER(8),
  reason                VARCHAR2(255),
  user_code             VARCHAR2(20)  NOT NULL,
  order_id              NUMBER(8),
  wallet_id             NUMBER(8),
  wallet_line_id        NUMBER(8),
  operation_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_loyalty_log             PRIMARY KEY (log_id)
);

CREATE INDEX ix_loyalty_log_ticket ON loyalty_log(terminal_code, ticket_no);
CREATE INDEX ix_loyalty_log_cust   ON loyalty_log(loyalty_customer_id);
CREATE INDEX ix_loyalty_log_at     ON loyalty_log(operation_at);

PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA
GRANT SELECT, INSERT, UPDATE ON app_party.loyalty_card          TO app_sales;
GRANT SELECT, INSERT, UPDATE ON app_party.loyalty_operation     TO app_sales;
GRANT SELECT, INSERT         ON app_party.loyalty_operation_type TO app_sales;
GRANT SELECT, INSERT, UPDATE ON app_party.loyalty_lot           TO app_sales;
GRANT SELECT                 ON app_party.loyalty_card_type     TO app_sales;
GRANT SELECT                 ON app_party.loyalty_app           TO app_sales;
GRANT SELECT                 ON app_party.loyalty_log           TO app_sales;

-- Trigger lecture seule pour app_api (consultation)
GRANT SELECT ON app_party.loyalty_card       TO app_api;
GRANT SELECT ON app_party.loyalty_operation  TO app_api;

PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_party/AppParty#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name LIKE 'LOYALTY%'
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name LIKE 'LOYALTY%'
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R2 TERMINÉ (7 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
