-- ============================================================
-- S06 : Seed app_gl — VERSION CORRIGÉE
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   SEED app_gl
PROMPT ===============================================================

DELETE FROM gl_entry_line;
DELETE FROM gl_entry;
DELETE FROM gl_period;
DELETE FROM gl_subaccount;
DELETE FROM gl_account;
DELETE FROM gl_journal;
DELETE FROM gl_company;
COMMIT;

PROMPT [1] Société comptable
INSERT INTO gl_company (company_code, legal_name, address, city, country, phone, tax_id, currency_code, has_customer_acct, has_supplier_acct)
VALUES ('01', 'STE SUPER SONIC', 'Avenue Charles de Gaulle', 'Pointe-Noire', 'Congo',
        '222 94 0270', 'M2005110000309073', 'XAF', TRUE, TRUE);

PROMPT [2] Journaux
INSERT INTO gl_journal (company_code, journal_code, journal_name, is_active, journal_type, nature, created_at, created_by)
VALUES ('01', 'VTE', 'Journal des ventes', TRUE, 'VEN', 'C', SYSDATE, 'ADMIN');
INSERT INTO gl_journal (company_code, journal_code, journal_name, is_active, journal_type, nature, created_at, created_by)
VALUES ('01', 'ACH', 'Journal des achats', TRUE, 'ACH', 'C', SYSDATE, 'ADMIN');
INSERT INTO gl_journal (company_code, journal_code, journal_name, is_active, journal_type, nature, created_at, created_by)
VALUES ('01', 'CAI', 'Journal de caisse', TRUE, 'TRE', 'C', SYSDATE, 'ADMIN');
INSERT INTO gl_journal (company_code, journal_code, journal_name, is_active, journal_type, nature, created_at, created_by)
VALUES ('01', 'BQE', 'Journal de banque', TRUE, 'TRE', 'C', SYSDATE, 'ADMIN');
INSERT INTO gl_journal (company_code, journal_code, journal_name, is_active, journal_type, nature, created_at, created_by)
VALUES ('01', 'OD',  'Operations diverses', TRUE, 'OD',  'C', SYSDATE, 'ADMIN');

PROMPT [3] Plan comptable (noms <= 50 caracteres, sans &)
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '000001', 'TAMPON OPENING BALANCE', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '000002', 'TAMPON ADJUSTMENT ACCOUNT', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '411111', 'CLIENTS DIVERS', TRUE, 'C', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '411270', 'STAR FOODS BEVERAGES PNR', TRUE, 'C', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '443110', 'TVA COLLECTEE', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '445220', 'TVA SUR ACHAT LOCAL', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '445410', 'TVA SERVICES EXTERIEURS', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '445420', 'TAXE SUR BOISSONS', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '521100', 'ESPECES ENCAISSEES', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '531100', 'CHEQUES RECUS', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '531200', 'VIREMENTS RECUS', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '585100', 'VIR FONDS BANQUE-CAISSE', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '585200', 'VIR FONDS CAISSE-CAISSE', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '701110', 'VENTES TVA', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '701120', 'VENTES HT', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '810010', 'ROUND OF (arrondi)', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');
INSERT INTO gl_account (company_code, account_code, account_name, is_active, account_type, manage_due_date, page_break, created_at, created_by)
VALUES ('01', '571110', 'CAISSE FONDS', TRUE, 'D', 'N', 'N', SYSDATE, 'ADMIN');

PROMPT [4] Périodes
INSERT INTO gl_period (company_code, period_code, start_date, end_date, is_active, is_closed, created_at, created_by)
VALUES ('01', '2025', DATE '2025-01-01', DATE '2025-12-31', TRUE, TRUE, SYSDATE, 'ADMIN');
INSERT INTO gl_period (company_code, period_code, start_date, end_date, is_active, is_closed, created_at, created_by)
VALUES ('01', '2026', DATE '2026-01-01', DATE '2026-12-31', TRUE, FALSE, SYSDATE, 'ADMIN');

PROMPT [5] Sous-comptes clients
INSERT INTO gl_subaccount (company_code, party_code, account_code, party_name, created_at, created_by)
VALUES ('01', 'SFP001', '411270', 'CLIENT DIVERS CASH', SYSDATE, 'ADMIN');
INSERT INTO gl_subaccount (company_code, party_code, account_code, party_name, created_at, created_by)
VALUES ('01', 'SFP002', '411270', 'CLIENT DIVERS CREDIT', SYSDATE, 'ADMIN');
INSERT INTO gl_subaccount (company_code, party_code, account_code, party_name, created_at, created_by)
VALUES ('01', 'SFP037', '411270', 'MAPAKOU MAJOLIE', SYSDATE, 'ADMIN');
INSERT INTO gl_subaccount (company_code, party_code, account_code, party_name, created_at, created_by)
VALUES ('01', 'CL0001', '411111', 'POS CASH ACCOUNT', SYSDATE, 'ADMIN');

COMMIT;

PROMPT [6] Validation
SELECT 'COMPANY'    AS tbl, COUNT(*) AS nb FROM gl_company
UNION ALL SELECT 'JOURNAL',   COUNT(*) FROM gl_journal
UNION ALL SELECT 'ACCOUNT',   COUNT(*) FROM gl_account
UNION ALL SELECT 'PERIOD',    COUNT(*) FROM gl_period
UNION ALL SELECT 'SUBACCOUNT',COUNT(*) FROM gl_subaccount;

PROMPT ✅ S06 terminé
EXIT;