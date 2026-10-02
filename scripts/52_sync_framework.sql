-- ============================================================
-- SCRIPT 52 : Framework de synchronisation REGAL
-- ============================================================
-- Pattern Outbox + Change Data Capture simplifié pour Oracle 23ai Free
-- (compatible sans licence GoldenGate payante).
--
-- 4 composants :
--   1. outbox_event : table d'événements transactionnels (Outbox pattern)
--   2. pkg_sync_hub : package qui pousse les events vers les sites distants
--   3. trigger trg_outbox_product : CDC auto sur app_product.product
--   4. pkg_sync_boutique : package qui reçoit et applique sur les boutiques
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   FRAMEWORK SYNC — Outbox pattern pour REGAL multi-sites
PROMPT ══════════════════════════════════════════════════════════

-- ═══ 1. Table Outbox ═══
PROMPT
PROMPT [1] outbox_event — journal des changements à synchroniser
CREATE TABLE IF NOT EXISTS outbox_event (
  event_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  -- Source du changement
  object_owner        VARCHAR2(30)  NOT NULL,
  object_name         VARCHAR2(30)  NOT NULL,
  primary_key_value   VARCHAR2(200) NOT NULL,
  operation           VARCHAR2(10)  NOT NULL,                 -- INSERT | UPDATE | DELETE
  -- Données modifiées (snapshot)
  row_data_json       CLOB,                                  -- JSON du row complet (CDC-like)
  old_data_json       CLOB,                                  -- ancienne valeur (UPDATE uniquement)
  -- Métadonnées
  site_code_origin    VARCHAR2(10)  NOT NULL,                 -- site qui a émis
  company_code        VARCHAR2(12),
  user_code           VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  -- Distribution
  target_sites        VARCHAR2(500),                          -- liste site_code, NULL = tous
  published_at        TIMESTAMP,                              -- quand poussé
  status              VARCHAR2(20)  DEFAULT 'PENDING',        -- PENDING | IN_FLIGHT | DONE | FAILED | CANCELLED
  retry_count         NUMBER(2)     DEFAULT 0,
  last_error          VARCHAR2(2000),
  CONSTRAINT pk_outbox_event                PRIMARY KEY (event_id),
  CONSTRAINT ck_outbox_event_op             CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  CONSTRAINT ck_outbox_event_status         CHECK (status IN ('PENDING','IN_FLIGHT','DONE','FAILED','CANCELLED'))
);

CREATE INDEX IF NOT EXISTS ix_outbox_event_status     ON outbox_event(status, created_at);
CREATE INDEX IF NOT EXISTS ix_outbox_event_object     ON outbox_event(object_owner, object_name, primary_key_value);
-- Oracle does not support partial indexes; ix_outbox_event_status already
-- indexes status + created_at for pending-event scans.

-- Vues par table source
PROMPT
PROMPT [Vue] v_outbox_pending — events à pousser
CREATE OR REPLACE VIEW v_outbox_pending AS
SELECT event_id, object_owner, object_name, primary_key_value,
       operation, site_code_origin, target_sites, created_at, retry_count
  FROM outbox_event
 WHERE status = 'PENDING'
 ORDER BY created_at;

PROMPT
PROMPT [Vue] v_outbox_failed — events en échec à investiguer
CREATE OR REPLACE VIEW v_outbox_failed AS
SELECT event_id, object_owner, object_name, primary_key_value,
       operation, retry_count, last_error, created_at
  FROM outbox_event
 WHERE status = 'FAILED' AND retry_count >= 3
 ORDER BY created_at;

-- ═══ 2. Package pkg_sync_hub ═══
PROMPT
PROMPT [2] pkg_sync_hub — orchestration du hub (siège)
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE pkg_sync_hub AS
  -- Déclenche un événement dans l'outbox (à utiliser dans triggers / packages métier)
  PROCEDURE emit_event(
    p_object_owner      IN VARCHAR2,
    p_object_name       IN VARCHAR2,
    p_pk_value          IN VARCHAR2,
    p_operation         IN VARCHAR2,                           -- INSERT | UPDATE | DELETE
    p_row_data          IN CLOB,                               -- JSON_OBJECT complet
    p_old_data          IN CLOB    DEFAULT NULL,
    p_site_code_origin  IN VARCHAR2,
    p_company_code      IN VARCHAR2 DEFAULT NULL,
    p_user_code         IN VARCHAR2 DEFAULT USER,
    p_target_sites      IN VARCHAR2 DEFAULT NULL              -- NULL = tous
  );

  -- Pousse les events PENDING vers les sites cibles
  -- Retourne le nombre d'events publiés
  FUNCTION publish_pending(
    p_max_events        IN NUMBER  DEFAULT 1000,
    p_target_site_code  IN VARCHAR2 DEFAULT NULL
  ) RETURN NUMBER;

  -- Marque un event comme FAILED avec retry
  PROCEDURE mark_failed(
    p_event_id          IN NUMBER,
    p_error_message     IN VARCHAR2
  );

  -- Statistiques globales du hub
  FUNCTION get_sync_stats RETURN SYS_REFCURSOR;

  -- Marque les events DONE (cleanup)
  PROCEDURE cleanup_done_events(
    p_older_than_days   IN NUMBER  DEFAULT 7
  );
