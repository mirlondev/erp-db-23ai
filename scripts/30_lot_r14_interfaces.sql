-- ============================================================
-- SCRIPT 30 : LOT R14 — Interfaces & Intégrations
-- Migration Oracle 11g (interfaces legacy, batch imports manuels)
--                  → Oracle 23ai/26ai (app_sys)
-- ============================================================
-- 5 nouvelles tables dans app_sys :
--   interface_endpoint, interface_log, sync_queue,
--   import_batch, export_config
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * BOOLEAN pour is_active (legacy Y/N)
--  * VARCHAR2(20) user_code (vs 5 legacy)
--  * JSON pour payloads (Oracle 23ai natif)
--  * schedule_cron pour cron standard (6 expressions)
--  * Retries intelligents avec backoff exponentiel (next_attempt)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R14 : INTERFACES & INTÉGRATIONS (5 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/5] interface_endpoint  — endpoints API externes (REST/webhooks)
CREATE TABLE interface_endpoint (
  endpoint_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  endpoint_code      VARCHAR2(40)  NOT NULL,
  endpoint_name      VARCHAR2(120) NOT NULL,
  url                VARCHAR2(500) NOT NULL,
  http_method        VARCHAR2(10)  DEFAULT 'POST',        -- GET | POST | PUT | PATCH | DELETE
  auth_type          VARCHAR2(20),                         -- NONE | API_KEY | OAUTH2 | BASIC | BEARER | CERT
  auth_config        JSON,                                  -- config auth (token URL, client_id, scope...)
  timeout_seconds    NUMBER(4)     DEFAULT 30,
  retry_count        NUMBER(2)     DEFAULT 3,
  retry_delay_sec    NUMBER(4)     DEFAULT 60,            -- backoff exponentiel : delay = retry_delay_sec * attempts
  headers_json       JSON,                                  -- headers HTTP additionnels
  payload_template   CLOB,                                  -- template JSON pour POST
  rate_limit_per_min NUMBER(6),                            -- limite d'appels par minute
  description        VARCHAR2(500),
  is_active          BOOLEAN       DEFAULT TRUE,
  created_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at         TIMESTAMP,
  CONSTRAINT pk_interface_endpoint          PRIMARY KEY (endpoint_id),
  CONSTRAINT uk_interface_endpoint_code     UNIQUE (endpoint_code),
  CONSTRAINT ck_interface_http_method        CHECK (http_method IN ('GET','POST','PUT','PATCH','DELETE')),
  CONSTRAINT ck_interface_auth_type          CHECK (auth_type IS NULL OR auth_type IN ('NONE','API_KEY','OAUTH2','BASIC','BEARER','CERT','HMAC'))
);

PROMPT
PROMPT [2/5] interface_log  — log des appels inter-systèmes
CREATE TABLE interface_log (
  log_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  endpoint_code      VARCHAR2(40)  NOT NULL,
  direction          VARCHAR2(10)  NOT NULL,                -- OUT (envoi) | IN (réception)
  request_payload    JSON,                                  -- corps envoyé (Oracle 23ai JSON natif)
  response_payload   JSON,                                  -- corps reçu
  http_status        NUMBER(4),                             -- 200, 201, 400, 401, 500, ...
  duration_ms        NUMBER(8),
  status             VARCHAR2(20)  DEFAULT 'SUCCESS',        -- SUCCESS | ERROR | TIMEOUT
  error_message      VARCHAR2(2000),
  error_code         VARCHAR2(40),
  retry_attempt      NUMBER(2)     DEFAULT 1,
  entity_type        VARCHAR2(30),                          -- business entity liée
  entity_id          VARCHAR2(100),
  correlation_id     VARCHAR2(64),                          -- ID de corrélation (X-Request-ID)
  ip_address         VARCHAR2(45),
  created_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_interface_log           PRIMARY KEY (log_id),
  CONSTRAINT ck_interface_direction     CHECK (direction IN ('IN','OUT','BOTH')),
  CONSTRAINT ck_interface_log_status    CHECK (status IN ('SUCCESS','ERROR','TIMEOUT','CLIENT_ERROR','SERVER_ERROR'))
);

