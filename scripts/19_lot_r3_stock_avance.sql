-- ============================================================
-- SCRIPT 19 : LOT R3 — Stock avancé
-- Migration Oracle 11g (GCPRMP, GCPART_LOT, GCSTOCK_STATUT, etc.)
--                  → Oracle 23ai/26ai (app_inv)
-- ============================================================
-- 7 nouvelles tables (procedure.txt en listait 8, mais inv_stock_alert
-- existe déjà — donc on l'ignore, comme indiqué dans la procédure) :
--   inv_avg_cost, inv_product_lot, inv_stock_status, inv_status_ref,
--   inv_count_zone, inv_movement_status, inv_reorder
--
-- Modernisations vs legacy 11g :
--  * BOOLEAN pour is_sale_allowed, reverse_qty_update, auto_entry, is_active
--  * user_code VARCHAR2(20) (vs 5 trop court)
--  * CHECKs explicites (quantités >= 0)
--  * Index ciblés sur les colonnes de reporting (expiry_date, period)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R3 : STOCK AVANCÉ (7 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/7] inv_avg_cost  (← GCPRMP) — coût moyen pondéré par période
CREATE TABLE inv_avg_cost (
  company_code        VARCHAR2(12)  NOT NULL,
  period              VARCHAR2(24)  NOT NULL,             -- ex. '2026-09' (mensuel)
  product_code        VARCHAR2(80)  NOT NULL,
  opening_qty         NUMBER(16,4)  DEFAULT 0,            -- stock initial de la période
  quantity            NUMBER(16,4)  DEFAULT 0,            -- entrées totales
  amount              NUMBER(16,4)  DEFAULT 0,            -- valeur des entrées
  closing_qty         NUMBER(16,4)  DEFAULT 0,            -- stock final
  avg_cost            NUMBER(16,4),                        -- PRMP calculé
  computed_at         TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_inv_avg_cost          PRIMARY KEY (company_code, period, product_code),
  CONSTRAINT ck_inv_avg_cost_qty       CHECK (quantity >= 0 AND opening_qty >= 0 AND closing_qty >= 0),
  CONSTRAINT ck_inv_avg_cost_amount    CHECK (amount >= 0),
  CONSTRAINT ck_inv_avg_cost_avg       CHECK (avg_cost IS NULL OR avg_cost >= 0)
);

CREATE INDEX ix_inv_avg_cost_prod      ON inv_avg_cost(product_code);
CREATE INDEX ix_inv_avg_cost_period    ON inv_avg_cost(period);

PROMPT
PROMPT [2/7] inv_product_lot  (← GCPART_LOT) — gestion des lots produit
CREATE TABLE inv_product_lot (
  product_code        VARCHAR2(80)  NOT NULL,
  lot_number          VARCHAR2(20)  NOT NULL,
  lot_status          VARCHAR2(2)   DEFAULT 'AV',         -- AV=Available, BL=Blocked, EX=Expired, RS=Reserved
  manufacturing_date  DATE,
  expiry_date         DATE          NOT NULL,
  received_date       DATE          DEFAULT SYSDATE,
  lot_qty             NUMBER(16,4)  DEFAULT 0,
  available_qty       NUMBER(16,4)  DEFAULT 0,
  supplier_lot_ref    VARCHAR2(40),
  memo                VARCHAR2(255),
  updated_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by          VARCHAR2(20)  NOT NULL,
  CONSTRAINT pk_inv_product_lot       PRIMARY KEY (product_code, lot_number),
  CONSTRAINT ck_inv_product_lot_status CHECK (lot_status IN ('AV','BL','EX','RS')),
  CONSTRAINT ck_inv_product_lot_qty   CHECK (lot_qty >= 0 AND available_qty >= 0)
);

CREATE INDEX ix_inv_product_lot_exp    ON inv_product_lot(expiry_date);
CREATE INDEX ix_inv_product_lot_status ON inv_product_lot(lot_status);
CREATE INDEX ix_inv_product_lot_prod   ON inv_product_lot(product_code, expiry_date);

PROMPT
PROMPT [3/7] inv_status_ref  (← GCPSTATUT) — référentiel des statuts de stock
CREATE TABLE inv_status_ref (
  status_code         VARCHAR2(3)   NOT NULL,
  status_name         VARCHAR2(60)  NOT NULL,
  is_active           BOOLEAN       DEFAULT TRUE,
  is_sale_allowed     BOOLEAN       DEFAULT TRUE,          -- peut-on vendre ce statut ?
  reverse_qty_update  BOOLEAN       DEFAULT FALSE,         -- annulation met-elle à jour le stock ?
  auto_entry          BOOLEAN       DEFAULT FALSE,         -- entrée auto lors d'un mouvement
  display_order       NUMBER(3),
  memo                VARCHAR2(255),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  created_by          VARCHAR2(20)  NOT NULL,
  updated_at          TIMESTAMP,
  updated_by          VARCHAR2(20),
  CONSTRAINT pk_inv_status_ref        PRIMARY KEY (status_code)
);

PROMPT
PROMPT [4/7] inv_stock_status  (← GCSTOCK_STATUT) — quantités par statut
CREATE TABLE inv_stock_status (
  product_code        VARCHAR2(80)  NOT NULL,
  warehouse_code      VARCHAR2(5)   NOT NULL,
  stock_status_code   VARCHAR2(3)   NOT NULL,
  quantity            NUMBER(15,3)  DEFAULT 0,
  last_movement_at    DATE,
  CONSTRAINT pk_inv_stock_status      PRIMARY KEY (product_code, warehouse_code, stock_status_code),
  CONSTRAINT fk_inv_stock_status_ref  FOREIGN KEY (stock_status_code)
    REFERENCES inv_status_ref(status_code),
  CONSTRAINT ck_inv_stock_status_qty  CHECK (quantity >= 0)
);

CREATE INDEX ix_inv_stock_status_prod ON inv_stock_status(product_code);
CREATE INDEX ix_inv_stock_status_wh   ON inv_stock_status(warehouse_code);

PROMPT
PROMPT [5/7] inv_count_zone  (← GCINVD_ZONE) — sous-lignes d'inventaire par zone
CREATE TABLE inv_count_zone (
  count_id            NUMBER        NOT NULL,
  warehouse_code      VARCHAR2(5)   NOT NULL,
  zone_number         VARCHAR2(8)   NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  product_code        VARCHAR2(80)  NOT NULL,
  qty_inv_st          NUMBER(16,4),                         -- stock théorique
  qty_inv_ex          NUMBER(16,4),                         -- explication écart
  qty_inv_ca          NUMBER(16,4),                         -- écart calculé (qty_inv - qty_inv_st)
  qty_inv_av          NUMBER(16,4),                         -- écart validé
  qty_inv             NUMBER(16,4),                         -- compté physique
  expiry_date         DATE,
  unit_code           VARCHAR2(12),
  coefficient         NUMBER(10,5),
  user_code           VARCHAR2(20),
  updated_at          TIMESTAMP,
  CONSTRAINT pk_inv_count_zone          PRIMARY KEY (count_id, warehouse_code, zone_number, line_no),
  CONSTRAINT fk_inv_count_zone_hdr      FOREIGN KEY (count_id)
    REFERENCES inv_count_header(count_id) ON DELETE CASCADE,
  CONSTRAINT ck_inv_count_zone_nonneg   CHECK (qty_inv_st IS NULL OR qty_inv_st >= 0)
);

CREATE INDEX ix_inv_count_zone_prod     ON inv_count_zone(product_code);

PROMPT
PROMPT [6/7] inv_movement_status — liaison mouvement ↔ statuts (FEFO/FIFO par statut)
CREATE TABLE inv_movement_status (
  movement_id         NUMBER        NOT NULL,
  stock_status_code   VARCHAR2(3)   NOT NULL,
  quantity            NUMBER(15,3)  NOT NULL,
  lot_number          VARCHAR2(20),
  CONSTRAINT pk_inv_movement_status    PRIMARY KEY (movement_id, stock_status_code),
  CONSTRAINT fk_inv_movement_status_mvt FOREIGN KEY (movement_id)
    REFERENCES inv_movement(movement_id) ON DELETE CASCADE,
  CONSTRAINT fk_inv_movement_status_ref FOREIGN KEY (stock_status_code)
    REFERENCES inv_status_ref(status_code),
  CONSTRAINT ck_inv_movement_status_qty CHECK (quantity <> 0)
);

CREATE INDEX ix_inv_movement_status_st ON inv_movement_status(stock_status_code);

PROMPT
PROMPT [7/7] inv_reorder  (← GCPART_REAPPRO) — propositions de réapprovisionnement
CREATE TABLE inv_reorder (
  product_code        VARCHAR2(80)  NOT NULL,
  generation_date     DATE          NOT NULL,
  supplier_code       VARCHAR2(32),
  consumption_rate    NUMBER(16,4),                         -- conso moyenne journalière
  min_stock           NUMBER(16,4),                         -- stock minimum
  reorder_qty         NUMBER(16,4),                         -- quantité à commander
  lead_time_days      NUMBER(5),                            -- délai fournisseur
  comparison_var      VARCHAR2(120),                        -- variable de comparaison (min, max, sell_days)
  comparison_value    NUMBER(16,4),                         -- valeur de comparaison
  proposed_qty        NUMBER(16,4),
  is_validated        BOOLEAN       DEFAULT FALSE,          -- validé par le gestionnaire ?
  validated_by        VARCHAR2(20),
  validated_at        TIMESTAMP,
  memo                VARCHAR2(255),
  CONSTRAINT pk_inv_reorder            PRIMARY KEY (product_code, generation_date),
  CONSTRAINT ck_inv_reorder_rates      CHECK (consumption_rate IS NULL OR consumption_rate >= 0),
  CONSTRAINT ck_inv_reorder_lead       CHECK (lead_time_days IS NULL OR lead_time_days >= 0)
);

CREATE INDEX ix_inv_reorder_date       ON inv_reorder(generation_date);
CREATE INDEX ix_inv_reorder_validated  ON inv_reorder(is_validated);

PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA
GRANT SELECT ON app_inv.inv_avg_cost          TO app_product;
GRANT SELECT ON app_inv.inv_reorder          TO app_product;
GRANT SELECT ON app_inv.inv_stock_status     TO app_api;
GRANT SELECT ON app_inv.inv_product_lot      TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_inv.inv_movement_status TO app_sales;

PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_inv/AppInv#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('INV_AVG_COST','INV_PRODUCT_LOT','INV_STOCK_STATUS',
                      'INV_STATUS_REF','INV_COUNT_ZONE','INV_MOVEMENT_STATUS',
                      'INV_REORDER')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('INV_AVG_COST','INV_PRODUCT_LOT','INV_STOCK_STATUS',
                      'INV_STATUS_REF','INV_COUNT_ZONE','INV_MOVEMENT_STATUS',
                      'INV_REORDER')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R3 TERMINÉ (7 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
