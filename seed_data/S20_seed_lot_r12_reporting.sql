-- ============================================================
-- S20 : Seed LOT R12 (KPI & Reporting)
-- Données de démo : 8 KPIs, snapshots sur 7 jours,
--                    3 objectifs commerciaux, 4 rapports, 5 exécutions.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R12 — KPI & Reporting
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R12]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM report_execution';
  EXECUTE IMMEDIATE 'DELETE FROM report_definition';
  EXECUTE IMMEDIATE 'DELETE FROM sales_target';
  EXECUTE IMMEDIATE 'DELETE FROM kpi_daily_snapshot';
  EXECUTE IMMEDIATE 'DELETE FROM kpi_definition';
  COMMIT;
END;
/


PROMPT [1] 8 définitions de KPI
INSERT INTO kpi_definition (kpi_code, kpi_name, kpi_category, unit,
                             formula, target_value, warning_threshold, critical_threshold,
                             comparison_op, refresh_frequency, sql_query,
                             display_order, is_active, description, created_by)
VALUES ('DAILY_REVENUE', 'CA journalier', 'SALES', 'XOF',
        'SUM(total_ttc) WHERE status=V', 200000, 150000, 100000,
        '<', 'REALTIME',
        'SELECT SUM(total_ttc) FROM app_sales.ticket WHERE TRUNC(ticket_date)=TRUNC(SYSDATE) AND status=''V''',
        10, TRUE, 'Chiffre d''affaires TTC journalier', 'ADMIN');

INSERT INTO kpi_definition (kpi_code, kpi_name, kpi_category, unit,
                             formula, target_value, warning_threshold, critical_threshold,
                             comparison_op, refresh_frequency,
                             display_order, is_active, description, created_by)
VALUES ('DAILY_TICKETS', 'Tickets par jour', 'SALES', 'COUNT',
        'COUNT(*) ticket V', 50, 30, 15,
        '<', 'DAILY',
        11, TRUE, 'Nombre de tickets émis par jour', 'ADMIN');

INSERT INTO kpi_definition (kpi_code, kpi_name, kpi_category, unit,
                             formula, target_value, warning_threshold, critical_threshold,
                             comparison_op, refresh_frequency,
                             display_order, is_active, description, created_by)
VALUES ('AVG_TICKET', 'Panier moyen', 'SALES', 'XOF',
        'AVG(total_ttc)', 8000, 6000, 4000,
        '<', 'DAILY',
        12, TRUE, 'Panier moyen TTC', 'ADMIN');

INSERT INTO kpi_definition (kpi_code, kpi_name, kpi_category, unit,
                             formula, target_value, comparison_op, refresh_frequency,
                             display_order, is_active, description, created_by)
VALUES ('STOCK_TURNOVER', 'Rotation stock', 'STOCK', 'RATIO',
        'COGS / avg_stock', NULL, '>', 'MONTHLY',
        30, TRUE, 'Nombre de fois que le stock est renouvelé par mois', 'ADMIN');

INSERT INTO kpi_definition (kpi_code, kpi_name, kpi_category, unit,
                             formula, target_value, comparison_op, refresh_frequency,
                             display_order, is_active, description, created_by)
VALUES ('CASH_VARIANCE', 'Écart caisse', 'CASH', 'XOF',
        'ABS(SUM(difference))', 5000, '>', 'DAILY',
        40, TRUE, 'Somme absolue des écarts de caisse', 'ADMIN');

INSERT INTO kpi_definition (kpi_code, kpi_name, kpi_category, unit,
                             formula, target_value, comparison_op, refresh_frequency,
                             display_order, is_active, description, created_by)
VALUES ('LOYALTY_MEMBERS', 'Adhérents fidélité', 'LOYALTY', 'COUNT',
        'COUNT(*) loyalty_card', NULL, '>', 'DAILY',
        50, TRUE, 'Nombre d''adhérents au programme', 'ADMIN');

INSERT INTO kpi_definition (kpi_code, kpi_name, kpi_category, unit,
                             formula, target_value, warning_threshold, comparison_op, refresh_frequency,
                             display_order, is_active, description, created_by)
VALUES ('OVERDUE_RATIO', 'Ratio en retard', 'FINANCIAL', 'PCT',
        'encours échu / encours total', 20, 30, '<', 'WEEKLY',
        60, TRUE, 'Pourcentage encours échu sur encours total', 'ADMIN');

INSERT INTO kpi_definition (kpi_code, kpi_name, kpi_category, unit,
                             formula, target_value, warning_threshold, comparison_op, refresh_frequency,
                             display_order, is_active, description, created_by)
