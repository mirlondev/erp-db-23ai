-- ============================================================
-- SCRIPT 43 : Package pkg_transfer_stock — Transfers entre emplacements
-- ============================================================
-- Ops stocks entre :
--   - Dépôt → Dépôt (DEP01 ↔ DEP02)
--   - Dépôt → Magasin (DEP01 → POS01) — réapprovisionnement POS
--   - Magasin → Dépôt (POS01 → DEP02) — restitution / surstock
--   - Magasin → Magasin (POS01 ↔ POS02) — équilibrage inter-POS
--
-- Workflow complet : DRAFT → REQUESTED → APPROVED → PACKED → IN_TRANSIT
--                    → RECEIVED → CLOSED (ou CANCELLED)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

PROMPT ══════════════════════════════════════════════════════════
PROMPT   PACKAGE pkg_transfer_stock
PROMPT ══════════════════════════════════════════════════════════

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

CREATE OR REPLACE PACKAGE pkg_transfer_stock AS
  -- Crée un brouillon de transfert
  FUNCTION create_transfer(
    p_source_type      IN VARCHAR2,           -- WAREHOUSE | STORE
    p_source_code      IN VARCHAR2,           -- 'DEP01' ou 'POS01'
    p_target_type      IN VARCHAR2,
    p_target_code      IN VARCHAR2,
    p_company_code     IN VARCHAR2,
    p_transfer_type    IN VARCHAR2,           -- REPLENISHMENT | REBALANCE | RETURN | ADJUSTMENT
    p_priority         IN NUMBER DEFAULT 3,
    p_user_code        IN VARCHAR2
  ) RETURN NUMBER;                           -- retourne transfer_id

  -- Ajoute une ligne au transfert
  PROCEDURE add_line(
    p_transfer_id   IN NUMBER,
    p_product_code  IN VARCHAR2,
    p_quantity      IN NUMBER,
    p_unit_code     IN VARCHAR2 DEFAULT 'UNIT',
    p_lot_number    IN VARCHAR2 DEFAULT NULL
  );

  -- Soumet pour approbation (DRAFT → REQUESTED)
  PROCEDURE submit_for_approval(
    p_transfer_id IN NUMBER,
    p_user_code   IN VARCHAR2
  );

  -- Approuve (REQUESTED → APPROVED)
  PROCEDURE approve_transfer(
    p_transfer_id   IN NUMBER,
    p_user_code     IN VARCHAR2,
    p_total_qty     IN NUMBER DEFAULT NULL
  );

  -- Marque le transfert comme PACKED (sortie de stock source simulée)
  PROCEDURE pack_transfer(
    p_transfer_id IN NUMBER,
    p_user_code   IN VARCHAR2
  );

  -- Marque le transfert comme IN_TRANSIT (transfert physique en cours)
  PROCEDURE ship_transfer(
    p_transfer_id    IN NUMBER,
    p_user_code      IN VARCHAR2,
    p_shipped_qty    IN NUMBER DEFAULT NULL
  );

  -- Réception : met à jour le stock destination + ligne par ligne
  PROCEDURE receive_transfer(
    p_transfer_id IN NUMBER,
    p_user_code   IN VARCHAR2
  );

  -- Annule un transfert (seulement DRAFT ou REQUESTED)
  PROCEDURE cancel_transfer(
    p_transfer_id IN NUMBER,
    p_reason      IN VARCHAR2,
    p_user_code   IN VARCHAR2
  );

  -- Vue synthétique : état d'un transfert (DRAFT, REQUESTED, APPROVED, ...)
  FUNCTION get_transfer_status(
    p_transfer_id IN NUMBER
  ) RETURN VARCHAR2;

  -- Calcul coût total estimé d'un transfert (basé sur standard_price)
  FUNCTION get_estimated_value(p_transfer_id IN NUMBER) RETURN NUMBER;

  -- Liste des transferts en cours (vue pipeline)
  FUNCTION get_active_transfers(p_location_type IN VARCHAR2, p_location_code IN VARCHAR2)
    RETURN SYS_REFCURSOR;

  -- Helper : calcule la quantité disponible pour transfert à un emplacement
  FUNCTION get_available_qty(
    p_location_type IN VARCHAR2,
    p_location_code IN VARCHAR2,
    p_product_code  IN VARCHAR2
  ) RETURN NUMBER;
END pkg_transfer_stock;
/

PROMPT ✓ Spec créée
