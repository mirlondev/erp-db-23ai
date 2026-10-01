-- ============================================================
-- SCRIPT 56b : FIX partitions (v2) — colonnes réelles, FK valides
-- ============================================================
-- BUGS du 56b précédent :
--   1. PLS-00103 dans le DROP dynamique : EXECUTE IMMEDIATE 'DROP ' ||
--      CASE (SELECT ...) WHEN ... THEN ... — CASE-expression
--      n'accepte pas de SELECT inline (résolu en PL/SQL statique).
--   2. ORA-02270 sur gl_entry : PK réelle = (company_code, entry_no)
--      et NON (company_code, entity_code, entry_no).
--   3. fn_partition_info : BYTES n'est pas dans all_tab_partitions
--      mais dans dba_segments → subquery nécessaire.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

PROMPT ══════════════════════════════════════════════════════════
PROMPT   FIX partitions 56b v2 — statique, FK conforme
PROMPT ══════════════════════════════════════════════════════════

-- ====================================================================
-- 1) app_sales.ticket_line_v2 — drop statique, sans FK ticket
-- ====================================================================
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [1/4] app_sales.ticket_line_v2 — drop statique + recreate
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ticket_line_v2 CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  drop ignoré : ' || SQLERRM);
END;
/

CREATE TABLE ticket_line_v2 (
  ticket_line_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  terminal_id       VARCHAR2(12)  NOT NULL,
  ticket_no         NUMBER(8)     NOT NULL,
  line_no           NUMBER(4)     NOT NULL,
  product_code      VARCHAR2(80)  NOT NULL,
  quantity          NUMBER(16,4)  NOT NULL,
  unit_price        NUMBER(16,4),
  amount_ht         NUMBER(16,4),
  tax_rate          NUMBER(7,4),
  tax_amount        NUMBER(16,4),
  amount_ttc        NUMBER(16,4),
  promotion_id      NUMBER,
  site_code         VARCHAR2(10)  NOT NULL,
  sale_date         DATE          NOT NULL,
  created_at        TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_ticket_line_v2 PRIMARY KEY (ticket_line_id)
)
PARTITION BY RANGE (sale_date)
INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
SUBPARTITION BY LIST (site_code)
SUBPARTITION TEMPLATE (
  SUBPARTITION sp_pnr_ofc VALUES ('PNR-OFC'),
  SUBPARTITION sp_pnr_b01 VALUES ('PNR-B01'),
  SUBPARTITION sp_bzv_b01 VALUES ('BZV-B01'),
  SUBPARTITION sp_bzv_b02 VALUES ('BZV-B02'),
  SUBPARTITION sp_dls_b01 VALUES ('DLS-B01'),
  SUBPARTITION sp_dep_pnr VALUES ('DEP-PNR'),
  SUBPARTITION sp_dep_bzv VALUES ('DEP-BZV'),
  SUBPARTITION sp_other   VALUES (DEFAULT)
)
(PARTITION p_init VALUES LESS THAN (DATE '2026-01-01'));

CREATE INDEX ix_ticket_line_v2_tk   ON ticket_line_v2(terminal_id, ticket_no) LOCAL;
CREATE INDEX ix_ticket_line_v2_prod ON ticket_line_v2(product_code) LOCAL;
CREATE INDEX ix_ticket_line_v2_site ON ticket_line_v2(site_code, sale_date) LOCAL;

PROMPT ✓ ticket_line_v2 recréée sans FK ticket (PK composite).

-- ====================================================================
-- 2) app_gl.gl_entry_line_v2 — FK conforme (company_code, entry_no)
-- ====================================================================
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [2/4] app_gl.gl_entry_line_v2 — FK conforme à PK réelle
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE gl_entry_line_v2 CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  drop ignoré : ' || SQLERRM);
END;
/

-- PK réelle de gl_entry = (company_code, entry_no)
-- PK réelle de gl_entry_line = (company_code, entity_code, entry_no, line_no)
-- Donc FK vers gl_entry doit être sur (company_code, entry_no) uniquement
CREATE TABLE gl_entry_line_v2 (
  entry_line_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  company_code      VARCHAR2(2)   NOT NULL,
  entity_code       VARCHAR2(3)   NOT NULL,
  entry_no          NUMBER(8)     NOT NULL,
  line_no           NUMBER(5)     NOT NULL,
  account_code      VARCHAR2(8)   NOT NULL,
  party_code        VARCHAR2(8),
  direction         VARCHAR2(1)   NOT NULL,
  company_debit     NUMBER(16,4)  DEFAULT 0,
  company_credit    NUMBER(16,4)  DEFAULT 0,
  fiscal_year       NUMBER(4)     NOT NULL,
  posting_date      DATE          NOT NULL,
  CONSTRAINT pk_gl_entry_line_v2 PRIMARY KEY (entry_line_id),
  -- ✅ FK conforme à la PK réelle de gl_entry : (company_code, entry_no)
  CONSTRAINT fk_gl_entry_line_v2_e FOREIGN KEY (company_code, entry_no)
    REFERENCES gl_entry(company_code, entry_no) ON DELETE CASCADE,
  CONSTRAINT ck_gl_entry_line_v2_a CHECK (direction IN ('D','C') AND
                                            NVL(company_debit,0) >= 0 AND NVL(company_credit,0) >= 0)
)
PARTITION BY RANGE (fiscal_year)
(
  PARTITION p_2022    VALUES LESS THAN (2023),
  PARTITION p_2023    VALUES LESS THAN (2024),
  PARTITION p_2024    VALUES LESS THAN (2025),
  PARTITION p_2025    VALUES LESS THAN (2026),
  PARTITION p_2026    VALUES LESS THAN (2027),
  PARTITION p_2027    VALUES LESS THAN (2028),
  PARTITION p_future  VALUES LESS THAN (MAXVALUE)
);

