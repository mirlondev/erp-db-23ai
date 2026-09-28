-- ============================================================
-- SCRIPT 46 : OHADA - Immobilisations & Amortissements
-- ============================================================
-- 5 tables pour la gestion des immobilisations SYSCOHADA :
--   imm_asset : fiche immobilisation (voie SYSCOHADA 2 classe 24-25)
--   imm_method : méthodes d'amortissement (LINEAR, DEGRESSIVE, ACCELERATED)
--   imm_depreciation : plan d'amortissement calculé par exercice
--   imm_disposal : sortie (cession/destruction)
--   imm_revaluation : réévaluation (réévaluation légale libre)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT, INSERT, UPDATE ON app_gl.gl_entry TO app_gl;

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   IMMOBILISATIONS OHADA (5 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/5] imm_asset — fiches d'immobilisations
CREATE TABLE imm_asset (
  asset_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  asset_code           VARCHAR2(20)  NOT NULL,              -- ex. IMM-2026-001
  company_code         VARCHAR2(12)  NOT NULL,
  asset_name           VARCHAR2(120) NOT NULL,              -- ex. 'Camion Mercedes Sprinter'
  category             VARCHAR2(20)  NOT NULL,              -- LAND|BUILDING|MACHINERY|EQUIPMENT|VEHICLE|FURNITURE|IT|SOFTWARE
  acquisition_date     DATE          NOT NULL,
  acquisition_value    NUMBER(16,4)  NOT NULL,              -- valeur d'origine en XOF
  residual_value       NUMBER(16,4)  DEFAULT 0,             -- valeur résiduelle (mise au rebut)
  useful_life_months   NUMBER(4)     NOT NULL,              -- durée d'utilité en mois
  depreciation_method  VARCHAR2(20)  DEFAULT 'LINEAR',      -- LINEAR | DEGRESSIVE | ACCELERATED
  depreciation_rate    NUMBER(7,4),                         -- taux annuel (calculé si NULL)
  gl_account_code      VARCHAR2(8),                         -- compte immo (244, 245, ...)
  accumulated_dep      NUMBER(16,4)  DEFAULT 0,             -- amortissement cumulé
  net_book_value       NUMBER(16,4),                        -- VNC (GENERATED)
  status               VARCHAR2(20)  DEFAULT 'ACTIVE',      -- ACTIVE | DISPOSED | WRITE_OFF | TRANSFERRED
  serial_number        VARCHAR2(80),
  location_code        VARCHAR2(20),                        -- localisation (entrepôt/site)
  supplier_code        VARCHAR2(32),
  invoice_ref          VARCHAR2(120),                       -- facture d'achat
  notes                VARCHAR2(1000),
  CONSTRAINT pk_imm_asset                   PRIMARY KEY (asset_id),
  CONSTRAINT uk_imm_asset_code              UNIQUE (asset_code, company_code),
  CONSTRAINT ck_imm_asset_category          CHECK (category IN ('LAND','BUILDING','MACHINERY','EQUIPMENT','VEHICLE','FURNITURE','IT','SOFTWARE','INTANGIBLE','CONSTRUCTION_IN_PROGRESS')),
  CONSTRAINT ck_imm_asset_method            CHECK (depreciation_method IN ('LINEAR','DEGRESSIVE','ACCELERATED','NONE')),
  CONSTRAINT ck_imm_asset_status            CHECK (status IN ('ACTIVE','DISPOSED','WRITE_OFF','TRANSFERRED','CONSTRUCTED')),
  CONSTRAINT ck_imm_asset_value             CHECK (acquisition_value > 0 AND NVL(residual_value,0) >= 0 AND useful_life_months > 0)
);

CREATE INDEX ix_imm_asset_company        ON imm_asset(company_code, status);
CREATE INDEX ix_imm_asset_category       ON imm_asset(category);
CREATE INDEX ix_imm_asset_acquisition    ON imm_asset(acquisition_date, company_code);

