-- ============================================================
-- SCRIPT 25 : LOT R9 — Inventaire physique complet
-- Migration Oracle 11g (zones inventaire mobile + ajustements post-comptage)
--                  → Oracle 23ai/26ai (app_inv)
-- ============================================================
-- 3 nouvelles tables dans app_inv :
--   inventory_count_zone,  inventory_count_detail,  inventory_adjustment
--
-- IMPORTANT — nomenclature :
--   R9 introduit inventory_count_zone (organisation, assignation aux compteurs)
--   Différent de inv_count_zone (R3 = détail ligne, legacy GCINVD_ZONE)
--   Les deux sont conservés intentionnellement :
--    * inv_count_zone (R3)         = lignes détaillées du comptage (qty_inv_st/ex/ca/av)
--    * inventory_count_zone (R9)   = zones physiques assignées aux compteurs
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R9 : INVENTAIRE PHYSIQUE COMPLET (3 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/3] inventory_count_zone  — zones physiques d'inventaire (vs inv_count_zone R3 = détail)
CREATE TABLE inventory_count_zone (
  zone_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  count_id            NUMBER        NOT NULL,             -- FK vers inv_count_header (R3)
  warehouse_code      VARCHAR2(5)   NOT NULL,
  zone_code           VARCHAR2(8)   NOT NULL,              -- ex. 'Z01', 'Z02-RESERVE'
  zone_name           VARCHAR2(60),
  assigned_to         VARCHAR2(20),                        -- code compteur
  assigned_at         TIMESTAMP,
  started_at          TIMESTAMP,
  completed_at        TIMESTAMP,
  nb_products_expected NUMBER(6),                          -- estimation pour planification
  nb_products_counted  NUMBER(6)     DEFAULT 0,
  nb_lines_counted     NUMBER(8)     DEFAULT 0,
  variance_value      NUMBER(16,4)  DEFAULT 0,             -- somme des écarts de la zone
  status              VARCHAR2(20)  DEFAULT 'PENDING',     -- PENDING | IN_PROGRESS | COMPLETED | RECONCILED | CANCELLED
  CONSTRAINT pk_inventory_count_zone        PRIMARY KEY (zone_id),
  CONSTRAINT uk_inventory_zone              UNIQUE (count_id, warehouse_code, zone_code),
  CONSTRAINT fk_inventory_zone_hdr          FOREIGN KEY (count_id)
    REFERENCES inv_count_header(count_id) ON DELETE CASCADE,
  CONSTRAINT ck_inventory_zone_status       CHECK (status IN ('PENDING','IN_PROGRESS','COMPLETED','RECONCILED','CANCELLED')),
  CONSTRAINT ck_inventory_zone_counts       CHECK (NB_PRODUCTS_COUNTED >= 0 AND NB_LINES_COUNTED >= 0)
);

CREATE INDEX ix_inventory_zone_status     ON inventory_count_zone(status);
CREATE INDEX ix_inventory_zone_assigned   ON inventory_count_zone(assigned_to);

PROMPT
PROMPT [2/3] inventory_count_detail  — détails comptés par ligne produit/zone
CREATE TABLE inventory_count_detail (
  detail_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  zone_id             NUMBER        NOT NULL,             -- FK vers inventory_count_zone (R9) ≠ inv_count_zone (R3)
  product_code        VARCHAR2(80)  NOT NULL,
  lot_number          VARCHAR2(20),                        -- si gestion par lot
  theoretical_qty     NUMBER(16,4),                        -- stock théorique avant comptage
  counted_qty_1       NUMBER(16,4),                        -- 1er comptage (aveugle)
  counted_qty_2       NUMBER(16,4),                        -- 2eme comptage (vérification)
  counted_qty_final   NUMBER(16,4),                        -- comptage définitif (saisi ou moyenne)
  variance_qty        NUMBER(16,4),                        -- counted_qty_final - theoretical_qty
  unit_cost           NUMBER(16,4),
  variance_value      NUMBER(16,4)  GENERATED ALWAYS AS (variance_qty * unit_cost),
  counted_by_1        VARCHAR2(20),
  counted_by_2        VARCHAR2(20),
  counted_at_1        TIMESTAMP,
  counted_at_2        TIMESTAMP,
  is_blind_count      BOOLEAN       DEFAULT TRUE,          -- compteur ne voit pas le théorique
  notes               VARCHAR2(500),
  CONSTRAINT pk_inventory_count_detail         PRIMARY KEY (detail_id),
  CONSTRAINT fk_inventory_detail_zone          FOREIGN KEY (zone_id)
    REFERENCES inventory_count_zone(zone_id) ON DELETE CASCADE,
  CONSTRAINT ck_inventory_detail_qty           CHECK (theoretical_qty IS NULL OR theoretical_qty >= 0),
  CONSTRAINT ck_inventory_detail_counted        CHECK ((counted_qty_1 IS NULL OR counted_qty_1 >= 0)
                                                     AND (counted_qty_2 IS NULL OR counted_qty_2 >= 0)
                                                     AND (counted_qty_final IS NULL OR counted_qty_final >= 0))
);

