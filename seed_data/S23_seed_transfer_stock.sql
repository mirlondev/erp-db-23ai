-- ============================================================
-- S23 : Seed pkg_transfer_stock + scénarios réalistes
-- ============================================================
-- Démonstration :
--   1. Réappro DÉPÔT → MAGASIN (DEP01 → FP1)
--   2. Réappro DÉPÔT → MAGASIN (DEP01 → B01)
--   3. Rééquilibrage MAGASIN → DÉPÔT (B01 → DEP02)
--   4. Transfert inter-dépôts DEP01 → DEP02 (rééquilibrage régional)
--   5. Workflow complet : DRAFT → CLOSED
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED TRANSFERTS STOCK (pkg_transfer_stock demo)
PROMPT ══════════════════════════════════════════════════════════

DECLARE
  -- Variables globales
  v_tid NUMBER;
  v_value NUMBER(16,4);

  -----------------------------------------------------------------
  -- Transfert 1 : Réappro DEP01 → FP1
  -----------------------------------------------------------------
  PROCEDURE demo_depot_to_store IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('--- 1. DEP01 → FP1 : Réappro 31275 ---');
    v_tid := pkg_transfer_stock.create_transfer(
      p_source_type    => 'WAREHOUSE',
      p_source_code    => 'DEP01',
      p_target_type    => 'STORE',
      p_target_code    => 'FP1',
      p_company_code   => 'COMP01',
      p_transfer_type  => 'REPLENISHMENT',
      p_priority       => 4,
      p_user_code      => 'INVENTORY'
    );
    pkg_transfer_stock.add_line(v_tid, '31275', 5, 'PCS', NULL);
    pkg_transfer_stock.add_line(v_tid, '31276', 2, 'PCS', NULL);
    pkg_transfer_stock.submit_for_approval(v_tid, 'INVENTORY');
    pkg_transfer_stock.approve_transfer(v_tid, 'MANAGER1', 150);
    pkg_transfer_stock.pack_transfer(v_tid, 'INVENTORY');
    pkg_transfer_stock.ship_transfer(v_tid, 'INVENTORY');
    pkg_transfer_stock.receive_transfer(v_tid, 'CAISSIER1');
    DBMS_OUTPUT.PUT_LINE('   Transfert # ' || v_tid || ' complet. Valeur: ' || pkg_transfer_stock.get_estimated_value(v_tid));
  EXCEPTION WHEN OTHERS THEN
    RAISE;
  END demo_depot_to_store;

  -----------------------------------------------------------------
  -- Transfert 2 : Réappro DEP01 → B01 — produit 19889
  -----------------------------------------------------------------
  PROCEDURE demo_depot_to_store_2 IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('--- 2. DEP01 → B01 : produit 19889 ---');
    v_tid := pkg_transfer_stock.create_transfer(
      p_source_type    => 'WAREHOUSE',
      p_source_code    => 'DEP01',
      p_target_type    => 'STORE',
      p_target_code    => 'B01',
      p_company_code   => 'COMP01',
      p_transfer_type  => 'REPLENISHMENT',
      p_priority       => 5,
      p_user_code      => 'INVENTORY'
    );
    pkg_transfer_stock.add_line(v_tid, '19889', 10, 'PCS', NULL);
    pkg_transfer_stock.submit_for_approval(v_tid, 'INVENTORY');
    pkg_transfer_stock.approve_transfer(v_tid, 'MANAGER1', 30);
    pkg_transfer_stock.pack_transfer(v_tid, 'INVENTORY');
    pkg_transfer_stock.ship_transfer(v_tid, 'INVENTORY');
    pkg_transfer_stock.receive_transfer(v_tid, 'CAISSIER2');
    DBMS_OUTPUT.PUT_LINE('   Transfert USB OK.');
  EXCEPTION WHEN OTHERS THEN
    RAISE;
  END demo_depot_to_store_2;

  -----------------------------------------------------------------
  -- Transfert 3 : Store → Dépôt (B01 → DEP02, excédent)
  -----------------------------------------------------------------
  PROCEDURE demo_store_to_depot IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('--- 3. B01 → DEP02 : Excédent produit 31275 ---');
    v_tid := pkg_transfer_stock.create_transfer(
      p_source_type    => 'STORE',
      p_source_code    => 'B01',
      p_target_type    => 'WAREHOUSE',
      p_target_code    => 'DEP02',
      p_company_code   => 'COMP01',
      p_transfer_type  => 'RETURN',
      p_priority       => 3,
      p_user_code      => 'MANAGER1'
    );
    pkg_transfer_stock.add_line(v_tid, '31275', 1, 'PCS', NULL);
    pkg_transfer_stock.submit_for_approval(v_tid, 'MANAGER1');
    pkg_transfer_stock.approve_transfer(v_tid, 'DIRECTOR', 25);
    pkg_transfer_stock.pack_transfer(v_tid, 'CAISSIER2');
    pkg_transfer_stock.ship_transfer(v_tid, 'CAISSIER2');
    pkg_transfer_stock.receive_transfer(v_tid, 'INVENTORY');
    DBMS_OUTPUT.PUT_LINE('   Restitution effectuée.');
  EXCEPTION WHEN OTHERS THEN
    RAISE;
  END demo_store_to_depot;

  -----------------------------------------------------------------
  -- Transfert 4 : Inter-dépôts DEP01 → DEP02
  -----------------------------------------------------------------
  PROCEDURE demo_inter_depot IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('--- 4. DEP01 → DEP02 : Rééquilibrage régional cahiers ---');
    v_tid := pkg_transfer_stock.create_transfer(
      p_source_type    => 'WAREHOUSE',
      p_source_code    => 'DEP01',
      p_target_type    => 'WAREHOUSE',
      p_target_code    => 'DEP02',
      p_company_code   => 'COMP01',
      p_transfer_type  => 'REBALANCE',
      p_priority       => 3,
      p_user_code      => 'INVENTORY'
    );
    pkg_transfer_stock.add_line(v_tid, '31275', 1, 'PCS', NULL);
    pkg_transfer_stock.submit_for_approval(v_tid, 'INVENTORY');
    pkg_transfer_stock.approve_transfer(v_tid, 'MANAGER1', 200);
    pkg_transfer_stock.pack_transfer(v_tid, 'INVENTORY');
    pkg_transfer_stock.ship_transfer(v_tid, 'INVENTORY');
    pkg_transfer_stock.receive_transfer(v_tid, 'INVENTORY');
    DBMS_OUTPUT.PUT_LINE('   Rééquilibrage DEP02 effectué.');
  EXCEPTION WHEN OTHERS THEN
    RAISE;
  END demo_inter_depot;

  -----------------------------------------------------------------
  -- Transfert 5 : En cours (DEMO) - brouillon pour montrer le pipeline
  -----------------------------------------------------------------
  PROCEDURE demo_in_progress IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('--- 5. EN COURS : DEP01 → FP1 (en attente approbation) ---');
    v_tid := pkg_transfer_stock.create_transfer(
      p_source_type    => 'WAREHOUSE',
      p_source_code    => 'DEP01',
      p_target_type    => 'STORE',
      p_target_code    => 'FP1',
      p_company_code   => 'COMP01',
      p_transfer_type  => 'REPLENISHMENT',
      p_priority       => 2,
      p_user_code      => 'INVENTORY'
    );
    pkg_transfer_stock.add_line(v_tid, '31275', 2, 'PCS', NULL);
    pkg_transfer_stock.add_line(v_tid, '31276', 1, 'PCS', NULL);
    pkg_transfer_stock.add_line(v_tid, '19889', 1, 'PCS', NULL);
    pkg_transfer_stock.submit_for_approval(v_tid, 'INVENTORY');
    DBMS_OUTPUT.PUT_LINE('   Transfert en attente approbation manager.');
  EXCEPTION WHEN OTHERS THEN
    RAISE;
  END demo_in_progress;

  -----------------------------------------------------------------
  -- Transfert 6 : Annulé - brouillon abandonné
  -----------------------------------------------------------------
  PROCEDURE demo_cancelled IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('--- 6. ANNULÉ : DEMO cancellation ---');
    v_tid := pkg_transfer_stock.create_transfer(
      p_source_type    => 'WAREHOUSE',
      p_source_code    => 'DEP01',
      p_target_type    => 'WAREHOUSE',
      p_target_code    => 'DEP02',
      p_company_code   => 'COMP01',
      p_transfer_type  => 'ADJUSTMENT',
      p_priority       => 5,
      p_user_code      => 'INVENTORY'
    );
    pkg_transfer_stock.add_line(v_tid, '31275', 1, 'PCS', NULL);
    pkg_transfer_stock.submit_for_approval(v_tid, 'INVENTORY');
    pkg_transfer_stock.cancel_transfer(v_tid, 'Erreur de saisie - annule avant approbation', 'INVENTORY');
    DBMS_OUTPUT.PUT_LINE('   Transfert correctement annulé.');
  EXCEPTION WHEN OTHERS THEN
    RAISE;
  END demo_cancelled;