VALUES ('PRODUCTS_BELOW_MIN', 'Produits sous le min', 'STOCK', 'COUNT',
        'COUNT(*) inv_stock sous min', 5, 15, '<', 'HOURLY',
        31, TRUE, 'Nombre de produits sous leur seuil minimum', 'ADMIN');


PROMPT [2] Snapshots KPI sur 7 jours pour 4 KPIs principaux
DECLARE
  v_date DATE;
  v_rev NUMBER;
BEGIN
  FOR d IN 0..6 LOOP
    v_date := TRUNC(SYSDATE - d);
    -- CA journalier avec variation
    v_rev := 180000 + ROUND(DBMS_RANDOM.VALUE(-30000, 30000));

    INSERT INTO kpi_daily_snapshot (snapshot_date, kpi_code, entity_type, entity_code, value, target_value)
    VALUES (v_date, 'DAILY_REVENUE', 'GLOBAL', 'ALL', v_rev, 200000);

    INSERT INTO kpi_daily_snapshot (snapshot_date, kpi_code, entity_type, entity_code, value, target_value)
    VALUES (v_date, 'DAILY_TICKETS', 'GLOBAL', 'ALL', 40 + ROUND(DBMS_RANDOM.VALUE(-10, 15)), 50);

    INSERT INTO kpi_daily_snapshot (snapshot_date, kpi_code, entity_type, entity_code, value, target_value)
    VALUES (v_date, 'AVG_TICKET', 'GLOBAL', 'ALL', 7500 + ROUND(DBMS_RANDOM.VALUE(-1500, 2500)), 8000);

    INSERT INTO kpi_daily_snapshot (snapshot_date, kpi_code, entity_type, entity_code, value, target_value)
    VALUES (v_date, 'PRODUCTS_BELOW_MIN', 'GLOBAL', 'ALL', 3 + ROUND(DBMS_RANDOM.VALUE(0, 5)), 5);

    -- Snapshot par terminal pour le CA
    INSERT INTO kpi_daily_snapshot (snapshot_date, kpi_code, entity_type, entity_code, value, target_value)
    VALUES (v_date, 'DAILY_REVENUE', 'POS', 'CAI01', ROUND(v_rev * 0.6), 120000);

    INSERT INTO kpi_daily_snapshot (snapshot_date, kpi_code, entity_type, entity_code, value, target_value)
    VALUES (v_date, 'DAILY_REVENUE', 'POS', 'CAI02', ROUND(v_rev * 0.4), 80000);
  END LOOP;
  COMMIT;
END;
/


PROMPT [3] 4 objectifs commerciaux
INSERT INTO sales_target (target_year, target_month, entity_type, entity_code,
                           target_amount, target_margin, target_tickets, target_new_customers,
                           notes, is_active, created_by)
VALUES (2026, NULL, 'GLOBAL', 'ALL',
        50000000, 15000000, 5000, 200,
        'Objectif annuel 2026', TRUE, 'ADMIN');

INSERT INTO sales_target (target_year, target_month, entity_type, entity_code,
                           target_amount, target_margin, target_tickets,
                           notes, is_active, created_by)
VALUES (2026, 9, 'GLOBAL', 'ALL',
        4000000, 1200000, 400,
        'Septembre 2026', TRUE, 'ADMIN');

INSERT INTO sales_target (target_year, target_month, entity_type, entity_code,
                           target_amount, target_tickets, created_by)
VALUES (2026, 9, 'POS', 'CAI01',
        2400000, 250, 'ADMIN');

INSERT INTO sales_target (target_year, target_month, entity_type, entity_code,
                           target_amount, target_tickets, created_by)
VALUES (2026, 9, 'POS', 'CAI02',
        1600000, 150, 'ADMIN');


PROMPT [4] 5 rapports catalogue
INSERT INTO report_definition (report_code, report_name, category,
                                description, sql_query,
                                default_format, is_scheduled, schedule_cron,
                                allowed_roles, is_active, created_by)
VALUES ('RPT_DAILY_SALES', 'Ventes quotidiennes', 'SALES',
        'Détail des ventes par jour avec CA HT/TTC, panier moyen, nb tickets',
        'SELECT TRUNC(ticket_date) AS jour, COUNT(*) AS nb, SUM(total_ttc) AS ca_ttc FROM app_sales.ticket WHERE status=''V'' GROUP BY TRUNC(ticket_date) ORDER BY 1 DESC',
        'PDF', TRUE, '0 8 * * *', 'MANAGER,ACCOUNTANT', TRUE, 'ADMIN');

INSERT INTO report_definition (report_code, report_name, category,
                                description, sql_query,
                                default_format, allowed_roles, is_active, created_by)
