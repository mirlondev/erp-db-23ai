-- ============================================================
-- SCRIPT 51 : Topologie Hub-and-Spoke pour REGAL
-- ============================================================
-- Le système REGAL legacy est multi-sites distribué :
--   - Siège (office/master) à Pointe-Noire
--   - Boutiques à Brazzaville, Dolisie, etc.
--   - Dépôts (entrepôts) à chaque site
--   - Sync manuelle via dumps quotidiens (réseau Congo instable)
--
-- Tables créées (6) :
--   site_master           : registre des sites (siège + boutiques + dépots)
--   site_link             : topologie réseau (liens entre sites + latence)
--   site_database         : métadonnées des bases de données par site
--   site_sync_schedule    : planification des syncs (cron quotidien)
--   site_sync_run         : exécution d'une sync (log + durée)
--   site_sync_conflict    : conflits détectés lors de la sync (à résoudre)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   TOPOLOGIE HUB-AND-SPOKE REGAL (6 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/6] site_master  — Référentiel des sites
CREATE TABLE site_master (
  site_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  site_code           VARCHAR2(10)  NOT NULL,                  -- PNR-OFC, BZV-B01, DLS-D01
  site_name           VARCHAR2(120) NOT NULL,
  site_type           VARCHAR2(20)  NOT NULL,                  -- OFFICE | DEPOT | BOUTIQUE | MIXED
  parent_site_id      NUMBER,                                  -- hiérarchie (BZV-B01 → BZV-OFC → PNR-OFC)
  company_code        VARCHAR2(12)  NOT NULL,
  country_code        VARCHAR2(2)   NOT NULL,
  city                VARCHAR2(80),
  department          VARCHAR2(80),
  address             VARCHAR2(200),
  phone               VARCHAR2(30),
  email               VARCHAR2(120),
  -- Sync metadata
  is_master           BOOLEAN       DEFAULT FALSE,
  sync_priority       NUMBER(1)     DEFAULT 5,                 -- 1 = haute, 9 = basse
  is_active           BOOLEAN       DEFAULT TRUE,
  opened_at           TIMESTAMP,
  closed_at           TIMESTAMP,
  notes               VARCHAR2(1000),
  CONSTRAINT pk_site_master                  PRIMARY KEY (site_id),
  CONSTRAINT uk_site_master_code             UNIQUE (site_code),
  CONSTRAINT ck_site_master_type             CHECK (site_type IN ('OFFICE','DEPOT','BOUTIQUE','MIXED','KIOSK')),
  CONSTRAINT fk_site_master_parent           FOREIGN KEY (parent_site_id)
    REFERENCES site_master(site_id),
  CONSTRAINT ck_site_master_country          CHECK (country_code = 'CG')
);

CREATE INDEX ix_site_master_company       ON site_master(company_code);
CREATE INDEX ix_site_master_type          ON site_master(site_type);
CREATE INDEX ix_site_master_parent        ON site_master(parent_site_id);

PROMPT
PROMPT [2/6] site_link  — Topologie réseau entre sites
CREATE TABLE site_link (
  link_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  source_site_id      NUMBER        NOT NULL,
  target_site_id      NUMBER        NOT NULL,
  link_type           VARCHAR2(20)  DEFAULT 'WEEKLY_DUMP',     -- REALTIME | DAILY_DUMP | WEEKLY_DUMP | MANUAL
  bandwidth_kbps      NUMBER(8),                               -- bande passante mesurée
  avg_latency_ms      NUMBER(6),                               -- latence ping moyenne
  reliability_pct     NUMBER(5,2)  DEFAULT 95.00,              -- % disponibilité
  is_active           BOOLEAN      DEFAULT TRUE,
  last_sync_at        TIMESTAMP,
  next_sync_at        TIMESTAMP,
  CONSTRAINT pk_site_link                    PRIMARY KEY (link_id),
  CONSTRAINT uk_site_link_pair               UNIQUE (source_site_id, target_site_id),
  CONSTRAINT fk_site_link_src                FOREIGN KEY (source_site_id)
    REFERENCES site_master(site_id),
  CONSTRAINT fk_site_link_tgt                FOREIGN KEY (target_site_id)
    REFERENCES site_master(site_id),
  CONSTRAINT ck_site_link_type               CHECK (link_type IN ('REALTIME','DAILY_DUMP','WEEKLY_DUMP','MANUAL','BATCH_NIGHTLY'))
);

