-- ============================================================
-- S10 : Seed LOT R2 (Fidélité client)
-- Données réalistes : 3 types de cartes (Basic/Silver/Gold),
--                     4 cartes, 6 opérations (achats + utilisation).
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_party/AppParty#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R2 — Fidélité client
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R2]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM loyalty_log';
  EXECUTE IMMEDIATE 'DELETE FROM loyalty_lot';
  EXECUTE IMMEDIATE 'DELETE FROM loyalty_operation';
  EXECUTE IMMEDIATE 'DELETE FROM loyalty_card';
  EXECUTE IMMEDIATE 'DELETE FROM loyalty_operation_type';
  EXECUTE IMMEDIATE 'DELETE FROM loyalty_app';
  EXECUTE IMMEDIATE 'DELETE FROM loyalty_card_type';
  COMMIT;
END;
/


PROMPT [1] 3 types de cartes
INSERT INTO loyalty_card_type (card_type_code, card_type_name, point_value, point_threshold,
                                bonus_rate, inactive_reset_days, is_active, memo, created_by)
VALUES ('BSC', 'Carte Basique', 100, 500, 5, 365, TRUE,
        '1 pt = 100 XOF, upgrade Silver à 500 pts', 'ADMIN');

INSERT INTO loyalty_card_type (card_type_code, card_type_name, point_value, point_threshold,
                                bonus_rate, inactive_reset_days, is_active, memo, created_by)
VALUES ('SLV', 'Carte Silver', 80, 2000, 10, 365, TRUE,
        '1 pt = 80 XOF (1.25x plus avantageux), upgrade Gold à 2000 pts', 'ADMIN');

INSERT INTO loyalty_card_type (card_type_code, card_type_name, point_value, point_threshold,
                                bonus_rate, inactive_reset_days, is_active, memo, created_by)
VALUES ('GLD', 'Carte Gold', 50, NULL, 0, 730, TRUE,
        '1 pt = 50 XOF, palier ultime, pas d''upgrade', 'ADMIN');


PROMPT [2] 5 types d'opération
INSERT INTO loyalty_operation_type (operation_type_code, operation_type_name, is_entry_allowed, sign, description, is_active, created_by)
VALUES ('PURCH', 'Achat',     TRUE,  '+', 'Gain de points suite à un achat',           TRUE, 'ADMIN');

INSERT INTO loyalty_operation_type (operation_type_code, operation_type_name, is_entry_allowed, sign, description, is_active, created_by)
VALUES ('BIRTH', 'Anniversaire', TRUE, '+', 'Bonus d''anniversaire',                    TRUE, 'ADMIN');

INSERT INTO loyalty_operation_type (operation_type_code, operation_type_name, is_entry_allowed, sign, description, is_active, created_by)
VALUES ('REDEEM','Utilisation',TRUE,  '-', 'Conversion de points en remise',           TRUE, 'ADMIN');

INSERT INTO loyalty_operation_type (operation_type_code, operation_type_name, is_entry_allowed, sign, description, is_active, created_by)
VALUES ('ADJUST', 'Ajustement',TRUE,  '+', 'Correction manuelle crédit',               TRUE, 'ADMIN');

INSERT INTO loyalty_operation_type (operation_type_code, operation_type_name, is_entry_allowed, sign, description, is_active, created_by)
VALUES ('EXPIRE', 'Expiration',FALSE, '-', 'Expiration des points (système)',          TRUE, 'ADMIN');


PROMPT [3] 1 application fidélité
INSERT INTO loyalty_app (app_code, app_name, is_production, app_key,
                         value_purchase_1pt, value_conversion_1pt,
                         base_url, cust_detail_api, cust_wallet_api,
                         debit_wallet_api, recharge_wallet_api, cust_type_api,
                         cancel_receipt_api, is_active)
VALUES ('FID01', 'Programme Fidélité Retail', FALSE, 'sk_test_loyalty_2026',
        100, 50,
        'https://api.loyalty.local/v1',
        '/customers/{id}', '/customers/{id}/wallet',
        '/wallet/debit', '/wallet/recharge', '/customers/{id}/type',
        '/receipts/cancel', TRUE);


PROMPT [4] 4 cartes de fidélité
INSERT INTO loyalty_card (card_number, card_type_code, status, title, last_name, first_name,
                          mobile_phone_1, personal_email, city_code, country_code,
                          points_balance, total_earned_points, last_used_at,
                          issue_date, party_id, created_by)
