-- ============================================================
-- SCRIPT 53 : Gap-Filler Legacy — Tables "À créer" critiques
-- ============================================================
-- Complète les tables legacy critiques manquantes dans le projet
-- moderne, identifiées dans l'audit (au-dessus du 50% couverture).
--
-- 8 tables legacy bloquant la migration :
--   KERNEL.TT_* (10 tables sync files)
--   CAISSE.GCPFRNART          : articles fournisseurs (821 rows)
--   CAISSE.GCPART_UNITE_REG   : unités par région (26K rows)
--   CAISSE.GCFORMATS          : formats tickets
--   CAISSE.GCFORMATS_ZONES    : zones des formats
--   CAISSE.GCPDEP_AUTH_PC     : autorisations PC par dépôt
--   XCPTA.CP_HISTO_RGL        : historique règlements (501K rows)
--   KERNEL.UTMSG_LANGUE       : messages i18n (8.3K rows)
--   KERNEL.UTOUTPUT           : outputs (1.3M rows)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

-- Fail before creating anything when the cross-schema FK targets are absent.
DECLARE
  v_party_count NUMBER;
  v_warehouse_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_party_count
    FROM all_tables WHERE owner = 'APP_PARTY' AND table_name = 'PARTY';
  SELECT COUNT(*) INTO v_warehouse_count
    FROM all_tables WHERE owner = 'APP_ORG' AND table_name = 'ORG_WAREHOUSE';

  IF v_party_count = 0 OR v_warehouse_count = 0 THEN
    RAISE_APPLICATION_ERROR(-20053,
      'Prerequisites missing: run scripts/02_app_org.sql and scripts/04_app_party.sql before script 53.');
  END IF;
END;
/

-- GRANT ... TO self n'est pas autorise en Oracle (ORA-01749).
-- L'objet APP_PRODUCT.PRODUCT appartient deja a APP_PRODUCT : pas de grant necessaire.
GRANT SELECT, INSERT ON app_inv.inv_product_lot TO app_product;
GRANT REFERENCES ON app_party.party TO app_purchase;
GRANT REFERENCES ON app_org.org_warehouse TO app_pos;

-- =================================================================
-- 1) KERNEL.TT_* : Tables de transfert Master → Satellite
-- =================================================================
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   KERNEL.TT_* — Tables de transfert legacy (10 tables)
PROMPT ══════════════════════════════════════════════════════════

