-- ============================================================
-- S30 : Seed topologie REGAL Hub-and-Spoke multi-sites
-- ============================================================
-- Implémente la topologie réelle REGAL :
--   Siège PNR-OFC (Pointe-Noire, MASTER)
--   ├── Boutique PNR-B01 (Pointe-Noire Centre)
--   ├── Boutique BZV-B01 (Brazzaville)
--   ├── Boutique BZV-B02 (Brazzaville Poto-Poto)
--   ├── Boutique DLS-B01 (Dolisie)
--   └── Dépôt DEP-PNR (Pointe-Noire, zone ind.)
--       └── Dépôt DEP-BZV (Brazzaville, port)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   TOPOLOGIE REGAL HUB-AND-SPOKE — Pointe-Noire / Brazzaville / Dolisie
PROMPT ══════════════════════════════════════════════════════════

BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM site_sync_conflict';
  EXECUTE IMMEDIATE 'DELETE FROM site_sync_run';
  EXECUTE IMMEDIATE 'DELETE FROM site_sync_schedule';
  EXECUTE IMMEDIATE 'DELETE FROM site_database';
  EXECUTE IMMEDIATE 'DELETE FROM site_link';
  EXECUTE IMMEDIATE 'DELETE FROM site_master';
  COMMIT;
END;
/

-- ═══ 1. Inscription des 7 sites REGAL ═══
PROMPT
PROMPT ▸ 7 sites REGAL Congo Brazzaville

INSERT INTO site_master (site_code, site_name, site_type, parent_site_id, company_code,
                         country_code, city, department, address, is_master, sync_priority)
VALUES ('PNR-OFC', 'Siège REGAL Pointe-Noire', 'OFFICE', NULL, 'REGAL', 'CG',
        'Pointe-Noire', 'Pointe-Noire', 'Avenue Charles de Gaulle, Centre-ville',
  TRUE, 1);

INSERT INTO site_master (site_code, site_name, site_type, parent_site_id, company_code,
                         country_code, city, department, address, sync_priority)
VALUES ('PNR-B01', 'Boutique Pointe-Noire Centre', 'BOUTIQUE',
        (SELECT site_id FROM site_master WHERE site_code = 'PNR-OFC'),
        'REGAL', 'CG', 'Pointe-Noire', 'Pointe-Noire',
        'Marché Central, Av. de la République', 2);

INSERT INTO site_master (site_code, site_name, site_type, parent_site_id, company_code,
                         country_code, city, department, address, sync_priority)
VALUES ('BZV-B01', 'Boutique Brazzaville Centre', 'BOUTIQUE',
        (SELECT site_id FROM site_master WHERE site_code = 'PNR-OFC'),
        'REGAL', 'CG', 'Brazzaville', 'Pool',
        'Avenue de l''Indépendance, Centre', 3);

INSERT INTO site_master (site_code, site_name, site_type, parent_site_id, company_code,
                         country_code, city, department, address, sync_priority)
VALUES ('BZV-B02', 'Boutique Brazzaville Poto-Poto', 'BOUTIQUE',
        (SELECT site_id FROM site_master WHERE site_code = 'PNR-OFC'),
        'REGAL', 'CG', 'Brazzaville', 'Pool',
        'Marché Poto-Poto', 4);

INSERT INTO site_master (site_code, site_name, site_type, parent_site_id, company_code,
                         country_code, city, department, address, sync_priority)
VALUES ('DLS-B01', 'Boutique Dolisie', 'BOUTIQUE',
        (SELECT site_id FROM site_master WHERE site_code = 'PNR-OFC'),
        'REGAL', 'CG', 'Dolisie', 'Niari',
        'Avenue de la Gare, Marché central', 5);

INSERT INTO site_master (site_code, site_name, site_type, parent_site_id, company_code,
                         country_code, city, department, address, sync_priority)
VALUES ('DEP-PNR', 'Dépôt central Pointe-Noire', 'DEPOT',
        (SELECT site_id FROM site_master WHERE site_code = 'PNR-OFC'),
        'REGAL', 'CG', 'Pointe-Noire', 'Pointe-Noire',
        'Zone Industrielle, Route de l''Aéroport', 2);

INSERT INTO site_master (site_code, site_name, site_type, parent_site_id, company_code,
                         country_code, city, department, address, sync_priority)
