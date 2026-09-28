-- ============================================================
-- SCRIPT 09 : Schéma app_gl (General Ledger)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DU SCHÉMA app_gl
PROMPT ═══════════════════════════════════════════════════════

PROMPT [1] Table gl_company
CREATE TABLE gl_company (
  company_code      VARCHAR2(2)   NOT NULL,
  legal_name        VARCHAR2(50),
  address           VARCHAR2(30),
  city              VARCHAR2(30),
  country           VARCHAR2(30),
  phone             VARCHAR2(30),
  tax_id            VARCHAR2(25),
  currency_code     VARCHAR2(3),
  has_customer_acct BOOLEAN       DEFAULT FALSE,
  has_supplier_acct BOOLEAN       DEFAULT FALSE,
  created_at        TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_gl_company PRIMARY KEY (company_code)
);

PROMPT [2] Table gl_journal
CREATE TABLE gl_journal (
  company_code      VARCHAR2(2)   NOT NULL,
  journal_code      VARCHAR2(5)   NOT NULL,
  journal_name      VARCHAR2(30)  NOT NULL,
  is_active         BOOLEAN       DEFAULT TRUE,
  journal_type      VARCHAR2(3)   NOT NULL,
  nature            VARCHAR2(1)   NOT NULL,
  created_at        DATE          NOT NULL,
  updated_at        DATE,
  created_by        VARCHAR2(5)   NOT NULL,
  CONSTRAINT pk_gl_journal PRIMARY KEY (company_code, journal_code),
  CONSTRAINT fk_gl_journal_company FOREIGN KEY (company_code) 
    REFERENCES gl_company(company_code)
);

PROMPT [3] Table gl_account
CREATE TABLE gl_account (
  company_code      VARCHAR2(2)   NOT NULL,
  account_code      VARCHAR2(8)   NOT NULL,
  account_name      VARCHAR2(50)  NOT NULL,
  is_active         BOOLEAN       DEFAULT TRUE,
  account_type      VARCHAR2(1)   NOT NULL,
  short_code        VARCHAR2(15),
  profile_code      VARCHAR2(3),
  reporting_account VARCHAR2(10),
  currency_code     VARCHAR2(3),
  manage_due_date   VARCHAR2(1)   NOT NULL,
  page_break        VARCHAR2(1)   NOT NULL,
  nature_code       VARCHAR2(8),
  lettering_no      NUMBER(4),
  notes           VARCHAR2(255),
  created_at        DATE          NOT NULL,
  updated_at        DATE,
  created_by        VARCHAR2(5)   NOT NULL,
  CONSTRAINT pk_gl_account PRIMARY KEY (company_code, account_code)
);

PROMPT [4] Table gl_subaccount
CREATE TABLE gl_subaccount (
  company_code      VARCHAR2(2)   NOT NULL,
  party_code        VARCHAR2(8)   NOT NULL,
  account_code      VARCHAR2(8)   NOT NULL,
  party_name        VARCHAR2(50)  NOT NULL,
  is_blocked        VARCHAR2(1),
  currency_code     VARCHAR2(3),
  payment_method    VARCHAR2(3),
  created_at        DATE          NOT NULL,
  updated_at        DATE,
  created_by        VARCHAR2(5)   NOT NULL,
  CONSTRAINT pk_gl_subaccount PRIMARY KEY (company_code, party_code),
  CONSTRAINT fk_gl_subaccount_acct FOREIGN KEY (company_code, account_code) 
    REFERENCES gl_account(company_code, account_code)
);

PROMPT [5] Table gl_period
CREATE TABLE gl_period (
  company_code      VARCHAR2(2)   NOT NULL,
  period_code       VARCHAR2(4)   NOT NULL,
  start_date        DATE          NOT NULL,
  end_date          DATE          NOT NULL,
  is_active         BOOLEAN       DEFAULT TRUE,
  is_closed         BOOLEAN       DEFAULT FALSE,
  created_at        DATE          NOT NULL,
  updated_at        DATE,
  created_by        VARCHAR2(5)   NOT NULL,
  CONSTRAINT pk_gl_period PRIMARY KEY (company_code, period_code)
);

