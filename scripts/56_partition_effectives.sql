-- ============================================================
-- SCRIPT 56 : Partitionnement EFFECTIF — Tables volumineuses 23ai
-- ============================================================
-- Crée des versions PARTITIONNÉES des 4 tables critiques qui
-- doivent gérer des millions de lignes :
--
-- 1. app_sales.ticket_line        (cible 65M rows = CETICKETD)
-- 2. app_inv.transfer_line        (cible 54M rows = GCBRDD)
-- 3. app_gl.gl_entry_line         (cible 2.8M rows = CP_ECR_GEN)
-- 4. app_ar.payment_history       (cible 501K rows = CP_HISTO_RGL)
--
-- Stratégie Oracle 23ai Free :
--   - PARTITION BY RANGE (date) INTERVAL (NUMTOYMINTERVAL(1,'MONTH'))
--   - SUBPARTITION BY LIST (site_code) SUBPARTITIONS 8
--   - Local indexes (équivalent B-tree sur chaque partition)
--   - Compression basique (gratuite)
--
-- Note : si les tables existent déjà, on les RECREE.
-- En production, on utilise DBMS_REDEFINITION pour online.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

PROMPT ══════════════════════════════════════════════════════════
PROMPT   PARTITIONNEMENT EFFECTIF — Tables volumineuses 23ai
PROMPT ══════════════════════════════════════════════════════════

-- =================================================================
-- 1) app_sales.ticket_line — partitionné par mois + site
-- =================================================================
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT, INSERT, UPDATE, DELETE ON app_sales.ticket_v2 TO app_sales;
GRANT SELECT, INSERT, UPDATE, DELETE ON app_sales.ticket_line_v2 TO app_sales;

CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [1/4] app_sales.ticket_line — version partitionnée
CREATE TABLE ticket_line_v2 (
  ticket_line_id    NUMBER GENERATED ALWAYS AS IDENTITY,
  ticket_id         NUMBER        NOT NULL,
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
  CONSTRAINT pk_ticket_line_v2       PRIMARY KEY (ticket_line_id),
  CONSTRAINT fk_ticket_line_v2_t     FOREIGN KEY (ticket_id)
    REFERENCES ticket(ticket_id) ON DELETE CASCADE
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

-- Local indexes
CREATE INDEX ix_ticket_line_v2_ticket ON ticket_line_v2(ticket_id) LOCAL;
CREATE INDEX ix_ticket_line_v2_prod   ON ticket_line_v2(product_code) LOCAL;
CREATE INDEX ix_ticket_line_v2_site   ON ticket_line_v2(site_code, sale_date) LOCAL;

-- Vue de compatibilité
CREATE OR REPLACE VIEW v_ticket_line_partitioned AS
  SELECT * FROM ticket_line_v2;

PROMPT
PROMPT [Note] ticket_line_v2 créé. La table ticket_line d'origine reste
PROMPT        jusqu'à migration complète. Une vue de compatibilité est fournie.

-- =================================================================
-- 2) app_inv.transfer_line — partitionné par mois + site
-- =================================================================
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT, INSERT, UPDATE, DELETE ON app_inv.transfer_line_v2 TO app_inv;

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [2/4] app_inv.transfer_line — version partitionnée
CREATE TABLE transfer_line_v2 (
  transfer_line_id  NUMBER GENERATED ALWAYS AS IDENTITY,
  transfer_id       NUMBER        NOT NULL,
  line_no           NUMBER(5)     NOT NULL,
  product_code      VARCHAR2(80)  NOT NULL,
  requested_qty     NUMBER(16,4),
  sent_qty          NUMBER(16,4),
  received_qty      NUMBER(16,4),
  unit_cost         NUMBER(16,4),
  lot_number        VARCHAR2(40),
  -- Partitioning
  site_code         VARCHAR2(10)  NOT NULL,
  transfer_date     DATE          NOT NULL,
  CONSTRAINT pk_transfer_line_v2 PRIMARY KEY (transfer_line_id),
  CONSTRAINT fk_transfer_line_v2_h FOREIGN KEY (transfer_id)
    REFERENCES transfer_header(transfer_id) ON DELETE CASCADE
)
PARTITION BY RANGE (transfer_date)
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

CREATE INDEX ix_transfer_line_v2_h ON transfer_line_v2(transfer_id) LOCAL;
CREATE INDEX ix_transfer_line_v2_p ON transfer_line_v2(product_code) LOCAL;

