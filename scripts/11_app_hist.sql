-- ============================================================
-- SCRIPT 11 : Schéma app_hist (Archives)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_hist/AppHist#2026@localhost:1521/FREEPDB1

PROMPT [1] Table hist_ticket
CREATE TABLE hist_ticket (
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
  CONSTRAINT pk_hist_ticket PRIMARY KEY (terminal_id, ticket_no)
);

PROMPT [2] Table hist_ticket_line
CREATE TABLE hist_ticket_line (
  terminal_id       VARCHAR2(12)  NOT NULL,
  ticket_no         NUMBER(8)     NOT NULL,
  line_no           NUMBER(3)     NOT NULL,
  product_code      VARCHAR2(80),
  description       VARCHAR2(120),
  quantity          NUMBER(16,4),
  unit_price        NUMBER(16,4),
  CONSTRAINT pk_hist_ticket_line PRIMARY KEY (terminal_id, ticket_no, line_no)
);

PROMPT [3] Table hist_doc
CREATE TABLE hist_doc (
  doc_id            NUMBER        NOT NULL,
  doc_type_code     VARCHAR2(20),
  doc_no            NUMBER(8),
  doc_date          DATE,
  party_code        VARCHAR2(32),
  total_ttc         NUMBER(16,4),
  status            VARCHAR2(4),
  archived_at       TIMESTAMP DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_hist_doc PRIMARY KEY (doc_id)
);

PROMPT [4] Table hist_doc_line
CREATE TABLE hist_doc_line (
  doc_id            NUMBER        NOT NULL,
  line_no           NUMBER(5)     NOT NULL,
  product_code      VARCHAR2(80),
  quantity          NUMBER(16,4),
  unit_price        NUMBER(16,4),
  amount            NUMBER(16,4),
  CONSTRAINT pk_hist_doc_line PRIMARY KEY (doc_id, line_no)
);

PROMPT [5] Table hist_gl_entry
CREATE TABLE hist_gl_entry (
  company_code      VARCHAR2(2),
  entry_no          NUMBER(8),
  accounting_date   DATE,
  journal_code      VARCHAR2(5),
  entry_label       VARCHAR2(50),
  entry_total       NUMBER(16,4),
  archived_at       TIMESTAMP DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_hist_gl_entry PRIMARY KEY (company_code, entry_no)
);

PROMPT [6] Table hist_gl_entry_line
CREATE TABLE hist_gl_entry_line (
  company_code      VARCHAR2(2),
  entry_no          NUMBER(8),
  line_no           NUMBER(5),
  account_code      VARCHAR2(8),
  party_code        VARCHAR2(8),
  direction         VARCHAR2(1),
  company_debit     NUMBER(16,4),
  company_credit    NUMBER(16,4),
  CONSTRAINT pk_hist_gl_entry_line PRIMARY KEY (company_code, entry_no, line_no)
);

PROMPT
PROMPT [7] Index pour les archives
CREATE INDEX ix_hist_ticket_date ON hist_ticket(ticket_date);
CREATE INDEX ix_hist_doc_date    ON hist_doc(doc_date);
CREATE INDEX ix_hist_gl_date     ON hist_gl_entry(accounting_date);

PROMPT [8] Validation
SELECT table_name FROM user_tables ORDER BY table_name;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_hist TERMINÉ
PROMPT ═══════════════════════════════════════════════════════