VALUES ('LC-0001', 'BSC', 'A', 'M.', 'Dupont', 'Jean',
        '+225 01 02 03 04', 'jdupont@example.com', 'ABJ', 'CIV',
        120, 120, SYSDATE, DATE '2025-03-15', 1, 'ADMIN');

INSERT INTO loyalty_card (card_number, card_type_code, status, title, last_name, first_name,
                          mobile_phone_1, personal_email, city_code, country_code,
                          points_balance, total_earned_points, last_used_at,
                          issue_date, party_id, created_by)
VALUES ('LC-0002', 'SLV', 'A', 'Mme', 'Martin', 'Sophie',
        '+225 05 06 07 08', 'smartin@example.com', 'ABJ', 'CIV',
        850, 1000, SYSDATE, DATE '2024-11-02', 2, 'ADMIN');

INSERT INTO loyalty_card (card_number, card_type_code, status, title, last_name, first_name,
                          mobile_phone_1, personal_email, city_code, country_code,
                          points_balance, total_earned_points, last_used_at,
                          issue_date, party_id, created_by)
VALUES ('LC-0003', 'GLD', 'A', 'M.', 'Durand', 'Paul',
        '+225 09 10 11 12', 'pdurand@example.com', 'ABJ', 'CIV',
        5200, 5200, SYSDATE, DATE '2023-06-10', 3, 'ADMIN');

INSERT INTO loyalty_card (card_number, card_type_code, status, title, last_name, first_name,
                          mobile_phone_1, personal_email, city_code, country_code,
                          points_balance, total_earned_points, last_used_at,
                          issue_date, created_by)
VALUES ('LC-0004', 'BSC', 'I', 'M.', 'Bernard', 'Luc',
        '+225 13 14 15 16', 'lbernard@example.com', 'DKR', 'SEN',
        0, 80, DATE '2024-01-20', DATE '2024-01-15', 'ADMIN');


PROMPT [5] 6 opérations (3 gains + 1 utilisation + 1 bonus + 1 expiration)
-- LC-0001 : gain sur achat ticket CAI01/1 (5000 XOF → 50 pts)
INSERT INTO loyalty_operation (card_id, operation_type_code, operation_date,
                              terminal_code, ticket_no, points, amount, label, created_by)
VALUES (1, 'PURCH', SYSDATE - 30,
        'CAI01', 1, 50, 5000, 'Achat ticket CAI01-1', 'ADMIN');

-- LC-0002 : gain sur ticket CAI01/2 (15000 XOF → 150 pts)
INSERT INTO loyalty_operation (card_id, operation_type_code, operation_date,
                              terminal_code, ticket_no, points, amount, label, created_by)
VALUES (2, 'PURCH', SYSDATE - 25,
        'CAI01', 2, 150, 15000, 'Achat ticket CAI01-2', 'ADMIN');

-- LC-0003 : bonus anniversaire
INSERT INTO loyalty_operation (card_id, operation_type_code, operation_date,
                              points, label, created_by)
VALUES (3, 'BIRTH', SYSDATE - 60,
        500, 'Bonus anniversaire Paul Durand', 'ADMIN');

-- LC-0003 : utilisation : conversion de 2000 pts = 100000 XOF
INSERT INTO loyalty_operation (card_id, operation_type_code, operation_date,
                              terminal_code, ticket_no, points, amount, label,
                              document_ref, created_by)
VALUES (3, 'REDEEM', SYSDATE - 15,
        'CAI01', NULL, 2000, 100000, 'Conversion 2000 pts',
        'REDEEM-2026-0001', 'ADMIN');

-- LC-0002 : ajustement manuel (correction)
INSERT INTO loyalty_operation (card_id, operation_type_code, operation_date,
                              points, label, created_by)
VALUES (2, 'ADJUST', SYSDATE - 10,
        100, 'Ajustement manuel - doublon détecté', 'ADMIN');

-- LC-0004 : expiration (carte inactive depuis 12 mois)
INSERT INTO loyalty_operation (card_id, operation_type_code, operation_date,
                              points, label, created_by)
VALUES (4, 'EXPIRE', SYSDATE - 90,
        80, 'Expiration - inactivité > 365j', 'SYSTEM');