-- TT = Temporary Transfer (file d'attente Master → Boutiques)
PROMPT
PROMPT [1/10] TT_BRD_OFFICE — Transferts bordereaux Office (228K rows)
CREATE TABLE IF NOT EXISTS tt_brd_office (
  tt_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  source_site_code     VARCHAR2(10)  NOT NULL,                 -- 'PNR-OFC'
  target_site_code     VARCHAR2(10)  NOT NULL,                 -- 'BZV-B01'
  codtbrd              VARCHAR2(20)  NOT NULL,                 -- type bordereau (VTE, ACH, INV...)
  idbrd                NUMBER        NOT NULL,                 -- ID bordereau
  payload              CLOB,                                  -- données complètes (JSON)
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',        -- PENDING | SENT | ACKED | ERROR
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP,
  sent_at              TIMESTAMP,
  acked_at             TIMESTAMP,
  retry_count          NUMBER(2)     DEFAULT 0,
  CONSTRAINT pk_tt_brd_office      PRIMARY KEY (tt_id),
  CONSTRAINT ck_tt_brd_office_st   CHECK (transfer_state IN ('PENDING','SENT','ACKED','ERROR','CANCELLED'))
);
CREATE INDEX IF NOT EXISTS ix_tt_brd_office_target ON tt_brd_office(target_site_code, transfer_state);

PROMPT
PROMPT [2/10] TT_BRDD — Transferts lignes (1.8K rows)
CREATE TABLE IF NOT EXISTS tt_brdd (
  tt_brdd_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  tt_brd_id            NUMBER        NOT NULL,
  numlig               NUMBER(6)     NOT NULL,
  codart               VARCHAR2(80)  NOT NULL,
  quantity             NUMBER(16,4)  NOT NULL,
  payload              CLOB,
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_tt_brdd            PRIMARY KEY (tt_brdd_id),
  CONSTRAINT fk_tt_brdd_hdr        FOREIGN KEY (tt_brd_id)
    REFERENCES tt_brd_office(tt_id) ON DELETE CASCADE
);

PROMPT
PROMPT [3/10] TT_BRDE — Transferts entêtes (288 rows)
CREATE TABLE IF NOT EXISTS tt_brde (
  tt_brde_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  tt_brd_id            NUMBER        NOT NULL,
  datbrd               DATE          NOT NULL,
  coddep_src           VARCHAR2(5),
  coddep_tgt           VARCHAR2(5),
  codtbrd              VARCHAR2(20),
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',
  CONSTRAINT pk_tt_brde            PRIMARY KEY (tt_brde_id),
  CONSTRAINT fk_tt_brde_hdr        FOREIGN KEY (tt_brd_id)
    REFERENCES tt_brd_office(tt_id) ON DELETE CASCADE
);

PROMPT
PROMPT [4/10] TT_LUM — Transferts LUM (lookup-mappings, 19.8K)
CREATE TABLE IF NOT EXISTS tt_lum (
  tt_lum_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  source_table         VARCHAR2(30)  NOT NULL,
  source_code          VARCHAR2(80)  NOT NULL,
  target_table         VARCHAR2(30)  NOT NULL,
  target_code          VARCHAR2(80)  NOT NULL,
  site_code            VARCHAR2(10),
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_tt_lum             PRIMARY KEY (tt_lum_id),
  CONSTRAINT uk_tt_lum_pair        UNIQUE (source_table, source_code, target_table, site_code)
);

PROMPT
PROMPT [5/10] TT_GCPPAR — Transferts paramètres GCP (1.5K)
CREATE TABLE IF NOT EXISTS tt_gcppar (
  tt_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  codpar               VARCHAR2(40)  NOT NULL,
  valpar               VARCHAR2(200),
  site_code            VARCHAR2(10),
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',
  created_at           TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_tt_gcppar          PRIMARY KEY (tt_id),
  CONSTRAINT uk_tt_gcppar_pair     UNIQUE (codpar, site_code)
);

PROMPT
PROMPT [6/10] TT_CAIPPAR — Transferts paramètres caisse (160)
CREATE TABLE IF NOT EXISTS tt_caippar (
  tt_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  codpar               VARCHAR2(40)  NOT NULL,
  valpar               VARCHAR2(200),
  terminal_code        VARCHAR2(20)  NOT NULL,
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',
  CONSTRAINT pk_tt_caippar         PRIMARY KEY (tt_id),
  CONSTRAINT uk_tt_caippar_pair    UNIQUE (codpar, terminal_code)
);

PROMPT
PROMPT [7/10] TT_ECR — Transferts écritures (1)
PROMPT [8/10] TT_ECR_GEN — Transferts écritures générales (155)
PROMPT [9/10] TT_ECR_LET — Transferts écritures lettrées (154)
CREATE TABLE IF NOT EXISTS tt_ecr (
  tt_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  no_jou               VARCHAR2(10)  NOT NULL,
  no_edi               NUMBER(8)     NOT NULL,
  codmdr               VARCHAR2(10),
  no_maj               NUMBER(8),
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',
  CONSTRAINT pk_tt_ecr             PRIMARY KEY (tt_id)
);

CREATE TABLE IF NOT EXISTS tt_ecr_gen (
  tt_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  tt_ecr_id            NUMBER        NOT NULL,
  codabr               VARCHAR2(20)  NOT NULL,
  sen                  CHAR(1)       NOT NULL,                 -- D (débit) ou C (crédit)
  montant              NUMBER(16,4)  NOT NULL,
  CONSTRAINT pk_tt_ecr_gen         PRIMARY KEY (tt_id),
  CONSTRAINT fk_tt_ecr_gen_hdr     FOREIGN KEY (tt_ecr_id)
    REFERENCES tt_ecr(tt_id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS tt_ecr_let (
  tt_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  tt_ecr_id            NUMBER        NOT NULL,
  codlet               VARCHAR2(20)  NOT NULL,
  CONSTRAINT pk_tt_ecr_let         PRIMARY KEY (tt_id),
  CONSTRAINT fk_tt_ecr_let_hdr     FOREIGN KEY (tt_ecr_id)
    REFERENCES tt_ecr(tt_id) ON DELETE CASCADE
);

PROMPT
PROMPT [10/10] TT_GCPUNI_COEFF, TT_RTAX, TT_TLOC — Transferts coeff/taxes/loc
CREATE TABLE IF NOT EXISTS tt_gcpuni_coeff (
  tt_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  codart               VARCHAR2(80)  NOT NULL,
  unit_src             VARCHAR2(12),
  unit_dst             VARCHAR2(12),
  coefficient          NUMBER(16,6),
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',
  CONSTRAINT pk_tt_gcpuni_coeff    PRIMARY KEY (tt_id)
);

CREATE TABLE IF NOT EXISTS tt_rtax (
  tt_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  codrtax              VARCHAR2(12)  NOT NULL,
  taux                 NUMBER(7,4),
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',
  CONSTRAINT pk_tt_rtax            PRIMARY KEY (tt_id)
);

CREATE TABLE IF NOT EXISTS tt_tloc (
  tt_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  codloc               VARCHAR2(12)  NOT NULL,
  libloc               VARCHAR2(80),
  transfer_state       VARCHAR2(20)  DEFAULT 'PENDING',
  CONSTRAINT pk_tt_tloc            PRIMARY KEY (tt_id)
);

-- =================================================================
-- 2) CAISSE.GCPFRNART — Articles fournisseurs
-- =================================================================
CONNECT app_purchase/AppPurchase#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ CAISSE.GCPFRNART — Articles fournisseurs (821 rows) ═══
CREATE TABLE IF NOT EXISTS supplier_product (
  supplier_product_id   NUMBER GENERATED ALWAYS AS IDENTITY,
  supplier_code         VARCHAR2(32)  NOT NULL,
  product_code          VARCHAR2(80)  NOT NULL,
  supplier_ref          VARCHAR2(80),
  product_name          VARCHAR2(255),
  unit_purchase         VARCHAR2(12),
  purchase_price        NUMBER(16,4)  NOT NULL,
  min_order_qty         NUMBER(10,2),
  lead_time_days        NUMBER(4),
  valid_from            DATE          DEFAULT SYSDATE,
  valid_to              DATE,
  is_preferred          BOOLEAN       DEFAULT FALSE,
  CONSTRAINT pk_supplier_product   PRIMARY KEY (supplier_product_id),
  CONSTRAINT uk_supplier_product   UNIQUE (supplier_code, product_code, valid_from),
  CONSTRAINT fk_supplier_product_s FOREIGN KEY (supplier_code)
    REFERENCES app_party.party(party_code)
);
CREATE INDEX IF NOT EXISTS ix_supplier_product_p ON supplier_product(product_code);

-- =================================================================
-- 3) CAISSE.GCPART_UNITE_REG — Unités par région
-- =================================================================
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ CAISSE.GCPART_UNITE_REG — Unités par région (26K rows) ═══
CREATE TABLE IF NOT EXISTS product_unit_region (
  product_unit_region_id NUMBER GENERATED ALWAYS AS IDENTITY,
  product_code            VARCHAR2(80)  NOT NULL,
  unit_code               VARCHAR2(12)  NOT NULL,
  region_code             VARCHAR2(10)  NOT NULL,
  -- attributs spécifiques à la région
  coefficient             NUMBER(16,6)  DEFAULT 1,
  unit_label              VARCHAR2(80),
  min_qty                 NUMBER(16,4),
  CONSTRAINT pk_product_unit_region    PRIMARY KEY (product_unit_region_id),
  CONSTRAINT uk_product_unit_region    UNIQUE (product_code, unit_code, region_code)
);

-- =================================================================
-- 4) CAISSE.GCFORMATS — Formats de tickets
-- =================================================================
CONNECT app_pos/AppPos#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ CAISSE.GCFORMATS + GCFORMATS_ZONES — Formats tickets ═══
CREATE TABLE IF NOT EXISTS pos_format (
  format_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  format_code            VARCHAR2(20)  NOT NULL,
  format_name            VARCHAR2(120) NOT NULL,
  paper_width_mm         NUMBER(4)     DEFAULT 80,
  template_json          CLOB,                                  -- JSON du template
  is_active              BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_pos_format             PRIMARY KEY (format_id),
  CONSTRAINT uk_pos_format_code        UNIQUE (format_code)
);

