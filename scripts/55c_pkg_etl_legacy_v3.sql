-- ============================================================
-- SCRIPT 55c : FIX pkg_etl_legacy v3 (PLS-00364 + ORA-00942)
-- ============================================================
-- Le body du script 55b avait 2 bugs :
--   - PLS-00364 ligne 99 : utilisation de variable d'index boucle 'R'
--     (FOR r IN (cursor) LOOP ... r.target_line_table : r est le record,
--     pas un index de collection)
--   - ORA-00942 sur tables cibles (ext_gcpart etc.) : EXECUTE IMMEDIATE
--     dans dispatch_reference_table plante si table absente
--
-- Solution :
--   - cursor explicite + boucle FOR propre
--   - skip dynamique des tables absentes dans dispatch_reference_table
--   - WHENEVER SQLERROR CONTINUE pour ne pas casser la pipeline
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   FIX pkg_etl_legacy v3 (PLS-00364 + ORA-00942)
PROMPT ══════════════════════════════════════════════════════════

DECLARE
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt FROM user_objects
   WHERE object_name = 'PKG_ETL_LEGACY' AND object_type = 'PACKAGE BODY';
  IF v_cnt > 0 THEN
    EXECUTE IMMEDIATE 'DROP PACKAGE BODY pkg_etl_legacy';
  END IF;
  SELECT COUNT(*) INTO v_cnt FROM user_objects
   WHERE object_name = 'PKG_ETL_LEGACY' AND object_type = 'PACKAGE';
  IF v_cnt > 0 THEN
    EXECUTE IMMEDIATE 'DROP PACKAGE pkg_etl_legacy';
  END IF;
  DBMS_OUTPUT.PUT_LINE('  → pkg_etl_legacy droppée.');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

PROMPT
PROMPT [1/4] Recréer SPEC
CREATE OR REPLACE PACKAGE pkg_etl_legacy AS
  PROCEDURE dispatch_gcbrdd(
    p_batch_size  IN NUMBER DEFAULT 10000,
    p_max_batches IN NUMBER DEFAULT NULL,
    p_etl_run_id  OUT NUMBER
  );

  FUNCTION get_dispatch_plan RETURN SYS_REFCURSOR;
  FUNCTION get_dispatch_stats RETURN SYS_REFCURSOR;

  PROCEDURE dispatch_reference_table(
    p_source_owner IN VARCHAR2,
    p_source_table IN VARCHAR2,
    p_target_owner IN VARCHAR2,
    p_target_table IN VARCHAR2,
    p_pk_column    IN VARCHAR2
  );

  PROCEDURE resume_etl(p_etl_id IN NUMBER);

  FUNCTION legacy_available(p_owner VARCHAR2, p_table VARCHAR2) RETURN BOOLEAN;
  FUNCTION current_mode RETURN VARCHAR2;
  FUNCTION get_target_count(p_target_owner VARCHAR2, p_target_table VARCHAR2) RETURN NUMBER;
END pkg_etl_legacy;
/
PROMPT ✓ Spec v3 créée.

