-- ============================================================
-- SCRIPT 22 : LOT R6 — Règlements clients avancés
-- Migration Oracle 11g (référentiels modes paiement, sessions caisse,
--                      lettrage, relances, balance âgée)
--                  → Oracle 23ai/26ai (app_ar)
-- ============================================================
-- 6 nouvelles tables dans app_ar (cf. procedure.txt) :
--   payment_method_ref, cash_register_session, invoice_payment_link,
--   customer_statement, aging_balance, dunning_log
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * BOOLEAN pour is_active / requires_reference (legacy 'Y'/'N')
--  * user_code VARCHAR2(20) (vs 5 legacy)
--  * CHECK explicites sur les statuts et les montants
--  * diff entre cash_register_session (back-office, réconciliation)
--    et app_pos.pos_session (front-office, terminal-driven) - séparation
--    volontaire car concepts différents
--  * Index ciblés sur party_code, dunning_level, snapshot_date
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R6 : RÈGLEMENTS CLIENTS AVANCÉS (6 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/6] payment_method_ref  — référentiel des modes de paiement
CREATE TABLE payment_method_ref (
  method_code          VARCHAR2(12)  NOT NULL,
  method_name          VARCHAR2(60)  NOT NULL,
  method_type          VARCHAR2(12)  NOT NULL,           -- CASH | CHECK | CARD | TRANSFER | MOBILE | OTHER
  journal_code         VARCHAR2(5),                     -- ex. 'CSH', 'BNK' (lien vers app_gl)
  gl_account_code      VARCHAR2(8),                     -- compte GL par défaut
  is_active            BOOLEAN       DEFAULT TRUE,
  requires_reference   BOOLEAN       DEFAULT FALSE,     -- ex. chèque → n° obligatoire
  max_amount           NUMBER(16,4),                    -- plafond (ex. mobile money)
  min_amount           NUMBER(16,4)  DEFAULT 0,
  commission_rate      NUMBER(5,2),                     -- % commission
  display_order        NUMBER(3)     DEFAULT 100,
  icon_code            VARCHAR2(20),                    -- pour l'UI
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_payment_method_ref       PRIMARY KEY (method_code),
  CONSTRAINT ck_payment_method_type      CHECK (method_type IN ('CASH','CHECK','CARD','TRANSFER','MOBILE','OTHER')),
  CONSTRAINT ck_payment_method_amounts   CHECK (max_amount IS NULL OR max_amount >= 0)
                                       , CHECK (min_amount >= 0),
  CONSTRAINT ck_payment_method_minmax    CHECK (max_amount IS NULL OR min_amount <= max_amount)
);

PROMPT
PROMPT [2/6] cash_register_session  — sessions de caisse back-office
CREATE TABLE cash_register_session (
  session_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  register_code        VARCHAR2(5)   NOT NULL,
  session_number       NUMBER(8)     NOT NULL,
  opened_by            VARCHAR2(20)  NOT NULL,
  opened_at            TIMESTAMP     NOT NULL,
  closed_by            VARCHAR2(20),
  closed_at            TIMESTAMP,
  opening_balance      NUMBER(16,4)  DEFAULT 0,
  closing_balance      NUMBER(16,4)  DEFAULT 0,           -- compté physique
  theoretical_balance  NUMBER(16,4),                     -- calculé (opening + total_cash - sorties)
  difference           NUMBER(16,4)  DEFAULT 0,           -- closing - theoretical
  total_cash           NUMBER(16,4)  DEFAULT 0,
  total_card           NUMBER(16,4)  DEFAULT 0,
  total_check          NUMBER(16,4)  DEFAULT 0,
  total_transfer       NUMBER(16,4)  DEFAULT 0,
  total_mobile         NUMBER(16,4)  DEFAULT 0,
  total_other          NUMBER(16,4)  DEFAULT 0,
  nb_transactions      NUMBER(8)     DEFAULT 0,
  status               VARCHAR2(20)  DEFAULT 'OPEN',      -- OPEN | CLOSED | RECONCILED
  validated_by         VARCHAR2(20),
  validated_at         TIMESTAMP,
  memo                 VARCHAR2(500),
  CONSTRAINT pk_cash_session             PRIMARY KEY (session_id),
  CONSTRAINT uk_cash_session             UNIQUE (register_code, session_number),
  CONSTRAINT ck_cash_sess_status         CHECK (status IN ('OPEN','CLOSED','RECONCILED')),
  CONSTRAINT ck_cash_sess_balance        CHECK (opening_balance >= 0 AND closing_balance >= 0)
);

