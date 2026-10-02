-- ============================================================
-- SCRIPT 45 : LOT 1G — Factures & Règlements (compléments)
-- Migration Oracle 11g → 23ai/26ai (app_ar enrichi)
-- ============================================================
-- 5 nouvelles tables de complément (Lot 1G, partiellement couvert par R5/R6).
-- Cible : gestion avancée des litiges, recouvrements, échéanciers.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT 1G : 5 tables dans app_ar (compléments)
PROMPT ══════════════════════════════════════════════════════════

GRANT SELECT, INSERT ON app_party.party TO app_ar;

CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [1/5] invoice_installment  (échéanciers de paiement)
CREATE TABLE invoice_installment (
  installment_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  invoice_id        NUMBER        NOT NULL,
  installment_no    NUMBER(3)     NOT NULL,
  due_date          DATE          NOT NULL,
  amount            NUMBER(16,4)  NOT NULL,
  paid_amount       NUMBER(16,4)  DEFAULT 0,
  paid_at           TIMESTAMP,
  payment_id        NUMBER,
  status            VARCHAR2(20)  DEFAULT 'PENDING',     -- PENDING | PARTIAL | PAID | OVERDUE
  CONSTRAINT pk_invoice_installment        PRIMARY KEY (installment_id),
  CONSTRAINT fk_invoice_installment_inv    FOREIGN KEY (invoice_id)
    REFERENCES invoice(invoice_id) ON DELETE CASCADE,
  CONSTRAINT ck_invoice_installment_status CHECK (status IN ('PENDING','PARTIAL','PAID','OVERDUE','CANCELLED')),
  CONSTRAINT ck_invoice_installment_amount CHECK (amount > 0 AND NVL(paid_amount, 0) >= 0)
);

CREATE INDEX ix_invoice_installment_inv    ON invoice_installment(invoice_id);
CREATE INDEX ix_invoice_installment_due     ON invoice_installment(due_date, status);

PROMPT
PROMPT [2/5] invoice_dispute  (litiges sur factures)
CREATE TABLE invoice_dispute (
  dispute_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  invoice_id        NUMBER        NOT NULL,
  opened_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  opened_by         VARCHAR2(20)  NOT NULL,
  reason_code       VARCHAR2(20)  NOT NULL,               -- DUPLICATE | WRONG_AMOUNT | MISSING_ITEMS | QUALITY | DELIVERY | OTHER
  description       VARCHAR2(2000) NOT NULL,
  amount_disputed   NUMBER(16,4),                        -- montant contesté (NULL = total)
  status            VARCHAR2(20)  DEFAULT 'OPEN',        -- OPEN | UNDER_REVIEW | RESOLVED | REJECTED | ESCALATED
  resolved_at       TIMESTAMP,
  resolved_by       VARCHAR2(20),
  resolution        VARCHAR2(2000),                      -- ACCEPTED | CREDIT_NOTE_ISSUED | REJECTED
  credit_note_id    NUMBER,                              -- si résolu par avoir
  CONSTRAINT pk_invoice_dispute           PRIMARY KEY (dispute_id),
  CONSTRAINT fk_invoice_dispute_inv       FOREIGN KEY (invoice_id)
    REFERENCES invoice(invoice_id) ON DELETE CASCADE,
  CONSTRAINT ck_invoice_dispute_status    CHECK (status IN ('OPEN','UNDER_REVIEW','RESOLVED','REJECTED','ESCALATED','CANCELLED'))
);

CREATE INDEX ix_invoice_dispute_status    ON invoice_dispute(status, opened_at);
CREATE INDEX ix_invoice_dispute_invoice   ON invoice_dispute(invoice_id);

PROMPT
PROMPT [3/5] dunning_schedule  (programme de relances par client)
CREATE TABLE dunning_schedule (
  schedule_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  schedule_code     VARCHAR2(20)  NOT NULL,
  schedule_name     VARCHAR2(120) NOT NULL,
  description       VARCHAR2(500),
  is_active         BOOLEAN       DEFAULT TRUE,
  -- 4 niveaux de relance : amical (J+7), ferme (J+15), mise en demeure (J+30), contentieux (J+60)
  level_1_days      NUMBER(4)     DEFAULT 7,
  level_1_method    VARCHAR2(20)  DEFAULT 'EMAIL',
  level_2_days      NUMBER(4)     DEFAULT 15,
  level_2_method    VARCHAR2(20)  DEFAULT 'SMS',
  level_3_days      NUMBER(4)     DEFAULT 30,
  level_3_method    VARCHAR2(20)  DEFAULT 'LETTER',
  level_4_days      NUMBER(4)     DEFAULT 60,
  level_4_method    VARCHAR2(20)  DEFAULT 'CALL',
  fee_level_3       NUMBER(16,4)  DEFAULT 0,             -- frais de retard
  fee_level_4       NUMBER(16,4)  DEFAULT 0,
  created_by        VARCHAR2(20),
  created_at        TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_dunning_schedule             PRIMARY KEY (schedule_id),
  CONSTRAINT uk_dunning_schedule_code        UNIQUE (schedule_code),
  CONSTRAINT ck_dunning_schedule_method      CHECK (level_1_method IN ('EMAIL','SMS','CALL','LETTER','PUSH'))
);

