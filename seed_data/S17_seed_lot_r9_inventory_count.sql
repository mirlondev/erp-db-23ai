-- ============================================================
-- S17 : Seed LOT R9 (Inventaire physique complet)
-- Données de démo : 1 session inventaire DEP01, 4 zones,
--                    8 lignes comptées (avec écarts et double comptage),
--                    4 ajustements générés.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R9 — Inventaire physique complet
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R9]
BEGIN
  -- Respecter les FK : DETAIL -> ZONE -> HEADER
  EXECUTE IMMEDIATE 'DELETE FROM inventory_adjustment';
  EXECUTE IMMEDIATE 'DELETE FROM inventory_count_detail';
  EXECUTE IMMEDIATE 'DELETE FROM inventory_count_zone';
  COMMIT;
END;
/


PROMPT [0] Création d'un inv_count_header de démo (pour la FK)
INSERT INTO inv_count_header (count_id, count_date, company_code, warehouse_code,
                               release_date, notes, status, created_by)
VALUES (DEFAULT, DATE '2026-09-30', 'COMP01', 'DEP01',
        DATE '2026-10-05', 'Inventaire tournant fin septembre', 'IN_PROGRESS', 'ADMIN');
COMMIT;

DECLARE
  v_count_id NUMBER;
BEGIN
  SELECT MAX(count_id) INTO v_count_id FROM inv_count_header;

  PROMPT [1] 4 zones assignées
  INSERT INTO inventory_count_zone (count_id, warehouse_code, zone_code, zone_name,
                                     assigned_to, assigned_at, started_at, completed_at,
                                     nb_products_expected, nb_products_counted, nb_lines_counted,
                                     variance_value, status)
  VALUES (v_count_id, 'DEP01', 'Z01', 'Papeterie & Bureau',
          'COMPTEUR1', SYSDATE - 3, SYSDATE - 3, SYSDATE - 2,
          25, 25, 28, -1250.50, 'COMPLETED');

  INSERT INTO inventory_count_zone (count_id, warehouse_code, zone_code, zone_name,
                                     assigned_to, assigned_at, started_at, completed_at,
                                     nb_products_expected, nb_products_counted, nb_lines_counted,
                                     variance_value, status)
  VALUES (v_count_id, 'DEP01', 'Z02', 'Informatique',
          'COMPTEUR2', SYSDATE - 3, SYSDATE - 3, SYSDATE - 2,
          15, 15, 18, 12450.00, 'COMPLETED');

  INSERT INTO inventory_count_zone (count_id, warehouse_code, zone_code, zone_name,
                                     assigned_to, assigned_at, started_at,
                                     nb_products_expected, nb_products_counted, nb_lines_counted,
                                     status)
  VALUES (v_count_id, 'DEP01', 'Z03', 'Réserve arrière',
          'COMPTEUR3', SYSDATE - 1, SYSDATE - 1,
          10, 6, 8, 'IN_PROGRESS');

  INSERT INTO inventory_count_zone (count_id, warehouse_code, zone_code, zone_name,
                                     nb_products_expected, status)
  VALUES (v_count_id, 'DEP01', 'Z04', 'Vitrine & PLV',
          8, 'PENDING');

  COMMIT;


  PROMPT [2] 8 lignes détaillées (mix double-comptage et écart)
  -- ART001 (zone Z01, double comptage cohérent)
  INSERT INTO inventory_count_detail (zone_id, product_code, theoretical_qty,
                                       counted_qty_1, counted_qty_2, counted_qty_final,
                                       unit_cost, is_blind_count,
                                       counted_by_1, counted_by_2,
                                       counted_at_1, counted_at_2)
  VALUES (1, 'ART001', 95,
          93, 93, 93, 1800, TRUE,
          'COMPTEUR1', 'COMPTEUR4',
          SYSDATE - 3, SYSDATE - 3);

  -- ART002 (zone Z01, écart simple -5)
  INSERT INTO inventory_count_detail (zone_id, product_code, theoretical_qty,
                                       counted_qty_1, counted_qty_2, counted_qty_final,
                                       unit_cost, is_blind_count,
                                       counted_by_1, counted_by_2,
                                       counted_at_1, counted_at_2,
                                       notes)
  VALUES (1, 'ART002', 425,
          420, 420, 420, 350, TRUE,
          'COMPTEUR1', 'COMPTEUR4',
          SYSDATE - 3, SYSDATE - 3,
          'Casse identifiée à la deuxième vérification');

  -- ART003 (zone Z02, écart positif)
  INSERT INTO inventory_count_detail (zone_id, product_code, theoretical_qty,
                                       counted_qty_1, counted_qty_2, counted_qty_final,
                                       unit_cost, is_blind_count,
                                       counted_by_1, counted_by_2,
                                       counted_at_1, counted_at_2)
  VALUES (2, 'ART003', 35,
          38, 38, 38, 11000, TRUE,
          'COMPTEUR2', 'COMPTEUR5',
          SYSDATE - 3, SYSDATE - 3);

  -- ART004 (zone Z02, écart négatif important)
  INSERT INTO inventory_count_detail (zone_id, product_code, theoretical_qty,
                                       counted_qty_1, counted_qty_2, counted_qty_final,
                                       unit_cost, is_blind_count,
                                       counted_by_1, counted_by_2,
                                       counted_at_1, counted_at_2,
                                       notes)
  VALUES (2, 'ART004', 50,
          42, 42, 42, 250, TRUE,
          'COMPTEUR2', 'COMPTEUR5',
          SYSDATE - 3, SYSDATE - 3,
          'Différence inexpliquée - à investiguer');

  -- ART005 (zone Z03 en cours, single count)
  INSERT INTO inventory_count_detail (zone_id, product_code, theoretical_qty,
                                       counted_qty_1, counted_qty_final,
                                       unit_cost, is_blind_count,
                                       counted_by_1, counted_at_1)
  VALUES (3, 'ART005', 200,
          198, 198, 150, TRUE,
          'COMPTEUR3', SYSDATE - 1);

  COMMIT;