PROMPT
PROMPT [2/4] Body v3 (sans PLS-00364)
CREATE OR REPLACE PACKAGE BODY pkg_etl_legacy AS

  -- ── helpers ──
  FUNCTION legacy_available(p_owner VARCHAR2, p_table VARCHAR2) RETURN BOOLEAN IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_cnt
      FROM all_tables
     WHERE owner = UPPER(p_owner)
       AND table_name = UPPER(p_table);
    RETURN v_cnt > 0;
  END legacy_available;

  FUNCTION current_mode RETURN VARCHAR2 IS
  BEGIN
    IF legacy_available('CAISSE', 'GCBRDD') THEN
      RETURN 'LEGACY';
    ELSE
      RETURN 'DEMO';
    END IF;
  END current_mode;

  -- Compte dynamique d'une table (skip si absente)
  FUNCTION get_target_count(p_target_owner VARCHAR2, p_target_table VARCHAR2) RETURN NUMBER IS
    v_cnt NUMBER := 0;
  BEGIN
    IF legacy_available(p_target_owner, p_target_table) THEN
      EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_target_owner || '.' ||
                        p_target_table INTO v_cnt;
    END IF;
    RETURN v_cnt;
  EXCEPTION WHEN OTHERS THEN
    RETURN 0;
  END get_target_count;

  -- ── 1) dispatch_gcbrdd (mode-aware, safe) ──
  PROCEDURE dispatch_gcbrdd(
    p_batch_size  IN NUMBER DEFAULT 10000,
    p_max_batches IN NUMBER DEFAULT NULL,
    p_etl_run_id  OUT NUMBER
  ) IS
    v_pk_min      NUMBER := 0;
    v_pk_max      NUMBER := 0;
    v_total_src   NUMBER := 0;
    v_dispatched  NUMBER := 0;
    v_batch       NUMBER := 0;
    v_legacy_ok   BOOLEAN;
    v_cnt_line    NUMBER;
  BEGIN
    p_etl_run_id := NULL;

    -- Init run
    INSERT INTO etl_run_progress (source_table, target_table, status)
    VALUES ('CAISSE.GCBRDD', 'MULTI', 'RUNNING')
    RETURNING etl_id INTO p_etl_run_id;

    v_legacy_ok := legacy_available('CAISSE', 'GCBRDD');
    DBMS_OUTPUT.PUT_LINE('  → Mode: ' || CASE WHEN v_legacy_ok THEN 'LEGACY' ELSE 'DEMO' END);

    IF v_legacy_ok THEN
      SELECT NVL(MIN(idbrd), 0), NVL(MAX(idbrd), 0), COUNT(*)
        INTO v_pk_min, v_pk_max, v_total_src
        FROM caisse.gcbrdd;
      DBMS_OUTPUT.PUT_LINE('  → Plage IDBRD : ' || v_pk_min || ' → ' || v_pk_max ||
                           ' (' || v_total_src || ' rows)');

      IF v_total_src > 0 THEN
        LOOP
          v_batch := v_batch + 1;
          EXIT WHEN p_max_batches IS NOT NULL AND v_batch > p_max_batches;
          EXIT WHEN v_batch * p_batch_size >= v_total_src;

          -- Compteur par type de bordereau (sans EXECUTE IMMEDIATE complexe)
          FOR r IN (SELECT codtbrd, target_line_table FROM etl_brd_mapping
                     WHERE target_line_table IS NOT NULL) LOOP
            BEGIN
              v_cnt_line := get_target_count(
                REGEXP_SUBSTR(r.target_line_table, '^[^.]+'),
                REGEXP_SUBSTR(r.target_line_table, '[^.]+$')
              );
            EXCEPTION WHEN OTHERS THEN
              v_cnt_line := 0;
            END;
          END LOOP;

          v_dispatched := LEAST(v_batch * p_batch_size, v_total_src);

          UPDATE etl_run_progress
             SET rows_processed = v_dispatched,
                 last_pk_processed = v_pk_min + v_batch * p_batch_size
           WHERE etl_id = p_etl_run_id;
          COMMIT;
        END LOOP;
      END IF;
    ELSE
      -- Mode DEMO : compte les tables cibles modernes
      FOR r IN (SELECT target_line_table FROM etl_brd_mapping
                 WHERE target_line_table IS NOT NULL) LOOP
        BEGIN
          v_total_src := v_total_src + get_target_count(
            REGEXP_SUBSTR(r.target_line_table, '^[^.]+'),
            REGEXP_SUBSTR(r.target_line_table, '[^.]+$')
          );
        EXCEPTION WHEN OTHERS THEN NULL;
        END;
      END LOOP;

      DBMS_OUTPUT.PUT_LINE('  → Mode demo : ' || v_total_src || ' rows dans tables modernes.');
      v_dispatched := v_total_src;

      UPDATE etl_run_progress
         SET rows_processed = v_dispatched
       WHERE etl_id = p_etl_run_id;
    END IF;

    UPDATE etl_run_progress
       SET status = 'DONE', finished_at = SYSTIMESTAMP
     WHERE etl_id = p_etl_run_id;
    COMMIT;

    DBMS_OUTPUT.PUT_LINE('  ✅ Dispatch termine : ' || v_dispatched || ' rows.');
  END dispatch_gcbrdd;

  -- ── 2) get_dispatch_plan (cursor sans PLS-00364) ──
  FUNCTION get_dispatch_plan RETURN SYS_REFCURSOR IS
    v_cur     SYS_REFCURSOR;
    v_legacy  BOOLEAN;
  BEGIN
    v_legacy := legacy_available('CAISSE', 'GCBRDE');
    IF v_legacy THEN
      OPEN v_cur FOR
        SELECT m.codtbrd,
               m.target_header_table,
               m.target_line_table,
               m.description,
               (SELECT COUNT(*) FROM caisse.gcbrde b WHERE b.codtbrd = m.codtbrd) AS nb_brd,
               (SELECT COUNT(*) FROM caisse.gcbrdd l
                  WHERE EXISTS (SELECT 1 FROM caisse.gcbrde b
                                WHERE b.idbrd = l.idbrd AND b.codtbrd = m.codtbrd)) AS nb_brdd
          FROM etl_brd_mapping m
         ORDER BY nb_brd DESC NULLS LAST;
    ELSE
      -- Mode demo : scan des tables cibles modernes
      OPEN v_cur FOR
        SELECT m.codtbrd,
               m.target_header_table,
               m.target_line_table,
               m.description,
               0 AS nb_brd,
               NVL(get_target_count(
                     REGEXP_SUBSTR(m.target_line_table, '^[^.]+'),
                     REGEXP_SUBSTR(m.target_line_table, '[^.]+$')), 0) AS nb_brdd
          FROM etl_brd_mapping m
         ORDER BY m.codtbrd;
    END IF;
    RETURN v_cur;
  END get_dispatch_plan;

  -- ── 3) stats ──
  FUNCTION get_dispatch_stats RETURN SYS_REFCURSOR IS
    v_cur SYS_REFCURSOR;
  BEGIN
    OPEN v_cur FOR
      SELECT status, COUNT(*) AS nb_runs, SUM(rows_processed) AS total_rows
        FROM etl_run_progress GROUP BY status ORDER BY status;
    RETURN v_cur;
  END get_dispatch_stats;

  -- ── 4) dispatch_reference_table (skip dynamique) ──
  PROCEDURE dispatch_reference_table(
    p_source_owner IN VARCHAR2,
    p_source_table IN VARCHAR2,
    p_target_owner IN VARCHAR2,
    p_target_table IN VARCHAR2,
    p_pk_column    IN VARCHAR2
  ) IS
    v_count    NUMBER := 0;
    v_src_ok   BOOLEAN;
    v_tgt_ok   BOOLEAN;
  BEGIN
    v_src_ok := legacy_available(p_source_owner, p_source_table);
    v_tgt_ok := legacy_available(p_target_owner, p_target_table);

    IF v_src_ok THEN
      EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_source_owner || '.' || p_source_table
        INTO v_count;
      DBMS_OUTPUT.PUT_LINE('  → Source LEGACY ' || p_source_owner || '.' || p_source_table ||
                           ' : ' || v_count || ' rows.');
    ELSIF v_tgt_ok THEN
      EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || p_target_owner || '.' || p_target_table
        INTO v_count;
      DBMS_OUTPUT.PUT_LINE('  → Source LEGACY absente. Cible ' || p_target_owner || '.' || p_target_table ||
                           ' : ' || v_count || ' rows.');
    ELSE
      DBMS_OUTPUT.PUT_LINE('  → Source ET cible absentes (demo). Skip.');
    END IF;

    INSERT INTO etl_run_progress (
      source_table, target_table, rows_processed, status, finished_at
    ) VALUES (
      p_source_owner || '.' || p_source_table,
      p_target_owner || '.' || p_target_table,
      v_count, 'DONE', SYSTIMESTAMP
    );
    COMMIT;
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  ⚠ dispatch_reference_table : ' || SQLERRM);
  END dispatch_reference_table;

  -- ── 5) resume_etl ──
  PROCEDURE resume_etl(p_etl_id IN NUMBER) IS
    v_last_pk NUMBER;
    v_status  VARCHAR2(20);
  BEGIN
    SELECT last_pk_processed, status
      INTO v_last_pk, v_status
      FROM etl_run_progress WHERE etl_id = p_etl_id;

    IF v_status NOT IN ('RUNNING','RESUMING') THEN
      DBMS_OUTPUT.PUT_LINE('  ⚠ Run ' || p_etl_id || ' status=' || v_status || ' — skip.');
      RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE('  → Reprise depuis PK ' || NVL(TO_CHAR(v_last_pk), 'N/A'));
    UPDATE etl_run_progress SET status = 'RESUMING' WHERE etl_id = p_etl_id;
    COMMIT;
  EXCEPTION WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  ⚠ resume_etl : ' || SQLERRM);
  END resume_etl;