BEGIN
  demo_depot_to_store;
  demo_depot_to_store_2;
  demo_store_to_depot;
  demo_inter_depot;
  demo_in_progress;
  demo_cancelled;
END;
/

COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'TRANSFER_HEADER'         AS tbl, COUNT(*) AS nb FROM transfer_header
UNION ALL SELECT 'TRANSFER_LINE',           COUNT(*) FROM transfer_line
UNION ALL SELECT 'INV_STOCK',              COUNT(*) FROM inv_stock
UNION ALL SELECT 'INV_MOVEMENT',           COUNT(*) FROM inv_movement
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Tous les transferts par statut
SELECT status, COUNT(*) AS nb,
       SUM(total_qty) AS qty_totale
  FROM transfer_header
 GROUP BY status
 ORDER BY DECODE(status, 'DRAFT',1,'REQUESTED',2,'APPROVED',3,'PACKED',4,'IN_TRANSIT',5,'RECEIVED',6,'CLOSED',7,'CANCELLED',99);

PROMPT [Q2] Transferts du dernier mois par type
SELECT transfer_number, source_warehouse, target_warehouse,
       status, total_qty, transfer_date
  FROM transfer_header
 ORDER BY transfer_date DESC
 FETCH FIRST 10 ROWS ONLY;

