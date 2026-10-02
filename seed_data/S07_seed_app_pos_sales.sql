-- ============================================================
-- S07 : Seed app_pos + app_sales
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_pos/AppPos#2026@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   SEED app_pos
PROMPT ===============================================================

DELETE FROM pos_cash_movement;
DELETE FROM pos_session;
DELETE FROM pos_terminal;
COMMIT;

PROMPT [1] Caisses (extraits CEPPAR)
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key, warehouse_code, price_list_code, pos_code)
VALUES ('FP1', 'Caisse FP1', 'XAF', 'POS_ACCESS', 'W90', '1', 'SSP');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key, warehouse_code, price_list_code, pos_code)
VALUES ('B01', 'Caisse B01', 'XAF', 'POS_ACCESS', 'W90', '1', 'PP2');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key, warehouse_code, price_list_code, pos_code)
VALUES ('C01', 'Caisse C01', 'XAF', 'POS_ACCESS', 'W90', '1', 'RDP');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key, warehouse_code, price_list_code, pos_code)
VALUES ('RM1', 'Caisse RM1', 'XAF', 'POS_ACCESS', 'W90', '1', 'RMN');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key, warehouse_code, price_list_code, pos_code)
VALUES ('MK1', 'Caisse MK1', 'XAF', 'POS_ACCESS', 'W90', '1', 'MKL');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key, warehouse_code, price_list_code, pos_code)
VALUES ('SB1', 'Caisse SB1', 'XAF', 'POS_ACCESS', 'W90', '1', 'SSB');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key, warehouse_code, price_list_code, pos_code)
VALUES ('CF1', 'Caisse CF1', 'XAF', 'POS_ACCESS', 'W90', '1', 'CBF');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key, warehouse_code, price_list_code, pos_code)
VALUES ('PS1', 'Caisse PS1', 'XAF', 'POS_ACCESS', 'W90', '1', 'SSP');
INSERT INTO pos_terminal (terminal_code, terminal_name, currency_code, access_key, warehouse_code, price_list_code, pos_code)
VALUES ('PZ1', 'Caisse PZ1', 'XAF', 'POS_ACCESS', 'W90', '1', 'RPB');

PROMPT [2] Sessions
INSERT INTO pos_session (terminal_id, session_no, user_code, opened_at, closed_at, opening_balance, closing_balance)
SELECT terminal_id, 626, 'VIJJU', DATE '2026-04-18', DATE '2026-04-18', 0, 0
  FROM pos_terminal WHERE terminal_code = 'FP1';

PROMPT [3] Validation
SELECT 'TERMINAL' AS tbl, COUNT(*) AS nb FROM pos_terminal
UNION ALL SELECT 'SESSION', COUNT(*) FROM pos_session;

PROMPT ✅ S07a terminé
EXIT;