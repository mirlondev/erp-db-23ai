-- ============================================================
-- SCRIPT 36 : LOT 1C + 1D — Coûts / Frais d'approche + Documents commerciaux
-- Migration Oracle 11g → 23ai/26ai (app_doc)
-- ============================================================
-- Lot 1C : 4 tables (Coûts approche + frais)
-- Lot 1D : 4 tables (Documents commerciaux)
-- Total : 8 nouvelles tables dans app_doc
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_doc/AppDoc#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT 1C + 1D : 8 tables
PROMPT ══════════════════════════════════════════════════════════


PROMPT
PROMPT ═══ LOT 1C : Coûts / Frais d'approche (4 tables) ═══

PROMPT [1C.1/4] doc_extra_cost  — frais supplémentaires header
CREATE TABLE doc_extra_cost (
  doc_id              NUMBER        NOT NULL,
  cost_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  cost_type           VARCHAR2(20)  NOT NULL,             -- TRANSPORT | INSURANCE | CUSTOMS | PACKAGING | OTHER
  cost_label          VARCHAR2(120),
  amount              NUMBER(16,4)  NOT NULL,
  currency_code       VARCHAR2(3)   DEFAULT 'XOF',
  exchange_rate       NUMBER(10,5)  DEFAULT 1,
  amount_in_local     NUMBER(16,4)  GENERATED ALWAYS AS (amount * exchange_rate),
  tax_rate            NUMBER(5,2),
  tax_amount          NUMBER(16,4),
  supplier_code       VARCHAR2(32),
  invoice_ref         VARCHAR2(120),
  allocation_method   VARCHAR2(20)  DEFAULT 'PROPORTIONAL', -- PROPORTIONAL | EQUAL | MANUAL
  is_allocated        BOOLEAN       DEFAULT FALSE,
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_doc_extra_cost             PRIMARY KEY (cost_id),
  CONSTRAINT fk_doc_extra_cost_hdr         FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT ck_doc_extra_cost_amount     CHECK (amount >= 0),
  CONSTRAINT ck_doc_extra_cost_type       CHECK (cost_type IN
    ('TRANSPORT','INSURANCE','CUSTOMS','PACKAGING','BANK','COMMISSION','OTHER')),
  CONSTRAINT ck_doc_extra_cost_alloc      CHECK (allocation_method IN ('PROPORTIONAL','EQUAL','MANUAL','PER_LINE','PER_QTY'))
);

CREATE INDEX ix_doc_extra_cost_doc        ON doc_extra_cost(doc_id);
CREATE INDEX ix_doc_extra_cost_type       ON doc_extra_cost(cost_type);

PROMPT [1C.2/4] doc_extra_cost_allocation  — ventilation des frais sur les lignes
CREATE TABLE doc_extra_cost_allocation (
  cost_id             NUMBER        NOT NULL,
  doc_id              NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  allocated_amount    NUMBER(16,4)  NOT NULL,
  allocated_pct       NUMBER(6,3),                       -- % de la ligne par rapport au total
  CONSTRAINT pk_doc_extra_cost_alloc       PRIMARY KEY (cost_id, doc_id, line_no),
  CONSTRAINT fk_doc_extra_cost_alloc_hdr   FOREIGN KEY (cost_id)
    REFERENCES doc_extra_cost(cost_id) ON DELETE CASCADE,
  CONSTRAINT fk_doc_extra_cost_alloc_line  FOREIGN KEY (doc_id, line_no)
    REFERENCES doc_line(doc_id, line_no) ON DELETE CASCADE,
  CONSTRAINT ck_doc_extra_cost_alloc_amt  CHECK (allocated_amount >= 0)
);

PROMPT [1C.3/4] doc_tax_detail  — détail multi-taxes (TVA, TS, TL, etc.)
CREATE TABLE doc_tax_detail (
  doc_id              NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  tax_code            VARCHAR2(12)  NOT NULL,             -- TVA18 | TVA9 | TL5 | TFP | etc.
  tax_label           VARCHAR2(60),
  tax_rate            NUMBER(5,2)   NOT NULL,
  base_amount         NUMBER(16,4)  NOT NULL,             -- base HT avant taxe
  tax_amount          NUMBER(16,4)  NOT NULL,
  is_exempt           BOOLEAN       DEFAULT FALSE,
  exemption_ref       VARCHAR2(60),                       -- référence exonération
  CONSTRAINT pk_doc_tax_detail              PRIMARY KEY (doc_id, line_no, tax_code),
  CONSTRAINT fk_doc_tax_detail_line         FOREIGN KEY (doc_id, line_no)
    REFERENCES doc_line(doc_id, line_no) ON DELETE CASCADE,
  CONSTRAINT ck_doc_tax_detail_amounts     CHECK (base_amount >= 0 AND tax_amount >= 0)
);

PROMPT [1C.4/4] doc_pricing_rule  — règles de prix appliquées au document
CREATE TABLE doc_pricing_rule (
  doc_id              NUMBER        NOT NULL,
  rule_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  rule_type           VARCHAR2(20)  NOT NULL,             -- DISCOUNT | PROMO | SURCHARGE | FX
  rule_code           VARCHAR2(20),
  rule_label          VARCHAR2(120),
  target_field        VARCHAR2(20)  DEFAULT 'LINE',      -- LINE | HEADER | SUBTOTAL
  target_line_no      NUMBER(4),                         -- NULL si HEADER
  rate                NUMBER(5,2),
  amount              NUMBER(16,4),
  is_conditional      BOOLEAN       DEFAULT FALSE,
  condition_expr      VARCHAR2(500),
  priority            NUMBER(3)     DEFAULT 100,
  CONSTRAINT pk_doc_pricing_rule            PRIMARY KEY (rule_id),
  CONSTRAINT fk_doc_pricing_rule_hdr       FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT ck_doc_pricing_rule_type      CHECK (rule_type IN ('DISCOUNT','PROMO','SURCHARGE','FX','ROUNDING'))
);

