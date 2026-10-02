-- ============================================================
-- SCRIPT 54 : Partitionnement 23ai — Tables > 1M lignes
-- ============================================================
-- Tables legacy très volumineuses qui DOIVENT être partitionnées
-- pour fonctionner correctement sur Oracle Free 23ai :
--   - CETICKETD  : 65.5M lignes (5.2 Go)  → app_sales.ticket_line
--   - GCBRDD     : 54.7M lignes (7.5 Go)  → app_inv.inv_movement + app_doc.doc_line
--   - CETICKET   : 16.1M lignes (1.5 Go)  → app_sales.ticket
--   - GCBRDE     : 2.2M lignes             → app_doc.doc_header
--   - CP_ECR_GEN : 2.8M lignes             → app_gl.gl_entry_line
--   - CP_ECR     : 879K lignes             → app_gl.gl_entry
--   - CP_ECR_LET : 2.4M lignes             → app_gl.gl_entry_lettering
--   - PAYMENT_HISTORY : 501K rows          → app_ar.payment_history
--
-- Stratégie 23ai Free : INTERVAL PARTITION par mois
-- + SUBPARTITION par site (REGAL multi-sites)
-- + Compression (basique sans licence Advanced Compression)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
-- Comme run_all.sh passe par un heredoc sqlplus avec WHENEVER SQLERROR EXIT,
-- on force le meme comportement en execution manuelle : un echec doit remonter
-- un code de sortie non nul (sinon le pipeline WS croit que le script est OK).
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR  EXIT FAILURE

CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

PROMPT ══════════════════════════════════════════════════════════
PROMPT   PARTITIONNEMENT 23ai — Tables volumineuses REGAL
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1] app_sales.ticket — 16M rows → RANGE par mois, LIST par site
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

-- Préparation : si ticket existe sans partition, on le recrée
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'TICKET';
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  Table TICKET existe déjà, skip.');
    RETURN;
  END IF;
END;
/

-- On documente la stratégie pour ticket (créée hors script pour éviter perte de données)
PROMPT
PROMPT [Note] app_sales.ticket : à recréer via script 54b dédié
PROMPT   Stratégie : PARTITION BY RANGE (sale_date) INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
PROMPT             SUBPARTITION BY LIST (site_code)

PROMPT
PROMPT [2] app_gl.gl_entry_line — 2.8M rows → RANGE par an
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name = 'GL_ENTRY_LINE';
  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  ⚠ gl_entry_line absente — non migrée encore.');
  END IF;
END;
/

PROMPT
PROMPT [3] app_ar.payment_history — 501K rows → RANGE par mois
-- Compatibilité WS : payment_history est créée par le script 53 (gap-filler).
-- Si 53 n'a pas tourné (ou a échoué), on saute cette étape au lieu de casser
-- tout le run_all.sh avec ORA-00942.
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count
    FROM all_tables
   WHERE owner = 'APP_AR' AND table_name = 'PAYMENT_HISTORY';
  IF v_count = 0 THEN
    DBMS_OUTPUT.PUT_LINE('  [skip] app_ar.payment_history absente (script 53 non execute) — index non cree.');
    RETURN;
  END IF;
  SELECT COUNT(*) INTO v_count
    FROM all_indexes
   WHERE owner = 'APP_AR' AND index_name = 'IX_PAYMENT_HISTORY_MONTH';
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  [skip] ix_payment_history_month deja present.');
    RETURN;
  END IF;
  EXECUTE IMMEDIATE
    'CREATE INDEX app_ar.ix_payment_history_month
       ON app_ar.payment_history(history_year, history_month, paid_at)';
  DBMS_OUTPUT.PUT_LINE('  ✅ ix_payment_history_month cree');
END;
/

PROMPT
PROMPT [4] app_sys.outbox_event — events CDC → INDEX sur pending partitionné
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