VALUES ('DEP-BZV', 'Dépôt Brazzaville Port', 'DEPOT',
        (SELECT site_id FROM site_master WHERE site_code = 'PNR-OFC'),
        'REGAL', 'CG', 'Brazzaville', 'Pool',
        'Zone portuaire, Avenue de la Liberation', 3);

COMMIT;
PROMPT 7 sites REGAL enregistrés.

-- ═══ 2. Liens réseau entre sites (latences réalistes Congo) ═══
PROMPT
PROMPT ▸ Liens réseau (latences typiques Congo)

INSERT INTO site_link (source_site_id, target_site_id, link_type,
                       bandwidth_kbps, avg_latency_ms, reliability_pct, last_sync_at)
SELECT src.site_id, tgt.site_id,
       CASE
         WHEN tgt.site_code = 'PNR-OFC' THEN 'DAILY_DUMP'
         ELSE 'DAILY_DUMP'
       END,
       CASE
         WHEN tgt.city = 'Pointe-Noire' THEN 10240          -- 10 Mbps (LAN/siège)
         WHEN tgt.city = 'Brazzaville'  THEN 2048           -- 2 Mbps (fibre RoC)
         WHEN tgt.city = 'Dolisie'      THEN 1024           -- 1 Mbps (satellite)
       END,
       CASE
         WHEN tgt.city = 'Pointe-Noire' THEN 5              -- 5 ms LAN
         WHEN tgt.city = 'Brazzaville'  THEN 45             -- 45 ms fibre
         WHEN tgt.city = 'Dolisie'      THEN 120            -- 120 ms satellite
       END,
       95.0,
       SYSTIMESTAMP - 1   -- sync hier
  FROM site_master src, site_master tgt
 WHERE src.site_code = 'PNR-OFC'
   AND tgt.site_code <> 'PNR-OFC';

COMMIT;

-- Liens boutique ↔ dépôt local
INSERT INTO site_link (source_site_id, target_site_id, link_type, bandwidth_kbps, avg_latency_ms)
SELECT b.site_id, d.site_id, 'MANUAL', 100000, 2
  FROM site_master b, site_master d
 WHERE b.site_type = 'BOUTIQUE'
   AND d.site_type = 'DEPOT'
   AND b.city = d.city;

COMMIT;

-- ═══ 3. Métadonnées BDs par site ═══
PROMPT
PROMPT ▸ Bases de données par site

INSERT INTO site_database (site_id, db_name, db_version, dblink_name,
                            dblink_host, dblink_port, dblink_service, db_role, schema_set)
SELECT site_id, 'PNR_OFFICE_23AI', 'Oracle 23ai Free', 'DBL_PNR_OFC',
       'regal-pnr-ofc', 1521, 'FREEPDB1', 'MASTER',
       'APP_SYS,APP_ORG,APP_PRODUCT,APP_PARTY,APP_INV,APP_DOC,APP_POS,APP_SALES,APP_GL,APP_AR,APP_HR,APP_CASH,APP_API'
  FROM site_master WHERE site_code = 'PNR-OFC';

INSERT INTO site_database (site_id, db_name, db_version, dblink_name,
                            dblink_host, dblink_port, dblink_service, db_role, schema_set)
SELECT site_id, 'BZV_BOUT01_21C', 'Oracle 21c XE', 'DBL_BZV_B01',
       'regal-bzv-b01', 1521, 'XEPDB1', 'SPEAKER',
       'CAISSE,CASH,TRANSFERT_LOCAL'
  FROM site_master WHERE site_code = 'BZV-B01';

INSERT INTO site_database (site_id, db_name, db_version, dblink_name,
                            dblink_host, dblink_port, dblink_service, db_role, schema_set)
SELECT site_id, 'DLS_BOUT01_21C', 'Oracle 21c XE', 'DBL_DLS_B01',
       'regal-dls-b01', 1521, 'XEPDB1', 'SPEAKER',
       'CAISSE,CASH,TRANSFERT_LOCAL'
  FROM site_master WHERE site_code = 'DLS-B01';

COMMIT;

-- ═══ 4. Planification des syncs ═══
PROMPT
PROMPT ▸ Planification sync quotidienne