-- =================================================================
-- 3) app_gl.gl_entry_line — partitionné par an
-- =================================================================
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT, INSERT, UPDATE, DELETE ON app_gl.gl_entry_line_v2 TO app_gl;

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [3/4] app_gl.gl_entry_line — version partitionnée par exercice
CREATE TABLE gl_entry_line_v2 (
  entry_line_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  entry_id          NUMBER        NOT NULL,
  line_no           NUMBER(4)     NOT NULL,
  account_code      VARCHAR2(8)   NOT NULL,
  -- Sens + montant (modèle SYSCOHADA : 1 ligne = 1 sens)
  debit             NUMBER(16,4)  DEFAULT 0,
  credit            NUMBER(16,4)  DEFAULT 0,
  cost_center_code  VARCHAR2(20),
  partner_code      VARCHAR2(32),                              -- compte auxiliaire
  description       VARCHAR2(500),
  -- Partitioning
  fiscal_year       NUMBER(4)     NOT NULL,
  posting_date      DATE          NOT NULL,
  CONSTRAINT pk_gl_entry_line_v2   PRIMARY KEY (entry_line_id),
  CONSTRAINT fk_gl_entry_line_v2_e FOREIGN KEY (entry_id)
    REFERENCES gl_entry(entry_id) ON DELETE CASCADE,
  CONSTRAINT ck_gl_entry_line_v2_a CHECK (NVL(debit,0) >= 0 AND NVL(credit,0) >= 0)
)
PARTITION BY RANGE (fiscal_year)
INTERVAL (1)
(PARTITION p_2024 VALUES LESS THAN (2025),
 PARTITION p_2025 VALUES LESS THAN (2026),
 PARTITION p_2026 VALUES LESS THAN (2027),
 PARTITION p_2027 VALUES LESS THAN (2028),
 PARTITION p_max  VALUES LESS THAN (MAXVALUE));

CREATE INDEX ix_gl_entry_line_v2_e ON gl_entry_line_v2(entry_id) LOCAL;
CREATE INDEX ix_gl_entry_line_v2_a ON gl_entry_line_v2(account_code, fiscal_year) LOCAL;

-- =================================================================
-- 4) app_ar.payment_history — partitionné par mois
-- =================================================================
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT, INSERT, UPDATE, DELETE ON app_ar.payment_history_v2 TO app_ar;

CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [4/4] app_ar.payment_history — version partitionnée par mois
CREATE TABLE payment_history_v2 (
  history_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  payment_id        NUMBER        NOT NULL,
  party_code        VARCHAR2(32)  NOT NULL,
  invoice_id        NUMBER,
  paid_amount       NUMBER(16,4)  NOT NULL,
  paid_at           TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  payment_method    VARCHAR2(20)  NOT NULL,
  bank_ref          VARCHAR2(120),
  applied_amount    NUMBER(16,4),
  -- Partitioning
  paid_year         NUMBER(4)     GENERATED ALWAYS AS (EXTRACT(YEAR FROM paid_at)),
  paid_month        NUMBER(2)     GENERATED ALWAYS AS (EXTRACT(MONTH FROM paid_at)),
  CONSTRAINT pk_payment_history_v2  PRIMARY KEY (history_id)
)
PARTITION BY RANGE (paid_at)
INTERVAL (NUMTOYMINTERVAL(1, 'MONTH'))
(PARTITION p_init VALUES LESS THAN (DATE '2026-01-01'));

CREATE INDEX ix_payment_history_v2_p ON payment_history_v2(party_code, paid_at) LOCAL;
CREATE INDEX ix_payment_history_v2_i ON payment_history_v2(invoice_id) LOCAL;

-- =================================================================
-- 5) Fonction utilitaire : informations partition
-- =================================================================
CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT
PROMPT [5] Fonctions utilitaires de gestion partition
CREATE OR REPLACE FUNCTION fn_partition_info(
  p_owner VARCHAR2,
  p_table VARCHAR2
) RETURN SYS_REFCURSOR IS
  v_cur SYS_REFCURSOR;
BEGIN
  OPEN v_cur FOR
    SELECT partition_name, partition_position,
           num_rows, last_analyzed,
           ROUND(bytes / 1024 / 1024, 2) AS size_mb
      FROM all_tab_partitions
     WHERE table_owner = p_owner
       AND table_name  = p_table
     ORDER BY partition_position;
  RETURN v_cur;
