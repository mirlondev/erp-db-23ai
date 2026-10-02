-- ============================================================
-- S09 : Seed LOT R1 (Promotions & Remises)
-- Données de démo réalistes : 4 promos actives + 1 palier tarifaire.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED LOT R1 — Promotions & Remises
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [Reset des tables R1]
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM price_tier_product';
  EXECUTE IMMEDIATE 'DELETE FROM price_tier_quantity';
  EXECUTE IMMEDIATE 'DELETE FROM price_tier';
  EXECUTE IMMEDIATE 'DELETE FROM promo_pos';
  EXECUTE IMMEDIATE 'DELETE FROM promo_customer_family';
  EXECUTE IMMEDIATE 'DELETE FROM promo_quantity';
  EXECUTE IMMEDIATE 'DELETE FROM promo_product';
  EXECUTE IMMEDIATE 'DELETE FROM promo_header';
  COMMIT;
END;
/

PROMPT
PROMPT [1] Promo #1 — Rentrée scolaire (BOGO : 10 achetés = 2 offerts)
INSERT INTO promo_header (promo_code, promo_name, promo_type,
                          start_date, end_date, status,
                          priority, memo, is_pos_restricted,
                          population, all_cust_family, calc_base,
                          created_by)
VALUES ('PROMO001', 'Rentrée scolaire - Cahiers 10+2',
        'BOGO', DATE '2026-09-01', DATE '2026-10-15', 'A',
        10, 'Achat de 10 cahiers = 2 gratuits', FALSE,
        'A', TRUE, 'P', 'ADMIN');

-- Articles concernés : ART001 (Cahier 200p)
INSERT INTO promo_product (promo_id, product_id, is_excluded, is_promo_product, unit_code, expected_qty)
SELECT ph.promo_id, p.product_id, FALSE, TRUE, p.stock_unit, 500
        FROM promo_header ph CROSS JOIN product p
 WHERE ph.promo_code = 'PROMO001' AND p.product_code = '31275';

-- Règle : pour 10 achetés, 2 gratuits
INSERT INTO promo_quantity (promo_id, min_qty, max_qty, free_qty, promo_price, discount_rate, is_linear)
SELECT promo_id, 10, NULL, 2, NULL, NULL, FALSE
        FROM promo_header WHERE promo_code = 'PROMO001';

-- Tous les POS
INSERT INTO promo_pos (promo_id, pos_code)
SELECT ph.promo_id, op.pos_code
        FROM promo_header ph CROSS JOIN app_org.org_pos op
 WHERE ph.promo_code = 'PROMO001';


PROMPT [2] Promo #2 — Soldes USB (remise 15%)
INSERT INTO promo_header (promo_code, promo_name, promo_type,
                          start_date, end_date, status,
                          priority, memo, coverage_rate,
                          population, calc_base, created_by)
VALUES ('PROMO002', 'Soldes été - USB -15%',
        'DISCOUNT', DATE '2026-07-01', DATE '2026-08-31', 'A',
        50, 'Remise exceptionnelle sur clés USB', 100,
        'A', 'P', 'ADMIN');

INSERT INTO promo_product (promo_id, product_id, is_excluded, unit_code)
SELECT ph.promo_id, p.product_id, FALSE, p.stock_unit
        FROM promo_header ph CROSS JOIN product p
 WHERE ph.promo_code = 'PROMO002' AND p.product_code = 'ADAPTER_USB_C';

INSERT INTO promo_quantity (promo_id, min_qty, max_qty, free_qty, promo_price, discount_rate, is_linear)
SELECT promo_id, 1, NULL, NULL, NULL, 15, FALSE
        FROM promo_header WHERE promo_code = 'PROMO002';


PROMPT [3] Promo #3 — Pack Bureau (3+1 sur stylos)
INSERT INTO promo_header (promo_code, promo_name, promo_type,
                          start_date, end_date, status, priority,
                          population, calc_base, created_by)
VALUES ('PROMO003', 'Pack Bureau Stylo Bleu',
        'BUNDLE', DATE '2026-01-01', DATE '2026-12-31', 'A', 30,
        'A', 'P', 'ADMIN');

-- ART002 = Stylo bleu
INSERT INTO promo_product (promo_id, product_id, is_excluded, is_promo_product)
SELECT ph.promo_id, p.product_id, FALSE, TRUE
        FROM promo_header ph CROSS JOIN product p
 WHERE ph.promo_code = 'PROMO003' AND p.product_code = '16411';

INSERT INTO promo_quantity (promo_id, min_qty, max_qty, free_qty, promo_price, discount_rate, is_linear)
SELECT promo_id, 3, NULL, 1, NULL, NULL, FALSE
        FROM promo_header WHERE promo_code = 'PROMO003';