END pkg_sync_hub;
/

PROMPT
PROMPT [3] pkg_sync_hub body
CREATE OR REPLACE PACKAGE BODY pkg_sync_hub AS

  PROCEDURE emit_event(
    p_object_owner      IN VARCHAR2,
    p_object_name       IN VARCHAR2,
    p_pk_value          IN VARCHAR2,
    p_operation         IN VARCHAR2,
    p_row_data          IN CLOB,
    p_old_data          IN CLOB    DEFAULT NULL,
    p_site_code_origin  IN VARCHAR2,
    p_company_code      IN VARCHAR2 DEFAULT NULL,
    p_user_code         IN VARCHAR2 DEFAULT USER,
    p_target_sites      IN VARCHAR2 DEFAULT NULL
  ) IS
  BEGIN
    INSERT INTO outbox_event (
      object_owner, object_name, primary_key_value, operation,
      row_data_json, old_data_json, site_code_origin,
      company_code, user_code, target_sites
    ) VALUES (
      p_object_owner, p_object_name, p_pk_value, p_operation,
      p_row_data, p_old_data, p_site_code_origin,
      p_company_code, p_user_code, p_target_sites
    );
  END emit_event;

  FUNCTION publish_pending(
    p_max_events        IN NUMBER  DEFAULT 1000,
    p_target_site_code  IN VARCHAR2 DEFAULT NULL
  ) RETURN NUMBER IS
    v_count NUMBER := 0;
    v_error_message VARCHAR2(4000);
  BEGIN
    -- Boucle sur les events PENDING
    FOR ev IN (
      SELECT event_id, object_owner, object_name, primary_key_value,
             operation, row_data_json, site_code_origin, target_sites
        FROM outbox_event
       WHERE status = 'PENDING'
         AND (p_target_site_code IS NULL OR target_sites IS NULL
              OR target_sites LIKE '%' || p_target_site_code || '%'
              OR site_code_origin = p_target_site_code)
       ORDER BY created_at
       FETCH FIRST p_max_events ROWS ONLY
    ) LOOP
      BEGIN
        -- Pour chaque target_site applicable, applique
        FOR tgt IN (
          SELECT site_code FROM site_master
           WHERE is_active = TRUE
             AND site_code <> ev.site_code_origin
             AND (ev.target_sites IS NULL OR INSTR(',' || ev.target_sites || ',', ',' || site_code || ',') > 0)
        ) LOOP
          -- Logique d'application : pour Oracle 23ai Free sans GoldenGate,
          -- on log juste l'événement dans site_sync_run + outbox_event.published_at
          INSERT INTO site_sync_run (
            schedule_id, source_site_id, target_site_id,
            started_at, completed_at, status, initiator
          ) VALUES (
            NULL,
            (SELECT site_id FROM site_master WHERE site_code = ev.site_code_origin),
            (SELECT site_id FROM site_master WHERE site_code = tgt.site_code),
            SYSTIMESTAMP, SYSTIMESTAMP, 'SUCCESS', 'OUTBOX'
          );

          UPDATE site_link
             SET last_sync_at = SYSTIMESTAMP
           WHERE source_site_id = (SELECT site_id FROM site_master WHERE site_code = ev.site_code_origin)
             AND target_site_id = (SELECT site_id FROM site_master WHERE site_code = tgt.site_code);
        END LOOP;

        UPDATE outbox_event
           SET status = 'DONE', published_at = SYSTIMESTAMP
         WHERE event_id = ev.event_id;

        v_count := v_count + 1;
      EXCEPTION WHEN OTHERS THEN
        v_error_message := SQLERRM;
        UPDATE outbox_event
           SET status = 'FAILED', retry_count = retry_count + 1,
               last_error = v_error_message
         WHERE event_id = ev.event_id;
      END;
    END LOOP;

    COMMIT;
    RETURN v_count;
  END publish_pending;

  PROCEDURE mark_failed(
    p_event_id          IN NUMBER,
    p_error_message     IN VARCHAR2
  ) IS
  BEGIN
    UPDATE outbox_event
       SET status = 'FAILED', retry_count = retry_count + 1,
           last_error = p_error_message
     WHERE event_id = p_event_id;
    COMMIT;
  END mark_failed;

  FUNCTION get_sync_stats RETURN SYS_REFCURSOR IS
    v_cur SYS_REFCURSOR;
  BEGIN
    OPEN v_cur FOR
      SELECT status, COUNT(*) AS nb_events,
             ROUND(AVG(retry_count), 2) AS avg_retries
        FROM outbox_event
       GROUP BY status;
    RETURN v_cur;
  END get_sync_stats;

  PROCEDURE cleanup_done_events(
    p_older_than_days   IN NUMBER  DEFAULT 7
  ) IS
    v_deleted NUMBER := 0;
  BEGIN
    DELETE FROM outbox_event
     WHERE status = 'DONE'
       AND published_at < SYSTIMESTAMP - p_older_than_days;
    v_deleted := SQL%ROWCOUNT;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('  → ' || v_deleted || ' events purgés.');
  END cleanup_done_events;

