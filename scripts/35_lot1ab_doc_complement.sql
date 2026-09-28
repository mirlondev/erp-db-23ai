-- ============================================================
-- SCRIPT 35 : LOT 1A + 1B - Documents complementaires (CORRIGE)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
SET SQLBLANKLINES ON

CONNECT app_doc/AppDoc#2026@localhost:1521/FREEPDB1

PROMPT ==============================================================
PROMPT   LOT 1A + 1B : 11 tables documents complementaires
PROMPT ==============================================================

-- Nettoyage idempotent
DECLARE
  PROCEDURE d(p_t VARCHAR2, p_n VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP '||p_t||' '||p_n;
    DBMS_OUTPUT.PUT_LINE('  DROP '||p_t||' '||p_n);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  d('TABLE','doc_attachment');
  d('TABLE','doc_request');
  d('TABLE','doc_foreign_header');
  d('TABLE','doc_delivery_option');
  d('TABLE','doc_loading_note');
  d('TABLE','doc_advance_lettering');
  d('TABLE','doc_line_cost');
  d('TABLE','doc_line_shortage');
  d('TABLE','doc_line_serial');
  d('TABLE','doc_line_lot');
  d('TABLE','doc_imputation');
END;
/

PROMPT
PROMPT === LOT 1A : Lignes document (5 tables) ===

PROMPT [1A.1/5] doc_imputation
CREATE TABLE doc_imputation (
  doc_id              NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  account_code        VARCHAR2(20),
  destination_1       VARCHAR2(60),
  destination_2       VARCHAR2(60),
  destination_3       VARCHAR2(60),
  amount              NUMBER(16,4),
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_doc_imputation      PRIMARY KEY (doc_id, line_no),
  CONSTRAINT fk_doc_imputation_line FOREIGN KEY (doc_id, line_no)
    REFERENCES doc_line(doc_id, line_no) ON DELETE CASCADE
);

CREATE INDEX ix_doc_imputation_account ON doc_imputation(account_code);

PROMPT [1A.2/5] doc_line_lot
CREATE TABLE doc_line_lot (
  doc_id              NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  lot_number          VARCHAR2(20)  NOT NULL,
  manufacturing_date  DATE,
  expiry_date         DATE          NOT NULL,
  lot_qty             NUMBER(16,4)  NOT NULL,
  lot_unit_cost       NUMBER(16,4),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_doc_line_lot        PRIMARY KEY (doc_id, line_no, lot_number),
  CONSTRAINT fk_doc_line_lot_line   FOREIGN KEY (doc_id, line_no)
    REFERENCES doc_line(doc_id, line_no) ON DELETE CASCADE,
  CONSTRAINT ck_doc_line_lot_qty    CHECK (lot_qty > 0)
);

CREATE INDEX ix_doc_line_lot_exp ON doc_line_lot(expiry_date);

PROMPT [1A.3/5] doc_line_serial
CREATE TABLE doc_line_serial (
  doc_id              NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  serial_number       VARCHAR2(30)  NOT NULL,
  direction           VARCHAR2(1)   NOT NULL,
  updated_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by          VARCHAR2(20)  NOT NULL,
  CONSTRAINT pk_doc_line_serial      PRIMARY KEY (doc_id, line_no, serial_number),
  CONSTRAINT fk_doc_line_serial_line FOREIGN KEY (doc_id, line_no)
    REFERENCES doc_line(doc_id, line_no) ON DELETE CASCADE,
  CONSTRAINT ck_doc_line_serial_dir  CHECK (direction IN ('I','O'))
);

PROMPT [1A.4/5] doc_line_shortage
CREATE TABLE doc_line_shortage (
  doc_id              NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  shortage_qty        NUMBER(16,4),
  damaged_qty         NUMBER(16,4),
  notes               VARCHAR2(500),
  CONSTRAINT pk_doc_line_shortage      PRIMARY KEY (doc_id, line_no),
  CONSTRAINT fk_doc_line_shortage_line FOREIGN KEY (doc_id, line_no)
    REFERENCES doc_line(doc_id, line_no) ON DELETE CASCADE,
  CONSTRAINT ck_doc_line_shortage_qty  CHECK (NVL(shortage_qty, 0) >= 0
                                             AND NVL(damaged_qty, 0) >= 0)
);

PROMPT [1A.5/5] doc_line_cost
CREATE TABLE doc_line_cost (
  doc_id                NUMBER        NOT NULL,
  line_no               NUMBER(4)     NOT NULL,
  line_amount           NUMBER(16,4),
  amount_fob            NUMBER(16,4),
  amount_add_duty_base  NUMBER(16,4),
  duty_rate             NUMBER(5,2),
  da_rate               NUMBER(5,2),
  vat_rate              NUMBER(5,2),
  prec_rate             NUMBER(5,2),
  other_rate            NUMBER(5,2),
  duty_amount           NUMBER(16,4),
  other_fap_amount      NUMBER(16,4),
  cost_amount           NUMBER(16,4),
  margin_rate           NUMBER(5,2),
  std_price_proposed    NUMBER(16,4),
  currency_code         VARCHAR2(3)   DEFAULT 'XOF',
  memo                  VARCHAR2(500),
  CONSTRAINT pk_doc_line_cost         PRIMARY KEY (doc_id, line_no),
  CONSTRAINT fk_doc_line_cost_line    FOREIGN KEY (doc_id, line_no)
    REFERENCES doc_line(doc_id, line_no) ON DELETE CASCADE,
  CONSTRAINT ck_doc_line_cost_amounts CHECK (NVL(line_amount, 0) >= 0
                                             AND NVL(cost_amount, 0) >= 0)
);

PROMPT
PROMPT === LOT 1B : Entetes document (6 tables) ===

PROMPT [1B.1/6] doc_advance_lettering
CREATE TABLE doc_advance_lettering (
  doc_id                 NUMBER        NOT NULL,
  company_code           VARCHAR2(12)  NOT NULL,
  entry_no               NUMBER(8)     NOT NULL,
  line_no                NUMBER(4)     NOT NULL,
  sub_line_no            NUMBER(4),
  debit_letter_amount    NUMBER(16,4),
  credit_letter_amount   NUMBER(16,4),
  created_at             TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_doc_adv_lettering      PRIMARY KEY (doc_id, company_code, entry_no, line_no),
  CONSTRAINT fk_doc_adv_lettering_hdr  FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE
);

PROMPT [1B.2/6] doc_loading_note
CREATE TABLE doc_loading_note (
  doc_id              NUMBER        NOT NULL,
  supplier_code       VARCHAR2(32),
  print_count         NUMBER(3)     DEFAULT 0,
  last_printed_at     DATE,
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP,
  created_by          VARCHAR2(20),
  CONSTRAINT pk_doc_loading_note      PRIMARY KEY (doc_id),
  CONSTRAINT fk_doc_loading_note_hdr  FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE
);

PROMPT [1B.3/6] doc_delivery_option
CREATE TABLE doc_delivery_option (
  doc_id              NUMBER        NOT NULL,
  delivery_option     VARCHAR2(2),
  delivery_date       DATE,
  delivery_time       VARCHAR2(8),
  delivery_location   VARCHAR2(255),
  multiple_delivery   BOOLEAN       DEFAULT FALSE,
  recipient_name      VARCHAR2(120),
  recipient_phone     VARCHAR2(20),
  notes               VARCHAR2(500),
  CONSTRAINT pk_doc_delivery_option      PRIMARY KEY (doc_id),
  CONSTRAINT fk_doc_delivery_option_hdr  FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT ck_doc_delivery_option_code CHECK (delivery_option IS NULL
                                             OR delivery_option IN ('01','02','03'))
);

PROMPT [1B.4/6] doc_foreign_header
CREATE TABLE doc_foreign_header (
  doc_id                    NUMBER        NOT NULL,
  delivery_city_code        VARCHAR2(3),
  provenance_country        VARCHAR2(3),
  origin_country            VARCHAR2(3),
  incoterm                  VARCHAR2(3),
  loading_place             VARCHAR2(120),
  mafob_amount              NUMBER(16,4),
  freight_amount            NUMBER(16,4),
  insurance_amount          NUMBER(16,4),
  ectn_amount               NUMBER(16,4),
  insurance_off             BOOLEAN       DEFAULT FALSE,
  ectn_off                  BOOLEAN       DEFAULT FALSE,
  sgs_license_no            VARCHAR2(20),
  sgs_license_date          DATE,
  sgs_expiry_date           DATE,
  sgs_amount                NUMBER(16,4),
  di_number                 VARCHAR2(20),
  di_date                   DATE,
  di_bank                   VARCHAR2(10),
  transport_bulk            BOOLEAN       DEFAULT FALSE,
  transport_conventional    BOOLEAN       DEFAULT FALSE,
  transport_container_lcl   BOOLEAN       DEFAULT FALSE,
  transport_container_fcl   BOOLEAN       DEFAULT FALSE,
  container_size_20         BOOLEAN       DEFAULT FALSE,
  container_size_40         BOOLEAN       DEFAULT FALSE,
  single_window_no          VARCHAR2(20),
  payment_term              VARCHAR2(3),
  delivery_address          VARCHAR2(255),
  billing_address           VARCHAR2(255),
  forwarder_code            VARCHAR2(3),
  po_print_count            NUMBER(3)     DEFAULT 0,
  created_by                VARCHAR2(20),
  created_at                TIMESTAMP     DEFAULT SYSTIMESTAMP,
  updated_by                VARCHAR2(20),
  updated_at                TIMESTAMP,
  CONSTRAINT pk_doc_foreign_header      PRIMARY KEY (doc_id),
  CONSTRAINT fk_doc_foreign_header_hdr  FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE,
  CONSTRAINT ck_doc_foreign_incoterm    CHECK (incoterm IS NULL
    OR incoterm IN ('EXW','FCA','CPT','CIP','DAP','DPU','DDP','FAS','FOB','CFR','CIF'))
);

CREATE INDEX ix_doc_foreign_hdr_inc ON doc_foreign_header(incoterm);

PROMPT [1B.5/6] doc_request
CREATE TABLE doc_request (
  doc_id                NUMBER        NOT NULL,
  request_type          VARCHAR2(2),
  source_warehouse      VARCHAR2(5),
  destination_warehouse VARCHAR2(5),
  final_doc_type        VARCHAR2(20),
  request_reference     VARCHAR2(120),
  CONSTRAINT pk_doc_request      PRIMARY KEY (doc_id),
  CONSTRAINT fk_doc_request_hdr  FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE
);

PROMPT [1B.6/6] doc_attachment
CREATE TABLE doc_attachment (
  doc_id              NUMBER        NOT NULL,
  attachment_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  title               VARCHAR2(120),
  doc_date            DATE,
  file_path           VARCHAR2(2000),
  file_id             NUMBER(8),
  file_size_bytes     NUMBER(12),
  mime_type           VARCHAR2(100),
  is_special          BOOLEAN       DEFAULT FALSE,
  is_signed           BOOLEAN       DEFAULT FALSE,
  signature_hash      VARCHAR2(64),
  created_by          VARCHAR2(20)  NOT NULL,
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_doc_attachment      PRIMARY KEY (attachment_id),
  CONSTRAINT fk_doc_attachment_hdr  FOREIGN KEY (doc_id)
    REFERENCES doc_header(doc_id) ON DELETE CASCADE
);

CREATE INDEX ix_doc_attachment_hdr  ON doc_attachment(doc_id);
CREATE INDEX ix_doc_attachment_hash ON doc_attachment(signature_hash);

PROMPT
PROMPT Collecte stats
BEGIN
  DBMS_STATS.GATHER_SCHEMA_STATS('APP_DOC', cascade => TRUE);
END;
/

PROMPT
PROMPT === Validation ===
SELECT table_name, num_rows FROM user_tables
 WHERE table_name IN ('DOC_IMPUTATION','DOC_LINE_LOT','DOC_LINE_SERIAL','DOC_LINE_SHORTAGE','DOC_LINE_COST',
                      'DOC_ADVANCE_LETTERING','DOC_LOADING_NOTE','DOC_DELIVERY_OPTION','DOC_FOREIGN_HEADER',
                      'DOC_REQUEST','DOC_ATTACHMENT')
 ORDER BY table_name;

SELECT object_name, object_type, status FROM user_objects WHERE status = 'INVALID';

PROMPT ==============================================================
PROMPT   LOT 1A + 1B TERMINES (11 tables)
PROMPT ==============================================================
EXIT;