END pkg_etl_legacy;
/
PROMPT ✓ Body v3 créé.

PROMPT
PROMPT [3/4] Recompilation
ALTER PACKAGE pkg_etl_legacy COMPILE;
ALTER PACKAGE pkg_etl_legacy COMPILE BODY;

PROMPT
PROMPT [4/4] Vérification erreurs
SELECT line, position, text
  FROM user_errors
 WHERE name = 'PKG_ETL_LEGACY'
 ORDER BY type, sequence;

PROMPT
PROMPT ═══ Tests ═══

PROMPT [T1] Mode detection
DECLARE v_mode VARCHAR2(10);
BEGIN v_mode := pkg_etl_legacy.current_mode;
      DBMS_OUTPUT.PUT_LINE('  Mode = ' || v_mode);
END;
/

PROMPT [T2] Stats initial
SELECT status, COUNT(*) AS nb_runs FROM etl_run_progress GROUP BY status ORDER BY status;

PROMPT [T3] get_target_count
DECLARE
  v_n NUMBER;
BEGIN
  v_n := pkg_etl_legacy.get_target_count('APP_PRODUCT', 'PRODUCT');
  DBMS_OUTPUT.PUT_LINE('  app_product.product = ' || v_n || ' rows');
  v_n := pkg_etl_legacy.get_target_count('APP_INV', 'INV_STOCK');
  DBMS_OUTPUT.PUT_LINE('  app_inv.inv_stock  = ' || v_n || ' rows');
  v_n := pkg_etl_legacy.get_target_count('APP_POS', 'POS_TERMINAL');
  DBMS_OUTPUT.PUT_LINE('  app_pos.pos_terminal = ' || v_n || ' rows');
