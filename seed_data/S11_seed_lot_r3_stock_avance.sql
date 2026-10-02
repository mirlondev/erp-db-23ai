-- ============================================================
-- S11 : Seed LOT R3 (Stock avancé)
-- Données de démo : statuts, PRMP, lots avec expiration,
--                    proposition de réappro.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R3 — Stock avancé
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R3]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM inv_reorder';
  EXECUTE IMMEDIATE 'DELETE FROM inv_movement_status';
  EXECUTE IMMEDIATE 'DELETE FROM inv_stock_status';
  EXECUTE IMMEDIATE 'DELETE FROM inv_count_zone';
  EXECUTE IMMEDIATE 'DELETE FROM inv_product_lot';
  EXECUTE IMMEDIATE 'DELETE FROM inv_avg_cost';
  EXECUTE IMMEDIATE 'DELETE FROM inv_status_ref';
  COMMIT;
END;
/

PROMPT
PROMPT [1] Référentiel statuts (8 statuts classiques du retail)
INSERT INTO inv_status_ref (status_code, status_name, is_active, is_sale_allowed, reverse_qty_update, auto_entry, display_order, memo, created_by)
VALUES ('AVL', 'Disponible',  TRUE,  TRUE,  TRUE,  TRUE,  10, 'Stock vendable', 'ADMIN');

INSERT INTO inv_status_ref (status_code, status_name, is_active, is_sale_allowed, reverse_qty_update, auto_entry, display_order, memo, created_by)
VALUES ('BLQ', 'Bloqué',      TRUE,  FALSE, TRUE,  FALSE, 20, 'Qualité / quarantaine', 'ADMIN');

INSERT INTO inv_status_ref (status_code, status_name, is_active, is_sale_allowed, reverse_qty_update, auto_entry, display_order, memo, created_by)
VALUES ('RSV', 'Réservé',     TRUE,  FALSE, FALSE, FALSE, 30, 'Réservé pour commande client', 'ADMIN');

INSERT INTO inv_status_ref (status_code, status_name, is_active, is_sale_allowed, reverse_qty_update, auto_entry, display_order, memo, created_by)
VALUES ('TRZ', 'Transit',     TRUE,  FALSE, TRUE,  TRUE,  40, 'Entrepôt vers dépôt', 'ADMIN');

INSERT INTO inv_status_ref (status_code, status_name, is_active, is_sale_allowed, reverse_qty_update, auto_entry, display_order, memo, created_by)
VALUES ('RET', 'Retour',      TRUE,  FALSE, TRUE,  TRUE,  50, 'Retour client en attente de tri', 'ADMIN');

INSERT INTO inv_status_ref (status_code, status_name, is_active, is_sale_allowed, reverse_qty_update, auto_entry, display_order, memo, created_by)
VALUES ('EXP', 'Expiré',      TRUE,  FALSE, FALSE, FALSE, 60, 'Péremption dépassée', 'ADMIN');

INSERT INTO inv_status_ref (status_code, status_name, is_active, is_sale_allowed, reverse_qty_update, auto_entry, display_order, memo, created_by)
VALUES ('DMG', 'Endommagé',   TRUE,  FALSE, TRUE,  FALSE, 70, 'Stock endommagé à déclasser', 'ADMIN');

INSERT INTO inv_status_ref (status_code, status_name, is_active, is_sale_allowed, reverse_qty_update, auto_entry, display_order, memo, created_by)
VALUES ('CNS', 'Consigné',    TRUE,  FALSE, TRUE,  FALSE, 80, 'Consigne (non propriété)', 'ADMIN');


PROMPT
PROMPT [2] Statuts par produit/dépôt (ART001, ART002, ART003 dans DEP01)
INSERT INTO inv_stock_status (product_code, warehouse_code, stock_status_code, quantity, last_movement_at)
VALUES
  ('ART001', 'DEP01', 'AVL', 80,  SYSDATE),
  ('ART001', 'DEP01', 'BLQ', 15,  SYSDATE - 10),
  ('ART001', 'DEP01', 'RSV', 5,   SYSDATE - 3),
  ('ART002', 'DEP01', 'AVL', 450, SYSDATE),
  ('ART002', 'DEP01', 'RET', 50,  SYSDATE - 5),
  ('ART003', 'DEP01', 'AVL', 40,  SYSDATE),
  ('ART003', 'DEP01', 'EXP', 10,  SYSDATE - 60),
  ('ART001', 'DEP02', 'AVL', 180, SYSDATE),
  ('ART004', 'DEP02', 'AVL', 150, SYSDATE);


PROMPT
PROMPT [3] Coûts moyens pondérés (PRMP) pour septembre 2026
INSERT INTO inv_avg_cost (company_code, period, product_code,
                          opening_qty, quantity, amount, closing_qty, avg_cost)
VALUES
  ('COMP01', '2026-09', 'ART001', 100, 50, 100000, 150, 2118.64),
  ('COMP01', '2026-09', 'ART002', 500, 200, 80000, 700, 423.73),
  ('COMP01', '2026-09', 'ART003',  50,  30, 360000, 80, 12711.86);