CREATE INDEX ix_cash_session_register    ON cash_register_session(register_code);
CREATE INDEX ix_cash_session_status      ON cash_register_session(status);
CREATE INDEX ix_cash_session_opened      ON cash_register_session(opened_at);

PROMPT
PROMPT [3/6] invoice_payment_link  — lien direct facture ↔ paiement (hors allocations)
CREATE TABLE invoice_payment_link (
  link_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  invoice_id           NUMBER        NOT NULL,
  payment_id           NUMBER        NOT NULL,
  amount               NUMBER(16,4)  NOT NULL,
  linked_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  linked_by            VARCHAR2(20),
  memo                 VARCHAR2(255),
  CONSTRAINT pk_invoice_payment_link     PRIMARY KEY (link_id),
  CONSTRAINT uk_invoice_payment          UNIQUE (invoice_id, payment_id),
  CONSTRAINT fk_ipl_invoice              FOREIGN KEY (invoice_id)
    REFERENCES invoice(invoice_id) ON DELETE CASCADE,
  CONSTRAINT fk_ipl_payment              FOREIGN KEY (payment_id)
    REFERENCES payment(payment_id) ON DELETE CASCADE,
  CONSTRAINT ck_ipl_amount              CHECK (amount > 0)
);

CREATE INDEX ix_ipl_invoice              ON invoice_payment_link(invoice_id);
CREATE INDEX ix_ipl_payment              ON invoice_payment_link(payment_id);

PROMPT
PROMPT [4/6] customer_statement  — relevés client périodiques
CREATE TABLE customer_statement (
  statement_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  party_code           VARCHAR2(32)  NOT NULL,
  statement_date       DATE          NOT NULL,
  period_start         DATE          NOT NULL,
  period_end           DATE          NOT NULL,
  opening_balance      NUMBER(16,4)  DEFAULT 0,
  total_debit          NUMBER(16,4)  DEFAULT 0,           -- facturations
  total_credit         NUMBER(16,4)  DEFAULT 0,           -- règlements + avoirs
  closing_balance      NUMBER(16,4)  DEFAULT 0,
  nb_invoices          NUMBER(6)     DEFAULT 0,
  nb_payments          NUMBER(6)     DEFAULT 0,
  currency_code        VARCHAR2(12)  DEFAULT 'XOF',
  status               VARCHAR2(20)  DEFAULT 'DRAFT',     -- DRAFT | SENT | ACKNOWLEDGED | DISPUTED
  sent_at              TIMESTAMP,
  sent_to              VARCHAR2(120),                    -- email du client
  acknowledged_at      TIMESTAMP,
  format               VARCHAR2(10)  DEFAULT 'PDF',       -- PDF | CSV | HTML
  file_path            VARCHAR2(255),
  created_by           VARCHAR2(20),
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_customer_statement       PRIMARY KEY (statement_id),
  CONSTRAINT uk_customer_stmt            UNIQUE (party_code, statement_date),
  CONSTRAINT ck_statement_period         CHECK (period_end >= period_start),
  CONSTRAINT ck_statement_status         CHECK (status IN ('DRAFT','SENT','ACKNOWLEDGED','DISPUTED','ARCHIVED'))
);

CREATE INDEX ix_statement_party          ON customer_statement(party_code);
CREATE INDEX ix_statement_period         ON customer_statement(period_start, period_end);
CREATE INDEX ix_statement_status         ON customer_statement(status);

PROMPT
PROMPT [5/6] aging_balance  — snapshot balance âgée par client
CREATE TABLE aging_balance (
  snapshot_date        DATE          NOT NULL,
  party_code           VARCHAR2(32)  NOT NULL,
  company_code         VARCHAR2(12)  NOT NULL,
  current_amount       NUMBER(16,4)  DEFAULT 0,           -- non échu
  days_1_30            NUMBER(16,4)  DEFAULT 0,
  days_31_60           NUMBER(16,4)  DEFAULT 0,
  days_61_90           NUMBER(16,4)  DEFAULT 0,
  days_over_90         NUMBER(16,4)  DEFAULT 0,
  total_due            NUMBER(16,4)  DEFAULT 0,
  currency_code        VARCHAR2(12)  DEFAULT 'XOF',
  computed_at          TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_aging_balance            PRIMARY KEY (snapshot_date, company_code, party_code),
  CONSTRAINT ck_aging_amounts            CHECK (current_amount >= 0
                                              AND days_1_30 >= 0
                                              AND days_31_60 >= 0
                                              AND days_61_90 >= 0
                                              AND days_over_90 >= 0
                                              AND total_due >= 0),
  CONSTRAINT ck_aging_total              CHECK (total_due = (NVL(current_amount,0) + NVL(days_1_30,0)
                                              + NVL(days_31_60,0) + NVL(days_61_90,0) + NVL(days_over_90,0)) - 0)
                                          -- ^ tolérance 0 pour ON DELETE CASCADE : recalculé en MV de toute façon
);