INSERT INTO site_sync_schedule (schedule_name, source_site_id, target_site_id,
                                  object_owner, object_name, sync_direction, sync_method,
                                  schedule_type, schedule_hour, schedule_minute,
                                  conflict_strategy)
SELECT 'Sync produits PNR-OFC -> ' || tgt.site_code, src.site_id, tgt.site_id,
       'APP_PRODUCT', 'PRODUCT', 'PUSH', 'DBLINK',
       'NIGHTLY', 2, 0, 'MASTER_WINS'
  FROM site_master src, site_master tgt
 WHERE src.site_code = 'PNR-OFC' AND tgt.site_code <> 'PNR-OFC';

INSERT INTO site_sync_schedule (schedule_name, source_site_id, target_site_id,
                                  object_owner, object_name, sync_direction, sync_method,
                                  schedule_type, schedule_hour, schedule_minute)
SELECT 'Sync tickets boutique -> ' || tgt.site_code,
       src.site_id, tgt.site_id,
       'APP_SALES', 'TICKET', 'PULL', 'DBLINK',
       'NIGHTLY', 4, 30
  FROM site_master src, site_master tgt
 WHERE tgt.site_code = 'PNR-OFC' AND src.site_type = 'BOUTIQUE';

COMMIT;
PROMPT Planification sync créée.

-- ═══ 5. Simulation d'events CDC ═══
PROMPT
PROMPT ▸ Simulation d'events (synchronisation master vers boutiques)

DECLARE
  v_origin_id NUMBER;
BEGIN
  SELECT site_id INTO v_origin_id FROM site_master WHERE site_code = 'PNR-OFC';

  -- Event 1 : nouveau produit créé (Tefal Wok)
  INSERT INTO outbox_event (
    object_owner, object_name, primary_key_value, operation,
    row_data_json, site_code_origin, company_code, user_code, status
  ) VALUES (
    'APP_PRODUCT', 'PRODUCT', '31274', 'INSERT',
    JSON_OBJECT(
      'product_code' VALUE '31274',
      'product_name' VALUE 'TEFAL PRIMA FRYPAN WOK 36+LID',
      'standard_price' VALUE 27500,
      'category' VALUE 'CUISINE',
      'barcode' VALUE '3168430187191'
    ),
    'PNR-OFC', 'REGAL', 'KAMAL', 'PENDING'
  );

  -- Event 2 : prix produit modifié
  INSERT INTO outbox_event (
    object_owner, object_name, primary_key_value, operation,
    row_data_json, old_data_json, site_code_origin, status
  ) VALUES (
    'APP_PRODUCT', 'PRODUCT', '31275', 'UPDATE',
    JSON_OBJECT('product_code' VALUE '31275', 'standard_price' VALUE 32000),
    JSON_OBJECT('product_code' VALUE '31275', 'standard_price' VALUE 27500),
    'PNR-OFC', 'PENDING'
  );

  -- Event 3 : suppression
  INSERT INTO outbox_event (
    object_owner, object_name, primary_key_value, operation,
    row_data_json, site_code_origin, status
  ) VALUES (
    'APP_PRODUCT', 'PRODUCT', 'OUT-1234', 'DELETE',
    NULL, 'PNR-OFC', 'PENDING'
  );

  -- Event 4 : prix modifié (déjà publié)
  INSERT INTO outbox_event (
    object_owner, object_name, primary_key_value, operation,
    row_data_json, site_code_origin, status, published_at
  ) VALUES (
    'APP_PRODUCT', 'PRODUCT', '19889', 'UPDATE',
    JSON_OBJECT('product_code' VALUE '19889', 'standard_price' VALUE 2950),
    'PNR-OFC', 'DONE', SYSTIMESTAMP - 1
  );

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → 4 events simulés.');
END;
/

-- ═══ 6. Sync runs historiques (simulations) ═══
PROMPT
PROMPT ▸ Historique syncs (30 derniers jours)

INSERT INTO site_sync_run (schedule_id, source_site_id, target_site_id,
                            started_at, completed_at, rows_inserted, rows_updated,
                            status, initiator)
