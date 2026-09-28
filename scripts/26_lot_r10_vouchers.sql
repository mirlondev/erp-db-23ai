-- ============================================================
-- SCRIPT 26 : LOT R10 — Cartes cadeaux / Bons d'achat
-- Migration Oracle 11g (CEBON, CEBON_LOT, ...)
--                  → Oracle 23ai/26ai (app_party)
-- ============================================================
-- 5 nouvelles tables dans app_party :
--   voucher_type, voucher_master, voucher_lot,
--   voucher_transaction, voucher_audit
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * BOOLEAN pour is_reusable, can_be_combined (legacy 'Y'/'N')
--  * user_code VARCHAR2(20) (vs 5 legacy)
--  * Status étendu : IS/PR/AC/US/CA/EX
--  * CHECK sur current_value >= 0 et <= initial_value
--  * Audit complet avec ip_address (VPD-ready)
--  * FK CASCADE sur les transactions (mais pas sur audit = on garde la trace)
--
-- CORRECTIONS ORACLE (vs version initiale) :
--  * ORA-02158 : Oracle ne supporte PAS "CREATE INDEX ... WHERE ..."
--    → ix_voucher_expiry : le WHERE était REDONDANT (Oracle B-tree n'indexe
--      jamais les lignes où la colonne est NULL). Simple index suffit.
--  * Idempotence : drop_if_exists au début
--  * DBMS_STATS pour peupler num_rows
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_party/AppParty#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R10 : CARTES CADEAUX & BONS D'ACHAT (5 tables)
PROMPT ══════════════════════════════════════════════════════════