PROMPT [4] Promo #4 — Client VIP (remise -10% sur tout, familles GOLD/PLATINUM)
INSERT INTO promo_header (promo_code, promo_name, promo_type,
                          start_date, end_date, status, priority,
                          population, calc_base, created_by)
VALUES ('PROMO004', 'Remise fidélité GOLD/PLATINUM',
        'DISCOUNT', DATE '2026-01-01', DATE '2026-12-31', 'A', 5,
        'C', 'P', 'ADMIN');

-- Aucune exclusion de produit (s'applique à tout)
-- (pas de ligne dans promo_product)

INSERT INTO promo_customer_family (promo_id, customer_family, is_active)
SELECT promo_id, 'GLD', TRUE FROM promo_header WHERE promo_code = 'PROMO004';
INSERT INTO promo_customer_family (promo_id, customer_family, is_active)
SELECT promo_id, 'PLT', TRUE FROM promo_header WHERE promo_code = 'PROMO004';

-- Règle unique : -10% sur tout l'assortiment
INSERT INTO promo_quantity (promo_id, min_qty, max_qty, free_qty, promo_price, discount_rate, is_linear)
SELECT promo_id, 1, NULL, NULL, NULL, 10, FALSE
        FROM promo_header WHERE promo_code = 'PROMO004';


PROMPT [5] Palier tarifaire #1 — "Gros volume Cahiers" : -5% dès 50 unités
INSERT INTO price_tier (tier_code, description, is_product_tier, price_list_codes,
                        is_pos_restricted, start_date, end_date, memo, is_active, created_by)
VALUES ('TIER001', 'Remise volume Cahiers',
        TRUE, 'STANDARD,WHOLESALE',
        FALSE, DATE '2026-01-01', DATE '2026-12-31',
        'Palier de remise quantitative sur ART001', TRUE, 'ADMIN');

-- Article : ART001 (Cahier 200p)
INSERT INTO price_tier_product (tier_id, product_id)
SELECT pt.tier_id, p.product_id
        FROM price_tier pt CROSS JOIN product p
 WHERE pt.tier_code = 'TIER001' AND p.product_code = '31275';

-- Seuils : 50+ = -5%, 100+ = -10%
INSERT INTO price_tier_quantity (tier_id, min_qty, max_qty, discount_amount, discount_rate)
SELECT tier_id, 50, 99, NULL, 5 FROM price_tier WHERE tier_code = 'TIER001';
INSERT INTO price_tier_quantity (tier_id, min_qty, max_qty, discount_amount, discount_rate)
SELECT tier_id, 100, NULL, NULL, 10 FROM price_tier WHERE tier_code = 'TIER001';

COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'PROMO_HEADER'           AS tbl, COUNT(*) AS nb FROM promo_header
UNION ALL SELECT 'PROMO_PRODUCT',          COUNT(*) FROM promo_product
UNION ALL SELECT 'PROMO_QUANTITY',         COUNT(*) FROM promo_quantity
UNION ALL SELECT 'PROMO_CUSTOMER_FAMILY',  COUNT(*) FROM promo_customer_family
UNION ALL SELECT 'PROMO_POS',              COUNT(*) FROM promo_pos
UNION ALL SELECT 'PRICE_TIER',             COUNT(*) FROM price_tier
UNION ALL SELECT 'PRICE_TIER_QUANTITY',    COUNT(*) FROM price_tier_quantity
UNION ALL SELECT 'PRICE_TIER_PRODUCT',     COUNT(*) FROM price_tier_product
 ORDER BY tbl;

PROMPT
PROMPT ═══ Démos / requêtes ═══

PROMPT [Q1] Promos actives par priorité
SELECT promo_code, promo_name, promo_type, start_date, end_date, priority
  FROM promo_header
 WHERE status = 'A'
   AND SYSDATE BETWEEN start_date AND end_date
 ORDER BY priority, promo_code;

PROMPT [Q2] Détail de la promo #1 (BOGO Cahiers)
SELECT ph.promo_code, pp.product_id, pq.min_qty, pq.free_qty
  FROM promo_header ph
  JOIN promo_product pp ON pp.promo_id = ph.promo_id
  JOIN promo_quantity pq ON pq.promo_id = ph.promo_id
 WHERE ph.promo_code = 'PROMO001';

PROMPT [Q3] Palier tarifaire sur Cahiers
SELECT pt.tier_code, ptq.min_qty, ptq.max_qty, ptq.discount_rate
  FROM price_tier pt
  JOIN price_tier_quantity ptq ON ptq.tier_id = pt.tier_id
  JOIN price_tier_product  ptp ON ptp.tier_id = pt.tier_id
  JOIN product             p   ON p.product_id   = ptp.product_id
 WHERE p.product_code = 'ART001'
 ORDER BY ptq.min_qty;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED LOT R1 TERMINÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