SELECT
  NULL,
  (SELECT site_id FROM site_master WHERE site_code = 'PNR-OFC'),
  tgt.site_id,
  SYSTIMESTAMP - 1 - dbms_random.value(0, 30),
  SYSTIMESTAMP - 1 - dbms_random.value(0, 30) + INTERVAL '15' MINUTE,
  ROUND(dbms_random.value(50, 500)),
  ROUND(dbms_random.value(0, 200)),
  CASE WHEN dbms_random.value < 0.85 THEN 'SUCCESS'
       WHEN dbms_random.value < 0.95 THEN 'PARTIAL'
       ELSE 'FAILED' END,
  'SCHEDULER'
  FROM site_master tgt
 WHERE tgt.site_code IN ('BZV-B01','BZV-B02','DLS-B01','PNR-B01');
COMMIT;

-- ═══ Volumétrie ═══
PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'site_master'         AS tbl, COUNT(*) AS nb FROM site_master
UNION ALL SELECT 'site_link',           COUNT(*) FROM site_link
UNION ALL SELECT 'site_database',       COUNT(*) FROM site_database
UNION ALL SELECT 'site_sync_schedule',  COUNT(*) FROM site_sync_schedule
UNION ALL SELECT 'site_sync_run',       COUNT(*) FROM site_sync_run
UNION ALL SELECT 'outbox_event',        COUNT(*) FROM outbox_event
 ORDER BY tbl;

PROMPT
PROMPT ═══ Demostrations ═══

PROMPT [Q1] Topologie hiérarchique des sites
SELECT LPAD(' ', 2 * (LEVEL - 1)) || site_code AS site_code,
       site_name, site_type, city,
       DECODE(is_master, 'Y', '★ MASTER', '') AS master_flag
  FROM site_master
 CONNECT BY PRIOR site_id = parent_site_id
 START WITH parent_site_id IS NULL
 ORDER SIBLINGS BY sync_priority;

PROMPT [Q2] Latence moyenne par destination
SELECT src.site_code AS origin, tgt.site_code AS destination,
       tgt.city, l.bandwidth_kbps, l.avg_latency_ms, l.reliability_pct
  FROM site_link l
  JOIN site_master src ON src.site_id = l.source_site_id
  JOIN site_master tgt ON tgt.site_id = l.target_site_id
 WHERE src.site_code = 'PNR-OFC'
 ORDER BY l.avg_latency_ms;

PROMPT [Q3] Statistiques des events CDC
SELECT status, COUNT(*) AS nb, ROUND(AVG(retry_count), 2) AS avg_retry
  FROM outbox_event
 GROUP BY status
 ORDER BY status;

PROMPT [Q4] Dernières syncs effectuées
SELECT sm.site_code AS source,
       tm.site_code AS target,
       sr.started_at, sr.completed_at, sr.rows_inserted,
       sr.status
  FROM site_sync_run sr
  JOIN site_master sm ON sm.site_id = sr.source_site_id
  JOIN site_master tm ON tm.site_id = sr.target_site_id
 ORDER BY sr.started_at DESC
 FETCH FIRST 10 ROWS ONLY;

PROMPT [Q5] Taux de succès des syncs (par destination)
SELECT tm.site_code AS destination, tm.city,
       COUNT(*) AS total_runs,
       SUM(CASE WHEN sr.status='SUCCESS' THEN 1 ELSE 0 END) AS success,
       ROUND(100 * SUM(CASE WHEN sr.status='SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_success
  FROM site_sync_run sr
  JOIN site_master tm ON tm.site_id = sr.target_site_id
 GROUP BY tm.site_code, tm.city
 ORDER BY tm.city;

PROMPT [Q6] Vue v_site_sync_status
SELECT * FROM v_site_sync_status;

PROMPT [Q7] Test pkg_sync_hub.publish_pending
DECLARE
  v_n NUMBER;
BEGIN
  v_n := pkg_sync_hub.publish_pending(10);
  DBMS_OUTPUT.PUT_LINE('  → ' || v_n || ' events publiés.');
END;
/

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ TOPOLOGIE REGAL : 7 sites + 4 events CDC + syncs simulées
PROMPT   - 1 siège MASTER (Pointe-Noire)
PROMPT   - 4 boutiques (PNR, BZV x2, DLS)
PROMPT   - 2 dépôts (PNR, BZV)
PROMPT   - Liens : 2 Mbps fibre BZV, 1 Mbps satellite DLS
PROMPT ══════════════════════════════════════════════════════════
EXIT;