VALUES ('RPT_TOP_PRODUCTS', 'Top 20 produits', 'SALES',
        'Classement des 20 produits les plus vendus sur 30j',
        'SELECT * FROM app_api.mv_monthly_top_products WHERE sale_month = TRUNC(SYSDATE,''MM'') ORDER BY total_amount DESC FETCH FIRST 20 ROWS ONLY',
        'XLSX', 'MANAGER', TRUE, 'ADMIN');

INSERT INTO report_definition (report_code, report_name, category,
                                description, sql_query,
                                default_format, allowed_roles, is_active, created_by)
VALUES ('RPT_OVERDUE', 'Encours en retard', 'FINANCIAL',
        'Liste des factures en retard avec balance âgée',
        'SELECT * FROM app_api.v_customer_balance WHERE credit_status IN (''WARNING'',''OVER_LIMIT'')',
        'PDF', 'ACCOUNTANT', TRUE, 'ADMIN');

INSERT INTO report_definition (report_code, report_name, category,
                                description, sql_query,
                                default_format, allowed_roles, is_active, created_by)
VALUES ('RPT_CRITICAL_STOCK', 'Stock critique', 'STOCK',
        'Produits sous leur seuil minimum avec quantité à recommander',
        'SELECT * FROM app_api.v_critical_stock ORDER BY stock_status, qty_to_reorder DESC',
        'CSV', 'MANAGER,INVENTORY', TRUE, 'ADMIN');

INSERT INTO report_definition (report_code, report_name, category,
                                description, default_format,
                                is_scheduled, schedule_cron, allowed_roles, is_active, created_by)
VALUES ('RPT_DAILY_KPI', 'KPI Dashboard', 'MIXED',
        'Tableau de bord quotidien CA/panier/tickets/produits sous min', 'HTML',
        TRUE, '0 7 * * *', 'MANAGER,DIRECTOR', TRUE, 'ADMIN');


PROMPT [5] 6 exécutions de rapports (historique)
INSERT INTO report_execution (report_code, parameters_json, output_format,
                               row_count, size_bytes, duration_ms, status,
                               started_at, completed_at, executed_by, ip_address)
VALUES ('RPT_DAILY_SALES',
        JSON_OBJECT('period' VALUE 'LAST_30_DAYS', 'format' VALUE 'PDF'),
        'PDF', 30, 245678, 1230, 'SUCCESS',
        SYSDATE - 1, SYSDATE - 1 + 1.3/24/60/60, 'MANAGER1', '192.168.1.45');

INSERT INTO report_execution (report_code, parameters_json, output_format,
                               row_count, size_bytes, duration_ms, status,
                               started_at, completed_at, executed_by)
VALUES ('RPT_TOP_PRODUCTS',
        JSON_OBJECT('period' VALUE 'CURRENT_MONTH'),
        'XLSX', 20, 125000, 540, 'SUCCESS',
        SYSDATE - 1/24, SYSDATE - 1/24 + 9/24/60/60, 'ADMIN');

INSERT INTO report_execution (report_code, parameters_json, output_format,
                               row_count, duration_ms, status,
                               started_at, completed_at, executed_by, error_message)
VALUES ('RPT_OVERDUE',
        JSON_OBJECT('as_of' VALUE TO_CHAR(SYSDATE, 'YYYY-MM-DD')),
        'PDF', NULL, 18500, 'FAILED',
        SYSDATE - 2/24, SYSDATE - 2/24 + 0.3/60/60, 'ACCOUNTANT',
        'ORA-00942: table or view does not exist');

INSERT INTO report_execution (report_code, output_format,
                               row_count, size_bytes, duration_ms, status,
                               started_at, completed_at, executed_by)
VALUES ('RPT_CRITICAL_STOCK', 'CSV',
        8, 12500, 220, 'SUCCESS',
        SYSDATE - 5/24, SYSDATE - 5/24 + 4/60/60, 'INVENTORY');

INSERT INTO report_execution (report_code, parameters_json, output_format, status,
                               started_at, executed_by)
VALUES ('RPT_DAILY_KPI',
        JSON_OBJECT('auto' VALUE TRUE),
        'HTML', 'RUNNING',
        SYSTIMESTAMP - 30/86400, 'SYSTEM');

INSERT INTO report_execution (report_code, output_format, status,
                               started_at, completed_at, executed_by, error_message)
VALUES ('RPT_TOP_PRODUCTS', 'XLSX', 'CANCELLED',
        SYSDATE - 3, SYSDATE - 3 + 5/60/60, 'MANAGER1',
        'Cancelled by user');

