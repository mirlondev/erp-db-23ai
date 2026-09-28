-- ============================================================
-- SCRIPT 21 : LOT R5 — Facturation & Avoirs
-- Migration Oracle 11g (CP_FACTURE, avoirs, règlements)
--                  → Oracle 23ai/26ai (nouveau schéma app_ar)
-- ============================================================
-- Le schéma app_ar est créé dans 00_init_schemas.sql (bootstrap).
-- Ce script ne fait que se connecter et créer les 7 tables.
--
-- 7 nouvelles tables dans app_ar :
--   invoice, invoice_line, credit_note, credit_note_line,
--   payment, payment_allocation, customer_credit
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * Devise par défaut harmonisée à XOF (au lieu de XAF legacy)
--  * user_code VARCHAR2(20) (vs 5 trop court)
--  * BOOLEAN pour blocked (legacy 'Y'/'N')
--  * status harmonisé sur 8 statuts
--  * CHECKs : amount_allocation cohérent, balance >= 0, etc.
--  * Index ciblés (date, party, status, due_date pour le suivi)
--
-- CORRECTIONS ORACLE (vs version initiale) :
--  * ORA-02158 : Oracle ne supporte PAS "CREATE INDEX ... WHERE ..."
--    → remplacé par index fonctionnel avec CASE (partial-index style)
--  * BOOLEAN ne peut pas être indexé directement en B-tree
--    → index fonctionnel CASE WHEN is_blocked THEN 1 END
--  * DBMS_STATS.GATHER_SCHEMA_STATS pour peupler num_rows
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R5 : FACTURATION & AVOIRS (7 tables dans app_ar)
PROMPT ══════════════════════════════════════════════════════════