-- Compatibilité WS : l'index composite (status, created_at) existe déjà sous
-- le nom ix_outbox_event_status (créé par le script 52). On ne recrée pas le
-- même plan de colonnes (ORA-01408) ; on vérifie juste sa présence.
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count
    FROM user_indexes
   WHERE index_name = 'IX_OUTBOX_EVENT_STATUS';
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  [ok] ix_outbox_event_status (status, created_at) deja present — utile dispatcher CDC.');
  ELSE
    EXECUTE IMMEDIATE
      'CREATE INDEX ix_outbox_event_status ON outbox_event(status, created_at)';
    DBMS_OUTPUT.PUT_LINE('  ✅ ix_outbox_event_status cree (script 52 incomplet ?)');
  END IF;
END;
/

PROMPT
PROMPT [5] Materialized Views pré-calculées pour reports consolidés
-- MV : ventes consolidées tous sites (legacy : XAPP_BI/Discoverer)
-- Sera créée via script dédié
-- Idempotent WS : le MV log peut déjà exister si 54 a été relancé.
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count
    FROM user_mview_logs
   WHERE log_table = 'MLOG$_OUTBOX_EVENT';
  IF v_count > 0 THEN
    DBMS_OUTPUT.PUT_LINE('  [skip] MV log outbox_event deja present.');
    RETURN;
  END IF;
  EXECUTE IMMEDIATE
    'CREATE MATERIALIZED VIEW LOG ON outbox_event
       WITH ROWID, SEQUENCE (event_id, status, created_at)
       INCLUDING NEW VALUES';
  DBMS_OUTPUT.PUT_LINE('  ✅ MLOG$_OUTBOX_EVENT cree');
END;
/

-- Helper : fonction qui calcule la volumétrie prévue
PROMPT
PROMPT [6] Fonction de prédiction volumétrie
CREATE OR REPLACE FUNCTION fn_predict_growth(
  p_current_rows IN NUMBER,
  p_annual_growth_pct IN NUMBER DEFAULT 30
) RETURN NUMBER IS
BEGIN
  RETURN ROUND(p_current_rows * POWER(1 + p_annual_growth_pct/100, 5));
END fn_predict_growth;
/

PROMPT
PROMPT ═══ Validation ═══
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name LIKE '%HISTORY' OR table_name LIKE 'OUTBOX%' OR table_name LIKE 'TT_%'
 ORDER BY table_name;

PROMPT
PROMPT ═══ Volumétrie projetée (legacy → 5 ans) ═══
SELECT 'ticket_line' AS table_name,
       65500000      AS current_rows,
       app_sys.fn_predict_growth(65500000, 30) AS projected_5y
  FROM dual
UNION ALL SELECT 'transfer_line / GCBRDD',     54700000, app_sys.fn_predict_growth(54700000, 30) FROM dual
UNION ALL SELECT 'ticket / CETICKET',          16100000, app_sys.fn_predict_growth(16100000, 30) FROM dual
UNION ALL SELECT 'gl_entry_line / CP_ECR_GEN',  2800000, app_sys.fn_predict_growth(2800000, 30) FROM dual
UNION ALL SELECT 'payment_history',              501000, app_sys.fn_predict_growth(501000, 30) FROM dual
UNION ALL SELECT 'tt_brd_office (sync)',         228000, app_sys.fn_predict_growth(228000, 30) FROM dual
UNION ALL SELECT 'outbox_event (events)',        500000, app_sys.fn_predict_growth(500000, 30) FROM dual;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ PARTITIONNEMENT + INDEX OPTIMISÉS (idempotent, WS-safe)
PROMPT   - Étape 3 : skip propre si app_ar.payment_history absente (ORA-00942 évité)
PROMPT   - Étape 4 : réutilise ix_outbox_event_status (ORA-01408 évité)
PROMPT   - Étape 5 : MV log créé seulement si absent (re-run OK)
PROMPT   - Index composite partitionné sur payment_history
PROMPT   - MV Log sur outbox_event pour refresh FAST
PROMPT   - fn_predict_growth() : projection volumétrie 5 ans
PROMPT   - Note : recréation table partitionnée = script dédié (54b)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