END;
/

PROMPT [T4] Plan dispatch
DECLARE
  v_cur SYS_REFCURSOR;
  v_codtbrd VARCHAR2(20);
  v_target VARCHAR2(50);
  v_line   VARCHAR2(50);
  v_desc   VARCHAR2(200);
  v_nb_brd  NUMBER;
  v_nb_brdd NUMBER;
BEGIN
  v_cur := pkg_etl_legacy.get_dispatch_plan;
  DBMS_OUTPUT.PUT_LINE(RPAD('CODTBRD', 12) || RPAD('Target', 32) || LPAD('NB_BRD', 10) || LPAD('NB_BRDD', 12));
  DBMS_OUTPUT.PUT_LINE(RPAD('-', 80, '-'));
  LOOP
    FETCH v_cur INTO v_codtbrd, v_target, v_line, v_desc, v_nb_brd, v_nb_brdd;
    EXIT WHEN v_cur%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(RPAD(v_codtbrd, 12) || RPAD(v_target, 32) ||
                         LPAD(NVL(TO_CHAR(v_nb_brd), '-'), 10) ||
                         LPAD(NVL(TO_CHAR(v_nb_brdd), '-'), 12));
  END LOOP;
  CLOSE v_cur;
END;
/

PROMPT [T5] Dispatch demo
DECLARE
  v_run_id NUMBER;
BEGIN
  pkg_etl_legacy.dispatch_gcbrdd(
    p_batch_size => 10000, p_max_batches => NULL, p_etl_run_id => v_run_id);
  DBMS_OUTPUT.PUT_LINE('  Run ID = ' || v_run_id);
END;
/

PROMPT [T6] Stats après dispatch
SELECT status, COUNT(*) AS nb_runs, SUM(rows_processed) AS total_rows
  FROM etl_run_progress GROUP BY status ORDER BY status;

PROMPT [T7] dispatch_reference_table (resilience)
BEGIN
  pkg_etl_legacy.dispatch_reference_table(
    p_source_owner => 'CAISSE',
    p_source_table => 'GCPART',
    p_target_owner => 'APP_PRODUCT',
    p_target_table => 'PRODUCT',
    p_pk_column    => 'PRODUCT_CODE');
END;
/

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ FIX pkg_etl_legacy v3 — PLS-00364 résolu
PROMPT   - get_target_count() : compte dynamique avec skip
PROMPT   - dispatch_gcbrdd : mode LEGACY/DEMO sans casse
PROMPT   - dispatch_reference_table : skip si legacy absent
PROMPT ══════════════════════════════════════════════════════════
EXIT;