PROMPT [Q3] État du stock par dépôt (post-transferts)
SELECT warehouse_code,
       COUNT(DISTINCT product_code) AS nb_references,
       SUM(stock_qty) AS total_unites
  FROM inv_stock
 GROUP BY warehouse_code
 ORDER BY warehouse_code;

PROMPT [Q4] Mouvements INV_MOVEMENT issus de transferts
SELECT movement_type, direction, COUNT(*) AS nb,
       SUM(quantity) AS total_qty
  FROM inv_movement
 WHERE movement_type = 'TRANSFER'
 GROUP BY movement_type, direction
 ORDER BY direction DESC;

PROMPT [Q5] Pipeline : transferts en attente ou en cours
SELECT transfer_number, source_warehouse, target_warehouse,
       total_qty, status, transfer_date
  FROM transfer_header
 WHERE status NOT IN ('CLOSED','CANCELLED')
 ORDER BY transfer_date;

PROMPT [Q6] Audit log des transferts (sys_audit_trail)
SELECT user_code, action_type,
       JSON_VALUE(new_values, '$.status') AS new_status,
       performed_at,
       severity
  FROM app_sys.sys_audit_trail
 WHERE entity_type = 'app_inv.transfer_header'
 ORDER BY performed_at DESC
 FETCH FIRST 10 ROWS ONLY;

PROMPT [Q7] Délai moyen entre création et réception
SELECT AVG(SYSDATE - transfer_date) AS avg_days_in_process,
       MIN(SYSDATE - transfer_date) AS min_days,
       MAX(SYSDATE - transfer_date) AS max_days
  FROM transfer_header
 WHERE status = 'CLOSED';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED TRANSFERTS TERMINÉ
PROMPT   4 transferts complets DEP01↔POS01, DEP01→POS02, etc.
PROMPT   1 transfert en attente (REQUESTED)
PROMPT   1 transfert annulé
PROMPT ══════════════════════════════════════════════════════════
EXIT;