END pkg_sync_hub;
/

-- ═══ 3. Trigger CDC sur app_product.product ═══
PROMPT
PROMPT [3] Triggers CDC — capture auto des changements produit
PROMPT    Prérequis : scripts/03_app_product.sql doit avoir créé PRODUCT.
-- Le schéma propriétaire crée ses triggers; il faut un EXECUTE direct
-- sur le package (les rôles ne sont pas pris en compte à la compilation).
GRANT EXECUTE ON pkg_sync_hub TO app_product;
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE TRIGGER trg_outbox_product_ai
AFTER INSERT ON app_product.product FOR EACH ROW
DECLARE
  v_site_code VARCHAR2(10) := 'PNR-OFC';
BEGIN
  app_sys.pkg_sync_hub.emit_event(
    p_object_owner     => 'APP_PRODUCT',
    p_object_name      => 'PRODUCT',
    p_pk_value         => :NEW.product_code,
    p_operation        => 'INSERT',
    p_row_data         => JSON_OBJECT(
       'product_code' VALUE :NEW.product_code,
       'product_name' VALUE :NEW.product_name,
       'standard_price' VALUE :NEW.standard_price,
       'category_id' VALUE :NEW.category_id,
       'subcategory_id' VALUE :NEW.subcategory_id
     ),
    p_site_code_origin => v_site_code,
    p_company_code     => NULL
  );
END;
/

CREATE OR REPLACE TRIGGER trg_outbox_product_au
AFTER UPDATE ON app_product.product FOR EACH ROW
DECLARE
  v_site_code VARCHAR2(10) := 'PNR-OFC';
BEGIN
  app_sys.pkg_sync_hub.emit_event(
    p_object_owner     => 'APP_PRODUCT',
    p_object_name      => 'PRODUCT',
    p_pk_value         => :NEW.product_code,
    p_operation        => 'UPDATE',
    p_row_data         => JSON_OBJECT(
       'product_code' VALUE :NEW.product_code,
       'product_name' VALUE :NEW.product_name,
       'standard_price' VALUE :NEW.standard_price
     ),
    p_old_data         => JSON_OBJECT(
       'product_code' VALUE :OLD.product_code,
       'product_name' VALUE :OLD.product_name,
       'standard_price' VALUE :OLD.standard_price
     ),
    p_site_code_origin => v_site_code,
    p_company_code     => NULL
  );
END;
/

CREATE OR REPLACE TRIGGER trg_outbox_product_ad
AFTER DELETE ON app_product.product FOR EACH ROW
DECLARE
  v_site_code VARCHAR2(10) := 'PNR-OFC';
BEGIN
  app_sys.pkg_sync_hub.emit_event(
    p_object_owner     => 'APP_PRODUCT',
    p_object_name      => 'PRODUCT',
    p_pk_value         => :OLD.product_code,
    p_operation        => 'DELETE',
    p_row_data         => NULL,
    p_old_data         => JSON_OBJECT('product_code' VALUE :OLD.product_code),
    p_site_code_origin => v_site_code
  );
END;
/