PROMPT
PROMPT ═══ LOT 1D : Documents commerciaux (4 tables) ═══

PROMPT [1D.1/4] doc_commercial_status  — suivi commercial du doc (avancement)
CREATE TABLE doc_commercial_status (
  doc_id              NUMBER        NOT NULL,
  status_seq          NUMBER(3)     NOT NULL,
  status_type         VARCHAR2(20)  NOT NULL,             -- QUOTED | ORDERED | CONFIRMED | DELIVERED | BILLED | PAID
  status_date         DATE          NOT NULL,
  user_code           VARCHAR2(20),
  notes               VARCHAR2(500),
  CONSTRAINT pk_doc_commercial_status       PRIMARY KEY (doc_id, status_seq),
  CONSTRAINT fk_doc_commercial_status_hdr   FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT ck_doc_commercial_status_type CHECK (status_type IN
    ('DRAFT','QUOTED','ORDERED','CONFIRMED','PARTIAL','DELIVERED','BILLED','PARTIAL_PAID','PAID','CLOSED','CANCELLED'))
);

CREATE INDEX ix_doc_commercial_status_date ON doc_commercial_status(status_date);

PROMPT [1D.2/4] doc_commercial_link  — liens inter-documents (devis→commande→livraison→facture)
CREATE TABLE doc_commercial_link (
  link_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  source_doc_id       NUMBER        NOT NULL,
  source_doc_type     VARCHAR2(20),
  target_doc_id       NUMBER        NOT NULL,
  target_doc_type     VARCHAR2(20)  NOT NULL,
  link_type           VARCHAR2(20)  DEFAULT 'TRANSFORM',  -- TRANSFORM | REFERENCE | COPY | GROUP
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  created_by          VARCHAR2(20),
  CONSTRAINT pk_doc_commercial_link         PRIMARY KEY (link_id),
  CONSTRAINT fk_doc_link_source             FOREIGN KEY (source_doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT fk_doc_link_target             FOREIGN KEY (target_doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT uk_doc_commercial_link         UNIQUE (source_doc_id, target_doc_id, link_type),
  CONSTRAINT ck_doc_link_type               CHECK (link_type IN ('TRANSFORM','REFERENCE','COPY','GROUP','SUBSTITUTE'))
);

CREATE INDEX ix_doc_link_target             ON doc_commercial_link(target_doc_id);

PROMPT [1D.3/4] doc_followup  — relances et suivis
CREATE TABLE doc_followup (
  followup_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  doc_id              NUMBER        NOT NULL,
  followup_type       VARCHAR2(20)  NOT NULL,             -- CALL | EMAIL | MEETING | NOTE | TASK
  followup_date       DATE          NOT NULL,
  followup_by         VARCHAR2(20)  NOT NULL,
  description         VARCHAR2(2000) NOT NULL,
  outcome             VARCHAR2(2000),
  next_followup_date  DATE,
  status              VARCHAR2(20)  DEFAULT 'OPEN',       -- OPEN | DONE | CANCELLED
  completed_at        TIMESTAMP,
  CONSTRAINT pk_doc_followup                PRIMARY KEY (followup_id),
  CONSTRAINT fk_doc_followup_hdr            FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT ck_doc_followup_type          CHECK (followup_type IN ('CALL','EMAIL','MEETING','NOTE','TASK','SMS','VISIT')),
  CONSTRAINT ck_doc_followup_status        CHECK (status IN ('OPEN','DONE','CANCELLED','DEFERRED'))
);

CREATE INDEX ix_doc_followup_date          ON doc_followup(followup_date);
CREATE INDEX ix_doc_followup_status        ON doc_followup(status, followup_date);

PROMPT [1D.4/4] doc_signature  — signatures électroniques
CREATE TABLE doc_signature (
  signature_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  doc_id              NUMBER        NOT NULL,
  signer_user_code    VARCHAR2(20)  NOT NULL,
  signer_role         VARCHAR2(40),                      -- 'CUSTOMER' | 'VENDOR' | 'MANAGER' | etc.
  signature_type      VARCHAR2(20)  DEFAULT 'ELECTRONIC', -- ELECTRONIC | DIGITAL_CERT | SCAN
  signature_hash      VARCHAR2(64)  NOT NULL,             -- SHA-256
  signed_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  ip_address          VARCHAR2(45),
  geolocation         VARCHAR2(100),
  certificate_serial  VARCHAR2(255),
  certificate_issuer  VARCHAR2(120),
  is_valid            BOOLEAN       DEFAULT TRUE,
  validation_method   VARCHAR2(60),
  CONSTRAINT pk_doc_signature               PRIMARY KEY (signature_id),
  CONSTRAINT fk_doc_signature_hdr           FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT ck_doc_signature_type         CHECK (signature_type IN ('ELECTRONIC','DIGITAL_CERT','SCAN','BIOMETRIC'))
);

CREATE INDEX ix_doc_signature_doc           ON doc_signature(doc_id);
CREATE INDEX ix_doc_signature_hash          ON doc_signature(signature_hash);

PROMPT
PROMPT ═══ Validation — Tables ═══
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('DOC_EXTRA_COST','DOC_EXTRA_COST_ALLOCATION','DOC_TAX_DETAIL','DOC_PRICING_RULE',
                      'DOC_COMMERCIAL_STATUS','DOC_COMMERCIAL_LINK','DOC_FOLLOWUP','DOC_SIGNATURE')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Objets invalides
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT 1C + 1D TERMINÉS (8 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