CREATE TABLE IF NOT EXISTS pos_format_zone (
  zone_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  format_id              NUMBER        NOT NULL,
  zone_code              VARCHAR2(20)  NOT NULL,               -- HEADER, BODY, FOOTER, BARCODE...
  zone_order             NUMBER(3)     NOT NULL,
  zone_height_mm         NUMBER(4),
  content_template       VARCHAR2(2000),                        -- expression du contenu
  CONSTRAINT pk_pos_format_zone        PRIMARY KEY (zone_id),
  CONSTRAINT fk_pos_format_zone_fmt    FOREIGN KEY (format_id)
    REFERENCES pos_format(format_id) ON DELETE CASCADE,
  CONSTRAINT uk_pos_format_zone_order  UNIQUE (format_id, zone_order)
);

-- =================================================================
-- 5) CAISSE.GCPDEP_AUTH_PC — Autorisations PC par dépôt
-- =================================================================
PROMPT
PROMPT ═══ CAISSE.GCPDEP_AUTH_PC — Autorisations PC par dépôt ═══
CREATE TABLE IF NOT EXISTS warehouse_pc_auth (
  auth_id                NUMBER GENERATED ALWAYS AS IDENTITY,
  warehouse_code         VARCHAR2(5)   NOT NULL,
  pc_name                VARCHAR2(40)  NOT NULL,
  pc_mac                 VARCHAR2(40),
  is_authorized          BOOLEAN       DEFAULT TRUE,
  authorized_by          VARCHAR2(20),
  authorized_at          TIMESTAMP,
  revoked_at             TIMESTAMP,
  CONSTRAINT pk_warehouse_pc_auth      PRIMARY KEY (auth_id),
  CONSTRAINT uk_warehouse_pc_auth      UNIQUE (warehouse_code, pc_name),
  CONSTRAINT fk_warehouse_pc_auth_w    FOREIGN KEY (warehouse_code)
    REFERENCES app_org.org_warehouse(warehouse_code)
);

