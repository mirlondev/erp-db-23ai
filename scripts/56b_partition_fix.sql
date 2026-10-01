-- ============================================================
-- SCRIPT 56b : FIX des partitions créées par 56_partition_effectives
-- ============================================================
-- 3 bugs corrigés :
--   1. ticket_line_v2 FK vers ticket(ticket_id) — n'existe pas,
--      ticket a une PK composite (terminal_id, ticket_no)
--   2. gl_entry_line_v2 MAXVALUE + INTERVAL = incompatible (ORA-14761)
--   3. fn_partition_info colonne BYTES inexistante (BYTES dans dba_segments)
--
-- Stratégie : drop + recréer les _v2 + recompiler fn_partition_info
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

PROMPT ══════════════════════════════════════════════════════════
PROMPT   FIX partitions 56 — colonnes réelles, FK valides
PROMPT ══════════════════════════════════════════════════════════

-- ====================================================================
-- 1) app_sales.ticket_line_v2 — recréer SANS FK vers ticket (PK composite)
-- ====================================================================
CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [1/4] app_sales.ticket_line_v2 — drop+recreate SANS FK ticket
BEGIN
  FOR o IN (SELECT object_name FROM user_objects
             WHERE object_name IN ('TICKET_LINE_V2','PK_TICKET_LINE_V2')
               AND object_type IN ('TABLE','INDEX','VIEW','CONSTRAINT')) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP ' ||
        CASE (SELECT object_type FROM user_objects WHERE object_name = o.object_name AND ROWNUM = 1)
          WHEN 'INDEX' THEN 'INDEX'
          WHEN 'VIEW' THEN 'VIEW'
          ELSE 'TABLE'
        END || ' ' || o.object_name || ' CASCADE CONSTRAINTS';
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('  → ancien ticket_line_v2 droppé.');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ticket_line_v2 (
  ticket_line_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  terminal_id       VARCHAR2(12)  NOT NULL,                   -- PK composite de ticket
  ticket_no         NUMBER(8)     NOT NULL,                   -- PK composite de ticket
  line_no           NUMBER(4)     NOT NULL,
  product_code      VARCHAR2(80)  NOT NULL,
  quantity          NUMBER(16,4)  NOT NULL,
  unit_price        NUMBER(16,4),
  amount_ht         NUMBER(16,4),
  tax_rate          NUMBER(7,4),
  tax_amount        NUMBER(16,4),
  amount_ttc        NUMBER(16,4),
  promotion_id      NUMBER,
  site_code         VARCHAR2(10)  NOT NULL,                   -- partitionnement
  sale_date         DATE          NOT NULL,                   -- partitionnement
  created_at        TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_ticket_line_v2       PRIMARY KEY (ticket_line_id)
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

CREATE INDEX ix_ticket_line_v2_tk ON ticket_line_v2(terminal_id, ticket_no) LOCAL;
CREATE INDEX ix_ticket_line_v2_prod ON ticket_line_v2(product_code) LOCAL;
CREATE INDEX ix_ticket_line_v2_site ON ticket_line_v2(site_code, sale_date) LOCAL;

PROMPT ✓ ticket_line_v2 recréée sans FK ticket.

-- ====================================================================
-- 2) app_gl.gl_entry_line_v2 — recréer SANS INTERVAL (sinon MAXVALUE interdit)
-- ====================================================================
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [2/4] app_gl.gl_entry_line_v2 — drop+recreate sans INTERVAL
BEGIN
  FOR o IN (SELECT object_name FROM user_objects
             WHERE object_name = 'GL_ENTRY_LINE_V2'
               AND object_type IN ('TABLE','INDEX')) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE ' || o.object_name || ' CASCADE CONSTRAINTS';
    EXCEPTION WHEN OTHERS THEN NULL;
    END;
  END LOOP;
END;
/

CREATE TABLE gl_entry_line_v2 (
  entry_line_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  company_code      VARCHAR2(2)   NOT NULL,
  entity_code       VARCHAR2(3)   NOT NULL,
  entry_no          NUMBER(8)     NOT NULL,
  line_no           NUMBER(5)     NOT NULL,
  account_code      VARCHAR2(8)   NOT NULL,
  party_code        VARCHAR2(8),
  direction         VARCHAR2(1)   NOT NULL,                  -- D ou C
  company_debit     NUMBER(16,4)  DEFAULT 0,
  company_credit    NUMBER(16,4)  DEFAULT 0,
  fiscal_year       NUMBER(4)     NOT NULL,
  -- Partitioning
  posting_date      DATE          NOT NULL,
  CONSTRAINT pk_gl_entry_line_v2 PRIMARY KEY (entry_line_id),
  CONSTRAINT fk_gl_entry_line_v2_e FOREIGN KEY (company_code, entity_code, entry_no)
    REFERENCES gl_entry(company_code, entity_code, entry_no) ON DELETE CASCADE,
  CONSTRAINT ck_gl_entry_line_v2_a CHECK (direction IN ('D','C') AND
                                            NVL(company_debit,0) >= 0 AND NVL(company_credit,0) >= 0)
)
PARTITION BY RANGE (fiscal_year)
(
  PARTITION p_2022 VALUES LESS THAN (2023),
  PARTITION p_2023 VALUES LESS THAN (2024),
  PARTITION p_2024 VALUES LESS THAN (2025),
  PARTITION p_2025 VALUES LESS THAN (2026),
  PARTITION p_2026 VALUES LESS THAN (2027),
  PARTITION p_2027 VALUES LESS THAN (2028),
  PARTITION p_future VALUES LESS THAN (MAXVALUE)
);

CREATE INDEX ix_gl_entry_line_v2_e ON gl_entry_line_v2(company_code, entity_code, entry_no) LOCAL;
CREATE INDEX ix_gl_entry_line_v2_a ON gl_entry_line_v2(account_code, fiscal_year) LOCAL;

PROMPT ✓ gl_entry_line_v2 recréée (RANGE simple, MAXVALUE OK).

-- ====================================================================
-- 3) fn_partition_info — utiliser dba_segments pour BYTES
-- ====================================================================
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [3/4] fn_partition_info — recompile avec dba_segments
CREATE OR REPLACE FUNCTION fn_partition_info(
  p_owner VARCHAR2,
  p_table VARCHAR2
) RETURN SYS_REFCURSOR IS
  v_cur SYS_REFCURSOR;
BEGIN
  -- BYTES vient de dba_segments, PAS de all_tab_partitions
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
-- 4) Privilèges + tests
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
SELECT partition_name, num_rows
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
END;
/

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ FIX 56b — partitions recréées + fn_partition_info OK
PROMPT ══════════════════════════════════════════════════════════
EXIT;
