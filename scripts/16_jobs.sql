-- ============================================================
-- SCRIPT 16 : Jobs de maintenance
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DES JOBS
PROMPT ═══════════════════════════════════════════════════════

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT [1] Job de rafraîchissement des MV
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_REFRESH_MVIEWS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN
                          DBMS_MVIEW.REFRESH(''MV_STOCK_SUMMARY'', ''C'');
                          DBMS_MVIEW.REFRESH(''MV_DAILY_SALES'', ''C'');
                          DBMS_MVIEW.REFRESH(''MV_PRODUCT_SALES'', ''C'');
                        END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=HOURLY; INTERVAL=1',
    enabled         => TRUE,
    comments        => 'Rafraîchissement horaire des vues matérialisées'
  );
END;
/

PROMPT ✅ JOB_REFRESH_MVIEWS créé

PROMPT [2] Job de purge des logs
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_PURGE_LOGS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN
                          DELETE FROM app_pos.pos_session_log
                           WHERE operation_at < ADD_MONTHS(SYSDATE, -12);
                          DELETE FROM app_doc.doc_log
                           WHERE operation_at < ADD_MONTHS(SYSDATE, -24);
                          COMMIT;
                        END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY; BYHOUR=2',
    enabled         => TRUE,
    comments        => 'Purge quotidienne des logs anciens'
  );
END;
/

PROMPT ✅ JOB_PURGE_LOGS créé

PROMPT [3] Job d'archivage des tickets anciens
BEGIN
  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'JOB_ARCHIVE_TICKETS',
    job_type        => 'PLSQL_BLOCK',
    job_action      => 'BEGIN
                          INSERT INTO app_hist.hist_ticket
                          SELECT terminal_id, ticket_no, ticket_date, session_no,
                                 customer_code, customer_name, total_ttc, total_ht,
                                 status, SYSTIMESTAMP
                            FROM app_sales.ticket
                           WHERE ticket_date < ADD_MONTHS(SYSDATE, -24)
                             AND status = ''V'';
                          COMMIT;
                        END;',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=MONTHLY; BYMONTHDAY=1; BYHOUR=3',
    enabled         => FALSE,
    comments        => 'Archivage mensuel des tickets de plus de 24 mois'
  );
END;
/

PROMPT ✅ JOB_ARCHIVE_TICKETS créé (désactivé)

PROMPT
PROMPT [Validation]
SELECT job_name, enabled, state, repeat_interval
  FROM user_scheduler_jobs
 ORDER BY job_name;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ JOBS TERMINÉS
PROMPT ═══════════════════════════════════════════════════════