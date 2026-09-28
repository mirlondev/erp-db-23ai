-- ============================================================
-- SCRIPT 47 : OHADA - Déclarations fiscales (TVA + autres)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   DÉCLARATIONS FISCALES OHADA (5 tables)
PROMPT ══════════════════════════════════════════════════════════

-- Nettoyage idempotent (ordre inverse des dépendances)
DECLARE
  PROCEDURE d(p_t VARCHAR2, p_n VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP '||p_t||' '||p_n||' CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('  DROP '||p_t||' '||p_n);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  d('VIEW','v_tax_summary_monthly');
  d('TABLE','tax_credit');
  d('TABLE','tax_payment');
  d('TABLE','tax_declaration_line');
  d('TABLE','tax_declaration');
  d('TABLE','tax_form_type');
END;
/

PROMPT
PROMPT [1/5] tax_form_type — catalogue des déclarations
CREATE TABLE tax_form_type (
  form_type_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  form_code            VARCHAR2(20)  NOT NULL,
  form_label           VARCHAR2(120) NOT NULL,
  form_type            VARCHAR2(20)  NOT NULL,
  frequency            VARCHAR2(20)  NOT NULL,
  jurisdiction         VARCHAR2(20)  NOT NULL,
  base_amount          NUMBER(16,4)  NOT NULL,
  rate                 NUMBER(7,4),
  legal_basis          VARCHAR2(255),
  due_day              NUMBER(2),
  CONSTRAINT pk_tax_form_type            PRIMARY KEY (form_type_id),
  CONSTRAINT uk_tax_form_code            UNIQUE (form_code, jurisdiction),
  CONSTRAINT ck_tax_form_type_kind       CHECK (form_type IN
    ('TVA','IS','IR','AAS','PATENTE','CESS','TAXE_HABITATION','FORM_UNIQUE','OTHER')),
  CONSTRAINT ck_tax_form_frequency       CHECK (frequency IN
    ('MONTHLY','QUARTERLY','ANNUAL','EVENT','BIANNUAL'))
);

PROMPT
PROMPT [2/5] tax_declaration — entête déclaration
CREATE TABLE tax_declaration (
  declaration_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  declaration_ref      VARCHAR2(30)  NOT NULL,
  form_type_id         NUMBER        NOT NULL,
  company_code         VARCHAR2(12)  NOT NULL,
  period_start         DATE          NOT NULL,
  period_end           DATE          NOT NULL,
  jurisdiction         VARCHAR2(20)  NOT NULL,
  base_amount          NUMBER(16,4)  DEFAULT 0,
  tax_due              NUMBER(16,4)  DEFAULT 0,
  credit_applied       NUMBER(16,4)  DEFAULT 0,
  amount_payable       NUMBER(16,4)  DEFAULT 0,
  status               VARCHAR2(20)  DEFAULT 'DRAFT',
  submitted_at         TIMESTAMP,
  submitted_by         VARCHAR2(20),
  acked_at             TIMESTAMP,
  paid_at              TIMESTAMP,
  notes                VARCHAR2(2000),
  CONSTRAINT pk_tax_declaration           PRIMARY KEY (declaration_id),
  CONSTRAINT uk_tax_declaration_ref       UNIQUE (declaration_ref),
  CONSTRAINT fk_tax_decl_form             FOREIGN KEY (form_type_id)
    REFERENCES tax_form_type(form_type_id),
  CONSTRAINT ck_tax_decl_status           CHECK (status IN
    ('DRAFT','SUBMITTED','ACKED','PAID','LATE','REJECTED','CANCELLED','UNDER_REVIEW'))
);

CREATE INDEX ix_tax_decl_period ON tax_declaration(period_start, period_end, jurisdiction);
CREATE INDEX ix_tax_decl_status ON tax_declaration(status);

PROMPT
PROMPT [3/5] tax_declaration_line — détail par taux (TVA)
CREATE TABLE tax_declaration_line (
  line_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  declaration_id       NUMBER        NOT NULL,
  line_no              NUMBER(3)     NOT NULL,
  rate_type            VARCHAR2(20)  NOT NULL,
  rate                 NUMBER(7,4)   NOT NULL,
  base_amount          NUMBER(16,4)  NOT NULL,
  tax_amount           NUMBER(16,4)  NOT NULL,
  deductible_base      NUMBER(16,4)  DEFAULT 0,
  deductible_tax       NUMBER(16,4)  DEFAULT 0,
  notes                VARCHAR2(500),
  CONSTRAINT pk_tax_declaration_line     PRIMARY KEY (line_id),
  CONSTRAINT fk_tax_line_decl            FOREIGN KEY (declaration_id)
    REFERENCES tax_declaration(declaration_id) ON DELETE CASCADE,
  CONSTRAINT uk_tax_line_order           UNIQUE (declaration_id, line_no),
  CONSTRAINT ck_tax_line_rate_type       CHECK (rate_type IN
    ('NORMAL','REDUCED','EXPORT','SUSPENDED','EXEMPT','INTERMEDIATE')),
  CONSTRAINT ck_tax_line_amount          CHECK (base_amount >= 0
    AND tax_amount >= 0 AND NVL(deductible_base,0) >= 0)
);

CREATE INDEX ix_tax_line_decl ON tax_declaration_line(declaration_id);

PROMPT
PROMPT [4/5] tax_payment — paiement effectif à la DGI
-- ⚠️ Référence logique vers gl_entry(company_code, entry_no) — SANS FK.
CREATE TABLE tax_payment (
  payment_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  payment_ref          VARCHAR2(30)  NOT NULL,
  declaration_id       NUMBER,
  company_code         VARCHAR2(12)  NOT NULL,
  payment_date         DATE          NOT NULL,
  payment_amount       NUMBER(16,4)  NOT NULL,
  payment_method       VARCHAR2(20)  NOT NULL,
  bank_account         VARCHAR2(40),
  bank_ref             VARCHAR2(120),
  jurisdiction         VARCHAR2(20)  NOT NULL,
  receiver_name        VARCHAR2(120),
  entry_company_code   VARCHAR2(2),
  entry_no             NUMBER(8),
  CONSTRAINT pk_tax_payment            PRIMARY KEY (payment_id),
  CONSTRAINT uk_tax_payment_ref        UNIQUE (payment_ref),
  CONSTRAINT fk_tax_payment_decl       FOREIGN KEY (declaration_id)
    REFERENCES tax_declaration(declaration_id),
  CONSTRAINT ck_tax_payment_method     CHECK (payment_method IN
    ('BANK_TRANSFER','CASH','MOBILE_MONEY','CHECK','SEPA','CARD'))
);

CREATE INDEX ix_tax_payment_decl  ON tax_payment(declaration_id);
CREATE INDEX ix_tax_payment_date  ON tax_payment(payment_date);
CREATE INDEX ix_tax_payment_entry ON tax_payment(entry_company_code, entry_no);

PROMPT
PROMPT [5/5] tax_credit — crédits de TVA reportables
CREATE TABLE tax_credit (
  credit_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  company_code          VARCHAR2(12)  NOT NULL,
  credit_source         VARCHAR2(20)  NOT NULL,
  origin_period         DATE          NOT NULL,
  total_credit          NUMBER(16,4)  NOT NULL,
  used_amount           NUMBER(16,4)  DEFAULT 0,
  remaining             NUMBER(16,4) GENERATED ALWAYS AS (total_credit - NVL(used_amount,0)),
  expiry_date           DATE,
  declaration_id_origin NUMBER,
  CONSTRAINT pk_tax_credit                PRIMARY KEY (credit_id),
  CONSTRAINT fk_tax_credit_origin         FOREIGN KEY (declaration_id_origin)
    REFERENCES tax_declaration(declaration_id),
  CONSTRAINT ck_tax_credit_source         CHECK (credit_source IN
    ('INPUT_VAT','OVERPAYMENT','CREDIT_NOTE','AUTOCONSOMMATION','EXPORT_REFUND')),
  CONSTRAINT ck_tax_credit_amount         CHECK (total_credit > 0
    AND NVL(used_amount,0) >= 0),
  CONSTRAINT ck_tax_credit_remaining      CHECK (total_credit >= NVL(used_amount,0))
);

CREATE INDEX ix_tax_credit_company ON tax_credit(company_code, origin_period);

-- Vue pratique
PROMPT
PROMPT [Vue pratique] v_tax_summary_monthly
CREATE OR REPLACE VIEW v_tax_summary_monthly AS
SELECT EXTRACT(YEAR  FROM d.period_end) AS fiscal_year,
       EXTRACT(MONTH FROM d.period_end) AS month_no,
       d.jurisdiction,
       SUM(d.tax_due)        AS total_tax_due,
       SUM(d.credit_applied) AS total_credit,
       SUM(d.amount_payable) AS total_payable,
       COUNT(*)              AS declarations_count
  FROM tax_declaration d
 WHERE d.status IN ('SUBMITTED','ACKED','PAID')
 GROUP BY EXTRACT(YEAR  FROM d.period_end),
          EXTRACT(MONTH FROM d.period_end),
          d.jurisdiction
 ORDER BY 1 DESC, 2 DESC;

-- Privilèges
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT ON app_gl.tax_form_type         TO app_api;
GRANT SELECT ON app_gl.tax_declaration       TO app_api;
GRANT SELECT ON app_gl.tax_declaration_line  TO app_api;
GRANT SELECT ON app_gl.tax_payment           TO app_api;
GRANT SELECT ON app_gl.tax_credit            TO app_api;
GRANT SELECT ON app_gl.tax_form_type         TO app_ar;
GRANT SELECT ON app_gl.tax_declaration       TO app_ar;

-- Validation
PROMPT
PROMPT ═══ Validation ═══
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('TAX_FORM_TYPE','TAX_DECLARATION','TAX_DECLARATION_LINE',
                      'TAX_PAYMENT','TAX_CREDIT')
 ORDER BY table_name;

SELECT object_name, object_type, status
  FROM user_objects WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ DÉCLARATIONS FISCALES OHADA TERMINÉES (5 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;