PROMPT [6] 2 lots fidélité (cumul par ticket)
INSERT INTO loyalty_lot (customer_id, last_name, first_name, mobile_phone,
                        lot_id, amount, warehouse_id, terminal_code, ticket_no,
                        order_id, points, created_by)
VALUES (1, 'Dupont', 'Jean', '+225 01 02 03 04',
        1001, 5000, 1, 'CAI01', 1, 1, 50, 'ADMIN');

INSERT INTO loyalty_lot (customer_id, last_name, first_name, mobile_phone,
                        lot_id, amount, warehouse_id, terminal_code, ticket_no,
                        order_id, points, created_by)
VALUES (2, 'Martin', 'Sophie', '+225 05 06 07 08',
        1002, 15000, 1, 'CAI01', 2, 2, 150, 'ADMIN');


PROMPT [7] 3 entrées de log
INSERT INTO loyalty_log (claim_option, ticket_no, terminal_code, loyalty_customer_id,
                          points, reason, user_code, order_id, wallet_id, wallet_line_id)
VALUES ('PT', 1, 'CAI01', 'LC-0001', 50, 'Claim OK', 'ADMIN', 1, 1001, 1);

INSERT INTO loyalty_log (claim_option, ticket_no, terminal_code, loyalty_customer_id,
                          points, reason, user_code, order_id, wallet_id, wallet_line_id)
VALUES ('PT', 2, 'CAI01', 'LC-0002', 150, 'Claim OK', 'ADMIN', 2, 1002, 1);

INSERT INTO loyalty_log (claim_option, ticket_no, terminal_code, loyalty_customer_id,
                          points, reason, user_code, order_id, wallet_id, wallet_line_id)
VALUES ('RD', NULL, 'CAI01', 'LC-0003', 2000, 'Redeem 2000 pts = 100000 XOF', 'ADMIN', 3, 1003, 1);

COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'LOYALTY_CARD_TYPE'      AS tbl, COUNT(*) AS nb FROM loyalty_card_type
UNION ALL SELECT 'LOYALTY_CARD',          COUNT(*) FROM loyalty_card
UNION ALL SELECT 'LOYALTY_OPERATION_TYPE', COUNT(*) FROM loyalty_operation_type
UNION ALL SELECT 'LOYALTY_OPERATION',     COUNT(*) FROM loyalty_operation
UNION ALL SELECT 'LOYALTY_LOT',           COUNT(*) FROM loyalty_lot
UNION ALL SELECT 'LOYALTY_APP',           COUNT(*) FROM loyalty_app
UNION ALL SELECT 'LOYALTY_LOG',           COUNT(*) FROM loyalty_log
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Soldes points par carte
SELECT c.card_number, ct.card_type_name, c.points_balance, c.last_used_at
  FROM loyalty_card c
  JOIN loyalty_card_type ct ON ct.card_type_code = c.card_type_code
 ORDER BY c.points_balance DESC;

PROMPT [Q2] Historique d'opérations par carte
SELECT c.card_number, ot.operation_type_name, ot.sign,
       o.operation_date, o.points, o.amount, o.label
  FROM loyalty_operation o
  JOIN loyalty_card c        ON c.card_id       = o.card_id
  JOIN loyalty_operation_type ot ON ot.operation_type_code = o.operation_type_code
 ORDER BY c.card_number, o.operation_date;

PROMPT [Q3] Total des points gagnés vs utilisés par client
SELECT c.card_number,
       SUM(CASE WHEN ot.sign = '+' THEN o.points ELSE 0 END) AS total_earned,
       SUM(CASE WHEN ot.sign = '-' THEN o.points ELSE 0 END) AS total_used,
       COUNT(*) AS nb_operations
  FROM loyalty_operation o
  JOIN loyalty_card c        ON c.card_id       = o.card_id
  JOIN loyalty_operation_type ot ON ot.operation_type_code = o.operation_type_code
 GROUP BY c.card_number
 ORDER BY total_earned DESC;

PROMPT [Q4] Valeur monétaire théorique du portefeuille
SELECT c.card_number, ct.card_type_name,
       c.points_balance,
       c.points_balance * ct.point_value AS valeur_xof
  FROM loyalty_card c
  JOIN loyalty_card_type ct ON ct.card_type_code = c.card_type_code
 ORDER BY valeur_xof DESC;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R2 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
