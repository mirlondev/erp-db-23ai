-- ============================================================
-- S12 : Seed LOT R4 (Réapprovisionnements & Transferts)
-- Données de démo : 2 transferts inter-dépôts,
--                    3 suggestions de réappro,
--                    1 bon de commande complet (3 lignes),
--                    snapshot valorisation stock.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R4 — Réappro & Transferts
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R4]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM stock_valuation';
  EXECUTE IMMEDIATE 'DELETE FROM purchase_order_line';
  EXECUTE IMMEDIATE 'DELETE FROM purchase_order_header';
  EXECUTE IMMEDIATE 'DELETE FROM replenishment_suggestion';
  EXECUTE IMMEDIATE 'DELETE FROM transfer_line';
  EXECUTE IMMEDIATE 'DELETE FROM transfer_header';
  COMMIT;
END;
/

PROMPT
PROMPT [1] Transfert #1 : DEP02 → DEP01 (renforcement stock stylos)
INSERT INTO transfer_header (transfer_number, transfer_date,
                              source_warehouse, target_warehouse,
                              status, memo, carrier_name, expected_arrival,
                              created_by, validated_by, validated_at)
VALUES ('TR-2026-001', SYSDATE - 5,
        'DEP02', 'DEP01',
        'SENT', 'Renforcement stock stylos avant rentrée', 'DHL',
        SYSDATE + 2,
        'ADMIN', 'ADMIN', SYSDATE - 4);

INSERT INTO transfer_line (transfer_id, line_no, product_code, description,
                            requested_qty, sent_qty, received_qty,
                            unit_code, unit_cost, status)
VALUES (1, 1, 'ART002', 'Stylo bleu', 200, 200, 0, 'UNIT', 350, 'SENT');

INSERT INTO transfer_line (transfer_id, line_no, product_code, description,
                            requested_qty, sent_qty, received_qty,
                            unit_code, unit_cost, status)
VALUES (1, 2, 'ART001', 'Cahier 200p', 50, 50, 0, 'UNIT', 1800, 'SENT');

UPDATE transfer_header
   SET total_qty = (SELECT SUM(sent_qty) FROM transfer_line WHERE transfer_id = 1)
 WHERE transfer_id = 1;


PROMPT
PROMPT [2] Transfert #2 : DEP01 → DEP02 (rééquilibrage USB)
INSERT INTO transfer_header (transfer_number, transfer_date,
                              source_warehouse, target_warehouse,
                              status, memo, carrier_name, expected_arrival,
                              received_at, created_by, validated_by, validated_at)
VALUES ('TR-2026-002', SYSDATE - 15,
        'DEP01', 'DEP02',
        'RECEIVED', 'Rééquilibrage USB après pic de vente', 'Transport interne',
        SYSDATE - 13,
        SYSDATE - 13,
        'ADMIN', 'ADMIN', SYSDATE - 14);

INSERT INTO transfer_line (transfer_id, line_no, product_code, description,
                            requested_qty, sent_qty, received_qty,
                            unit_code, unit_cost, status)
VALUES (2, 1, 'ART003', 'USB 32 Go', 20, 20, 20, 'UNIT', 11000, 'RECEIVED');

UPDATE transfer_header
   SET total_qty = (SELECT SUM(received_qty) FROM transfer_line WHERE transfer_id = 2)
 WHERE transfer_id = 2;


PROMPT
PROMPT [3] 3 suggestions de réapprovisionnement
INSERT INTO replenishment_suggestion (product_code, warehouse_code,
                                       current_stock, min_stock, max_stock,
                                       avg_consumption, days_of_cover,
                                       suggested_qty, supplier_code, lead_time_days,
                                       status, priority_score, generated_at,
                                       decided_by, decided_at)
VALUES ('ART001', 'DEP01', 100, 50, 500, 5.5, 18.2,
        200, 'FOU001', 7, 'NEW', 85.5, SYSDATE, NULL, NULL);

INSERT INTO replenishment_suggestion (product_code, warehouse_code,
                                       current_stock, min_stock, max_stock,
                                       avg_consumption, days_of_cover,
                                       suggested_qty, supplier_code, lead_time_days,
                                       status, priority_score, generated_at,
                                       decided_by, decided_at)
VALUES ('ART002', 'DEP01', 450, 100, 1000, 25.0, 18.0,
        500, 'FOU001', 5, 'APPROVED', 75.0, SYSDATE - 1, 'ADMIN', SYSDATE);

INSERT INTO replenishment_suggestion (product_code, warehouse_code,
                                       current_stock, min_stock, max_stock,
                                       avg_consumption, days_of_cover,
                                       suggested_qty, supplier_code, lead_time_days,
                                       status, priority_score, generated_at,
                                       decided_by, decided_at)
VALUES ('ART003', 'DEP01', 40, 20, 100, 1.5, 26.7,
        50, 'FOU002', 14, 'NEW', 60.0, SYSDATE, NULL, NULL);


PROMPT
PROMPT [4] Bon de commande #1 — BC-2026-001 (3 articles)
INSERT INTO purchase_order_header (po_number, po_date, supplier_code, supplier_name,
                                    warehouse_code, expected_date, status,
                                    currency_code, exchange_rate,
                                    total_ht, total_tax, total_ttc,
                                    memo, payment_terms, incoterm,
                                    created_by, sent_at, confirmed_at)