CREATE INDEX ix_interface_log_endpoint   ON interface_log(endpoint_code, created_at DESC);
CREATE INDEX ix_interface_log_status     ON interface_log(status, created_at DESC);
CREATE INDEX ix_interface_log_entity     ON interface_log(entity_type, entity_id);
CREATE INDEX ix_interface_log_corr       ON interface_log(correlation_id);
-- ⚠️ CORRECTION ORA-02158 : index fonctionnel (DESC déplacé sur l'expression)
CREATE INDEX ix_interface_log_errors ON interface_log(
  CASE WHEN status IN ('ERROR','TIMEOUT','SERVER_ERROR') THEN endpoint_code END,
  CASE WHEN status IN ('ERROR','TIMEOUT','SERVER_ERROR') THEN created_at END
);
PROMPT
PROMPT [3/5] sync_queue  — file d'attente pour synchronisations cross-systèmes
CREATE TABLE sync_queue (
  queue_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  entity_type        VARCHAR2(30)  NOT NULL,                -- PRODUCT | TICKET | INVOICE | ...
  entity_id          VARCHAR2(100) NOT NULL,
  operation          VARCHAR2(10)  NOT NULL,                -- INSERT | UPDATE | DELETE
  payload            JSON,
  target_system      VARCHAR2(30)  NOT NULL,                -- ERP | ECOMMERCE | CRM | BI | MOBILE
  priority           NUMBER(2)     DEFAULT 5,               -- 1=highest, 10=lowest
  status             VARCHAR2(20)  DEFAULT 'PENDING',       -- PENDING | PROCESSING | SUCCESS | FAILED | CANCELLED
  attempts           NUMBER(3)     DEFAULT 0,
  max_attempts       NUMBER(3)     DEFAULT 5,
  next_attempt_at    TIMESTAMP     DEFAULT SYSTIMESTAMP,
  last_attempt_at    TIMESTAMP,
  processed_at       TIMESTAMP,
  error_message      VARCHAR2(2000),
  locked_by          VARCHAR2(30),                          -- worker qui traite
  locked_at          TIMESTAMP,
  correlation_id     VARCHAR2(64),
  created_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_sync_queue              PRIMARY KEY (queue_id),
  CONSTRAINT ck_sync_operation          CHECK (operation IN ('INSERT','UPDATE','DELETE','UPSERT')),
  CONSTRAINT ck_sync_status             CHECK (status IN ('PENDING','PROCESSING','SUCCESS','FAILED','CANCELLED')),
  CONSTRAINT ck_sync_priority           CHECK (priority BETWEEN 1 AND 10),
  CONSTRAINT ck_sync_attempts           CHECK (attempts >= 0 AND attempts <= max_attempts),
  CONSTRAINT ck_sync_locked             CHECK ((locked_by IS NULL) = (locked_at IS NULL))
);

-- ⚠️ CORRECTION ORA-02158 : index fonctionnel
CREATE INDEX ix_sync_queue_pending ON sync_queue(
  CASE WHEN status = 'PENDING' THEN priority END,
  CASE WHEN status = 'PENDING' THEN next_attempt_at END,
  CASE WHEN status = 'PENDING' THEN status END
);
CREATE INDEX ix_sync_queue_entity       ON sync_queue(entity_type, entity_id);
CREATE INDEX ix_sync_queue_target       ON sync_queue(target_system, status);
CREATE INDEX ix_sync_queue_corr         ON sync_queue(correlation_id);

PROMPT
PROMPT [4/5] import_batch  — import par lot (CSV/Excel/JSON)
CREATE TABLE import_batch (
  batch_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  batch_code         VARCHAR2(40)  NOT NULL,
  import_type        VARCHAR2(30)  NOT NULL,                -- PRODUCTS | CUSTOMERS | INVOICES | STOCK | PRICES
  source_file        VARCHAR2(500),                        -- chemin du fichier source
  source_format      VARCHAR2(10)  DEFAULT 'CSV',           -- CSV | XLSX | JSON | XML
  source_system      VARCHAR2(30),                         -- d'où viennent les données
  total_rows         NUMBER(8),                            -- total lignes à traiter
  success_rows       NUMBER(8)     DEFAULT 0,
  error_rows         NUMBER(8)     DEFAULT 0,
  skipped_rows       NUMBER(8)     DEFAULT 0,
  validation_errors  CLOB,                                 -- JSON array des erreurs par ligne
  status             VARCHAR2(20)  DEFAULT 'PENDING',       -- PENDING | RUNNING | SUCCESS | PARTIAL | FAILED
  started_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  completed_at       TIMESTAMP,
  duration_ms        NUMBER(10),
  started_by         VARCHAR2(20),
  parameters_json    JSON,                                 -- mapping config / filtres
  CONSTRAINT pk_import_batch             PRIMARY KEY (batch_id),
  CONSTRAINT uk_import_batch_code        UNIQUE (batch_code),
  CONSTRAINT ck_import_status            CHECK (status IN ('PENDING','RUNNING','SUCCESS','PARTIAL','FAILED','CANCELLED')),
  CONSTRAINT ck_import_format            CHECK (source_format IN ('CSV','XLSX','JSON','XML','PARQUET','AVRO')),
  CONSTRAINT ck_import_rows              CHECK (NVL(success_rows,0) >= 0 AND NVL(error_rows,0) >= 0
                                              AND (total_rows IS NULL OR total_rows >= 0)
                                              AND (NVL(success_rows,0) + NVL(error_rows,0)) <= NVL(total_rows, 999999999))
);

CREATE INDEX ix_import_batch_status      ON import_batch(status, started_at DESC);
CREATE INDEX ix_import_batch_type        ON import_batch(import_type, started_at DESC);

PROMPT
PROMPT [5/5] export_config  — config d'exports récurrents (vers BI/CRM/etc.)
CREATE TABLE export_config (
  export_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  export_code        VARCHAR2(40)  NOT NULL,
  export_name        VARCHAR2(120) NOT NULL,
  target_system      VARCHAR2(30)  NOT NULL,                -- BI | DATA_LAKE | PARTNER | MOBILE | ECOMMERCE
  format             VARCHAR2(10)  DEFAULT 'CSV',           -- CSV | XLSX | JSON | PARQUET | XML
  query_sql          CLOB,                                 -- requête SQL d'extraction
  file_pattern       VARCHAR2(200),                        -- ex. 'sales_%YYYY%MM%DD.csv'
  output_path        VARCHAR2(500),                        -- répertoire destination
  schedule_cron      VARCHAR2(100),                        -- cron expression (5 fields std)
  compression_type   VARCHAR2(10),                         -- GZIP | ZIP | BZ2 | NONE
  include_header     BOOLEAN       DEFAULT TRUE,
  delimiter_char     VARCHAR2(1)   DEFAULT ',',
  encoding           VARCHAR2(20)  DEFAULT 'UTF-8',
  is_active          BOOLEAN       DEFAULT TRUE,
  last_run_at        TIMESTAMP,
  last_run_status    VARCHAR2(20),
  last_run_row_count NUMBER(10),
  last_run_file_path VARCHAR2(500),
  last_run_duration_ms NUMBER(10),
  created_by         VARCHAR2(20),
  created_at         TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by         VARCHAR2(20),
  updated_at         TIMESTAMP,
  CONSTRAINT pk_export_config            PRIMARY KEY (export_id),
  CONSTRAINT uk_export_config_code       UNIQUE (export_code),
  CONSTRAINT ck_export_format            CHECK (format IN ('CSV','XLSX','JSON','PARQUET','XML','AVRO','NDJSON')),
  CONSTRAINT ck_export_last_status       CHECK (last_run_status IS NULL OR last_run_status IN ('SUCCESS','FAILED','PARTIAL','TIMEOUT'))
);

CREATE INDEX ix_export_config_active    ON export_config(is_active, target_system);

PROMPT
PROMPT ═══ Privilèges ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

-- app_api gère les interfaces (lecture/écriture complète)
GRANT SELECT, INSERT, UPDATE ON app_sys.interface_endpoint  TO app_api;
GRANT SELECT, INSERT         ON app_sys.interface_log      TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_sys.sync_queue          TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_sys.import_batch       TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_sys.export_config      TO app_api;

-- Job DBMS_SCHEDULER pour traiter sync_queue
GRANT CREATE JOB TO app_api;


PROMPT
PROMPT ═══ Validation — Tables ═══
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('INTERFACE_ENDPOINT','INTERFACE_LOG','SYNC_QUEUE',
                      'IMPORT_BATCH','EXPORT_CONFIG')
 ORDER BY table_name;

PROMPT
PROMPT ═══ Validation — Contraintes ═══
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('INTERFACE_ENDPOINT','INTERFACE_LOG','SYNC_QUEUE',
                      'IMPORT_BATCH','EXPORT_CONFIG')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT ═══ Validation — Objets invalides ═══
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R14 TERMINÉ (5 tables) — FIN DU PLAN RETAIL
PROMPT ══════════════════════════════════════════════════════════
EXIT;