PROMPT [6] Table gl_entry
CREATE TABLE gl_entry (
  company_code      VARCHAR2(2)   NOT NULL,
  entity_code       VARCHAR2(3)   NOT NULL,
  journal_code      VARCHAR2(5)   NOT NULL,
  period_code       VARCHAR2(4)   NOT NULL,
  accounting_date   DATE          NOT NULL,
  entry_date        DATE          NOT NULL,
  doc_date          DATE          NOT NULL,
  document_no       VARCHAR2(10)  NOT NULL,
  entry_no          NUMBER(8)     NOT NULL,
  currency_code     VARCHAR2(3)   NOT NULL,
  exchange_rate     NUMBER(13,7)  DEFAULT 1 NOT NULL,
  entry_label       VARCHAR2(50),
  company_total     NUMBER(16,4),
  entry_total       NUMBER(16,4),
  is_printed        VARCHAR2(1)   DEFAULT 'N' NOT NULL,
  is_posted         VARCHAR2(1)   DEFAULT 'N' NOT NULL,
  created_at        DATE          NOT NULL,
  updated_at        DATE,
  created_by        VARCHAR2(5)   NOT NULL,
  CONSTRAINT pk_gl_entry PRIMARY KEY (company_code, entry_no)
);

CREATE INDEX ix_gl_entry_date ON gl_entry(accounting_date);
CREATE INDEX ix_gl_entry_journal ON gl_entry(journal_code);

PROMPT [7] Table gl_entry_line
CREATE TABLE gl_entry_line (
  company_code      VARCHAR2(2)   NOT NULL,
  entity_code       VARCHAR2(3)   NOT NULL,
  entry_no          NUMBER(8)     NOT NULL,
  line_no           NUMBER(5)     NOT NULL,
  account_code      VARCHAR2(8)   NOT NULL,
  party_code        VARCHAR2(8),
  short_code        VARCHAR2(2),
  line_label        VARCHAR2(50),
  accounting_date   DATE          NOT NULL,
  due_date          DATE,
  value_date        DATE,
  payment_method    VARCHAR2(3),
  cash_code         VARCHAR2(2),
  counter_account   VARCHAR2(8),
  counter_party     VARCHAR2(8),
  direction         VARCHAR2(1)   NOT NULL,
  lettering_no      NUMBER(4),
  lettering_ref     VARCHAR2(15),
  company_debit     NUMBER(16,4),
  company_credit    NUMBER(16,4),
  account_debit     NUMBER(16,4),
  account_credit    NUMBER(16,4),
  entry_debit       NUMBER(16,4),
  entry_credit      NUMBER(16,4),
  CONSTRAINT pk_gl_entry_line PRIMARY KEY (company_code, entry_no, line_no),
  CONSTRAINT fk_gl_entry_line_hdr FOREIGN KEY (company_code, entry_no) 
    REFERENCES gl_entry(company_code, entry_no) ON DELETE CASCADE,
  CONSTRAINT ck_gl_entry_line_dir CHECK (direction IN ('D','C'))
);

CREATE INDEX ix_gl_entry_line_account ON gl_entry_line(company_code, account_code);
CREATE INDEX ix_gl_entry_line_party   ON gl_entry_line(company_code, account_code, party_code);

PROMPT [8] Table gl_lettering
CREATE TABLE gl_lettering (
  company_code      VARCHAR2(2)   NOT NULL,
  entity_code       VARCHAR2(3)   NOT NULL,
  entry_no          NUMBER(8)     NOT NULL,
  line_no           NUMBER(5)     NOT NULL,
  sub_line_no       NUMBER(5),
  level_no          NUMBER(2),
  account_code      VARCHAR2(8)   NOT NULL,
  party_code        VARCHAR2(8),
  line_label        VARCHAR2(50),
  accounting_date   DATE          NOT NULL,
  due_date          DATE,
  lettering_ref     VARCHAR2(15),
  lettering_code    VARCHAR2(1),
  lettering_date    DATE,
  lettering_no      NUMBER(4),
  currency_code     VARCHAR2(3),
  direction         VARCHAR2(1)   NOT NULL,
  company_debit     NUMBER(16,4),
  company_credit    NUMBER(16,4),
  account_debit     NUMBER(16,4),
  account_credit    NUMBER(16,4),
  entry_debit       NUMBER(16,4),
  entry_credit      NUMBER(16,4),
  tax_amount        NUMBER(16,4),
  taxable_amount    NUMBER(16,4),
  non_taxable_amount NUMBER(16,4),
  CONSTRAINT pk_gl_lettering PRIMARY KEY (company_code, entity_code, entry_no, line_no)
);

