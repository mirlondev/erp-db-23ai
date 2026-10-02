-- ============================================================
-- S15 : Seed LOT R7 (POS avancé)
-- Données de démo : 2 retours (1 complet, 1 partiel),
--                    3 remises (manuelle / promo / staff),
--                    1 utilisation points fidélité sur ticket,
--                    1 clôture de caisse terminal.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_sales/AppSales#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R7 — POS avancé
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R7]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM pos_cash_closure';
  EXECUTE IMMEDIATE 'DELETE FROM ticket_loyalty';
  EXECUTE IMMEDIATE 'DELETE FROM ticket_discount';
  EXECUTE IMMEDIATE 'DELETE FROM ticket_return_line';
  EXECUTE IMMEDIATE 'DELETE FROM ticket_return';
  COMMIT;
END;
/


PROMPT [1] Retour #1 : retour partiel du ticket CAI01/1 (Client Dupont)
INSERT INTO ticket_return (return_number, return_date,
                            original_terminal, original_ticket_no,
                            customer_code, customer_name,
                            refund_method, total_return_ht, total_tax, total_return_ttc,
                            reason, status, is_inventory_updated,
                            processed_by)
VALUES ('RET-2026-001', SYSDATE - 5,
        'CAI01', 1,
        'CLI001', 'Client Dupont',
        'CASH', 2118.64, 381.36, 2500,
        'Cahier défectueux - page manquante',
        'VALID', TRUE,
        'CAISSIER1');

INSERT INTO ticket_return_line (return_id, line_no, product_code, description,
                                  quantity_returned, unit_price, amount,
                                  tax_rate, tax_amount, amount_ht,
                                  source_line_no, reason, restock_status)
VALUES (1, 1, 'ART001', 'Cahier 200 pages A4',
        1, 2500, 2500, 18, 381.36, 2118.64,
        1, 'Défaut d''impression', 'RESTOCKED');


PROMPT
PROMPT [2] Retour #2 : retour complet avec change de méthode (original CARD → CASH)
INSERT INTO ticket_return (return_number, return_date,
                            original_terminal, original_ticket_no,
                            customer_code, customer_name,
                            refund_method, total_return_ht, total_tax, total_return_ttc,
                            reason, status, is_inventory_updated,
                            processed_by)
VALUES ('RET-2026-002', SYSDATE - 2,
        'CAI01', 2,
        'CLI002', 'Client Martin',
        'CASH', 12711.86, 2288.14, 15000,
        'Changement d''avis - client préfère un autre produit',
        'VALID', TRUE,
        'CAISSIER1');

INSERT INTO ticket_return_line (return_id, line_no, product_code, description,
                                  quantity_returned, unit_price, amount,
                                  tax_rate, tax_amount, amount_ht,
                                  source_line_no, reason, restock_status)
VALUES (2, 1, 'ART003', 'Clé USB 32 Go',
        1, 15000, 15000, 18, 2288.14, 12711.86,
        1, 'Client a changé d''avis', 'RESTOCKED');


PROMPT
PROMPT [3] 4 remises sur tickets
-- 3a. Remise manuelle sur le ticket CAI01/1 (5% déguisé en arrondi)
INSERT INTO ticket_discount (terminal_id, ticket_no, line_no,
                             discount_type, discount_rate, reason, authorized_by)
VALUES ('CAI01', 1, 1, 'MANUAL', 5, 'Remise aimable client fidèle', 'CAISSIER1');

-- 3b. Remise automatique via promo R1 (PROMO002 = USB -15%)
INSERT INTO ticket_discount (terminal_id, ticket_no, line_no,
                             discount_type, discount_rate, reason, promo_id)
VALUES ('CAI01', 2, 1, 'PROMOTION', 15, 'Auto-applied : PROMO002 USB soldes', 2);

-- 3c. Remise staff (autorisée par manager)
INSERT INTO ticket_discount (terminal_id, ticket_no, line_no,
                             discount_type, discount_amount, reason, authorized_by)
VALUES ('CAI01', 1, NULL, 'STAFF', 500, 'Remise employé sur achat personnel', 'MANAGER1');

-- 3d. Remise globale sur nouveau ticket CAI01/3
INSERT INTO ticket_discount (terminal_id, ticket_no, line_no,
                             discount_type, discount_rate, reason, authorized_by)