PROMPT
PROMPT [2/5] imm_method — méthodes d'amortissement (planning)
CREATE TABLE imm_method (
  method_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  method_code          VARCHAR2(20)  NOT NULL,
  method_label         VARCHAR2(80)  NOT NULL,
  method_type          VARCHAR2(20)  NOT NULL,              -- LINEAIRE | DEGRESSIVE | ACCELERATED | NONE
  formula              VARCHAR2(1000) NOT NULL,             -- description / formule
  tva_applicable       BOOLEAN       DEFAULT FALSE,
  applicable_to        VARCHAR2(120),                       -- 'VEHICLE:EQ' → BUILDING, VEHICLE, ...
  CONSTRAINT pk_imm_method                PRIMARY KEY (method_id),
  CONSTRAINT uk_imm_method_code           UNIQUE (method_code),
  CONSTRAINT ck_imm_method_type           CHECK (method_type IN ('LINEAR','DEGRESSIVE','ACCELERATED','NONE'))
);

PROMPT
PROMPT [3/5] imm_depreciation — plan d'amortissement calculé
CREATE TABLE imm_depreciation (
  depr_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  asset_id             NUMBER        NOT NULL,
  fiscal_year          NUMBER(4)     NOT NULL,              -- exercice (4 chiffres)
  period_no            NUMBER(2)     NOT NULL,              -- mois (1-12)
  period_start         DATE          NOT NULL,
  period_end           DATE          NOT NULL,
  depr_amount          NUMBER(16,4)  NOT NULL,              -- dotation mensuelle
  cumulative_depr      NUMBER(16,4)  NOT NULL,              -- cumulé fin période
  residual_value_at    NUMBER(16,4)  NOT NULL,              -- valeur nette comptable
  entry_id             NUMBER,                              -- écriture comptable (gl_entry)
  posted_at            TIMESTAMP,                           -- quand comptabilisée
  status               VARCHAR2(20)  DEFAULT 'PENDING',     -- PENDING | POSTED | ADJUSTED | CANCELLED
  CONSTRAINT pk_imm_depreciation          PRIMARY KEY (depr_id),
  CONSTRAINT fk_imm_depr_asset            FOREIGN KEY (asset_id)
    REFERENCES imm_asset(asset_id) ON DELETE CASCADE,
  CONSTRAINT fk_imm_depr_entry            FOREIGN KEY (entry_id)
    REFERENCES gl_entry(entry_id),
  CONSTRAINT uk_imm_depr_period           UNIQUE (asset_id, fiscal_year, period_no),
  CONSTRAINT ck_imm_depr_status           CHECK (status IN ('PENDING','POSTED','ADJUSTED','CANCELLED'))
);

CREATE INDEX ix_imm_depr_year         ON imm_depreciation(fiscal_year, period_no, status);
CREATE INDEX ix_imm_depr_pending      ON imm_depreciation(status);

PROMPT
PROMPT [4/5] imm_disposal — sorties (cession, mise au rebut, vol)
CREATE TABLE imm_disposal (
  disposal_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  asset_id             NUMBER        NOT NULL,
  disposal_date        DATE          NOT NULL,
  disposal_type        VARCHAR2(20)  NOT NULL,              -- SALE | DESTRUCTION | THEFT | TRANSFER | RETURN
  disposal_value       NUMBER(16,4)  NOT NULL,              -- prix de cession
  net_book_value_at    NUMBER(16,4)  NOT NULL,              -- VNC au moment de la sortie
  gain_loss_amount     NUMBER(16,4),                        -- +/- value de cession
  buyer                VARCHAR2(120),
  document_ref         VARCHAR2(120),                       -- référence reçu
  notes                VARCHAR2(1000),
  entry_id             NUMBER,                              -- écriture comptable
  CONSTRAINT pk_imm_disposal              PRIMARY KEY (disposal_id),
  CONSTRAINT fk_imm_disposal_asset        FOREIGN KEY (asset_id)
    REFERENCES imm_asset(asset_id),
  CONSTRAINT fk_imm_disposal_entry        FOREIGN KEY (entry_id)
    REFERENCES gl_entry(entry_id),
  CONSTRAINT ck_imm_disposal_type         CHECK (disposal_type IN ('SALE','DESTRUCTION','THEFT','TRANSFER','RETURN','LOSS')),
  CONSTRAINT ck_imm_disposal_value        CHECK (disposal_value >= 0)
);

