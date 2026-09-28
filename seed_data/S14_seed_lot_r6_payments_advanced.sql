-- ============================================================
-- S14 : Seed LOT R6 (Règlements clients avancés)
-- Données de démo : référentiel modes paiement + 2 sessions de caisse
--                    + liens facture/paiement + relevé + balance âgée + relances.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_ar/AppAr#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R6 — Règlements clients avancés
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R6]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM dunning_log';
  EXECUTE IMMEDIATE 'DELETE FROM aging_balance';
  EXECUTE IMMEDIATE 'DELETE FROM customer_statement';
  EXECUTE IMMEDIATE 'DELETE FROM invoice_payment_link';
  EXECUTE IMMEDIATE 'DELETE FROM cash_register_session';
  EXECUTE IMMEDIATE 'DELETE FROM payment_method_ref';
  COMMIT;
END;
/


PROMPT [1] 7 modes de paiement
INSERT INTO payment_method_ref (method_code, method_name, method_type,
                                 journal_code, gl_account_code, is_active,
                                 requires_reference, max_amount, min_amount,
                                 commission_rate, display_order, icon_code)
VALUES ('CASH', 'Espèces', 'CASH', 'CSH', '530000', TRUE,
        FALSE, NULL, 0, 0, 10, 'cash');

INSERT INTO payment_method_ref (method_code, method_name, method_type,
                                 journal_code, gl_account_code, is_active,
                                 requires_reference, max_amount, commission_rate,
                                 display_order, icon_code)
VALUES ('CHECK', 'Chèque', 'CHECK', 'BNK', '511200', TRUE,
        TRUE, 5000000, 1.5, 20, 'check');

INSERT INTO payment_method_ref (method_code, method_name, method_type,
                                 journal_code, gl_account_code, is_active,
                                 requires_reference, max_amount, commission_rate,
                                 display_order, icon_code)
VALUES ('CARD', 'Carte bancaire', 'CARD', 'BNK', '511100', TRUE,
        TRUE, 10000000, 2.0, 30, 'card');

INSERT INTO payment_method_ref (method_code, method_name, method_type,
                                 journal_code, gl_account_code, is_active,
                                 requires_reference, max_amount, commission_rate,
                                 display_order, icon_code)
VALUES ('TRANSFER', 'Virement', 'TRANSFER', 'BNK', '521000', TRUE,
        TRUE, NULL, 0.5, 40, 'transfer');

INSERT INTO payment_method_ref (method_code, method_name, method_type,
                                 journal_code, gl_account_code, is_active,
                                 requires_reference, max_amount, commission_rate,
                                 display_order, icon_code)
VALUES ('MOBILE_OM', 'Orange Money', 'MOBILE', 'MOBILE_OM_ACC', '531100', TRUE,
        TRUE, 2000000, 1.0, 50, 'mobile_om');

INSERT INTO payment_method_ref (method_code, method_name, method_type,
                                 journal_code, gl_account_code, is_active,
                                 requires_reference, max_amount, commission_rate,
                                 display_order, icon_code)
VALUES ('MOBILE_MTN', 'MTN Mobile Money', 'MOBILE', 'MOBILE_MTN_ACC', '531200', TRUE,
        TRUE, 2000000, 1.0, 60, 'mobile_mtn');

INSERT INTO payment_method_ref (method_code, method_name, method_type,
                                 is_active, requires_reference, max_amount,
                                 commission_rate, display_order, icon_code)
VALUES ('OTHER', 'Autre', 'OTHER', TRUE,
        FALSE, NULL, 0, 999, 'other');


PROMPT [2] 3 sessions de caisse
INSERT INTO cash_register_session (register_code, session_number, opened_by, opened_at,
                                    closed_by, closed_at,
                                    opening_balance, closing_balance, theoretical_balance, difference,
                                    total_cash, total_card, total_check, total_transfer, total_mobile,
                                    nb_transactions, status, validated_by)
VALUES ('C01', 1, 'CAISSIER1', SYSDATE - 7,
        'CAISSIER1', SYSDATE - 7 + 8/24,
        50000, 234500, 234000, 500,
        184500, 0, 0, 0, 0,
        42, 'RECONCILED', 'ADMIN');