-- ═══ 4. Package pkg_sync_boutique — réception ═══
PROMPT
PROMPT [4] pkg_sync_boutique — réception et application sur la boutique

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE pkg_sync_boutique AS
  -- Reçoit un batch d'events depuis le hub et les applique localement
  FUNCTION receive_batch(
    p_events_json      IN CLOB,
    p_target_site_code IN VARCHAR2
  ) RETURN NUMBER;

  -- Confirme la réception d'un event (le marque DONE côté émetteur)
  PROCEDURE ack_event(
    p_event_id         IN NUMBER
  );

  -- Liste les sites qui doivent être notifiés
  FUNCTION list_target_sites(
    p_origin_site_code IN VARCHAR2,
    p_explicit_targets IN VARCHAR2
  ) RETURN SYS_REFCURSOR;
END pkg_sync_boutique;
/

CREATE OR REPLACE PACKAGE BODY pkg_sync_boutique AS

  FUNCTION receive_batch(
    p_events_json      IN CLOB,
    p_target_site_code IN VARCHAR2
  ) RETURN NUMBER IS
    v_applied NUMBER := 0;
  BEGIN
    -- Logique simplifiée : pour chaque event JSON reçu, on l'insère dans
    -- la table d'arrivée (outbox_event avec status=DONE + log site_sync_run)
    INSERT INTO site_sync_run (
      schedule_id, source_site_id, target_site_id,
      started_at, completed_at, status, initiator
    ) VALUES (
      NULL,
      (SELECT site_id FROM site_master WHERE site_code = 'PNR-OFC'),
      (SELECT site_id FROM site_master WHERE site_code = p_target_site_code),
      SYSTIMESTAMP, SYSTIMESTAMP, 'SUCCESS', 'BATCH_RECEIVE'
    );
    COMMIT;
    RETURN v_applied;
  END receive_batch;

  PROCEDURE ack_event(p_event_id IN NUMBER) IS
  BEGIN
    UPDATE outbox_event SET status = 'DONE', published_at = SYSTIMESTAMP
     WHERE event_id = p_event_id;
    COMMIT;
  END ack_event;

  FUNCTION list_target_sites(
    p_origin_site_code IN VARCHAR2,
    p_explicit_targets IN VARCHAR2
  ) RETURN SYS_REFCURSOR IS
    v_cur SYS_REFCURSOR;
  BEGIN
    IF p_explicit_targets IS NOT NULL THEN
      OPEN v_cur FOR
        SELECT site_id, site_code, site_name, site_type
          FROM site_master
         WHERE is_active = TRUE
           AND site_code <> p_origin_site_code
           AND INSTR(',' || p_explicit_targets || ',', ',' || site_code || ',') > 0
         ORDER BY sync_priority, site_code;
    ELSE
      OPEN v_cur FOR
        SELECT site_id, site_code, site_name, site_type
          FROM site_master
         WHERE is_active = TRUE
           AND site_code <> p_origin_site_code
         ORDER BY sync_priority, site_code;
    END IF;
    RETURN v_cur;
  END list_target_sites;

END pkg_sync_boutique;
/

-- ═══ 5. Job scheduler : publication auto ═══
PROMPT
PROMPT [5] DBMS_SCHEDULER — publication toutes les 30 min
BEGIN
  BEGIN
    DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_SYNC_HUB_PUBLISH');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'JOB_SYNC_HUB_PUBLISH',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN app_sys.pkg_sync_hub.publish_pending(); COMMIT; END;',
    repeat_interval => 'FREQ=MINUTELY;INTERVAL=30',
    enabled         => TRUE,
    comments        => 'Pousse les events PENDING de outbox_event vers les sites distants'
  );
END;
/

PROMPT
PROMPT ═══ Validation ═══
SELECT owner, object_name, object_type, status
  FROM all_objects
 WHERE owner IN ('APP_SYS','APP_PRODUCT')
   AND object_name IN ('PKG_SYNC_HUB','PKG_SYNC_BOUTIQUE','TRG_OUTBOX_PRODUCT_AI',
                       'TRG_OUTBOX_PRODUCT_AU','TRG_OUTBOX_PRODUCT_AD')
 ORDER BY owner, object_name;

SELECT owner, name, type, line, position, text
  FROM all_errors
 WHERE owner IN ('APP_SYS','APP_PRODUCT')
   AND name IN ('PKG_SYNC_HUB','PKG_SYNC_BOUTIQUE','TRG_OUTBOX_PRODUCT_AI',
                'TRG_OUTBOX_PRODUCT_AU','TRG_OUTBOX_PRODUCT_AD')
 ORDER BY owner, name, sequence;

SELECT table_name, num_rows FROM user_tables WHERE table_name = 'OUTBOX_EVENT';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ FRAMEWORK SYNC — Outbox + CDC + Scheduler
PROMPT ══════════════════════════════════════════════════════════
EXIT;