CREATE INDEX ix_inv_detail_prod                ON inventory_count_detail(product_code);
CREATE INDEX ix_inv_detail_lot                 ON inventory_count_detail(lot_number);

PROMPT
PROMPT [3/3] inventory_adjustment  — ajustements de stock post-comptage
CREATE TABLE inventory_adjustment (
  adjustment_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  count_id            NUMBER        NOT NULL,
  product_code        VARCHAR2(80)  NOT NULL,
  warehouse_code      VARCHAR2(5)   NOT NULL,
  old_qty             NUMBER(16,4),                        -- stock avant
  new_qty             NUMBER(16,4),                        -- stock après
  adjustment_qty      NUMBER(16,4)  GENERATED ALWAYS AS (new_qty - old_qty),
  unit_cost           NUMBER(16,4),
  adjustment_value    NUMBER(16,4)  GENERATED ALWAYS AS ((new_qty - old_qty) * unit_cost),
  reason              VARCHAR2(255),                        -- THEFT | BREAKAGE | COUNT_ERROR | EXPIRED | OTHER
  movement_id         NUMBER,                              -- FK vers inv_movement (créé automatiquement)
  approved_by         VARCHAR2(20),
  approved_at         TIMESTAMP,
  posted_to_stock     BOOLEAN       DEFAULT FALSE,         -- déjà impacté sur inv_stock ?
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_inventory_adjustment        PRIMARY KEY (adjustment_id),
  CONSTRAINT fk_inv_adjust_hdr              FOREIGN KEY (count_id)
    REFERENCES inv_count_header(count_id) ON DELETE CASCADE,
  CONSTRAINT ck_inv_adjust_reason           CHECK (reason IS NULL OR reason IN
    ('THEFT','BREAKAGE','COUNT_ERROR','EXPIRED','FOUND','DAMAGED','RECLASSIFICATION','OTHER'))
);

CREATE INDEX ix_inv_adjust_count             ON inventory_adjustment(count_id);
CREATE INDEX ix_inv_adjust_product           ON inventory_adjustment(product_code, warehouse_code);
CREATE INDEX ix_inv_adjust_posted            ON inventory_adjustment(posted_to_stock);
CREATE INDEX ix_inv_adjust_reason            ON inventory_adjustment(reason);

PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

-- app_api lit tout (reporting inventaire)
GRANT SELECT ON app_inv.inventory_count_zone   TO app_api;
GRANT SELECT ON app_inv.inventory_count_detail TO app_api;
GRANT SELECT ON app_inv.inventory_adjustment   TO app_api;

-- app_gl pour impact comptable des écarts
GRANT SELECT ON app_inv.inventory_adjustment   TO app_gl;

-- app_party pour bloquer les clients sur stock manquant
-- (pas nécessaire ici, mais app_inv.product fait déjà le lien via parties)

PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('INVENTORY_COUNT_ZONE','INVENTORY_COUNT_DETAIL','INVENTORY_ADJUSTMENT')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('INVENTORY_COUNT_ZONE','INVENTORY_COUNT_DETAIL','INVENTORY_ADJUSTMENT')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R9 TERMINÉ (3 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