PROMPT
PROMPT [4] Lots produit (gestion DLC)
INSERT INTO inv_product_lot (product_code, lot_number, lot_status, manufacturing_date, expiry_date,
                              received_date, lot_qty, available_qty, supplier_lot_ref, memo, updated_by)
VALUES
  ('ART001', 'LOT-2026-001-A', 'AV', DATE '2026-01-15', DATE '2027-01-15',
   DATE '2026-01-20', 60, 50, 'SUP-A-1234', 'Lot fournisseur A', 'ADMIN'),
  ('ART001', 'LOT-2026-002-A', 'BL', DATE '2026-03-10', DATE '2027-03-10',
   DATE '2026-03-15', 40, 30, 'SUP-A-1567', 'Lot bloqué pour contrôle qualité', 'ADMIN'),
  ('ART002', 'LOT-2026-003-B', 'AV', DATE '2026-02-05', DATE '2028-02-05',
   DATE '2026-02-10', 500, 450, 'SUP-B-7891', 'Lot principal stylos', 'ADMIN'),
  ('ART003', 'LOT-2026-004-C', 'EX', DATE '2025-09-01', DATE '2026-09-01',
   DATE '2025-09-05', 50, 0, 'SUP-C-3456', 'Péremption dépassée', 'ADMIN'),
  ('ART003', 'LOT-2026-005-C', 'AV', DATE '2026-04-01', DATE '2027-04-01',
   DATE '2026-04-05', 50, 40, 'SUP-C-3789', 'Nouveau lot USB', 'ADMIN');


PROMPT
PROMPT [5] Propositions de réapprovisionnement
INSERT INTO inv_reorder (product_code, generation_date, supplier_code, consumption_rate,
                          min_stock, reorder_qty, lead_time_days,
                          comparison_var, comparison_value, proposed_qty,
                          is_validated, validated_by, validated_at, memo)
VALUES
  ('ART001', SYSDATE, 'FOU001', 5.5,  50, 100, 7, 'MIN_STOCK', 50, 100,
   TRUE, 'ADMIN', SYSDATE, 'Cahiers - conso 5.5/jour, stock min 50'),
  ('ART002', SYSDATE, 'FOU001', 25.0, 100, 500, 5, 'SELL_DAYS', 14, 350,
   FALSE, NULL, NULL, 'Stylos - proposition à valider'),
  ('ART003', SYSDATE, 'FOU002', 1.5,  20, 50, 14, 'MIN_STOCK', 20, 50,
   TRUE, 'ADMIN', SYSDATE, 'USB - conso 1.5/jour');


PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'INV_AVG_COST'           AS tbl, COUNT(*) AS nb FROM inv_avg_cost
UNION ALL SELECT 'INV_PRODUCT_LOT',      COUNT(*) FROM inv_product_lot
UNION ALL SELECT 'INV_STATUS_REF',        COUNT(*) FROM inv_status_ref
UNION ALL SELECT 'INV_STOCK_STATUS',      COUNT(*) FROM inv_stock_status
UNION ALL SELECT 'INV_REORDER',           COUNT(*) FROM inv_reorder
UNION ALL SELECT 'INV_MOVEMENT_STATUS',   COUNT(*) FROM inv_movement_status
UNION ALL SELECT 'INV_COUNT_ZONE',        COUNT(*) FROM inv_count_zone
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Lots expirant dans les 90 prochains jours
SELECT product_code, lot_number, expiry_date, available_qty, lot_status
  FROM inv_product_lot
 WHERE expiry_date BETWEEN SYSDATE AND SYSDATE + 90
   AND lot_status = 'AV'
 ORDER BY expiry_date;

PROMPT [Q2] Lots déjà expirés (action qualité requise)
SELECT product_code, lot_number, expiry_date, lot_status, available_qty
  FROM inv_product_lot
 WHERE expiry_date < SYSDATE
 ORDER BY expiry_date;

PROMPT [Q3] PRMP du mois en cours
SELECT product_code, opening_qty, quantity, amount, closing_qty, avg_cost
  FROM inv_avg_cost
 WHERE period = TO_CHAR(SYSDATE, 'YYYY-MM')
 ORDER BY product_code;

PROMPT [Q4] Statut du stock dans DEP01 (par statut)
SELECT stock_status_code,
       COUNT(DISTINCT product_code) AS nb_products,
       SUM(quantity)                AS total_qty
  FROM inv_stock_status
 WHERE warehouse_code = 'DEP01'
 GROUP BY stock_status_code
 ORDER BY stock_status_code;

PROMPT [Q5] Réappro à valider
SELECT product_code, supplier_code, consumption_rate, min_stock,
       proposed_qty, lead_time_days, comparison_var
  FROM inv_reorder
 WHERE is_validated = FALSE
 ORDER BY product_code;

PROMPT [Q6] Stock total par produit (tous statuts/tous dépôts)
SELECT product_code,
       SUM(quantity) AS total_qty,
       SUM(CASE WHEN stock_status_code = 'AVL' THEN quantity ELSE 0 END) AS dispo_qty,
       SUM(CASE WHEN stock_status_code = 'BLQ' THEN quantity ELSE 0 END) AS bloque_qty
  FROM inv_stock_status
 GROUP BY product_code
 ORDER BY product_code;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R3 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