CREATE INDEX ix_aging_party              ON aging_balance(party_code);
CREATE INDEX ix_aging_date               ON aging_balance(snapshot_date);

PROMPT
PROMPT [6/6] dunning_log  — journal des relances
CREATE TABLE dunning_log (
  log_id               NUMBER GENERATED ALWAYS AS IDENTITY,
  party_code           VARCHAR2(32)  NOT NULL,
  invoice_id           NUMBER        NOT NULL,
  dunning_level        NUMBER(2)     NOT NULL,           -- 1=aimable, 2=ferme, 3=contentieux
  dunning_date         DATE          NOT NULL,
  amount_due           NUMBER(16,4),
  days_overdue         NUMBER(4),
  contact_method       VARCHAR2(20),                     -- EMAIL | SMS | CALL | LETTER
  contact_detail       VARCHAR2(120),
  message              VARCHAR2(2000),
  status               VARCHAR2(20)  DEFAULT 'SENT',     -- SENT | PENDING | RESPONDED | FAILED
  response_received_at TIMESTAMP,
  response_detail      VARCHAR2(2000),
  created_by           VARCHAR2(20),
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_dunning_log              PRIMARY KEY (log_id),
  CONSTRAINT fk_dunning_invoice          FOREIGN KEY (invoice_id)
    REFERENCES invoice(invoice_id) ON DELETE CASCADE,
  CONSTRAINT ck_dunning_level            CHECK (dunning_level BETWEEN 1 AND 5),
  CONSTRAINT ck_dunning_status           CHECK (status IN ('SENT','PENDING','RESPONDED','FAILED','CANCELLED')),
  CONSTRAINT ck_dunning_method           CHECK (contact_method IS NULL OR contact_method IN ('EMAIL','SMS','CALL','LETTER','PUSH'))
);

CREATE INDEX ix_dunning_party            ON dunning_log(party_code);
CREATE INDEX ix_dunning_invoice          ON dunning_log(invoice_id);
CREATE INDEX ix_dunning_date             ON dunning_log(dunning_date);
CREATE INDEX ix_dunning_level            ON dunning_log(dunning_level, dunning_date);

PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT system/oracle@localhost:1521/FREEPDB1

-- app_cash peut lire les sessions (rapprochement)
GRANT SELECT ON app_ar.cash_register_session TO app_cash;
-- app_pos peut lire aussi (réconciliation temps réel)
GRANT SELECT ON app_ar.cash_register_session TO app_pos;
-- app_gl pour la compta
GRANT SELECT ON app_ar.payment_method_ref     TO app_gl;
GRANT SELECT ON app_ar.invoice_payment_link  TO app_gl;
GRANT SELECT ON app_ar.aging_balance         TO app_gl;
GRANT SELECT ON app_ar.dunning_log          TO app_gl;
-- app_party pour le suivi client
GRANT SELECT ON app_ar.customer_statement    TO app_party;
GRANT SELECT ON app_ar.aging_balance         TO app_party;
-- app_api (exposition JSON)
GRANT SELECT ON app_ar.payment_method_ref     TO app_api;
GRANT SELECT ON app_ar.cash_register_session  TO app_api;
GRANT SELECT ON app_ar.invoice_payment_link    TO app_api;
GRANT SELECT ON app_ar.customer_statement      TO app_api;
GRANT SELECT ON app_ar.aging_balance           TO app_api;
GRANT SELECT ON app_ar.dunning_log             TO app_api;

PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('PAYMENT_METHOD_REF','CASH_REGISTER_SESSION','INVOICE_PAYMENT_LINK',
                      'CUSTOMER_STATEMENT','AGING_BALANCE','DUNNING_LOG')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('PAYMENT_METHOD_REF','CASH_REGISTER_SESSION','INVOICE_PAYMENT_LINK',
                      'CUSTOMER_STATEMENT','AGING_BALANCE','DUNNING_LOG')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R6 TERMINÉ (6 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