PROMPT
PROMPT [4/5] collection_case  (dossier de recouvrement)
CREATE TABLE collection_case (
  case_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  case_number       VARCHAR2(20)  NOT NULL,
  case_type         VARCHAR2(20)  NOT NULL,              -- AMICABLE | FORMAL | LEGAL
  party_code        VARCHAR2(32)  NOT NULL,
  company_code      VARCHAR2(12)  NOT NULL,
  opened_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  opened_by         VARCHAR2(20)  NOT NULL,
  assigned_to       VARCHAR2(20),                       -- agent de recouvrement
  total_claimed     NUMBER(16,4) NOT NULL,
  total_recovered   NUMBER(16,4)  DEFAULT 0,
  lawyer_name       VARCHAR2(120),
  lawyer_ref        VARCHAR2(120),
  court_name        VARCHAR2(120),
  court_ref         VARCHAR2(120),
  status            VARCHAR2(20)  DEFAULT 'OPEN',       -- OPEN | NEGOTIATING | COURT | RECOVERED | CLOSED | CANCELLED
  closed_at         TIMESTAMP,
  closure_notes     VARCHAR2(2000),
  CONSTRAINT pk_collection_case             PRIMARY KEY (case_id),
  CONSTRAINT uk_collection_case_no          UNIQUE (case_number),
  CONSTRAINT ck_collection_case_type        CHECK (case_type IN ('AMICABLE','FORMAL','LEGAL')),
  CONSTRAINT ck_collection_case_status      CHECK (status IN ('OPEN','NEGOTIATING','COURT','RECOVERED','CLOSED','CANCELLED')),
  CONSTRAINT ck_collection_case_amount      CHECK (total_claimed > 0 AND NVL(total_recovered, 0) >= 0)
);

CREATE INDEX ix_collection_case_party       ON collection_case(party_code);
CREATE INDEX ix_collection_case_status       ON collection_case(status);

PROMPT
PROMPT [5/5] collection_case_invoice  — liaison dossier/factures
CREATE TABLE collection_case_invoice (
  case_id           NUMBER        NOT NULL,
  invoice_id        NUMBER        NOT NULL,
  amount            NUMBER(16,4)  NOT NULL,
  recovered_amount  NUMBER(16,4)  DEFAULT 0,
  CONSTRAINT pk_collection_case_inv         PRIMARY KEY (case_id, invoice_id),
  CONSTRAINT fk_coll_case_inv_case          FOREIGN KEY (case_id)
    REFERENCES collection_case(case_id) ON DELETE CASCADE,
  CONSTRAINT fk_coll_case_inv_inv           FOREIGN KEY (invoice_id)
    REFERENCES invoice(invoice_id),
  CONSTRAINT ck_coll_case_inv_amount        CHECK (amount > 0 AND NVL(recovered_amount,0) >= 0)
);

PROMPT
PROMPT ═══ Privilèges ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

GRANT SELECT ON app_ar.invoice_installment       TO app_api;
GRANT SELECT ON app_ar.invoice_dispute           TO app_api;
GRANT SELECT ON app_ar.dunning_schedule          TO app_api;
GRANT SELECT ON app_ar.collection_case           TO app_api;
GRANT SELECT ON app_ar.collection_case_invoice   TO app_api;
GRANT SELECT ON app_ar.invoice_installment       TO app_gl;
GRANT SELECT ON app_ar.invoice_dispute           TO app_gl;
GRANT SELECT ON app_ar.dunning_schedule          TO app_gl;
GRANT SELECT ON app_ar.collection_case           TO app_gl;
GRANT SELECT ON app_ar.collection_case_invoice   TO app_gl;
GRANT SELECT ON app_ar.collection_case           TO app_party;

PROMPT
PROMPT ═══ Validation ═══
CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('INVOICE_INSTALLMENT','INVOICE_DISPUTE','DUNNING_SCHEDULE',
                      'COLLECTION_CASE','COLLECTION_CASE_INVOICE')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Objets invalides
SELECT object_name, object_type, status
  FROM user_objects WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT 1G TERMINÉ (5 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
