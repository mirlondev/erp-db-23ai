-- ============================================================
-- S18 : Seed LOT R10 (Cartes cadeaux / Bons d'achat)
-- Données de démo : 4 types, 2 lots, 5 bons, 8 transactions,
--                    6 entrées d'audit (CREATE + USE + RELOAD + EXPIRE).
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_party/AppParty#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R10 — Cartes cadeaux / Bons d'achat
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R10]
BEGIN
  -- Respecter l'ordre FK : audit → transaction → master → lot → type
  EXECUTE IMMEDIATE 'DELETE FROM voucher_audit';
  EXECUTE IMMEDIATE 'DELETE FROM voucher_transaction';
  EXECUTE IMMEDIATE 'DELETE FROM voucher_master';
  EXECUTE IMMEDIATE 'DELETE FROM voucher_lot';
  EXECUTE IMMEDIATE 'DELETE FROM voucher_type';
  COMMIT;
END;
/

PROMPT [1] 4 types de bons
INSERT INTO voucher_type (voucher_type_code, voucher_type_name, is_reusable, valid_months,
                           min_value, max_value, can_be_combined, is_active, memo)
VALUES ('GIFT', 'Carte cadeau', FALSE, 12, 1000, 500000, FALSE, TRUE,
        'Carte cadeau standard, non rechargeable, 12 mois');

INSERT INTO voucher_type (voucher_type_code, voucher_type_name, is_reusable, valid_months,
                           min_value, max_value, can_be_combined, is_active, memo)
VALUES ('PROMO', 'Bon promotionnel', FALSE, 3, 1000, 50000, TRUE, TRUE,
        'Bon émis lors d''une promo, cumulable, 3 mois');

INSERT INTO voucher_type (voucher_type_code, voucher_type_name, is_reusable, valid_months,
                           min_value, max_value, can_be_combined, is_active, memo)
VALUES ('RETURN', 'Avoir retour', FALSE, 6, 100, 1000000, TRUE, TRUE,
        'Avoir émis lors d''un retour, 6 mois');

INSERT INTO voucher_type (voucher_type_code, voucher_type_name, is_reusable, valid_months,
                           min_value, max_value, can_be_combined, is_active, memo)
VALUES ('PREPAID', 'Carte prépayée rechargeable', TRUE, 24, 5000, NULL, TRUE, TRUE,
        'Carte rechargeable type TravelCard, 24 mois, pas de plafond max');


PROMPT [2] 2 lots d'émission
INSERT INTO voucher_lot (lot_number, voucher_type_code, lot_name,
                          initial_value, quantity, issued_qty,
                          issue_date, expiry_date, created_by)
VALUES (1001, 'GIFT', 'Cartes cadeaux Noël 2026',
        10000, 100, 5, DATE '2026-09-01', DATE '2027-09-01', 'ADMIN');

INSERT INTO voucher_lot (lot_number, voucher_type_code, lot_name,
                          initial_value, quantity, issued_qty, used_qty,
                          issue_date, expiry_date, created_by)
VALUES (1002, 'RETURN', 'Avoirs septembre',
        5000, 50, 2, 1,
        DATE '2026-09-15', DATE '2027-03-15', 'ADMIN');


PROMPT [3] 5 bons (4 gift cards + 1 avoir)
INSERT INTO voucher_master (voucher_number, voucher_lot_no, voucher_type_code,
                             issue_channel, issue_date,
                             initial_value, current_value,
                             beneficiary_code, beneficiary_name, beneficiary_label,
                             issue_status, printed_at, printed_by,
                             issued_by, expiry_date)
VALUES ('VC-2026-000001', 1001, 'GIFT', 'ST', DATE '2026-09-15',
        10000, 10000, NULL, NULL, 'Pour Marie - Bon anniversaire',
        'AC', DATE '2026-09-15', 'CAISSIER1',
        'CAISSIER1', DATE '2027-09-15');

INSERT INTO voucher_master (voucher_number, voucher_lot_no, voucher_type_code,
                             issue_channel, issue_date,
                             initial_value, current_value,
                             beneficiary_code, beneficiary_name, beneficiary_label,
                             issue_status, printed_at, printed_by,
                             issued_by, expiry_date)
VALUES ('VC-2026-000002', 1001, 'GIFT', 'WE', DATE '2026-09-20',
        25000, 25000, 'CLI002', 'Client Martin', 'Carte cadeau web',
        'AC', DATE '2026-09-20', 'SITE_WEB',
        'WEBHOOK', DATE '2027-09-20');

INSERT INTO voucher_master (voucher_number, voucher_lot_no, voucher_type_code,
                             issue_channel, issue_date,
                             initial_value, current_value,
                             beneficiary_label, issue_status,
                             consumed_at, consumed_ticket_no, consumed_terminal_code,
                             issued_by, expiry_date)