PROMPT
PROMPT [3/6] site_database  — Métadonnées des BDs de chaque site
CREATE TABLE site_database (
  db_id               NUMBER GENERATED ALWAYS AS IDENTITY,
  site_id             NUMBER        NOT NULL,
  db_name             VARCHAR2(30)  NOT NULL,                  -- PNR_OFFICE, BZV_BOUT01, DLS_BOUT01
  db_version          VARCHAR2(40),                            -- Oracle 23ai Free | 21c XE | 11g legacy
  dblink_name         VARCHAR2(40),                            -- nom DBLink Oracle
  dblink_host         VARCHAR2(120),
  dblink_port         NUMBER(5),
  dblink_service      VARCHAR2(60),
  db_role             VARCHAR2(20)  DEFAULT 'SPEAKER',         -- MASTER | SPEAKER | LEGACY | STAGING
  schema_set          VARCHAR2(200),                           -- liste schémas (CAISSE,CASH,XCPTA,...)
  is_active           BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_site_database                PRIMARY KEY (db_id),
  CONSTRAINT uk_site_database_name           UNIQUE (db_name),
  CONSTRAINT fk_site_database_site           FOREIGN KEY (site_id)
    REFERENCES site_master(site_id),
  CONSTRAINT ck_site_database_role           CHECK (db_role IN ('MASTER','SPEAKER','LEGACY','STAGING','BACKUP'))
);

PROMPT
PROMPT [4/6] site_sync_schedule  — Planification cron
CREATE TABLE site_sync_schedule (
  schedule_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  schedule_name       VARCHAR2(120) NOT NULL,
  source_site_id      NUMBER        NOT NULL,
  target_site_id      NUMBER        NOT NULL,
  -- Table ou groupe de tables à synchroniser
  object_owner        VARCHAR2(30),                            -- 'APP_PRODUCT', 'TRANSFERT'
  object_name         VARCHAR2(30),                            -- 'PRODUCT', 'TR_GCBRDE'
  sync_direction      VARCHAR2(20)  DEFAULT 'PUSH',            -- PUSH | PULL | BIDIRECTIONAL
  sync_method         VARCHAR2(20)  DEFAULT 'DBLINK',          -- DBLINK | GOLDENGATE | EXPORT_IMPORT | MATERIALIZED_VIEW
  -- Timing cron-like (legacy dumps : nightly)
  schedule_type       VARCHAR2(20)  DEFAULT 'NIGHTLY',         -- HOURLY | NIGHTLY | WEEKLY | MANUAL
  schedule_hour       NUMBER(2),                               -- heure du cron (0-23)
  schedule_minute     NUMBER(2)     DEFAULT 0,
  -- Volume max pour ne pas saturer le lien
  max_rows_per_sync   NUMBER(10),
  -- Conflits
  conflict_strategy   VARCHAR2(20)  DEFAULT 'MASTER_WINS',     -- MASTER_WINS | LAST_WRITE_WINS | MANUAL_REVIEW
  is_active           BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_site_sync_schedule           PRIMARY KEY (schedule_id),
  CONSTRAINT uk_site_sync_schedule_pair      UNIQUE (source_site_id, target_site_id, object_owner, object_name),
  CONSTRAINT fk_site_sync_schedule_src       FOREIGN KEY (source_site_id)
    REFERENCES site_master(site_id),
  CONSTRAINT fk_site_sync_schedule_tgt       FOREIGN KEY (target_site_id)
    REFERENCES site_master(site_id),
  CONSTRAINT ck_site_sync_schedule_dir       CHECK (sync_direction IN ('PUSH','PULL','BIDIRECTIONAL')),
  CONSTRAINT ck_site_sync_schedule_method    CHECK (sync_method IN ('DBLINK','GOLDENGATE','EXPORT_IMPORT','MATERIALIZED_VIEW','CSV_FILE','JSON_API')),
  CONSTRAINT ck_site_sync_schedule_strategy  CHECK (conflict_strategy IN ('MASTER_WINS','LAST_WRITE_WINS','MANUAL_REVIEW','SPEAKER_WINS','SOURCE_PRIORITY'))
);

