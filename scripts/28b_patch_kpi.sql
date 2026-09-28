-- ============================================================
-- 28b : PATCH — Création des tables KPI manquantes
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   PATCH KPI_DEFINITION + KPI_DAILY_SNAPSHOT
PROMPT ══════════════════════════════════════════════════════════

-- Nettoyage idempotent
DECLARE
  PROCEDURE d(p_t VARCHAR2, p_n VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP '||p_t||' '||p_n||' CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('  DROP '||p_t||' '||p_n);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  d('TABLE','kpi_daily_snapshot');
  d('TABLE','kpi_definition');
END;
/

-- [1] KPI_DEFINITION
PROMPT
PROMPT [1/2] kpi_definition
CREATE TABLE kpi_definition (
  kpi_code              VARCHAR2(30)  NOT NULL,
  kpi_name              VARCHAR2(120) NOT NULL,
  kpi_category          VARCHAR2(20)  NOT NULL,   -- SALES | STOCK | CASH | LOYALTY | FINANCIAL
  unit                  VARCHAR2(20),              -- XOF | COUNT | PCT | RATIO
  formula               VARCHAR2(500),
  target_value          NUMBER(16,4),
  warning_threshold     NUMBER(16,4),
  critical_threshold    NUMBER(16,4),
  comparison_op         VARCHAR2(2)   DEFAULT '>', -- '>' : atteindre cible par le haut ; '<' : rester sous
  refresh_frequency     VARCHAR2(20)  DEFAULT 'DAILY', -- REALTIME | HOURLY | DAILY | WEEKLY | MONTHLY
  sql_query             VARCHAR2(4000),
  display_order         NUMBER(4)     DEFAULT 100,
  is_active             BOOLEAN       DEFAULT TRUE,
  description           VARCHAR2(500),
  created_by            VARCHAR2(20),
  created_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at            TIMESTAMP,
  CONSTRAINT pk_kpi_definition       PRIMARY KEY (kpi_code),
  CONSTRAINT ck_kpi_category         CHECK (kpi_category IN
    ('SALES','STOCK','CASH','LOYALTY','FINANCIAL','MIXED')),
  CONSTRAINT ck_kpi_compare          CHECK (comparison_op IN ('>','<','>=','<=','=')),
  CONSTRAINT ck_kpi_frequency        CHECK (refresh_frequency IN
    ('REALTIME','HOURLY','DAILY','WEEKLY','MONTHLY'))
);

CREATE INDEX ix_kpi_def_category  ON kpi_definition(kpi_category);
CREATE INDEX ix_kpi_def_active    ON kpi_definition(is_active);
CREATE INDEX ix_kpi_def_order     ON kpi_definition(display_order);

-- [2] KPI_DAILY_SNAPSHOT
PROMPT
PROMPT [2/2] kpi_daily_snapshot
CREATE TABLE kpi_daily_snapshot (
  snapshot_date         DATE          NOT NULL,
  kpi_code              VARCHAR2(30)  NOT NULL,
  entity_type           VARCHAR2(20)  DEFAULT 'GLOBAL', -- GLOBAL | POS | WAREHOUSE | PRODUCT
  entity_code           VARCHAR2(20)  DEFAULT 'ALL',
  value                 NUMBER(16,4),
  target_value          NUMBER(16,4),
  variance              NUMBER(16,4)  GENERATED ALWAYS AS (value - target_value) VIRTUAL,
  variance_pct          NUMBER(8,2)   GENERATED ALWAYS AS (
                            CASE WHEN target_value IS NOT NULL AND target_value <> 0
                                 THEN ROUND((value - target_value) * 100 / target_value, 2)
                                 ELSE NULL END) VIRTUAL,
  achieved              BOOLEAN       DEFAULT FALSE,
  computed_at           TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_kpi_daily_snapshot    PRIMARY KEY (snapshot_date, kpi_code, entity_type, entity_code),
  CONSTRAINT fk_kpi_daily_def         FOREIGN KEY (kpi_code)
    REFERENCES kpi_definition(kpi_code) ON DELETE CASCADE,
  CONSTRAINT ck_kpi_daily_entity      CHECK (entity_type IN
    ('GLOBAL','POS','WAREHOUSE','PRODUCT','PARTY'))
);

CREATE INDEX ix_kpi_daily_code       ON kpi_daily_snapshot(kpi_code, snapshot_date);
CREATE INDEX ix_kpi_daily_date       ON kpi_daily_snapshot(snapshot_date);
CREATE INDEX ix_kpi_daily_entity     ON kpi_daily_snapshot(entity_type, entity_code);

PROMPT
PROMPT ═══ Validation ═══
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('KPI_DEFINITION','KPI_DAILY_SNAPSHOT')
 ORDER BY table_name;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ PATCH KPI TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;