INSERT INTO cash_register_session (register_code, session_number, opened_by, opened_at,
                                    closed_by, closed_at,
                                    opening_balance, closing_balance, theoretical_balance, difference,
                                    total_cash, total_card, total_check, total_transfer, total_mobile, total_other,
                                    nb_transactions, status, memo)
VALUES ('C02', 1, 'CAISSIER2', SYSDATE - 2,
        'CAISSIER2', SYSDATE - 2 + 9/24,
        75000, 567800, 568500, -700,
        412300, 80000, 0, 0, 0, 500,
        68, 'CLOSED', 'Petit écart de caisse à investigar');

INSERT INTO cash_register_session (register_code, session_number, opened_by, opened_at,
                                    opening_balance, status)
VALUES ('C01', 2, 'CAISSIER1', SYSDATE,
        50000, 'OPEN');


PROMPT [3] Liens facture ↔ paiement (rappel : REG-001 couvre FA-001 ; REG-002 couvre FA-002 partiellement)
-- On insère ici pour le seed, les allocations étaient déjà en payment_allocation dans R5
INSERT INTO invoice_payment_link (invoice_id, payment_id, amount, linked_by, memo)
VALUES (1, 1, 5000, 'ADMIN', 'Règlement FA-001 par REG-001');

INSERT INTO invoice_payment_link (invoice_id, payment_id, amount, linked_by, memo)
VALUES (2, 2, 10000, 'ADMIN', 'Acompte sur FA-002 par virement');


PROMPT [4] 3 relevés client (statement)
INSERT INTO customer_statement (party_code, statement_date, period_start, period_end,
                                 opening_balance, total_debit, total_credit, closing_balance,
                                 nb_invoices, nb_payments, status, sent_at, sent_to, format, created_by)
VALUES ('CLI001', DATE '2026-09-30', DATE '2026-09-01', DATE '2026-09-30',
        0, 5000, 5000, 0, 1, 1, 'SENT', SYSDATE - 1, 'jdupont@example.com', 'PDF', 'ADMIN');

INSERT INTO customer_statement (party_code, statement_date, period_start, period_end,
                                 opening_balance, total_debit, total_credit, closing_balance,
                                 nb_invoices, nb_payments, status, sent_at, sent_to, format, created_by)
VALUES ('CLI002', DATE '2026-09-30', DATE '2026-09-01', DATE '2026-09-30',
        0, 15000, 15000, 0, 1, 2, 'SENT', SYSDATE - 1, 'smartin@example.com', 'PDF', 'ADMIN');

INSERT INTO customer_statement (party_code, statement_date, period_start, period_end,
                                 opening_balance, total_debit, total_credit, closing_balance,
                                 nb_invoices, status, format, created_by)
VALUES ('CLI003', DATE '2026-09-30', DATE '2026-09-01', DATE '2026-09-30',
        0, 25000, 0, 25000, 1, 'DRAFT', 'PDF', 'ADMIN');


PROMPT [5] Balance âgée (snapshot fin septembre)
INSERT INTO aging_balance (snapshot_date, party_code, company_code,
                            current_amount, days_1_30, days_31_60, days_over_90, total_due)
VALUES
  (DATE '2026-09-30', 'CLI001', 'COMP01', 0, 0, 0, 0, 0),          -- soldé
  (DATE '2026-09-30', 'CLI002', 'COMP01', 5000, 0, 0, 0, 5000),     -- 5000 dans 30j
  (DATE '2026-09-30', 'CLI003', 'COMP01', 0, 0, 25000, 0, 25000);   -- 25000 entre 31-60j


PROMPT [6] 4 relances pour CLI003 (sur la facture FA-2026-003 en retard)
INSERT INTO dunning_log (party_code, invoice_id, dunning_level, dunning_date,
                          amount_due, days_overdue, contact_method, contact_detail,
                          message, status, response_received_at, response_detail, created_by)