PROMPT
PROMPT [9] Insertion des données

INSERT INTO gl_company (company_code, legal_name, currency_code, has_customer_acct, has_supplier_acct)
VALUES ('01', 'Ma Société', 'XOF', TRUE, TRUE);

INSERT INTO gl_journal (company_code, journal_code, journal_name, is_active, journal_type, nature, created_at, created_by)
VALUES ('01', 'SAL', 'Journal des ventes', TRUE, 'SAL', 'A', SYSDATE, 'ADMIN');
INSERT INTO gl_journal (company_code, journal_code, journal_name, is_active, journal_type, nature, created_at, created_by)
VALUES ('01', 'PUR', 'Journal des achats', TRUE, 'PUR', 'A', SYSDATE, 'ADMIN');
INSERT INTO gl_journal (company_code, journal_code, journal_name, is_active, journal_type, nature, created_at, created_by)
VALUES ('01', 'CSH', 'Journal de caisse', TRUE, 'CSH', 'A', SYSDATE, 'ADMIN');
INSERT INTO gl_journal (company_code, journal_code, journal_name, is_active, journal_type, nature, created_at, created_by)
VALUES ('01', 'MSC', 'Opérations diverses', TRUE, 'MSC', 'A', SYSDATE, 'ADMIN');

INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '411000', 'Clients', TRUE, 'C', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '401000', 'Fournisseurs', TRUE, 'C', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '521000', 'Banque', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '530000', 'Caisse', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '701000', 'Ventes de marchandises', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '601000', 'Achats de marchandises', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '443000', 'TVA collectée', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '445000', 'TVA déductible', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');

INSERT INTO gl_period (company_code, period_code, start_date, end_date, is_active, is_closed, created_at, created_by)
VALUES ('01', '2026', DATE '2026-01-01', DATE '2026-12-31', TRUE, FALSE, SYSDATE, 'ADMIN');

INSERT INTO gl_subaccount (company_code, party_code, account_code, party_name, created_at, created_by)
VALUES ('01', 'CLI001', '411000', 'Client Dupont', SYSDATE, 'ADMIN');
INSERT INTO gl_subaccount (company_code, party_code, account_code, party_name, created_at, created_by)
VALUES ('01', 'FOU001', '401000', 'Fournisseur ABC', SYSDATE, 'ADMIN');

-- Écriture de vente comptant
INSERT INTO gl_entry (company_code, entity_code, journal_code, period_code,
                     accounting_date, entry_date, doc_date, document_no,
                     entry_no, currency_code, entry_label, company_total,
                     entry_total, created_at, created_by)
VALUES ('01', '001', 'SAL', '2026', SYSDATE, SYSDATE, SYSDATE, 'SAL001',
        1, 'XOF', 'Vente comptoir', 5000, 5000, SYSDATE, 'ADMIN');

INSERT INTO gl_entry_line (company_code, entity_code, entry_no, line_no,
                           account_code, line_label, accounting_date,
                           direction, company_debit, account_debit, entry_debit)
VALUES ('01', '001', 1, 1, '530000', 'Vente comptoir', SYSDATE,
        'D', 5000, 5000, 5000);

INSERT INTO gl_entry_line (company_code, entity_code, entry_no, line_no,
                           account_code, line_label, accounting_date,
                           direction, company_credit, account_credit, entry_credit)
VALUES ('01', '001', 1, 2, '701000', 'Vente comptoir', SYSDATE,
        'C', 4237.29, 4237.29, 4237.29);

INSERT INTO gl_entry_line (company_code, entity_code, entry_no, line_no,
                           account_code, line_label, accounting_date,
                           direction, company_credit, account_credit, entry_credit)
VALUES ('01', '001', 1, 3, '443000', 'TVA sur vente', SYSDATE,
        'C', 762.71, 762.71, 762.71);

COMMIT;

PROMPT
PROMPT [10] Validation
SELECT company_code, legal_name, has_customer_acct, has_supplier_acct
  FROM gl_company;

SELECT e.entry_no, e.entry_label, l.line_no, l.account_code, l.direction,
       l.company_debit, l.company_credit
  FROM gl_entry e
  JOIN gl_entry_line l ON l.company_code = e.company_code AND l.entry_no = e.entry_no
 ORDER BY e.entry_no, l.line_no;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_gl TERMINÉ
PROMPT ═══════════════════════════════════════════════════════
