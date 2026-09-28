-- ============================================================
-- S08 : Seed app_cash — Codes mouvement
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED

CONNECT app_cash/AppCash#2026@localhost:1521/FREEPDB1

DELETE FROM cash_movement;
DELETE FROM cash_journal;
DELETE FROM cash_movement_type;
DELETE FROM cash_register;
COMMIT;

PROMPT [1] Types de mouvement (CAICODMVT réels)
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active) VALUES ('EXP', 'EXPENSES (Dépense)', 'D', TRUE);
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active) VALUES ('IN',  'OPENING BALANCE (Solde ouverture)', 'R', TRUE);
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active) VALUES ('PAY', 'PAYMENT (Paiement)', 'D', TRUE);
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active) VALUES ('RCC', 'RECEIVE FROM CREDIT CUSTOMER', 'R', TRUE);
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active) VALUES ('RCO', 'OTHER CASH RECEIVE', 'R', TRUE);
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active) VALUES ('RCS', 'RECEIVE FROM CASH SALES', 'R', TRUE);
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active) VALUES ('TRB', 'TRANSFER TO BANK', 'D', TRUE);
INSERT INTO cash_movement_type (movement_type_code, movement_type_name, direction, is_active) VALUES ('TRO', 'TRANSFER TO OFFICE', 'D', TRUE);

PROMPT [2] Caisse
INSERT INTO cash_register (register_code, register_name, manager_name, currency_code, journal_code, balance)
VALUES ('C01', 'Caisse principale PNR', 'Caissier 1', 'XAF', 'CAI', 0);
INSERT INTO cash_register (register_code, register_name, manager_name, currency_code, journal_code, balance)
VALUES ('C02', 'Caisse secondaire PNR', 'Caissier 2', 'XAF', 'CAI', 0);
INSERT INTO cash_register (register_code, register_name, manager_name, currency_code, journal_code, balance)
VALUES ('C03', 'Caisse BZV', 'Caissier 3', 'XAF', 'CAI', 0);

COMMIT;

PROMPT [3] Validation
SELECT 'MOUVEMENTS' AS tbl, COUNT(*) AS nb FROM cash_movement_type
UNION ALL SELECT 'CAISSES', COUNT(*) FROM cash_register;

PROMPT ✅ S08 terminé
EXIT;