VALUES ('CLI003', 3, 1, SYSDATE - 25, 25000, 5,
        'EMAIL', 'durand@example.com',
        'Cher client, nous vous rappelons que la facture FA-2026-003...',
        'RESPONDED', SYSDATE - 23, 'Client promet de payer sous 15j', 'ADMIN');

INSERT INTO dunning_log (party_code, invoice_id, dunning_level, dunning_date,
                          amount_due, days_overdue, contact_method, contact_detail,
                          message, status, created_by)
VALUES ('CLI003', 3, 2, SYSDATE - 15, 25000, 15,
        'SMS', '+225 09 10 11 12',
        '2eme rappel : votre facture FA-2026-003 de 25000 XOF est en retard de 15j',
        'SENT', 'ADMIN');

INSERT INTO dunning_log (party_code, invoice_id, dunning_level, dunning_date,
                          amount_due, days_overdue, contact_method, contact_detail,
                          message, status, created_by)
VALUES ('CLI003', 3, 3, SYSDATE - 5, 25000, 25,
        'CALL', '+225 09 10 11 12',
        'Appel téléphonique - client injoignable, message laissé sur répondeur',
        'FAILED', 'ADMIN');

INSERT INTO dunning_log (party_code, invoice_id, dunning_level, dunning_date,
                          amount_due, days_overdue, contact_method, contact_detail,
                          message, status, created_by)
VALUES ('CLI003', 3, 2, SYSDATE - 1, 25000, 29,
        'LETTER', 'Abidjan Yopougon',
        'Lettre recommandée AR - mise en demeure avant contentieux',
        'PENDING', 'ADMIN');

COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'PAYMENT_METHOD_REF'       AS tbl, COUNT(*) AS nb FROM payment_method_ref
UNION ALL SELECT 'CASH_REGISTER_SESSION',  COUNT(*) FROM cash_register_session
UNION ALL SELECT 'INVOICE_PAYMENT_LINK',   COUNT(*) FROM invoice_payment_link
UNION ALL SELECT 'CUSTOMER_STATEMENT',     COUNT(*) FROM customer_statement
UNION ALL SELECT 'AGING_BALANCE',          COUNT(*) FROM aging_balance
UNION ALL SELECT 'DUNNING_LOG',            COUNT(*) FROM dunning_log
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Modes de paiement actifs par type
SELECT method_type, COUNT(*) AS nb, MAX(max_amount) AS plafond_max
  FROM payment_method_ref
 WHERE is_active = TRUE
 GROUP BY method_type
 ORDER BY method_type;

PROMPT [Q2] Sessions de caisse de la semaine
SELECT register_code, session_number, opened_at, closed_at,
       total_cash + NVL(total_card,0) + NVL(total_check,0)
         + NVL(total_transfer,0) + NVL(total_mobile,0) AS total_session,
       difference, status
  FROM cash_register_session
 ORDER BY opened_at DESC
 FETCH FIRST 5 ROWS ONLY;

PROMPT [Q3] Balance âgée actuelle (snapshot)
SELECT party_code, current_amount, days_1_30, days_31_60, days_over_90, total_due
  FROM aging_balance
 WHERE snapshot_date = DATE '2026-09-30'
 ORDER BY total_due DESC;

PROMPT [Q4] Toutes les relances actives
SELECT party_code, dunning_level, dunning_date, amount_due, days_overdue,
       contact_method, status
  FROM dunning_log
 ORDER BY party_code, dunning_level, dunning_date;

PROMPT [Q5] Prochaine étape de relance par client
SELECT party_code,
       MAX(dunning_level) AS niveau_max_atteint,
       MAX(dunning_date) AS derniere_relance,
       SUM(CASE WHEN status = 'PENDING' THEN 1 ELSE 0 END) AS en_attente,
       SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) AS echecs
  FROM dunning_log
 GROUP BY party_code
 ORDER BY party_code;

PROMPT [Q6] Sessions avec écart (à reconcilier)
SELECT register_code, session_number, opened_at, closed_at,
       difference, theoretical_balance, closing_balance
  FROM cash_register_session
 WHERE difference <> 0
 ORDER BY ABS(difference) DESC;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R6 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