-- ============================================================
-- NETTOYAGE : drop des objets s'ils existent (idempotence)
-- ============================================================
PROMPT
PROMPT ═══ Nettoyage préalable (idempotence) ═══
DECLARE
  PROCEDURE drop_if_exists(p_type VARCHAR2, p_name VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP ' || p_type || ' ' || p_name;
    DBMS_OUTPUT.PUT_LINE('  DROP ' || p_type || ' ' || p_name);
  EXCEPTION
    WHEN OTHERS THEN NULL;  -- n'existe pas, ok
  END;
BEGIN
  -- Tables (cascade sur les FK)
  drop_if_exists('TABLE', 'payment_allocation');
  drop_if_exists('TABLE', 'invoice_payment_link');
  drop_if_exists('TABLE', 'dunning_log');
  drop_if_exists('TABLE', 'aging_balance');
  drop_if_exists('TABLE', 'customer_statement');
  drop_if_exists('TABLE', 'cash_register_session');
  drop_if_exists('TABLE', 'payment_method_ref');
  drop_if_exists('TABLE', 'customer_credit');
  drop_if_exists('TABLE', 'payment');
  drop_if_exists('TABLE', 'credit_note_line');
  drop_if_exists('TABLE', 'credit_note');
  drop_if_exists('TABLE', 'invoice_line');
  drop_if_exists('TABLE', 'invoice');
END;
/

-- ============================================================
-- [1/7] invoice — entête facture client
-- ============================================================
PROMPT
PROMPT [1/7] invoice  (← CP_FACTURE) — entête facture client
CREATE TABLE invoice (
  invoice_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  invoice_number       VARCHAR2(20)  NOT NULL,
  invoice_date         DATE          NOT NULL,
  company_code         VARCHAR2(12)  NOT NULL,
  party_code           VARCHAR2(32)  NOT NULL,
  party_name           VARCHAR2(120),
  address_1            VARCHAR2(120),
  address_2            VARCHAR2(120),
  address_3            VARCHAR2(120),
  address_4            VARCHAR2(120),
  currency_code        VARCHAR2(12)  DEFAULT 'XOF',
  exchange_rate        NUMBER(10,5)  DEFAULT 1,
  due_date             DATE,
  payment_method       VARCHAR2(12),
  tax_regime           VARCHAR2(12),
  total_ht             NUMBER(16,4)  DEFAULT 0,
  total_tax            NUMBER(16,4)  DEFAULT 0,
  total_ttc            NUMBER(16,4)  DEFAULT 0,
  total_paid           NUMBER(16,4)  DEFAULT 0,
  balance              NUMBER(16,4)  DEFAULT 0,
  status               VARCHAR2(20)  DEFAULT 'DRAFT',
  document_ref         VARCHAR2(50),
  source_doc_id        NUMBER,
  source_ticket_term   VARCHAR2(12),
  source_ticket_no     NUMBER(8),
  memo                 VARCHAR2(2000),
  created_by           VARCHAR2(20),
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by           VARCHAR2(20),
  updated_at           TIMESTAMP,
  CONSTRAINT pk_invoice              PRIMARY KEY (invoice_id),
  CONSTRAINT uk_invoice_number       UNIQUE (invoice_number),
  CONSTRAINT ck_invoice_status       CHECK (status IN ('DRAFT','VALID','PARTIAL','PAID','OVERDUE','CANCELLED')),
  CONSTRAINT ck_invoice_amounts      CHECK (total_ht >= 0 AND total_tax >= 0 AND total_ttc >= 0
                                            AND total_paid >= 0 AND balance >= 0),
  CONSTRAINT ck_invoice_paid_le_ttc  CHECK (total_paid <= total_ttc)
);

CREATE INDEX ix_invoice_date         ON invoice(invoice_date);
CREATE INDEX ix_invoice_party        ON invoice(party_code);
CREATE INDEX ix_invoice_status       ON invoice(status);
CREATE INDEX ix_invoice_due          ON invoice(due_date);

-- ⚠️ ORACLE ne supporte PAS "CREATE INDEX ... WHERE ..." (ORA-02158)
-- Émulation d'un index partiel via index fonctionnel CASE.
-- L'index ne stocke QUE les lignes où status IN ('VALID','PARTIAL','OVERDUE').
PROMPT   → ix_invoice_overdue (index fonctionnel, émulation partial-index)
CREATE INDEX ix_invoice_overdue ON invoice(
  CASE WHEN status IN ('VALID','PARTIAL','OVERDUE') THEN status END,
  CASE WHEN status IN ('VALID','PARTIAL','OVERDUE') THEN due_date END
);

-- ============================================================
-- [2/7] invoice_line — lignes facture
-- ============================================================
PROMPT
PROMPT [2/7] invoice_line  (← CP_FACTURE_RUBR_CPT) — lignes facture
CREATE TABLE invoice_line (
  invoice_id           NUMBER        NOT NULL,
  line_no              NUMBER(5)     NOT NULL,
  product_code         VARCHAR2(80),
  description          VARCHAR2(120),
  quantity             NUMBER(16,4),
  unit_code            VARCHAR2(12),
  unit_price           NUMBER(16,4),
  amount               NUMBER(16,4),
  discount_rate        NUMBER(5,2),
  tax_rate             NUMBER(5,2),
  tax_amount           NUMBER(16,4),
  amount_ht            NUMBER(16,4),
  amount_ttc           NUMBER(16,4),
  source_ticket_no     NUMBER(8),
  CONSTRAINT pk_invoice_line         PRIMARY KEY (invoice_id, line_no),
  CONSTRAINT fk_invoice_line_hdr     FOREIGN KEY (invoice_id)
    REFERENCES invoice(invoice_id) ON DELETE CASCADE,
  CONSTRAINT ck_invoice_line_qty     CHECK (quantity IS NULL OR quantity >= 0)
);

CREATE INDEX ix_invoice_line_prod    ON invoice_line(product_code);

-- ============================================================
-- [3/7] credit_note — avoirs client
-- ============================================================
PROMPT
PROMPT [3/7] credit_note  — avoirs client
CREATE TABLE credit_note (
  credit_note_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  credit_note_no       VARCHAR2(20)  NOT NULL,
  credit_note_date     DATE          NOT NULL,
  company_code         VARCHAR2(12)  NOT NULL,
  party_code           VARCHAR2(32)  NOT NULL,
  party_name           VARCHAR2(120),
  source_invoice_id    NUMBER,
  currency_code        VARCHAR2(12)  DEFAULT 'XOF',
  exchange_rate        NUMBER(10,5)  DEFAULT 1,
  total_ht             NUMBER(16,4)  DEFAULT 0,
  total_tax            NUMBER(16,4)  DEFAULT 0,
  total_ttc            NUMBER(16,4)  DEFAULT 0,
  status               VARCHAR2(20)  DEFAULT 'DRAFT',
  reason               VARCHAR2(255),
  applied_to_invoice   NUMBER,
  memo                 VARCHAR2(2000),
  created_by           VARCHAR2(20),
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_credit_note          PRIMARY KEY (credit_note_id),
  CONSTRAINT uk_credit_note_no       UNIQUE (credit_note_no),
  CONSTRAINT fk_credit_note_invoice  FOREIGN KEY (source_invoice_id)
    REFERENCES invoice(invoice_id),
  CONSTRAINT ck_credit_note_status   CHECK (status IN ('DRAFT','VALID','APPLIED','CANCELLED')),
  CONSTRAINT ck_credit_note_amounts  CHECK (total_ht >= 0 AND total_tax >= 0 AND total_ttc >= 0)
);

CREATE INDEX ix_credit_note_date     ON credit_note(credit_note_date);
CREATE INDEX ix_credit_note_party    ON credit_note(party_code);
CREATE INDEX ix_credit_note_invoice  ON credit_note(source_invoice_id);
CREATE INDEX ix_credit_note_status   ON credit_note(status);

-- ============================================================
-- [4/7] credit_note_line — lignes d'avoir
-- ============================================================
PROMPT
PROMPT [4/7] credit_note_line  — lignes d'avoir
CREATE TABLE credit_note_line (
  credit_note_id       NUMBER        NOT NULL,
  line_no              NUMBER(5)     NOT NULL,
  product_code         VARCHAR2(80),
  description          VARCHAR2(120),
  quantity             NUMBER(16,4),
  unit_price           NUMBER(16,4),
  amount               NUMBER(16,4),
  tax_rate             NUMBER(5,2),
  tax_amount           NUMBER(16,4),
  source_invoice_line_no NUMBER(5),
  CONSTRAINT pk_credit_note_line     PRIMARY KEY (credit_note_id, line_no),
  CONSTRAINT fk_credit_note_line_hdr FOREIGN KEY (credit_note_id)
    REFERENCES credit_note(credit_note_id) ON DELETE CASCADE,
  CONSTRAINT ck_credit_note_line_qty CHECK (quantity IS NULL OR quantity >= 0)
);

CREATE INDEX ix_credit_note_line_prod ON credit_note_line(product_code);

-- ============================================================
-- [5/7] payment — règlements client
-- ============================================================
PROMPT
PROMPT [5/7] payment  — règlements client
CREATE TABLE payment (
  payment_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  payment_number       VARCHAR2(20)  NOT NULL,
  payment_date         DATE          NOT NULL,
  company_code         VARCHAR2(12)  NOT NULL,
  party_code           VARCHAR2(32)  NOT NULL,
  party_name           VARCHAR2(120),
  payment_method       VARCHAR2(12)  NOT NULL,
  reference            VARCHAR2(80),
  bank_code            VARCHAR2(20),
  currency_code        VARCHAR2(12)  DEFAULT 'XOF',
  exchange_rate        NUMBER(10,5)  DEFAULT 1,
  amount               NUMBER(16,4)  NOT NULL,
  amount_allocated     NUMBER(16,4)  DEFAULT 0,
  status               VARCHAR2(20)  DEFAULT 'VALID',
  memo                 VARCHAR2(255),
  created_by           VARCHAR2(20),
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_payment              PRIMARY KEY (payment_id),
  CONSTRAINT uk_payment_number       UNIQUE (payment_number),
  CONSTRAINT ck_payment_status       CHECK (status IN ('DRAFT','VALID','CANCELLED')),
  CONSTRAINT ck_payment_amount       CHECK (amount > 0),
  CONSTRAINT ck_payment_alloc        CHECK (amount_allocated >= 0 AND amount_allocated <= amount)
);

CREATE INDEX ix_payment_date         ON payment(payment_date);
CREATE INDEX ix_payment_party        ON payment(party_code);
CREATE INDEX ix_payment_method       ON payment(payment_method);
CREATE INDEX ix_payment_status       ON payment(status);

-- ============================================================
-- [6/7] payment_allocation — lettrage paiement/facture
-- ============================================================
PROMPT
PROMPT [6/7] payment_allocation  (← GCRGLE + GCRGLD) — lettrage paiement/facture
CREATE TABLE payment_allocation (
  allocation_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  payment_id           NUMBER        NOT NULL,
  invoice_id           NUMBER,
  document_type        VARCHAR2(20)  NOT NULL,
  document_ref         VARCHAR2(50),
  amount_applied       NUMBER(16,4)  NOT NULL,
  allocation_date      DATE          DEFAULT SYSDATE,
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_payment_allocation   PRIMARY KEY (allocation_id),
  CONSTRAINT fk_payment_alloc_pay    FOREIGN KEY (payment_id)
    REFERENCES payment(payment_id) ON DELETE CASCADE,
  CONSTRAINT fk_payment_alloc_inv    FOREIGN KEY (invoice_id)
    REFERENCES invoice(invoice_id),
  CONSTRAINT ck_payment_alloc_amount CHECK (amount_applied <> 0),
  CONSTRAINT ck_payment_alloc_doc    CHECK (document_type IN ('INVOICE','CREDIT_NOTE','ADVANCE'))
);

CREATE INDEX ix_palloc_payment       ON payment_allocation(payment_id);
CREATE INDEX ix_palloc_invoice       ON payment_allocation(invoice_id);
CREATE INDEX ix_palloc_date          ON payment_allocation(allocation_date);

-- ============================================================
-- [7/7] customer_credit — encours client
-- ============================================================
PROMPT
PROMPT [7/7] customer_credit  — encours client
CREATE TABLE customer_credit (
  party_code           VARCHAR2(32)  NOT NULL,
  company_code         VARCHAR2(12)  NOT NULL,
  credit_limit         NUMBER(16,4)  DEFAULT 0,
  credit_days          NUMBER(3)     DEFAULT 30,
  current_balance      NUMBER(16,4)  DEFAULT 0,
  overdue_balance      NUMBER(16,4)  DEFAULT 0,
  last_invoice_date    DATE,
  last_payment_date    DATE,
  is_blocked           BOOLEAN       DEFAULT FALSE,
  blocked_reason       VARCHAR2(255),
  updated_at           TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_customer_credit      PRIMARY KEY (party_code, company_code),
  CONSTRAINT ck_customer_credit_lim  CHECK (credit_limit >= 0 AND credit_days >= 0),
  CONSTRAINT ck_customer_credit_bal  CHECK (current_balance >= 0 AND overdue_balance >= 0),
  CONSTRAINT ck_customer_credit_ord  CHECK (overdue_balance <= current_balance)
);

CREATE INDEX ix_customer_credit_company ON customer_credit(company_code);

-- ⚠️ BOOLEAN ne peut PAS être indexé directement en B-tree Oracle
-- Index fonctionnel : stocke 1 pour TRUE, NULL sinon (émulation partial-index).
PROMPT   → ix_customer_credit_blocked (index fonctionnel sur BOOLEAN)
CREATE INDEX ix_customer_credit_blocked ON customer_credit(
  CASE WHEN is_blocked THEN 1 ELSE NULL END
);

-- ============================================================
-- Statistiques (pour peupler num_rows)
-- ============================================================
PROMPT
PROMPT ═══ Collecte des statistiques (num_rows) ═══
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS(
    ownname          => 'APP_AR',
    estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
    cascade          => TRUE
  );
  DBMS_OUTPUT.PUT_LINE('  Statistiques collectées.');
END;
/

-- ============================================================
-- Privilèges croisés (fait en tant que SYSTEM)
-- ============================================================
PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT system/oracle@localhost:1521/FREEPDB1

-- app_sales peut lire les factures et paiements (suivi en caisse)
GRANT SELECT ON app_ar.invoice             TO app_sales;
GRANT SELECT ON app_ar.invoice_line        TO app_sales;
GRANT SELECT ON app_ar.payment             TO app_sales;
GRANT SELECT ON app_ar.customer_credit     TO app_sales;

-- app_gl peut lire pour la comptabilisation
GRANT SELECT ON app_ar.invoice             TO app_gl;
GRANT SELECT ON app_ar.credit_note         TO app_gl;
GRANT SELECT ON app_ar.payment             TO app_gl;
GRANT SELECT ON app_ar.payment_allocation  TO app_gl;

-- app_party peut lire l'encours
GRANT SELECT ON app_ar.customer_credit     TO app_party;

-- app_api peut tout lire (exposition JSON)
GRANT SELECT ON app_ar.invoice             TO app_api;
GRANT SELECT ON app_ar.invoice_line        TO app_api;
GRANT SELECT ON app_ar.credit_note         TO app_api;
GRANT SELECT ON app_ar.credit_note_line    TO app_api;
GRANT SELECT ON app_ar.payment             TO app_api;
GRANT SELECT ON app_ar.payment_allocation  TO app_api;
GRANT SELECT ON app_ar.customer_credit     TO app_api;

-- ============================================================
-- VALIDATION FINALE
-- ============================================================
PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('INVOICE','INVOICE_LINE','CREDIT_NOTE','CREDIT_NOTE_LINE',
                      'PAYMENT','PAYMENT_ALLOCATION','CUSTOMER_CREDIT')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT table_name, constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('INVOICE','INVOICE_LINE','CREDIT_NOTE','CREDIT_NOTE_LINE',
                      'PAYMENT','PAYMENT_ALLOCATION','CUSTOMER_CREDIT')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Index (dont fonctionnels)
SELECT table_name, index_name, status, funcidx_status
  FROM user_indexes
 WHERE table_name IN ('INVOICE','INVOICE_LINE','CREDIT_NOTE','CREDIT_NOTE_LINE',
                      'PAYMENT','PAYMENT_ALLOCATION','CUSTOMER_CREDIT')
 ORDER BY table_name, index_name;

PROMPT
PROMPT [Validation] Expressions des index fonctionnels
SELECT index_name, column_expression
  FROM user_ind_expressions
 WHERE index_name IN ('IX_INVOICE_OVERDUE','IX_CUSTOMER_CREDIT_BLOCKED')
 ORDER BY index_name, column_position;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R5 TERMINÉ (7 tables dans app_ar)
PROMPT ══════════════════════════════════════════════════════════
EXIT;