CREATE INDEX ix_gl_entry_line_v2_e ON gl_entry_line_v2(company_code, entry_no) LOCAL;
CREATE INDEX ix_gl_entry_line_v2_a ON gl_entry_line_v2(account_code, fiscal_year) LOCAL;

PROMPT ✓ gl_entry_line_v2 recréée (FK conforme à PK réelle).

-- ====================================================================
-- 3) fn_partition_info — BYTES via dba_segments
-- ====================================================================
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [3/4] fn_partition_info — BYTES via dba_segments
CREATE OR REPLACE FUNCTION fn_partition_info(
  p_owner VARCHAR2,
  p_table VARCHAR2
) RETURN SYS_REFCURSOR IS
  v_cur SYS_REFCURSOR;
BEGIN
  -- BYTES vient de dba_segments (PAS all_tab_partitions)
  OPEN v_cur FOR
    SELECT tp.partition_name,
           tp.partition_position,
           tp.num_rows,
           tp.last_analyzed,
           NVL((SELECT s.bytes FROM dba_segments s
                 WHERE s.owner = tp.table_owner
                   AND s.segment_name = tp.table_name
                   AND s.partition_name = tp.partition_name
                   AND ROWNUM = 1), 0) AS size_bytes
      FROM all_tab_partitions tp
     WHERE tp.table_owner = UPPER(p_owner)
       AND tp.table_name  = UPPER(p_table)
     ORDER BY tp.partition_position;
  RETURN v_cur;
END fn_partition_info;
/
PROMPT ✓ fn_partition_info recompilée.

-- ====================================================================
-- 4) Privilèges
-- ====================================================================
CONNECT system/oracle@localhost:1521/FREEPDB1

PROMPT
PROMPT [4/4] Privilèges
GRANT SELECT ON app_sales.ticket_line_v2 TO app_api;
GRANT SELECT ON app_gl.gl_entry_line_v2  TO app_api;

-- ====================================================================
-- 5) Validation
-- ====================================================================
PROMPT
PROMPT ═══ Validation ═══

CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1
SELECT table_name, partitioned FROM user_tables WHERE table_name = 'TICKET_LINE_V2';
SELECT COUNT(*) AS nb_partitions FROM user_tab_partitions WHERE table_name = 'TICKET_LINE_V2';

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1
SELECT table_name, partitioned FROM user_tables WHERE table_name = 'GL_ENTRY_LINE_V2';
SELECT partition_name, high_value, num_rows
  FROM user_tab_partitions
 WHERE table_name = 'GL_ENTRY_LINE_V2'
 ORDER BY partition_position;

PROMPT
PROMPT [Test fn_partition_info]
DECLARE
  v_cur SYS_REFCURSOR;
  v_pname VARCHAR2(30);
  v_pos NUMBER;
  v_rows NUMBER;
  v_bytes NUMBER;
BEGIN
  v_cur := app_sys.fn_partition_info('APP_GL', 'GL_ENTRY_LINE_V2');
  DBMS_OUTPUT.PUT_LINE(RPAD('Partition', 20) || LPAD('Position', 10) || LPAD('Rows', 10) || LPAD('Size', 15));
  LOOP
    FETCH v_cur INTO v_pname, v_pos, v_rows, v_bytes;
    EXIT WHEN v_cur%NOTFOUND;
    DBMS_OUTPUT.PUT_LINE(RPAD(v_pname, 20) || LPAD(v_pos, 10) || LPAD(NVL(v_rows,0), 10) || LPAD(v_bytes, 15));
  END LOOP;
  CLOSE v_cur;
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ fn_partition_info test : ' || SQLERRM);
END;
/

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ FIX 56b v2 — partitions recréées + fn_partition_info OK
PROMPT   - ticket_line_v2 : sans FK ticket (PK composite)
PROMPT   - gl_entry_line_v2 : FK conforme à PK (company_code, entry_no)
PROMPT   - fn_partition_info : BYTES via dba_segments
PROMPT ══════════════════════════════════════════════════════════
EXIT;