COMMIT;


PROMPT [6] Rafraîchissement manuel des MV pour le seed
DECLARE
  v_err_count NUMBER := 0;
BEGIN
  FOR mv IN (SELECT mview_name FROM user_mviews WHERE mview_name LIKE 'MV\_%' ESCAPE '\') LOOP
    BEGIN
      DBMS_MVIEW.REFRESH(mv.mview_name, 'C');
    EXCEPTION WHEN OTHERS THEN
      v_err_count := v_err_count + 1;
      DBMS_OUTPUT.PUT_LINE('Skip MV ' || mv.mview_name || ' : ' || SQLERRM);
    END;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('MV refreshed, errors=' || v_err_count);
END;
/


PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'KPI_DEFINITION'         AS tbl, COUNT(*) AS nb FROM kpi_definition
UNION ALL SELECT 'KPI_DAILY_SNAPSHOT',   COUNT(*) FROM kpi_daily_snapshot
UNION ALL SELECT 'SALES_TARGET',         COUNT(*) FROM sales_target
UNION ALL SELECT 'REPORT_DEFINITION',    COUNT(*) FROM report_definition
UNION ALL SELECT 'REPORT_EXECUTION',     COUNT(*) FROM report_execution
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Performance KPI aujourd'hui
SELECT kd.kpi_name, kd.unit,
       kds.value AS valeur_actuelle,
       kds.target_value AS cible,
       kds.variance,
       kds.variance_pct,
       kds.achieved
  FROM kpi_daily_snapshot kds
  JOIN kpi_definition kd ON kd.kpi_code = kds.kpi_code
 WHERE kds.snapshot_date = TRUNC(SYSDATE)
   AND kds.entity_type = 'GLOBAL'
 ORDER BY kd.display_order;

PROMPT [Q2] Progression objectif septembre
SELECT target_month,
       target_amount AS cible,
       NVL(achieved.actual, 0) AS realise,
       ROUND(NVL(achieved.actual, 0) * 100 / target_amount, 1) AS pct_atteint
  FROM sales_target st
  LEFT JOIN (
    SELECT TRUNC(ticket_date, 'MM') AS mois, SUM(total_ttc) AS actual
      FROM app_sales.ticket WHERE status='V'
      GROUP BY TRUNC(ticket_date, 'MM')
  ) achieved ON achieved.mois = TO_DATE(st.target_year || LPAD(st.target_month, 2, '0') || '01', 'YYYYMMDD')
 WHERE st.target_year = 2026 AND st.target_month = 9
   AND st.entity_type = 'GLOBAL';

PROMPT [Q3] Top 10 des exécutions de rapports (par durée)
SELECT report_code, status, duration_ms, row_count, size_bytes, executed_by, started_at
  FROM report_execution
 ORDER BY duration_ms DESC
 FETCH FIRST 10 ROWS ONLY;

PROMPT [Q4] Taux de succès des rapports
SELECT status, COUNT(*) AS nb,
       ROUND(AVG(duration_ms), 0) AS avg_duration_ms,
       ROUND(AVG(row_count), 0) AS avg_rows
  FROM report_execution
 GROUP BY status
 ORDER BY nb DESC;

PROMPT [Q5] KPI globaux vs par POS
SELECT kpi_code, entity_type, entity_code, value, target_value, variance_pct
  FROM kpi_daily_snapshot
 WHERE snapshot_date = TRUNC(SYSDATE)
   AND kpi_code = 'DAILY_REVENUE'
 ORDER BY entity_type, entity_code;

PROMPT [Q6] Stock critique (via vue)
SELECT *
  FROM v_critical_stock
 ORDER BY stock_status, qty_to_reorder DESC;

PROMPT [Q7] Encours clients (via vue)
SELECT party_code, party_name, outstanding, credit_limit, utilization_pct, credit_status
  FROM v_customer_balance
 WHERE utilization_pct > 0
 ORDER BY utilization_pct DESC;

PROMPT [Q8] KPIs non atteints (variation négative vs cible)
SELECT kd.kpi_name, kds.value, kds.target_value, kds.variance_pct
  FROM kpi_daily_snapshot kds
  JOIN kpi_definition kd ON kd.kpi_code = kds.kpi_code
 WHERE kds.snapshot_date = TRUNC(SYSDATE)
   AND kds.achieved = FALSE
 ORDER BY kds.variance_pct;

PROMPT [Q9] Vues matérialisées populées
SELECT mview_name, num_rows, last_refresh_date, staleness
  FROM user_mviews
 WHERE mview_name LIKE 'MV\_%' ESCAPE '\'
 ORDER BY mview_name;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R12 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