END;
/


PROMPT [3] 4 ajustements post-comptage (générés à partir des écarts)
INSERT INTO inventory_adjustment (count_id, product_code, warehouse_code,
                                   old_qty, new_qty, unit_cost,
                                   reason, approved_by, approved_at, posted_to_stock, created_by)
VALUES (1, 'ART001', 'DEP01',
        95, 93, 1800,
        'COUNT_ERROR', 'MANAGER1', SYSDATE - 1, TRUE, 'ADMIN');

INSERT INTO inventory_adjustment (count_id, product_code, warehouse_code,
                                   old_qty, new_qty, unit_cost,
                                   reason, approved_by, approved_at, posted_to_stock, created_by)
VALUES (1, 'ART002', 'DEP01',
        425, 420, 350,
        'BREAKAGE', 'MANAGER1', SYSDATE - 1, TRUE, 'ADMIN');

INSERT INTO inventory_adjustment (count_id, product_code, warehouse_code,
                                   old_qty, new_qty, unit_cost,
                                   reason, approved_by, approved_at, posted_to_stock, created_by)
VALUES (1, 'ART003', 'DEP01',
        35, 38, 11000,
        'FOUND', 'MANAGER1', SYSDATE - 1, FALSE, 'ADMIN');

INSERT INTO inventory_adjustment (count_id, product_code, warehouse_code,
                                   old_qty, new_qty, unit_cost,
                                   reason, approved_by, approved_at, posted_to_stock, created_by)
VALUES (1, 'ART004', 'DEP01',
        50, 42, 250,
        'THEFT', 'MANAGER2', SYSDATE, FALSE, 'ADMIN');

COMMIT;


PROMPT [4] Application des ajustements sur inv_stock (génération inv_movement)
-- Cette partie simule un trigger ou un batch qui :
--   1) pour chaque adjustment posted_to_stock=FALSE
--   2) crée un inv_movement + maj inv_stock
BEGIN
  FOR adj IN (SELECT * FROM inventory_adjustment WHERE posted_to_stock = FALSE) LOOP
    -- Création du mouvement
    INSERT INTO inv_movement (movement_date, warehouse_code, product_code,
                              movement_type, direction, quantity, unit_cost,
                              document_type, document_id, notes, created_by)
    VALUES (SYSDATE, adj.warehouse_code, adj.product_code,
            'ADJ', 'O', -adj.adjustment_qty, adj.unit_cost,
            'INV_ADJ', adj.adjustment_id, 'Ajustement inventaire #'||adj.adjustment_id, 'ADMIN');

    -- Mise à jour du stock
    UPDATE inv_stock
       SET stock_qty   = stock_qty + adj.adjustment_qty,
           updated_at  = SYSTIMESTAMP,
           last_count_at = SYSDATE
     WHERE warehouse_code = adj.warehouse_code
       AND product_code   = adj.product_code;

    -- Marquer comme posté
    UPDATE inventory_adjustment
       SET posted_to_stock = TRUE
     WHERE adjustment_id = adj.adjustment_id;
  END LOOP;

  -- Mise à jour du statut du count
  UPDATE inv_count_header
     SET status = 'VALIDATED',
         release_date = SYSDATE
   WHERE count_id = 1;

  COMMIT;