VALUES ('BC-2026-001', SYSDATE - 2, 'FOU001', 'Fournisseur ABC',
        'DEP01', SYSDATE + 5, 'CONFIRMED',
        'XOF', 1,
        195000, 35100, 230100,
        'Réappro rentrée scolaire', '30 jours fin de mois', 'CIF',
        'ADMIN', SYSDATE - 2, SYSDATE - 1);

INSERT INTO purchase_order_line (po_id, line_no, product_code, description,
                                  ordered_qty, received_qty, invoiced_qty,
                                  unit_code, unit_price, unit_price_ht,
                                  discount_rate, tax_rate,
                                  amount_ht, amount_ttc, expected_date, status)
VALUES (1, 1, 'ART001', 'Cahier 200 pages A4',
        100, 0, 0, 'UNIT', 2500, 2118.64, 0, 18,
        211864, 250000, SYSDATE + 5, 'OPEN');

INSERT INTO purchase_order_line (po_id, line_no, product_code, description,
                                  ordered_qty, received_qty, invoiced_qty,
                                  unit_code, unit_price, unit_price_ht,
                                  discount_rate, tax_rate,
                                  amount_ht, amount_ttc, expected_date, status)
VALUES (1, 2, 'ART002', 'Stylo à bille bleu',
        100, 0, 0, 'UNIT', 500, 423.73, 0, 18,
        42373, 50000, SYSDATE + 5, 'OPEN');

INSERT INTO purchase_order_line (po_id, line_no, product_code, description,
                                  ordered_qty, received_qty, invoiced_qty,
                                  unit_code, unit_price, unit_price_ht,
                                  discount_rate, tax_rate,
                                  amount_ht, amount_ttc, expected_date, status)
VALUES (1, 3, 'ART004', 'Bloc-notes A5',
        50, 50, 50, 'UNIT', 350, 296.61, 0, 18,
        -59237, -69820, SYSDATE - 1, 'RECEIVED');

-- Note : pour le seed, on met -59237 sur la 3e ligne pour montrer
-- l'effet d'un avoir (le fournisseur a renvoyé en surplus annulé)
-- En prod, on aurait une vraie facture d'avoir séparée.

COMMIT;


PROMPT
PROMPT [5] Snapshot de valorisation stock (clôture mensuelle)
INSERT INTO stock_valuation (valuation_date, warehouse_code, product_code,
                              quantity, avg_cost, total_value, valuation_method, currency_code)
VALUES
  (DATE '2026-09-30', 'DEP01', 'ART001', 95,  2118.64,    201271, 'PRMP', 'XOF'),
  (DATE '2026-09-30', 'DEP01', 'ART002', 425, 423.73,     180085, 'PRMP', 'XOF'),
  (DATE '2026-09-30', 'DEP01', 'ART003',  35, 12711.86,   444915, 'PRMP', 'XOF'),
  (DATE '2026-09-30', 'DEP02', 'ART001', 180, 2118.64,    381355, 'PRMP', 'XOF'),
  (DATE '2026-09-30', 'DEP02', 'ART004', 145, 296.61,     43008,  'PRMP', 'XOF');


PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'TRANSFER_HEADER'          AS tbl, COUNT(*) AS nb FROM transfer_header
UNION ALL SELECT 'TRANSFER_LINE',           COUNT(*) FROM transfer_line
UNION ALL SELECT 'REPLENISHMENT_SUGG',      COUNT(*) FROM replenishment_suggestion
UNION ALL SELECT 'PURCHASE_ORDER_HDR',      COUNT(*) FROM purchase_order_header
UNION ALL SELECT 'PURCHASE_ORDER_LINE',     COUNT(*) FROM purchase_order_line
UNION ALL SELECT 'STOCK_VALUATION',         COUNT(*) FROM stock_valuation
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Transferts en cours
SELECT transfer_number, transfer_date, source_warehouse, target_warehouse,
       status, total_qty
  FROM transfer_header
 WHERE status IN ('SENT','VALID')
 ORDER BY transfer_date DESC;

PROMPT [Q2] Suggestions NEW (à traiter)
SELECT product_code, warehouse_code, current_stock, min_stock,
       days_of_cover, suggested_qty, supplier_code, priority_score
  FROM replenishment_suggestion
 WHERE status = 'NEW'
 ORDER BY priority_score DESC;

PROMPT [Q3] Bons de commande ouverts
SELECT po_number, po_date, supplier_name, expected_date, status,
       total_ht, total_ttc
  FROM purchase_order_header
 WHERE status IN ('DRAFT','SENT','CONFIRMED','PARTIAL')
 ORDER BY expected_date;

PROMPT [Q4] Lignes BC avec retard
SELECT h.po_number, l.product_code, l.description, l.ordered_qty,
       l.received_qty, l.expected_date,
       GREATEST(0, SYSDATE - l.expected_date) AS retard_jours
  FROM purchase_order_line l
  JOIN purchase_order_header h ON h.po_id = l.po_id
 WHERE l.status IN ('OPEN','PARTIAL')
   AND l.expected_date < SYSDATE
 ORDER BY retard_jours DESC;

PROMPT [Q5] Valorisation stock totale par dépôt
SELECT warehouse_code,
       SUM(total_value) AS valeur_totale,
       COUNT(DISTINCT product_code) AS nb_references
  FROM stock_valuation
 WHERE valuation_date = DATE '2026-09-30'
 GROUP BY warehouse_code
 ORDER BY warehouse_code;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R4 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