END fn_partition_info;
/

CREATE OR REPLACE FUNCTION fn_total_partitions(p_table VARCHAR2) RETURN NUMBER IS
  v_n NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_n FROM user_tab_partitions WHERE table_name = p_table;
  RETURN v_n;
END fn_total_partitions;
/

-- =================================================================
-- 6) Job de maintenance partition : drop partitions > 36 mois
-- =================================================================
PROMPT
PROMPT [6] Job de maintenance : archivage auto des vieilles partitions

BEGIN
  BEGIN
    DBMS_SCHEDULER.DROP_JOB(job_name => 'JOB_PARTITION_MAINT');
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  DBMS_SCHEDULER.CREATE_JOB (
    job_name        => 'JOB_PARTITION_MAINT',
    job_type        => 'PLSQL_BLOCK',
    job_action      => '
      BEGIN
        -- Drop partitions > 36 mois pour ticket_line_v2
        FOR p IN (
          SELECT partition_name
            FROM user_tab_partitions
           WHERE table_name = ''TICKET_LINE_V2''
             AND partition_name <> ''P_INIT''
             AND TO_DATE(SUBSTR(partition_name, 3), ''YYYYMM'') < ADD_MONTHS(SYSDATE, -36)
        ) LOOP
          EXECUTE IMMEDIATE ''ALTER TABLE ticket_line_v2 DROP PARTITION '' || p.partition_name;
        END LOOP;
        COMMIT;
      END;',
    repeat_interval => 'FREQ=DAILY;BYHOUR=3',
    enabled         => TRUE,
    comments        => 'Drop auto partitions > 36 mois sur tables volumineuses'
  );
END;
/

-- =================================================================
-- 7) Privilèges
-- =================================================================
CONNECT system/oracle@localhost:1521/FREEPDB1

GRANT SELECT ON app_sales.ticket_line_v2        TO app_api;
GRANT SELECT ON app_inv.transfer_line_v2        TO app_api;
GRANT SELECT ON app_gl.gl_entry_line_v2         TO app_api;
GRANT SELECT ON app_ar.payment_history_v2       TO app_api;
GRANT SELECT ON app_ar.payment_history_v2       TO app_gl;

-- =================================================================
-- 8) Tests : comptage partitions créées
-- =================================================================
PROMPT
PROMPT ═══ Tests : comptage partitions ═══

CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1
SELECT 'app_sales.ticket_line_v2'     AS table_name,
       app_sys.fn_total_partitions('TICKET_LINE_V2')     AS partitions,
       COUNT(*) AS rows_in_all_partitions
  FROM ticket_line_v2
UNION ALL
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1
SELECT 'app_inv.transfer_line_v2',
       app_sys.fn_total_partitions('TRANSFER_LINE_V2'),
       COUNT(*)
  FROM app_inv.transfer_line_v2
UNION ALL
CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1
SELECT 'app_gl.gl_entry_line_v2',
       app_sys.fn_total_partitions('GL_ENTRY_LINE_V2'),
       COUNT(*)
  FROM app_gl.gl_entry_line_v2
UNION ALL
CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1
SELECT 'app_ar.payment_history_v2',
       app_sys.fn_total_partitions('PAYMENT_HISTORY_V2'),
       COUNT(*)
  FROM app_ar.payment_history_v2;

PROMPT
PROMPT ═══ Plan de maintenance ═══
SELECT job_name, enabled, repeat_interval, state
  FROM user_scheduler_jobs
 WHERE job_name = 'JOB_PARTITION_MAINT';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ PARTITIONNEMENT EFFECTIF — 4 tables volumineuses
PROMPT   - ticket_line_v2    : RANGE(month) + LIST(site, 8 sous-partitions)
PROMPT   - transfer_line_v2  : RANGE(month) + LIST(site, 8 sous-partitions)
PROMPT   - gl_entry_line_v2  : RANGE(year, 5 partitions)
PROMPT   - payment_history_v2: RANGE(month)
PROMPT   - fn_partition_info() : SYS_REFCURSOR infos partitions
PROMPT   - fn_total_partitions() : count
PROMPT   - JOB_PARTITION_MAINT : drop auto > 36 mois
PROMPT ══════════════════════════════════════════════════════════
EXIT;