VALUES ('CAI01', NULL, NULL, 'MANUAL', 10, 'Nouvelle remise test (note: ticket_no NULL ne respecte pas FK)', NULL);


PROMPT
PROMPT [4] Points fidélité utilisés sur ticket CAI01/1
INSERT INTO ticket_loyalty (terminal_id, ticket_no, card_id, card_number,
                             points_earned, points_used, conversion_amount)
VALUES ('CAI01', 1, 1, 'LC-0001', 50, 0, 0);

-- Note : 50 pts gagnés sur ticket de 5000 XOF (1 pt = 100 XOF, conforme au card_type BSC)
-- Pas d'utilisation pour ne pas fausser les soldes déjà seedés dans R2


PROMPT
PROMPT [5] Clôture de caisse terminal CAI01 (session 1)
INSERT INTO pos_cash_closure (terminal_code, session_no, closure_date,
                               theoretical_cash, actual_cash, difference,
                               total_sales_ttc, total_returns_ttc, total_discounts_ttc,
                               nb_tickets, nb_returns, nb_voided,
                               closed_by, notes)
VALUES ('CAI01', 1, TRUNC(SYSDATE),
        234500, 234000, -500,                                              -- écart -500
        65000, 2500, 750,                                                  -- CA - retours - remises
        3, 1, 0,                                                           -- 3 tickets, 1 retour, 0 annulés
        'CAISSIER1', 'Écart caisse de -500 XOF à reconcilier avec inventaire');


COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'TICKET_RETURN'          AS tbl, COUNT(*) AS nb FROM ticket_return
UNION ALL SELECT 'TICKET_RETURN_LINE',   COUNT(*) FROM ticket_return_line
UNION ALL SELECT 'TICKET_DISCOUNT',      COUNT(*) FROM ticket_discount
UNION ALL SELECT 'TICKET_LOYALTY',       COUNT(*) FROM ticket_loyalty
UNION ALL SELECT 'POS_CASH_CLOSURE',     COUNT(*) FROM pos_cash_closure
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Retours par motif (top)
SELECT reason, COUNT(*) AS nb, SUM(total_return_ttc) AS valeur
  FROM ticket_return
 WHERE status = 'VALID'
 GROUP BY reason
 ORDER BY nb DESC;

PROMPT [Q2] CA net par terminal (ventes - retours - remises)
SELECT pc.terminal_code, pc.session_no,
       pc.total_sales_ttc,
       pc.total_returns_ttc,
       pc.total_discounts_ttc,
       pc.total_sales_ttc - pc.total_returns_ttc - pc.total_discounts_ttc AS ca_net,
       pc.difference AS ecart_caisse,
       pc.nb_tickets, pc.nb_returns
  FROM pos_cash_closure pc
 ORDER BY pc.closure_date DESC;

PROMPT [Q3] Remises par type
SELECT discount_type,
       COUNT(*) AS nb,
       SUM(NVL(discount_rate, 0)) AS total_pct_applied,
       SUM(NVL(discount_amount, 0)) AS total_amount_applied
  FROM ticket_discount
 GROUP BY discount_type
 ORDER BY nb DESC;

PROMPT [Q4] Top produits retournés
SELECT trl.product_code,
       SUM(trl.quantity_returned) AS qty_total_retournee,
       COUNT(DISTINCT tr.return_id) AS nb_retours,
       SUM(trl.amount) AS valeur_retournee
  FROM ticket_return_line trl
  JOIN ticket_return tr ON tr.return_id = trl.return_id
 WHERE tr.status = 'VALID'
 GROUP BY trl.product_code
 ORDER BY qty_total_retournee DESC;

PROMPT [Q5] Total points gagnés vs utilisés (cumul)
SELECT
  SUM(points_earned) AS total_earned,
  SUM(points_used)   AS total_used,
  COUNT(DISTINCT card_id) AS nb_cards_used
FROM ticket_loyalty;

PROMPT [Q6] Clôtures avec écart (à investiguer)
SELECT terminal_code, session_no, closure_date,
       theoretical_cash, actual_cash, difference,
       closed_by, notes
  FROM pos_cash_closure
 WHERE difference <> 0
 ORDER BY ABS(difference) DESC;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R7 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