PROMPT
PROMPT [5/5] imm_revaluation — réévaluation d'immobilisations (système SYSCOHADA révisé)
CREATE TABLE imm_revaluation (
  revaluation_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  asset_id             NUMBER        NOT NULL,
  revaluation_date     DATE          NOT NULL,
  revaluation_type     VARCHAR2(20)  NOT NULL,              -- FREE | LEGAL | INFLATIONARY | INDEX_TRIGGER
  old_value            NUMBER(16,4)  NOT NULL,              -- VNC avant
  new_value            NUMBER(16,4)  NOT NULL,              -- nouvelle VNC
  coefficient          NUMBER(10,4)  NOT NULL,              -- new / old
  legal_basis          VARCHAR2(255),                       -- référence légale ('Loi n°...')
  authorizing_body     VARCHAR2(120),                       -- 'Assemblée Générale', 'Conseil Administration'
  entry_id             NUMBER,
  notes                VARCHAR2(1000),
  CONSTRAINT pk_imm_revaluation          PRIMARY KEY (revaluation_id),
  CONSTRAINT fk_imm_rev_asset            FOREIGN KEY (asset_id)
    REFERENCES imm_asset(asset_id),
  CONSTRAINT fk_imm_rev_entry            FOREIGN KEY (entry_id)
    REFERENCES gl_entry(entry_id),
  CONSTRAINT ck_imm_rev_type             CHECK (revaluation_type IN ('FREE','LEGAL','INFLATIONARY','INDEX_TRIGGER'))
);

-- Privilèges
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT ON app_gl.imm_asset             TO app_api;
GRANT SELECT ON app_gl.imm_depreciation     TO app_api;
GRANT SELECT ON app_gl.imm_disposal         TO app_api;
GRANT SELECT ON app_gl.imm_revaluation      TO app_api;
GRANT SELECT ON app_gl.imm_method           TO app_api;
GRANT SELECT, INSERT ON app_gl.imm_asset            TO app_audit;
GRANT SELECT, INSERT ON app_gl.imm_depreciation    TO app_audit;

-- Vue pratique : Fiches d'immobilisations avec cumul amortissement
PROMPT
PROMPT [Vue pratique] v_imm_summary
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE VIEW v_imm_summary AS
SELECT a.asset_id,
       a.asset_code,
       a.asset_name,
       a.category,
       a.acquisition_date,
       a.acquisition_value,
       a.accumulated_dep,
       a.net_book_value,
       -- Cout mensuel
       CASE WHEN a.useful_life_months > 0
            THEN ROUND(a.acquisition_value / a.useful_life_months, 4)
            ELSE 0 END AS monthly_depr,
       -- Progression amortissement (%)
       CASE WHEN a.acquisition_value > 0
            THEN ROUND(100 * a.accumulated_dep / a.acquisition_value, 2)
            ELSE 0 END AS depr_progress_pct,
       -- Status
       a.status
  FROM imm_asset a
 WHERE a.status = 'ACTIVE';

PROMPT
PROMPT ═══ Validation ═══
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('IMM_ASSET','IMM_METHOD','IMM_DEPRECIATION','IMM_DISPOSAL','IMM_REVALUATION')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Pas d'objets invalides
SELECT object_name, object_type, status
  FROM user_objects WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ IMMOBILISATIONS OHADA TERMINÉES (5 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