VALUES ('VC-2026-000003', 1001, 'GIFT', 'ST', DATE '2026-09-22',
        5000, 0, 'Cadeau client occasionnel',
        'US', SYSDATE - 5, 1, 'CAI01',
        'CAISSIER1', DATE '2027-09-22');

INSERT INTO voucher_master (voucher_number, voucher_lot_no, voucher_type_code,
                             issue_channel, issue_date,
                             initial_value, current_value,
                             beneficiary_label, issue_status,
                             issued_by, expiry_date)
VALUES ('VC-2026-000004', 1001, 'GIFT', 'MO', DATE '2026-09-25',
        15000, 15000, 'Application mobile',
        'PR', 'CAISSIER2', DATE '2027-09-25');

INSERT INTO voucher_master (voucher_number, voucher_lot_no, voucher_type_code,
                             issue_channel, issue_date,
                             initial_value, current_value,
                             beneficiary_code, beneficiary_name, beneficiary_label,
                             issue_status, consumed_at, consumed_ticket_no, consumed_terminal_code,
                             consumed_invoice_id,
                             issued_by, expiry_date)
VALUES ('AV-2026-000001', 1002, 'RETURN', 'ST', DATE '2026-09-25',
        2500, 0, 'CLI001', 'Client Dupont', 'Avoir suite retour RET-2026-001',
        'US', SYSDATE - 5, NULL, NULL,
        1,
        'CAISSIER1', DATE '2027-03-25');


PROMPT [4] 8 transactions
-- Émission (1 par bon)
INSERT INTO voucher_transaction (voucher_id, transaction_type, amount,
                                  balance_before, balance_after,
                                  terminal_code, user_code, notes)
VALUES (1, 'ISSUE', 10000, 0, 10000, 'CAI01', 'CAISSIER1', 'Émission bon cadeau');

INSERT INTO voucher_transaction (voucher_id, transaction_type, amount,
                                  balance_before, balance_after,
                                  user_code, notes)
VALUES (2, 'ISSUE', 25000, 0, 25000, 'WEBHOOK', 'Émission via site web');

INSERT INTO voucher_transaction (voucher_id, transaction_type, amount,
                                  balance_before, balance_after,
                                  terminal_code, user_code, notes)
VALUES (3, 'ISSUE', 5000, 0, 5000, 'CAI01', 'CAISSIER1', 'Émission bon occasionnel');

INSERT INTO voucher_transaction (voucher_id, transaction_type, amount,
                                  balance_before, balance_after,
                                  user_code, notes)
VALUES (4, 'ISSUE', 15000, 0, 15000, 'CAISSIER2', 'Émission via app mobile');

INSERT INTO voucher_transaction (voucher_id, transaction_type, amount,
                                  balance_before, balance_after,
                                  terminal_code, user_code, notes)
VALUES (5, 'ISSUE', 2500, 0, 2500, 'CAI01', 'CAISSIER1', 'Émission avoir retour');

-- Utilisation (consommation)
INSERT INTO voucher_transaction (voucher_id, transaction_type, amount,
                                  balance_before, balance_after,
                                  terminal_code, ticket_no, user_code, notes)
VALUES (3, 'USE', 5000, 5000, 0, 'CAI01', 1, 'CAISSIER1', 'Utilisation complète sur ticket 1');

-- 2 utilisations partielles sur avoir AV-001 (1 sur RET-2026-001, 1 sur RET-2026-002)
INSERT INTO voucher_transaction (voucher_id, transaction_type, amount,
                                  balance_before, balance_after,
                                  terminal_code, ticket_no, user_code, document_ref, notes)
VALUES (5, 'USE', 1500, 2500, 1000, 'CAI01', 1, 'CAISSIER1',
        'RET-2026-001', 'Utilisation partielle avoir');

-- Recharge (carte PREPAID sur le bon 4, qui pourrait être rechargé)
INSERT INTO voucher_transaction (voucher_id, transaction_type, amount,
                                  balance_before, balance_after,
                                  terminal_code, user_code, notes)
VALUES (4, 'RELOAD', 10000, 15000, 25000, 'CAI01', 'CAISSIER1', 'Recharge +10000 XOF');


PROMPT [5] 6 entrées d'audit
INSERT INTO voucher_audit (voucher_id, action, new_status, new_value,
                           performed_by, ip_address, session_id, client_info)
VALUES (1, 'CREATE', 'IS', 10000, 'CAISSIER1', '192.168.1.10', 'SESS-001', 'POS-CAI01/Chrome 120');

INSERT INTO voucher_audit (voucher_id, action, old_status, new_status,
                           performed_by, ip_address)
VALUES (1, 'PRINT', 'IS', 'PR', 'CAISSIER1', '192.168.1.10');

INSERT INTO voucher_audit (voucher_id, action, old_status, new_status,
                           old_value, new_value, performed_by, ip_address)