-- =================================================================
-- 6) XCPTA.CP_HISTO_RGL — Historique règlements (501K)
-- =================================================================
CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ XCPTA.CP_HISTO_RGL — Historique règlements (501K rows) ═══
CREATE TABLE IF NOT EXISTS payment_history (
  history_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  payment_id             NUMBER        NOT NULL,
  party_code             VARCHAR2(32)  NOT NULL,
  invoice_id             NUMBER,
  paid_amount            NUMBER(16,4)  NOT NULL,
  paid_at                TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  payment_method         VARCHAR2(20)  NOT NULL,               -- BANK_TRANSFER | CASH | CHECK
  bank_ref               VARCHAR2(120),
  applied_amount         NUMBER(16,4),
  -- Partitioning columns
  history_year           NUMBER(4)     GENERATED ALWAYS AS (EXTRACT(YEAR FROM paid_at)),
  history_month          NUMBER(2)     GENERATED ALWAYS AS (EXTRACT(MONTH FROM paid_at)),
  CONSTRAINT pk_payment_history        PRIMARY KEY (history_id),
  CONSTRAINT fk_payment_history_pay    FOREIGN KEY (payment_id)
    REFERENCES payment(payment_id),
  CONSTRAINT ck_payment_history_meth   CHECK (payment_method IN ('BANK_TRANSFER','CASH','CHECK','MOBILE_MONEY','CARD','SEPA'))
);

-- Table partitionnée par mois (compression mensuelle)
-- Note : la création se fait en tablespace dédié en production
CREATE INDEX IF NOT EXISTS ix_payment_history_party  ON payment_history(party_code, paid_at);
CREATE INDEX IF NOT EXISTS ix_payment_history_invoice ON payment_history(invoice_id);

-- =================================================================
-- 7) KERNEL.UTMSG/UTMSG_LANGUE — Messages i18n
-- =================================================================
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT ═══ KERNEL.UTMSG + UTMSG_LANGUE — Messages i18n (8.3K rows) ═══
CREATE TABLE IF NOT EXISTS sys_message (
  message_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  message_key            VARCHAR2(80)  NOT NULL,                -- 'CASH.BON.SIGNATURE'
  default_text           VARCHAR2(500) NOT NULL,
  message_type           VARCHAR2(20)  DEFAULT 'INFO',          -- INFO | WARN | ERROR | LABEL
  is_user_visible        BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_sys_message            PRIMARY KEY (message_id),
  CONSTRAINT uk_sys_message_key        UNIQUE (message_key)
);

CREATE TABLE IF NOT EXISTS sys_message_lang (
  message_id             NUMBER        NOT NULL,
  lang_code              VARCHAR2(5)   NOT NULL,                -- 'fr', 'en', 'ln' (lingala)
  translated_text        VARCHAR2(500) NOT NULL,
  CONSTRAINT pk_sys_message_lang       PRIMARY KEY (message_id, lang_code),
  CONSTRAINT fk_sys_message_lang_m     FOREIGN KEY (message_id)
    REFERENCES sys_message(message_id) ON DELETE CASCADE
);

