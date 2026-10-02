-- ============================================================
-- SCRIPT 17 : LOT R1 — Promotions & Remises
-- Migration Oracle 11g (GCPROMO*, GCPPALIER*) → 23ai/26ai
-- ============================================================
-- 8 nouvelles tables dans app_product : promotions par produit,
-- quantité, famille client, point de vente, paliers tarifaires.
-- Style : Identity, BOOLEAN natif, contraintes nommées, ON DELETE CASCADE.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R1 : PROMOTIONS & REMISES (8 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/8] promo_header  (← GCPROMO)
CREATE TABLE promo_header (
  promo_id            NUMBER GENERATED ALWAYS AS IDENTITY,
  promo_code          VARCHAR2(12)  NOT NULL,
  promo_name          VARCHAR2(120) NOT NULL,
  promo_type          VARCHAR2(12)  DEFAULT 'DISCOUNT',     -- DISCOUNT | BOGO | BUNDLE | PRICE
  start_date          DATE,
  end_date            DATE,
  status              VARCHAR2(1)   DEFAULT 'A',            -- A=Active, I=Inactive, E=Expired
  coverage_rate       NUMBER(5,2),                          -- % population ciblée
  priority            NUMBER(3)     DEFAULT 100,            -- tri d'application
  memo                VARCHAR2(255),
  is_pos_restricted   BOOLEAN       DEFAULT FALSE,
  only_prices         VARCHAR2(20),                         -- listes de prix concernées
  excluded_prices     VARCHAR2(20),                         -- listes exclues
  population          VARCHAR2(1)   DEFAULT 'A',            -- A=All, C=Customers, E=Employees
  all_cust_family     BOOLEAN       DEFAULT FALSE,          -- toutes familles clients ?
  calc_base           VARCHAR2(1)   DEFAULT 'P',            -- P=Promo, S=Standard
  total_qty_promo     NUMBER(16,4),                         -- stock alloué à la promo
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by          VARCHAR2(20),
  updated_at          TIMESTAMP,
  CONSTRAINT pk_promo_header         PRIMARY KEY (promo_id),
  CONSTRAINT uk_promo_code           UNIQUE (promo_code),
  CONSTRAINT ck_promo_status         CHECK (status IN ('A','I','E')),
  CONSTRAINT ck_promo_type           CHECK (promo_type IN ('DISCOUNT','BOGO','BUNDLE','PRICE')),
  CONSTRAINT ck_promo_population     CHECK (population IN ('A','C','E','S')),
  CONSTRAINT ck_promo_calc_base       CHECK (calc_base IN ('P','S','Q')),
  CONSTRAINT ck_promo_dates          CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date)
);

CREATE INDEX ix_promo_header_dates  ON promo_header(start_date, end_date);
CREATE INDEX ix_promo_header_status ON promo_header(status);
CREATE INDEX ix_promo_header_active ON promo_header(status, start_date, end_date);

PROMPT [2/8] promo_product  (← GCPROMO_ART)
CREATE TABLE promo_product (
  promo_id            NUMBER        NOT NULL,
  product_id          NUMBER        NOT NULL,
  is_excluded         BOOLEAN       DEFAULT FALSE,
  is_promo_product    BOOLEAN       DEFAULT FALSE,
  unit_code           VARCHAR2(12)  DEFAULT 'UNIT',
  expected_qty        NUMBER(16,4),
  CONSTRAINT pk_promo_product           PRIMARY KEY (promo_id, product_id),
  CONSTRAINT fk_promo_product_header    FOREIGN KEY (promo_id)
    REFERENCES promo_header(promo_id) ON DELETE CASCADE,
  CONSTRAINT fk_promo_product_product   FOREIGN KEY (product_id)
    REFERENCES product(product_id) ON DELETE CASCADE
);

CREATE INDEX ix_promo_product_prod ON promo_product(product_id);

PROMPT [3/8] promo_quantity  (← GCPROMO_QTE) — seuils "achetez X obtenez Y"
CREATE TABLE promo_quantity (
  promo_id            NUMBER              NOT NULL,
  rule_no             NUMBER GENERATED ALWAYS AS IDENTITY,
  min_qty             NUMBER(16,3)        NOT NULL,
  max_qty             NUMBER(16,3),
  free_qty            NUMBER(16,3),
  promo_price         NUMBER(16,4),
  discount_rate       NUMBER(5,2),
  is_linear           BOOLEAN             DEFAULT FALSE,    -- application linéaire au-delà du seuil
  CONSTRAINT pk_promo_quantity        PRIMARY KEY (promo_id, rule_no),
  CONSTRAINT fk_promo_quantity_header FOREIGN KEY (promo_id)
    REFERENCES promo_header(promo_id) ON DELETE CASCADE,
  CONSTRAINT ck_promo_qty_min         CHECK (min_qty > 0),
  CONSTRAINT ck_promo_qty_range       CHECK (max_qty IS NULL OR max_qty >= min_qty),
  CONSTRAINT ck_promo_qty_xor         CHECK (free_qty IS NOT NULL OR promo_price IS NOT NULL OR discount_rate IS NOT NULL)
);