VALUES (3, 'BALANCE_CHANGE', 'AC', 'US', 5000, 0, 'CAISSIER1', '192.168.1.10');

INSERT INTO voucher_audit (voucher_id, action, old_status, new_status,
                           old_value, new_value, performed_by, ip_address)
VALUES (4, 'BALANCE_CHANGE', 'AC', 'AC', 15000, 25000, 'CAISSIER1', '192.168.1.10');

INSERT INTO voucher_audit (voucher_id, action, old_status, new_status,
                           performed_by, ip_address, session_id)
VALUES (2, 'STATUS_CHANGE', 'PR', 'AC', 'WEBHOOK', '10.0.0.5', 'EXT-WEB-20260920-AABBCC');

INSERT INTO voucher_audit (voucher_id, action, new_status, new_value,
                           performed_by, ip_address, session_id, client_info)
VALUES (5, 'CREATE', 'IS', 2500, 'CAISSIER1', '192.168.1.10', 'SESS-005', 'POS-CAI01/Firefox 119');

COMMIT;

PROMPT [6] Mise à jour des compteurs de lot
UPDATE voucher_lot vl
   SET vl.issued_qty = (SELECT COUNT(*) FROM voucher_master WHERE voucher_lot_no = vl.lot_number),
       vl.used_qty = (SELECT COUNT(*) FROM voucher_master
                        WHERE voucher_lot_no = vl.lot_number AND issue_status = 'US')
 WHERE vl.lot_number IN (1001, 1002);
COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'VOUCHER_TYPE'           AS tbl, COUNT(*) AS nb FROM voucher_type
UNION ALL SELECT 'VOUCHER_LOT',           COUNT(*) FROM voucher_lot
UNION ALL SELECT 'VOUCHER_MASTER',        COUNT(*) FROM voucher_master
UNION ALL SELECT 'VOUCHER_TRANSACTION',   COUNT(*) FROM voucher_transaction
UNION ALL SELECT 'VOUCHER_AUDIT',         COUNT(*) FROM voucher_audit
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Bons actifs (non utilisés)
SELECT voucher_number, voucher_type_code, initial_value, current_value,
       beneficiary_label, issue_status, expiry_date
  FROM voucher_master
 WHERE issue_status IN ('IS','PR','AC')
 ORDER BY expiry_date;

PROMPT [Q2] Bons expirant dans 60j
SELECT voucher_number, current_value, expiry_date,
       GREATEST(0, expiry_date - SYSDATE) AS jours_restants
  FROM voucher_master
 WHERE expiry_date BETWEEN SYSDATE AND SYSDATE + 60
   AND issue_status NOT IN ('US','CA','EX')
 ORDER BY expiry_date;

PROMPT [Q3] Solde cumulé par type
SELECT voucher_type_code,
       COUNT(*)               AS nb_bons,
       SUM(initial_value)     AS total_initial,
       SUM(current_value)     AS total_courant,
       SUM(initial_value - current_value) AS total_consomme
  FROM voucher_master
 GROUP BY voucher_type_code
 ORDER BY voucher_type_code;

PROMPT [Q4] Bons d'un bénéficiaire donné
SELECT voucher_number, voucher_type_code, initial_value, current_value,
       issue_date, issue_status
  FROM voucher_master
 WHERE beneficiary_code = 'CLI002'
 ORDER BY issue_date DESC;

PROMPT [Q5] Historique des transactions d'un bon
SELECT vt.transaction_at, vt.transaction_type, vt.amount,
       vt.balance_before, vt.balance_after, vt.user_code, vt.notes
  FROM voucher_transaction vt
 WHERE vt.voucher_id = 4
 ORDER BY vt.transaction_at;

PROMPT [Q6] Audit : tous les changements de statut
SELECT va.performed_at, va.action, va.old_status, va.new_status,
       vm.voucher_number, va.performed_by, va.ip_address
  FROM voucher_audit va
  JOIN voucher_master vm ON vm.voucher_id = va.voucher_id
 ORDER BY va.performed_at DESC
 FETCH FIRST 10 ROWS ONLY;

PROMPT [Q7] Lots d'émission avec soldes
SELECT vl.lot_number, vl.lot_name, vl.quantity, vl.initial_value,
       vl.issued_qty, vl.used_qty,
       ROUND(vl.used_qty * 100.0 / NULLIF(vl.issued_qty, 0), 1) AS pct_use,
       vl.expiry_date
  FROM voucher_lot vl
 ORDER BY vl.issue_date DESC;

PROMPT [Q8] Bons rechargeables avec leur potentiel de recharge
SELECT v.voucher_number, v.current_value,
       vt.voucher_type_name AS type,
       vt.max_value
  FROM voucher_master v
  JOIN voucher_type vt ON vt.voucher_type_code = v.voucher_type_code
 WHERE vt.is_reusable = TRUE
 ORDER BY v.current_value DESC;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R10 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