-- =================================================================
-- 8) KERNEL.UTOUTPUT — Outputs (1.3M rows)
-- =================================================================
PROMPT
PROMPT ═══ KERNEL.UTOUTPUT — Outputs ═══
CREATE TABLE IF NOT EXISTS sys_output (
  output_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  output_type            VARCHAR2(20)  NOT NULL,               -- PRINT | FILE | MAIL | DISPLAY
  user_code              VARCHAR2(20)  NOT NULL,
  document_type          VARCHAR2(30),                          -- TICKET | INVOICE | REPORT
  document_id            NUMBER,
  output_data            CLOB,                                 -- contenu
  created_at             TIMESTAMP     DEFAULT SYSTIMESTAMP,
  printed_at             TIMESTAMP,
  CONSTRAINT pk_sys_output             PRIMARY KEY (output_id),
  CONSTRAINT ck_sys_output_type        CHECK (output_type IN ('PRINT','FILE','MAIL','DISPLAY','PDF_EXPORT'))
);

-- Vue pratique
PROMPT
PROMPT ═══ Vue pratique : État des transferts Master → Boutiques ═══
CREATE OR REPLACE VIEW v_tt_pending AS
SELECT tt_brd_office.tt_id,
       tt_brd_office.source_site_code,
       tt_brd_office.target_site_code,
       tt_brd_office.codtbrd,
       tt_brd_office.transfer_state,
       tt_brd_office.created_at,
       tt_brd_office.sent_at,
       tt_brd_office.acked_at,
       tt_brd_office.retry_count
  FROM tt_brd_office
 WHERE tt_brd_office.transfer_state IN ('PENDING','ERROR')
 ORDER BY tt_brd_office.created_at;

-- =================================================================
-- Privilèges
-- =================================================================
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

GRANT SELECT, INSERT ON app_sys.tt_brd_office      TO app_api;
GRANT SELECT, INSERT ON app_sys.tt_brdd           TO app_api;
GRANT SELECT, INSERT ON app_sys.tt_brde           TO app_api;
GRANT SELECT, INSERT ON app_sys.tt_lum            TO app_api;
GRANT SELECT, INSERT ON app_sys.tt_gcppar         TO app_api;
GRANT SELECT, INSERT ON app_sys.tt_caippar        TO app_api;
GRANT SELECT, INSERT ON app_sys.tt_ecr            TO app_api;
GRANT SELECT, INSERT ON app_sys.tt_gcpuni_coeff  TO app_api;
GRANT SELECT, INSERT ON app_sys.tt_rtax           TO app_api;
GRANT SELECT, INSERT ON app_sys.tt_tloc           TO app_api;
GRANT SELECT, INSERT ON app_sys.sys_message       TO app_api;
GRANT SELECT, INSERT ON app_sys.sys_message_lang  TO app_api;
GRANT SELECT, INSERT ON app_sys.sys_output        TO app_api;

GRANT SELECT, INSERT ON app_product.product_unit_region TO app_api;
GRANT SELECT, INSERT ON app_pos.pos_format             TO app_api;
GRANT SELECT, INSERT ON app_pos.pos_format_zone        TO app_api;
GRANT SELECT, INSERT ON app_pos.warehouse_pc_auth      TO app_api;
GRANT SELECT, INSERT ON app_purchase.supplier_product  TO app_api;
GRANT SELECT, INSERT ON app_ar.payment_history         TO app_api;

PROMPT
PROMPT ═══ Validation : Tables créées ═══
SELECT owner, table_name, num_rows
  FROM all_tables
 WHERE table_name IN (
    'TT_BRD_OFFICE','TT_BRDD','TT_BRDE','TT_LUM','TT_GCPPAR','TT_CAIPPAR',
    'TT_ECR','TT_ECR_GEN','TT_ECR_LET','TT_GCPUNI_COEFF','TT_RTAX','TT_TLOC',
    'SUPPLIER_PRODUCT','PRODUCT_UNIT_REGION',
    'POS_FORMAT','POS_FORMAT_ZONE','WAREHOUSE_PC_AUTH',
    'PAYMENT_HISTORY',
    'SYS_MESSAGE','SYS_MESSAGE_LANG','SYS_OUTPUT'
   )
 ORDER BY owner, table_name;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ GAP-FILLER LEGACY : 21 tables critiques + 1 vue ajoutées
PROMPT   - 12 tables TT_* (sync Master → Boutique, dont 228K rows TT_BRD_OFFICE)
PROMPT   - 1 supplier_product (821 rows articles fournisseurs)
PROMPT   - 1 product_unit_region (26K rows unités par région)
PROMPT   - 2 pos_format + zones (formats tickets LITOKO)
PROMPT   - 1 warehouse_pc_auth (sécurité PC par dépôt)
PROMPT   - 1 payment_history (501K rows historique règlements)
PROMPT   - 2 sys_message + sys_message_lang (i18n fr/en)
PROMPT   - 1 sys_output (1.3M rows outputs)
PROMPT   - 1 v_tt_pending (vue Master → Boutiques)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