PROMPT [4/8] promo_customer_family  (← GCPROMO_FAMTIE)
CREATE TABLE promo_customer_family (
  promo_id            NUMBER        NOT NULL,
  customer_family     VARCHAR2(3)   NOT NULL,
  is_active           BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_promo_customer_family PRIMARY KEY (promo_id, customer_family),
  CONSTRAINT fk_promo_cust_fam_header FOREIGN KEY (promo_id)
    REFERENCES promo_header(promo_id) ON DELETE CASCADE
);

PROMPT [5/8] promo_pos  (← GCPROMO_PTVTE) — POS où la promo s'applique
CREATE TABLE promo_pos (
  promo_id            NUMBER        NOT NULL,
  pos_code            VARCHAR2(5)   NOT NULL,
  CONSTRAINT pk_promo_pos           PRIMARY KEY (promo_id, pos_code),
  CONSTRAINT fk_promo_pos_header    FOREIGN KEY (promo_id)
    REFERENCES promo_header(promo_id) ON DELETE CASCADE
);

PROMPT [6/8] price_tier  (← GCPPALIER) — paliers tarifaires (remise par quantité)
CREATE TABLE price_tier (
  tier_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  tier_code           VARCHAR2(12)  NOT NULL,
  description         VARCHAR2(120) NOT NULL,
  is_product_tier     BOOLEAN       DEFAULT FALSE,
  price_list_codes    VARCHAR2(120),
  is_pos_restricted   BOOLEAN       DEFAULT FALSE,
  start_date          DATE,
  end_date            DATE,
  memo                VARCHAR2(255),
  is_active           BOOLEAN       DEFAULT TRUE,
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  updated_by          VARCHAR2(20),
  updated_at          TIMESTAMP,
  CONSTRAINT pk_price_tier      PRIMARY KEY (tier_id),
  CONSTRAINT uk_price_tier_code UNIQUE (tier_code)
);

CREATE INDEX ix_price_tier_active  ON price_tier(is_active, start_date, end_date);

PROMPT [7/8] price_tier_quantity  (← GCPPALIER_QTE)
CREATE TABLE price_tier_quantity (
  tier_id             NUMBER              NOT NULL,
  rule_no             NUMBER GENERATED ALWAYS AS IDENTITY,
  min_qty             NUMBER(16,3)        NOT NULL,
  max_qty             NUMBER(16,3),
  discount_amount     NUMBER(16,4),
  discount_rate       NUMBER(5,2),
  CONSTRAINT pk_price_tier_quantity     PRIMARY KEY (tier_id, rule_no),
  CONSTRAINT fk_price_tier_qty_tier     FOREIGN KEY (tier_id)
    REFERENCES price_tier(tier_id) ON DELETE CASCADE,
  CONSTRAINT ck_price_tier_qty_min      CHECK (min_qty > 0),
  CONSTRAINT ck_price_tier_qty_range    CHECK (max_qty IS NULL OR max_qty >= min_qty),
  CONSTRAINT ck_price_tier_qty_amount   CHECK (discount_amount IS NOT NULL OR discount_rate IS NOT NULL)
);

PROMPT [8/8] price_tier_product  (← GCPPALIER_ART)
CREATE TABLE price_tier_product (
  tier_id             NUMBER        NOT NULL,
  product_id          NUMBER        NOT NULL,
  CONSTRAINT pk_price_tier_product         PRIMARY KEY (tier_id, product_id),
  CONSTRAINT fk_price_tier_prod_tier       FOREIGN KEY (tier_id)
    REFERENCES price_tier(tier_id) ON DELETE CASCADE,
  CONSTRAINT fk_price_tier_prod_product    FOREIGN KEY (product_id)
    REFERENCES product(product_id) ON DELETE CASCADE
);

CREATE INDEX ix_price_tier_product_prod ON price_tier_product(product_id);

PROMPT
PROMPT ═══ Privilèges croisés (app_sales peut lire les promos) ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA
GRANT SELECT ON app_product.promo_header         TO app_sales;
GRANT SELECT ON app_product.promo_product       TO app_sales;
GRANT SELECT ON app_product.promo_quantity       TO app_sales;
GRANT SELECT ON app_product.promo_customer_family TO app_sales;
GRANT SELECT ON app_product.promo_pos           TO app_sales;
GRANT SELECT ON app_product.price_tier          TO app_sales;
GRANT SELECT ON app_product.price_tier_quantity TO app_sales;
GRANT SELECT ON app_product.price_tier_product  TO app_sales;

PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name LIKE 'PROMO%'
    OR table_name LIKE 'PRICE_TIER%'
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('PROMO_HEADER','PROMO_PRODUCT','PROMO_QUANTITY',
                      'PROMO_CUSTOMER_FAMILY','PROMO_POS',
                      'PRICE_TIER','PRICE_TIER_QUANTITY','PRICE_TIER_PRODUCT')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R1 TERMINÉ (8 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