END;
/


PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'INV_COUNT_HEADER'         AS tbl, COUNT(*) AS nb FROM inv_count_header
UNION ALL SELECT 'INVENTORY_COUNT_ZONE',   COUNT(*) FROM inventory_count_zone
UNION ALL SELECT 'INVENTORY_COUNT_DETAIL', COUNT(*) FROM inventory_count_detail
UNION ALL SELECT 'INVENTORY_ADJUSTMENT',   COUNT(*) FROM inventory_adjustment
UNION ALL SELECT 'INV_MOVEMENT',           COUNT(*) FROM inv_movement
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Zones de l'inventaire DEP01
SELECT zone_code, zone_name, assigned_to, status,
       nb_products_counted, variance_value
  FROM inventory_count_zone
 WHERE warehouse_code = 'DEP01'
 ORDER BY zone_code;

PROMPT [Q2] Écarts identifiés (par produit)
SELECT d.product_code,
       d.theoretical_qty,
       d.counted_qty_final,
       d.variance_qty,
       d.variance_value,
       a.reason
  FROM inventory_count_detail d
  LEFT JOIN inventory_adjustment a ON a.product_code = d.product_code
                                  AND a.warehouse_code = 'DEP01'
                                  AND a.count_id = 1
 ORDER BY ABS(d.variance_qty) DESC;

PROMPT [Q3] Ajustements par motif (top pertes)
SELECT reason,
       COUNT(*)               AS nb_ajustements,
       SUM(adjustment_qty)    AS qty_ajustee,
       SUM(adjustment_value)  AS valeur_impact
  FROM inventory_adjustment
 GROUP BY reason
 ORDER BY valeur_impact;

PROMPT [Q4] Taux d'écart par compteur
SELECT z.assigned_to,
       COUNT(d.detail_id)             AS nb_lignes,
       SUM(NVL(d.variance_qty, 0))    AS variance_totale,
       SUM(NVL(d.variance_value, 0))  AS valeur_variance,
       ROUND(AVG(ABS(NVL(d.variance_qty, 0))), 2) AS ecart_moyen
  FROM inventory_count_zone z
  JOIN inventory_count_detail d ON d.zone_id = z.zone_id
 GROUP BY z.assigned_to
 ORDER BY valeur_variance;

PROMPT [Q5] Ajustements non postés (à traiter)
SELECT adjustment_id, product_code, warehouse_code,
       adjustment_qty, reason, created_at
  FROM inventory_adjustment
 WHERE posted_to_stock = FALSE;

PROMPT [Q6] Inventaires validés
SELECT count_id, count_date, warehouse_code, status, release_date
  FROM inv_count_header
 ORDER BY count_date DESC;

PROMPT [Q7] Résumé global de l'inventaire DEP01
SELECT
  (SELECT COUNT(*) FROM inventory_count_zone WHERE warehouse_code = 'DEP01' AND count_id = 1)     AS nb_zones,
  (SELECT COUNT(*) FROM inventory_count_detail d JOIN inventory_count_zone z ON z.zone_id=d.zone_id
                                                WHERE z.warehouse_code='DEP01' AND z.count_id=1)  AS nb_lignes,
  (SELECT COUNT(*) FROM inventory_adjustment WHERE warehouse_code = 'DEP01' AND count_id = 1)   AS nb_adjustments,
  (SELECT SUM(adjustment_value) FROM inventory_adjustment WHERE warehouse_code='DEP01' AND count_id=1) AS valeur_ajustement,
  (SELECT COUNT(*) FROM inventory_adjustment WHERE warehouse_code='DEP01' AND count_id=1 AND posted_to_stock=TRUE) AS nb_posted
FROM DUAL;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R9 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