PROMPT
PROMPT [5/6] site_sync_run  — Journal d'exécution des syncs
CREATE TABLE site_sync_run (
  run_id              NUMBER GENERATED ALWAYS AS IDENTITY,
  schedule_id         NUMBER,                                  -- NULL = ad-hoc run
  source_site_id      NUMBER        NOT NULL,
  target_site_id      NUMBER        NOT NULL,
  started_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  completed_at        TIMESTAMP,
  duration_sec        NUMBER(10)   GENERATED ALWAYS AS
    (CASE WHEN completed_at IS NULL THEN NULL
          ELSE EXTRACT(SECOND FROM (completed_at - started_at))
             + EXTRACT(MINUTE FROM (completed_at - started_at)) * 60
             + EXTRACT(HOUR FROM (completed_at - started_at)) * 3600 END),
  rows_extracted      NUMBER(12),
  rows_inserted       NUMBER(12),
  rows_updated        NUMBER(12),
  rows_skipped        NUMBER(12),
  rows_in_conflict    NUMBER(12),
  status              VARCHAR2(20)  DEFAULT 'RUNNING',         -- RUNNING | SUCCESS | PARTIAL | FAILED | CANCELLED
  error_message       VARCHAR2(4000),
  initiator           VARCHAR2(50),                            -- SCHEDULER | MANUAL | TRIGGER
  CONSTRAINT pk_site_sync_run                PRIMARY KEY (run_id),
  CONSTRAINT fk_site_sync_run_schedule       FOREIGN KEY (schedule_id)
    REFERENCES site_sync_schedule(schedule_id),
  CONSTRAINT fk_site_sync_run_src            FOREIGN KEY (source_site_id)
    REFERENCES site_master(site_id),
  CONSTRAINT fk_site_sync_run_tgt            FOREIGN KEY (target_site_id)
    REFERENCES site_master(site_id),
  CONSTRAINT ck_site_sync_run_status         CHECK (status IN ('RUNNING','SUCCESS','PARTIAL','FAILED','CANCELLED'))
);

CREATE INDEX ix_site_sync_run_started     ON site_sync_run(started_at DESC);
CREATE INDEX ix_site_sync_run_status      ON site_sync_run(status);
CREATE INDEX ix_site_sync_run_source      ON site_sync_run(source_site_id);

PROMPT
PROMPT [6/6] site_sync_conflict  — Conflits détectés
CREATE TABLE site_sync_conflict (
  conflict_id         NUMBER GENERATED ALWAYS AS IDENTITY,
  run_id              NUMBER        NOT NULL,
  -- Quelle ligne est en conflit
  object_owner        VARCHAR2(30)  NOT NULL,
  object_name         VARCHAR2(30)  NOT NULL,
  primary_key_value   VARCHAR2(200) NOT NULL,
  -- Détail du conflit
  source_value        CLOB,
  target_value        CLOB,
  detection_at        TIMESTAMP     DEFAULT SYSTIMESTAMP,
  resolution          VARCHAR2(20)  DEFAULT 'PENDING',         -- PENDING | RESOLVED | IGNORED
  resolution_strategy VARCHAR2(30),                            -- MASTER_WINS | LAST_WRITE_WINS | MANUAL
  resolved_at         TIMESTAMP,
  resolved_by         VARCHAR2(20),
  notes               VARCHAR2(2000),
  CONSTRAINT pk_site_sync_conflict          PRIMARY KEY (conflict_id),
  CONSTRAINT fk_site_sync_conflict_run      FOREIGN KEY (run_id)
    REFERENCES site_sync_run(run_id) ON DELETE CASCADE,
  CONSTRAINT ck_site_sync_conflict_res      CHECK (resolution IN ('PENDING','RESOLVED','IGNORED','AUTO_MERGED'))
);

CREATE INDEX ix_site_sync_conflict_pending  ON site_sync_conflict(resolution) WHERE resolution = 'PENDING';

-- Vue récapitulative : dernière sync par site
PROMPT
PROMPT [Vue pratique] v_site_sync_status
CREATE OR REPLACE VIEW v_site_sync_status AS
SELECT sm.site_code, sm.site_name, sm.site_type, sm.city,
       COUNT(sr.run_id)                                                    AS total_runs,
       SUM(CASE WHEN sr.status = 'SUCCESS'  THEN 1 ELSE 0 END)             AS successful,
       SUM(CASE WHEN sr.status = 'FAILED'   THEN 1 ELSE 0 END)             AS failed,
       SUM(CASE WHEN sr.status = 'PARTIAL'  THEN 1 ELSE 0 END)             AS partial,
       MAX(sr.started_at)                                                   AS last_run_at,
       ROUND(AVG(sr.duration_sec), 0)                                       AS avg_duration_sec,
       SUM(NVL(sr.rows_inserted, 0))                                        AS total_rows_inserted,
       SUM(NVL(sr.rows_in_conflict, 0))                                     AS total_conflicts
  FROM site_master sm
  LEFT JOIN site_sync_run sr
    ON (sr.source_site_id = sm.site_id OR sr.target_site_id = sm.site_id)
 GROUP BY sm.site_code, sm.site_name, sm.site_type, sm.city
 ORDER BY sm.site_type, sm.site_code;

-- Privilèges
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT, INSERT, UPDATE ON app_sys.site_master         TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_sys.site_link           TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_sys.site_database       TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_sys.site_sync_schedule  TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_sys.site_sync_run       TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_sys.site_sync_conflict  TO app_api;

PROMPT
PROMPT ═══ Validation ═══
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name LIKE 'SITE\_%' ESCAPE '\'
 ORDER BY table_name;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ TOPOLOGIE HUB-AND-SPOKE INSTALLÉE (6 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