-- ============================================================
-- NETTOYAGE préalable (idempotence)
-- ============================================================
PROMPT
PROMPT ═══ Nettoyage préalable (idempotence) ═══
DECLARE
  PROCEDURE drop_if_exists(p_type VARCHAR2, p_name VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP ' || p_type || ' ' || p_name;
    DBMS_OUTPUT.PUT_LINE('  DROP ' || p_type || ' ' || p_name);
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;
BEGIN
  drop_if_exists('TABLE', 'voucher_audit');
  drop_if_exists('TABLE', 'voucher_transaction');
  drop_if_exists('TABLE', 'voucher_master');
  drop_if_exists('TABLE', 'voucher_lot');
  drop_if_exists('TABLE', 'voucher_type');
END;
/

-- ============================================================
-- [1/5] voucher_type
-- ============================================================
PROMPT
PROMPT [1/5] voucher_type  — référentiel des types de bons
CREATE TABLE voucher_type (
  voucher_type_code   VARCHAR2(8)   NOT NULL,
  voucher_type_name   VARCHAR2(120) NOT NULL,
  is_reusable         BOOLEAN       DEFAULT FALSE,
  valid_months        NUMBER(3),
  min_value           NUMBER(16,4)  DEFAULT 0,
  max_value           NUMBER(16,4),
  can_be_combined     BOOLEAN       DEFAULT FALSE,
  is_active           BOOLEAN       DEFAULT TRUE,
  memo                VARCHAR2(255),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_voucher_type           PRIMARY KEY (voucher_type_code),
  CONSTRAINT ck_voucher_type_months    CHECK (valid_months IS NULL OR valid_months > 0),
  CONSTRAINT ck_voucher_type_minmax    CHECK (min_value >= 0
                                              AND (max_value IS NULL OR max_value >= min_value))
);

-- ============================================================
-- [2/5] voucher_master
-- ============================================================
PROMPT
PROMPT [2/5] voucher_master  (← CEBON) — bon d'achat
CREATE TABLE voucher_master (
  voucher_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  voucher_number         VARCHAR2(20)  NOT NULL,
  voucher_lot_no         NUMBER(8)     NOT NULL,
  voucher_type_code      VARCHAR2(8)   NOT NULL,
  issue_channel          VARCHAR2(2)   DEFAULT 'ST',
  issue_date             DATE          NOT NULL,
  initial_value          NUMBER(16,4)  NOT NULL,
  current_value          NUMBER(16,4)  NOT NULL,
  beneficiary_code       VARCHAR2(32),
  beneficiary_name       VARCHAR2(120),
  beneficiary_label      VARCHAR2(255) NOT NULL,
  issue_status           VARCHAR2(2)   DEFAULT 'IS',
  printed_at             DATE,
  printed_by             VARCHAR2(20),
  encashment_code        VARCHAR2(2),
  consumed_at            TIMESTAMP,
  consumed_ticket_no     NUMBER(8),
  consumed_terminal_code VARCHAR2(12),
  consumed_invoice_id    NUMBER,
  memo                   VARCHAR2(500),
  issued_by              VARCHAR2(20)  NOT NULL,
  issued_at              TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  expiry_date            DATE,
  CONSTRAINT pk_voucher_master             PRIMARY KEY (voucher_id),
  CONSTRAINT uk_voucher_number             UNIQUE (voucher_number),
  CONSTRAINT fk_voucher_master_type        FOREIGN KEY (voucher_type_code)
    REFERENCES voucher_type(voucher_type_code),
  CONSTRAINT ck_voucher_issue_channel      CHECK (issue_channel IN ('ST','WE','MO','CS','API')),
  CONSTRAINT ck_voucher_issue_status       CHECK (issue_status IN ('IS','PR','AC','US','CA','EX')),
  CONSTRAINT ck_voucher_values             CHECK (initial_value > 0
                                              AND current_value >= 0
                                              AND current_value <= initial_value)
);

CREATE INDEX ix_voucher_lot       ON voucher_master(voucher_lot_no);
CREATE INDEX ix_voucher_status    ON voucher_master(issue_status);
CREATE INDEX ix_voucher_benef     ON voucher_master(beneficiary_code);
CREATE INDEX ix_voucher_channel   ON voucher_master(issue_channel);

-- ⚠️ ORACLE : "CREATE INDEX ... WHERE ..." est INVALIDE (ORA-02158)
-- Ici le WHERE était REDONDANT : un index B-tree Oracle n'indexe JAMAIS
-- les lignes dont la colonne indexée est NULL. Donc un simple index
-- sur expiry_date a EXACTEMENT le même comportement qu'un "partial index"
-- sur "expiry_date IS NOT NULL".
PROMPT   → ix_voucher_expiry (index simple — le WHERE était redondant)
CREATE INDEX ix_voucher_expiry    ON voucher_master(expiry_date);

-- ============================================================
-- [3/5] voucher_lot
-- ============================================================
PROMPT
PROMPT [3/5] voucher_lot  — lots d'émission
CREATE TABLE voucher_lot (
  lot_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  lot_number          NUMBER(8)     NOT NULL,
  voucher_type_code   VARCHAR2(8)   NOT NULL,
  lot_name            VARCHAR2(120),
  initial_value       NUMBER(16,4)  NOT NULL,
  quantity            NUMBER(6)     NOT NULL,
  total_value         NUMBER(16,4)  GENERATED ALWAYS AS (initial_value * quantity),
  issued_qty          NUMBER(6)     DEFAULT 0,
  used_qty            NUMBER(6)     DEFAULT 0,
  issue_date          DATE          NOT NULL,
  expiry_date         DATE,
  created_by          VARCHAR2(20)  NOT NULL,
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_voucher_lot             PRIMARY KEY (lot_id),
  CONSTRAINT uk_voucher_lot_number      UNIQUE (lot_number),
  CONSTRAINT fk_voucher_lot_type        FOREIGN KEY (voucher_type_code)
    REFERENCES voucher_type(voucher_type_code),
  CONSTRAINT ck_voucher_lot_qty         CHECK (quantity > 0
                                              AND initial_value >= 0
                                              AND NVL(issued_qty,0) <= quantity)
);

CREATE INDEX ix_voucher_lot_type     ON voucher_lot(voucher_type_code);

-- ============================================================
-- [4/5] voucher_transaction
-- ============================================================
PROMPT
PROMPT [4/5] voucher_transaction  — historique transactions par bon
CREATE TABLE voucher_transaction (
  transaction_id      NUMBER GENERATED ALWAYS AS IDENTITY,
  voucher_id          NUMBER        NOT NULL,
  transaction_type    VARCHAR2(10)  NOT NULL,
  amount              NUMBER(16,4)  NOT NULL,
  balance_before      NUMBER(16,4)  NOT NULL,
  balance_after       NUMBER(16,4)  NOT NULL,
  terminal_code       VARCHAR2(12),
  ticket_no           NUMBER(8),
  transaction_at      TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  user_code           VARCHAR2(20),
  document_ref        VARCHAR2(120),
  notes               VARCHAR2(255),
  CONSTRAINT pk_voucher_transaction       PRIMARY KEY (transaction_id),
  CONSTRAINT fk_voucher_transaction_hdr   FOREIGN KEY (voucher_id)
    REFERENCES voucher_master(voucher_id) ON DELETE CASCADE,
  CONSTRAINT ck_voucher_trans_type        CHECK (transaction_type IN
    ('ISSUE','USE','RELOAD','EXPIRE','CANCEL','ADJUST')),
  CONSTRAINT ck_voucher_trans_amount      CHECK (amount > 0),
  CONSTRAINT ck_voucher_trans_balance     CHECK (
    balance_before >= 0
    AND balance_after >= 0
    AND balance_after <= balance_before + DECODE(transaction_type, 'RELOAD', amount, 0)
  )
);

CREATE INDEX ix_voucher_trans_voucher     ON voucher_transaction(voucher_id);
CREATE INDEX ix_voucher_trans_date        ON voucher_transaction(transaction_at);
CREATE INDEX ix_voucher_trans_type        ON voucher_transaction(transaction_type);
CREATE INDEX ix_voucher_trans_ticket      ON voucher_transaction(terminal_code, ticket_no);

-- ============================================================
-- [5/5] voucher_audit
-- ============================================================
PROMPT
PROMPT [5/5] voucher_audit  — audit complet (traçabilité réglementaire)
CREATE TABLE voucher_audit (
  audit_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  voucher_id          NUMBER        NOT NULL,
  action              VARCHAR2(30)  NOT NULL,
  old_status          VARCHAR2(2),
  new_status          VARCHAR2(2),
  old_value           NUMBER(16,4),
  new_value           NUMBER(16,4),
  performed_by        VARCHAR2(20)  NOT NULL,
  performed_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  ip_address          VARCHAR2(45),
  session_id          VARCHAR2(64),
  client_info         VARCHAR2(500),
  CONSTRAINT pk_voucher_audit             PRIMARY KEY (audit_id),
  CONSTRAINT fk_voucher_audit_hdr         FOREIGN KEY (voucher_id)
    REFERENCES voucher_master(voucher_id),
  CONSTRAINT ck_voucher_audit_action      CHECK (action IN
    ('CREATE','UPDATE','STATUS_CHANGE','BALANCE_CHANGE','PRINT','ENCODE','VOID'))
);

CREATE INDEX ix_voucher_audit_voucher     ON voucher_audit(voucher_id);
CREATE INDEX ix_voucher_audit_at          ON voucher_audit(performed_at);
CREATE INDEX ix_voucher_audit_action      ON voucher_audit(action);

-- ============================================================
-- Statistiques (pour peupler num_rows)
-- ============================================================
PROMPT
PROMPT ═══ Collecte des statistiques ═══
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(
    ownname          => 'APP_PARTY',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    cascade          => TRUE
  );
  DBMS_OUTPUT.PUT_LINE('  Statistiques collectées.');
END;
/

-- ============================================================
-- Privilèges croisés
-- ============================================================
PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT system/oracle@localhost:1521/FREEPDB1

-- app_sales émet et consomme les bons en caisse
GRANT SELECT, INSERT, UPDATE ON app_party.voucher_master       TO app_sales;
GRANT SELECT, INSERT         ON app_party.voucher_transaction  TO app_sales;
GRANT SELECT                 ON app_party.voucher_type         TO app_sales;
GRANT SELECT                 ON app_party.voucher_lot          TO app_sales;
GRANT SELECT                 ON app_party.voucher_audit        TO app_sales;

-- app_api pour exposition REST
GRANT SELECT ON app_party.voucher_master       TO app_api;
GRANT SELECT ON app_party.voucher_type         TO app_api;
GRANT SELECT ON app_party.voucher_lot          TO app_api;
GRANT SELECT ON app_party.voucher_transaction  TO app_api;
GRANT SELECT ON app_party.voucher_audit        TO app_api;

-- app_gl pour traçabilité comptable
GRANT SELECT ON app_party.voucher_master       TO app_gl;
GRANT SELECT ON app_party.voucher_transaction  TO app_gl;

-- ============================================================
-- VALIDATION FINALE
-- ============================================================
PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_party/AppParty#2026@localhost:1521/FREEPDB1

SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name LIKE 'VOUCHER%'
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT table_name, constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name LIKE 'VOUCHER%'
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Index
SELECT table_name, index_name, status
  FROM user_indexes
 WHERE table_name LIKE 'VOUCHER%'
 ORDER BY table_name, index_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R10 TERMINÉ (5 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;