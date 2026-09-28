-- ============================================================
-- SCRIPT 46 : OHADA - Immobilisations & Amortissements (CORRIGÉ)
-- ============================================================
-- ⚠️ La PK de gl_entry est composite : (company_code, entry_no).
--    Il n'existe PAS de colonne entry_id.
--    → Les FK vers gl_entry sont donc REMPLACÉES par des références
--      logiques : colonnes entry_company_code + entry_no (sans FK).
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

-- Nettoyage idempotent (ordre inverse des dépendances)
DECLARE
  PROCEDURE d(p_t VARCHAR2, p_n VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP '||p_t||' '||p_n||' CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('  DROP '||p_t||' '||p_n);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  d('VIEW','v_imm_summary');
  d('TABLE','imm_revaluation');
  d('TABLE','imm_disposal');
  d('TABLE','imm_depreciation');
  d('TABLE','imm_method');
  d('TABLE','imm_asset');
END;
/

-- ------------------------------------------------------------------
-- [1/5] imm_asset
-- ------------------------------------------------------------------
PROMPT
PROMPT [1/5] imm_asset — fiches d'immobilisations
CREATE TABLE imm_asset (
  asset_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  asset_code           VARCHAR2(20)  NOT NULL,
  company_code         VARCHAR2(12)  NOT NULL,
  asset_name           VARCHAR2(120) NOT NULL,
  category             VARCHAR2(20)  NOT NULL,
  acquisition_date     DATE          NOT NULL,
  acquisition_value    NUMBER(16,4)  NOT NULL,
  residual_value       NUMBER(16,4)  DEFAULT 0,
  useful_life_months   NUMBER(4)     NOT NULL,
  depreciation_method  VARCHAR2(20)  DEFAULT 'LINEAR',
  depreciation_rate    NUMBER(7,4),
  gl_account_code      VARCHAR2(8),
  accumulated_dep      NUMBER(16,4)  DEFAULT 0,
  net_book_value       NUMBER(16,4),
  status               VARCHAR2(20)  DEFAULT 'ACTIVE',
  serial_number        VARCHAR2(80),
  location_code        VARCHAR2(20),
  supplier_code        VARCHAR2(32),
  invoice_ref          VARCHAR2(120),
  notes                VARCHAR2(1000),
  CONSTRAINT pk_imm_asset              PRIMARY KEY (asset_id),
  CONSTRAINT uk_imm_asset_code         UNIQUE (asset_code, company_code),
  CONSTRAINT ck_imm_asset_category     CHECK (category IN
    ('LAND','BUILDING','MACHINERY','EQUIPMENT','VEHICLE','FURNITURE','IT',
     'SOFTWARE','INTANGIBLE','CONSTRUCTION_IN_PROGRESS')),
  CONSTRAINT ck_imm_asset_method       CHECK (depreciation_method IN
    ('LINEAR','DEGRESSIVE','ACCELERATED','NONE')),
  CONSTRAINT ck_imm_asset_status       CHECK (status IN
    ('ACTIVE','DISPOSED','WRITE_OFF','TRANSFERRED','CONSTRUCTED')),
  CONSTRAINT ck_imm_asset_value        CHECK (acquisition_value > 0
    AND NVL(residual_value,0) >= 0 AND useful_life_months > 0)
);

CREATE INDEX ix_imm_asset_company     ON imm_asset(company_code, status);
CREATE INDEX ix_imm_asset_category    ON imm_asset(category);
CREATE INDEX ix_imm_asset_acquisition ON imm_asset(acquisition_date, company_code);

-- ------------------------------------------------------------------
-- [2/5] imm_method
-- ------------------------------------------------------------------
PROMPT
PROMPT [2/5] imm_method — méthodes d'amortissement
CREATE TABLE imm_method (
  method_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  method_code          VARCHAR2(20)  NOT NULL,
  method_label         VARCHAR2(80)  NOT NULL,
  method_type          VARCHAR2(20)  NOT NULL,
  formula              VARCHAR2(1000) NOT NULL,
  tva_applicable       BOOLEAN       DEFAULT FALSE,
  applicable_to        VARCHAR2(120),
  CONSTRAINT pk_imm_method             PRIMARY KEY (method_id),
  CONSTRAINT uk_imm_method_code        UNIQUE (method_code),
  CONSTRAINT ck_imm_method_type        CHECK (method_type IN
    ('LINEAR','DEGRESSIVE','ACCELERATED','NONE'))
);

-- ------------------------------------------------------------------
-- [3/5] imm_depreciation — référence logique vers gl_entry
-- ------------------------------------------------------------------
PROMPT
PROMPT [3/5] imm_depreciation — plan d'amortissement calculé
-- Référence logique vers gl_entry(company_code, entry_no) — SANS FK.
CREATE TABLE imm_depreciation (
  depr_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  asset_id             NUMBER        NOT NULL,
  fiscal_year          NUMBER(4)     NOT NULL,
  period_no            NUMBER(2)     NOT NULL,
  period_start         DATE          NOT NULL,
  period_end           DATE          NOT NULL,
  depr_amount          NUMBER(16,4)  NOT NULL,
  cumulative_depr      NUMBER(16,4)  NOT NULL,
  residual_value_at    NUMBER(16,4)  NOT NULL,
  entry_company_code   VARCHAR2(2),   -- référence logique vers gl_entry
  entry_no             NUMBER(8),     -- référence logique vers gl_entry
  posted_at            TIMESTAMP,
  status               VARCHAR2(20)  DEFAULT 'PENDING',
  CONSTRAINT pk_imm_depreciation       PRIMARY KEY (depr_id),
  CONSTRAINT fk_imm_depr_asset         FOREIGN KEY (asset_id)
    REFERENCES imm_asset(asset_id) ON DELETE CASCADE,
  CONSTRAINT uk_imm_depr_period        UNIQUE (asset_id, fiscal_year, period_no),
  CONSTRAINT ck_imm_depr_status        CHECK (status IN
    ('PENDING','POSTED','ADJUSTED','CANCELLED'))
);

CREATE INDEX ix_imm_depr_year    ON imm_depreciation(fiscal_year, period_no, status);
CREATE INDEX ix_imm_depr_pending ON imm_depreciation(status);
CREATE INDEX ix_imm_depr_entry   ON imm_depreciation(entry_company_code, entry_no);

-- ------------------------------------------------------------------
-- [4/5] imm_disposal
-- ------------------------------------------------------------------
PROMPT
PROMPT [4/5] imm_disposal — sorties (cession, mise au rebut, vol)
CREATE TABLE imm_disposal (
  disposal_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  asset_id             NUMBER        NOT NULL,
  disposal_date        DATE          NOT NULL,
  disposal_type        VARCHAR2(20)  NOT NULL,
  disposal_value       NUMBER(16,4)  NOT NULL,
  net_book_value_at    NUMBER(16,4)  NOT NULL,
  gain_loss_amount     NUMBER(16,4),
  buyer                VARCHAR2(120),
  document_ref         VARCHAR2(120),
  notes                VARCHAR2(1000),
  entry_company_code   VARCHAR2(2),
  entry_no             NUMBER(8),
  CONSTRAINT pk_imm_disposal           PRIMARY KEY (disposal_id),
  CONSTRAINT fk_imm_disposal_asset     FOREIGN KEY (asset_id)
    REFERENCES imm_asset(asset_id),
  CONSTRAINT ck_imm_disposal_type      CHECK (disposal_type IN
    ('SALE','DESTRUCTION','THEFT','TRANSFER','RETURN','LOSS')),
  CONSTRAINT ck_imm_disposal_value     CHECK (disposal_value >= 0)
);

-- ------------------------------------------------------------------
-- [5/5] imm_revaluation
-- ------------------------------------------------------------------
PROMPT
PROMPT [5/5] imm_revaluation — réévaluation d'immobilisations
CREATE TABLE imm_revaluation (
  revaluation_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  asset_id             NUMBER        NOT NULL,
  revaluation_date     DATE          NOT NULL,
  revaluation_type     VARCHAR2(20)  NOT NULL,
  old_value            NUMBER(16,4)  NOT NULL,
  new_value            NUMBER(16,4)  NOT NULL,
  coefficient          NUMBER(10,4)  NOT NULL,
  legal_basis          VARCHAR2(255),
  authorizing_body     VARCHAR2(120),
  entry_company_code   VARCHAR2(2),
  entry_no             NUMBER(8),
  notes                VARCHAR2(1000),
  CONSTRAINT pk_imm_revaluation        PRIMARY KEY (revaluation_id),
  CONSTRAINT fk_imm_rev_asset          FOREIGN KEY (asset_id)
    REFERENCES imm_asset(asset_id),
  CONSTRAINT ck_imm_rev_type           CHECK (revaluation_type IN
    ('FREE','LEGAL','INFLATIONARY','INDEX_TRIGGER'))
);

-- ------------------------------------------------------------------
-- Vue pratique
-- ------------------------------------------------------------------
PROMPT
PROMPT [Vue pratique] v_imm_summary
CREATE OR REPLACE VIEW v_imm_summary AS
SELECT a.asset_id, a.asset_code, a.asset_name, a.category,
       a.acquisition_date, a.acquisition_value,
       a.accumulated_dep, a.net_book_value,
       CASE WHEN a.useful_life_months > 0
            THEN ROUND(a.acquisition_value / a.useful_life_months, 4)
            ELSE 0 END AS monthly_depr,
       CASE WHEN a.acquisition_value > 0
            THEN ROUND(100 * a.accumulated_dep / a.acquisition_value, 2)
            ELSE 0 END AS depr_progress_pct,
       a.status
  FROM imm_asset a
 WHERE a.status = 'ACTIVE';

-- ------------------------------------------------------------------
-- Privilèges
-- ------------------------------------------------------------------
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT ON app_gl.imm_asset            TO app_api;
GRANT SELECT ON app_gl.imm_depreciation     TO app_api;
GRANT SELECT ON app_gl.imm_disposal         TO app_api;
GRANT SELECT ON app_gl.imm_revaluation      TO app_api;
GRANT SELECT ON app_gl.imm_method           TO app_api;
GRANT SELECT, INSERT ON app_gl.imm_asset         TO app_audit;
GRANT SELECT, INSERT ON app_gl.imm_depreciation  TO app_audit;

-- ------------------------------------------------------------------
-- Validation
-- ------------------------------------------------------------------
PROMPT
PROMPT ═══ Validation ═══
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('IMM_ASSET','IMM_METHOD','IMM_DEPRECIATION',
                      'IMM_DISPOSAL','IMM_REVALUATION')
 ORDER BY table_name;

SELECT object_name, object_type, status
  FROM user_objects WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ IMMOBILISATIONS OHADA TERMINÉES (5 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;