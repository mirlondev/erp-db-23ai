-- ============================================================
-- S03 : Seed app_product — VERSION CORRIGÉE
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

PROMPT ===============================================================
PROMPT   SEED app_product — SUPER SONIC
PROMPT ===============================================================

-- Nettoyage
DELETE FROM product_price;
DELETE FROM product_barcode;
DELETE FROM product_unit;
DELETE FROM product;
DELETE FROM prod_subcategory;
DELETE FROM prod_category;
DELETE FROM prod_brand;
DELETE FROM prod_nature;
DELETE FROM prod_shelf;
DELETE FROM prod_price_list;
COMMIT;

PROMPT [1] Natures
INSERT INTO prod_nature (nature_code, nature_name, nature_type, is_active, tax_rate)
VALUES ('ARN', 'Articles revendus en l''état', 'GOODS', TRUE, 18.9);
INSERT INTO prod_nature (nature_code, nature_name, nature_type, is_active, tax_rate)
VALUES ('PFA', 'Produits finis A', 'GOODS', TRUE, 18.9);
INSERT INTO prod_nature (nature_code, nature_name, nature_type, is_active, tax_rate)
VALUES ('MPR', 'Matières premières', 'GOODS', TRUE, 18.9);
INSERT INTO prod_nature (nature_code, nature_name, nature_type, is_active, tax_rate)
VALUES ('SRV', 'Services', 'SERVICE', TRUE, 18.9);
INSERT INTO prod_nature (nature_code, nature_name, nature_type, is_active, tax_rate)
VALUES ('999', 'Article par défaut', 'GOODS', TRUE, 18.9);

PROMPT [2] Familles
INSERT INTO prod_category (category_code, category_name) VALUES ('EPI', 'Épicerie');
INSERT INTO prod_category (category_code, category_name) VALUES ('BOI', 'Boissons');
INSERT INTO prod_category (category_code, category_name) VALUES ('HEN', 'Hygiène / Entretien');
INSERT INTO prod_category (category_code, category_name) VALUES ('ELE', 'Électroménager');
INSERT INTO prod_category (category_code, category_name) VALUES ('MEL', 'Meubles');
INSERT INTO prod_category (category_code, category_name) VALUES ('INF', 'Informatique / Électronique');
INSERT INTO prod_category (category_code, category_name) VALUES ('PAP', 'Papeterie');
INSERT INTO prod_category (category_code, category_name) VALUES ('999', 'Famille par défaut');

PROMPT [3] Sous-familles (via sous-requêtes sur category_code)
INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'EPI01', 'Conserves' FROM prod_category WHERE category_code = 'EPI';

INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'EPI02', 'Céréales' FROM prod_category WHERE category_code = 'EPI';

INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'BOI01', 'Sodas' FROM prod_category WHERE category_code = 'BOI';

INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'HEN01', 'Shampooings' FROM prod_category WHERE category_code = 'HEN';

INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'HEN02', 'Savons' FROM prod_category WHERE category_code = 'HEN';

INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'ELE01', 'Ustensiles cuisine' FROM prod_category WHERE category_code = 'ELE';

INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'ELE02', 'Accessoires cuisine' FROM prod_category WHERE category_code = 'ELE';

INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'INF01', 'Smartphones' FROM prod_category WHERE category_code = 'INF';

INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'INF02', 'Accessoires mobiles' FROM prod_category WHERE category_code = 'INF';

INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
SELECT category_id, 'SF999', 'Sous-famille par défaut' FROM prod_category WHERE category_code = '999';

PROMPT [4] Rayons
INSERT INTO prod_shelf (shelf_code, shelf_name) VALUES ('R01', 'Rayon principal PNR');
INSERT INTO prod_shelf (shelf_code, shelf_name) VALUES ('R02', 'Rayon Électroménager');
INSERT INTO prod_shelf (shelf_code, shelf_name) VALUES ('R03', 'Rayon Électronique');
INSERT INTO prod_shelf (shelf_code, shelf_name) VALUES ('R99', 'Rayon par défaut');

PROMPT [5] Marques
INSERT INTO prod_brand (brand_code, brand_name) VALUES ('TEFAL', 'Tefal');
INSERT INTO prod_brand (brand_code, brand_name) VALUES ('CF',    'Colgate Fermion');
INSERT INTO prod_brand (brand_code, brand_name) VALUES ('SMSNG', 'Samsung');
INSERT INTO prod_brand (brand_code, brand_name) VALUES ('ORSE',  'Orse');
INSERT INTO prod_brand (brand_code, brand_name) VALUES ('FANCF', 'Fanico');
INSERT INTO prod_brand (brand_code, brand_name) VALUES ('DIN',   'Divers importes');

PROMPT [6] Listes de prix
INSERT INTO prod_price_list (price_list_code, price_list_name, tax_rate, is_active)
VALUES ('0', 'STANDARD PUBLIC TARIF', 18.9, TRUE);
INSERT INTO prod_price_list (price_list_code, price_list_name, tax_rate, is_active)
VALUES ('1', 'RETAIL PRICE PNR', 18.9, TRUE);
INSERT INTO prod_price_list (price_list_code, price_list_name, tax_rate, is_active)
VALUES ('2', 'WHOLESALE PRICE PNR', 18.9, TRUE);
INSERT INTO prod_price_list (price_list_code, price_list_name, tax_rate, is_active)
VALUES ('5', 'RETAIL PRICE BZV', 18.9, TRUE);
INSERT INTO prod_price_list (price_list_code, price_list_name, tax_rate, is_active)
VALUES ('6', 'WHOLESALE PRICE BZV', 18.9, TRUE);

PROMPT [7] Articles (via sous-requêtes sur les codes)
-- Tefal (nature=ARN, categ=ELE, sfam=ELE01, brand=TEFAL, shelf=R02)
PROMPT [7b] Articles génériques (boucle PL/SQL)
DECLARE
  v_nature_id   NUMBER;
  v_category_id NUMBER;
  v_subcat_id   NUMBER;
  v_brand_id    NUMBER;
  v_shelf_id    NUMBER;
BEGIN
  SELECT nature_id   INTO v_nature_id   FROM prod_nature    WHERE nature_code = 'ARN';
  SELECT category_id INTO v_category_id FROM prod_category  WHERE category_code = '999';
  SELECT subcategory_id INTO v_subcat_id FROM prod_subcategory WHERE subcategory_code = 'SF999';
  SELECT brand_id    INTO v_brand_id    FROM prod_brand     WHERE brand_code = 'DIN';
  SELECT shelf_id    INTO v_shelf_id    FROM prod_shelf     WHERE shelf_code = 'R99';

  FOR i IN 1 .. 5 LOOP
    INSERT INTO product (product_code, short_name, product_name,
                         nature_id, category_id, subcategory_id, brand_id, shelf_id,
                         stock_unit, status, is_stock_managed, created_by)
    VALUES ('1641' || i, 'ART1641' || i, 'Article générique ' || i,
            v_nature_id, v_category_id, v_subcat_id, v_brand_id, v_shelf_id,
            'PCS', 'ACTIVE', TRUE, 'SQL');
  END LOOP;
  COMMIT;
END;
/
INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, standard_price, standard_price_ht, barcode, status,
                     is_stock_managed, created_by)
SELECT '31275', 'TEFAL JUST CHEF CASS', 'TEFAL JUST CHEF CASSEROLE 22+L',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 27500, 23128.68, '3168430187191', 'ACTIVE', TRUE, 'KAMAL'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'ELE'
   AND s.subcategory_code = 'ELE01'
   AND b.brand_code  = 'TEFAL'
   AND sh.shelf_code = 'R02';

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, standard_price, standard_price_ht, barcode, status,
                     is_stock_managed, created_by)
SELECT '31276', 'TEFAL FLAVOUR SAUTEP', 'TEFAL FLAVOUR SAUTEPAN 24+LID',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 22000, 18502.94, '3168430138964', 'ACTIVE', TRUE, 'KAMAL'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'ELE'
   AND s.subcategory_code = 'ELE01'
   AND b.brand_code  = 'TEFAL'
   AND sh.shelf_code = 'R02';

-- Colgate Care (HEN/HEN01/CF)
INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, purchase_unit, sale_unit,
                     standard_price, standard_price_ht, barcode, status, is_stock_managed, created_by)
SELECT '19889', 'CF LING INTIMES', 'CF LING INTIMES DOUCEUR X20',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 'CTN', 'PCS', 2950, 2481.07, '3468080603134', 'ACTIVE', TRUE, 'KAMAL'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'HEN'
   AND s.subcategory_code = 'HEN01'
   AND b.brand_code  = 'CF'
   AND sh.shelf_code = 'R01';

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, purchase_unit, sale_unit,
                     standard_price, standard_price_ht, barcode, status, is_stock_managed, created_by)
SELECT '19890', 'CF DCH ALOE V 750M', 'CF DCHE ALOE VERA 750ML',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 'CTN', 'PCS', 4500, 3784.69, '3468080404915', 'ACTIVE', TRUE, 'KAMAL'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'HEN'
   AND s.subcategory_code = 'HEN01'
   AND b.brand_code  = 'CF'
   AND sh.shelf_code = 'R01';

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, purchase_unit, sale_unit,
                     standard_price, standard_price_ht, barcode, status, is_stock_managed, created_by)
SELECT '19891', 'CF DCH SENSIT 750M', 'CF DCH SENSIT 750M',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 'CTN', 'PCS', 3750, 3153.91, '3468080404922', 'ACTIVE', TRUE, 'KAMAL'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'HEN'
   AND s.subcategory_code = 'HEN01'
   AND b.brand_code  = 'CF'
   AND sh.shelf_code = 'R01';

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, purchase_unit, sale_unit,
                     standard_price, standard_price_ht, barcode, status, is_stock_managed, created_by)
SELECT '19896', 'SELS DE BAIN MANGUE', 'SELS DE BAIN MANGUE 1.3KG',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 'CTN', 'PCS', 2500, 2102.61, '3468111130098', 'ACTIVE', TRUE, 'KAMAL'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'HEN'
   AND s.subcategory_code = 'HEN02'
   AND b.brand_code  = 'ORSE'
   AND sh.shelf_code = 'R01';

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, purchase_unit, sale_unit,
                     standard_price, standard_price_ht, barcode, status, is_stock_managed, created_by)
SELECT '19900', 'SELS DE BAIN RELAX L', 'CF SELS DE BAIN LAVANDE 1.3KG',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 'CTN', 'PCS', 2950, 2481.08, '3468080130210', 'ACTIVE', TRUE, 'KAMAL'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'HEN'
   AND s.subcategory_code = 'HEN02'
   AND b.brand_code  = 'ORSE'
   AND sh.shelf_code = 'R01';

-- Électronique Samsung
INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, standard_price, standard_price_ht, status, is_stock_managed, created_by)
SELECT 'MOBILE_A17', 'SAMSUNG A17', 'MOBILE SAMSUNG SM-A175F/DS BLACK 4/128GB',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 175000, 147182.51, 'ACTIVE', TRUE, 'ADMIN'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'INF'
   AND s.subcategory_code = 'INF01'
   AND b.brand_code  = 'SMSNG'
   AND sh.shelf_code = 'R03';

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, standard_price, standard_price_ht, status, is_stock_managed, created_by)
SELECT 'SCREEN_GUARD_A17', 'SCREEN GUARD A17', 'SCREEN GUARD SAMSUNG A17 IKPTEMPERED GLASS',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 10000, 8410.43, 'ACTIVE', TRUE, 'ADMIN'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'INF'
   AND s.subcategory_code = 'INF02'
   AND b.brand_code  = 'SMSNG'
   AND sh.shelf_code = 'R03';

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, standard_price, standard_price_ht, status, is_stock_managed, created_by)
SELECT 'COVER_A17', 'COVER A17', 'COVER SAMSUNG A17 LEATHER LOGO CASE',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 10000, 8410.43, 'ACTIVE', TRUE, 'ADMIN'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'INF'
   AND s.subcategory_code = 'INF02'
   AND b.brand_code  = 'SMSNG'
   AND sh.shelf_code = 'R03';

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, standard_price, standard_price_ht, status, is_stock_managed, created_by)
SELECT 'ADAPTER_USB_C', 'ADAPTER TYPE C', 'SAMSUNG TYPE C 2PIN ADAPTER 15W',
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 14500, 12195.12, 'ACTIVE', TRUE, 'ADMIN'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = 'INF'
   AND s.subcategory_code = 'INF02'
   AND b.brand_code  = 'SMSNG'
   AND sh.shelf_code = 'R03';

-- Articles génériques
INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, status, is_stock_managed, created_by)
SELECT '1641'||ROWNUM, 'ART1641'||ROWNUM, 'Article générique '||ROWNUM,
       n.nature_id, c.category_id, s.subcategory_id, b.brand_id, sh.shelf_id,
       'PCS', 'ACTIVE', TRUE, 'SQL'
  FROM prod_nature n, prod_category c, prod_subcategory s, prod_brand b, prod_shelf sh
 WHERE n.nature_code  = 'ARN'
   AND c.category_code = '999'
   AND s.subcategory_code = 'SF999'
   AND b.brand_code  = 'DIN'
   AND sh.shelf_code = 'R99'
   AND ROWNUM <= 5
 CONNECT BY ROWNUM <= 5;

COMMIT;

PROMPT [8] Validation
SELECT 'PRODUCT'           AS tbl, COUNT(*) AS nb FROM product
UNION ALL SELECT 'PROD_NATURE',      COUNT(*) FROM prod_nature
UNION ALL SELECT 'PROD_CATEGORY',    COUNT(*) FROM prod_category
UNION ALL SELECT 'PROD_SUBCATEGORY', COUNT(*) FROM prod_subcategory
UNION ALL SELECT 'PROD_BRAND',       COUNT(*) FROM prod_brand
UNION ALL SELECT 'PROD_SHELF',       COUNT(*) FROM prod_shelf
UNION ALL SELECT 'PROD_PRICE_LIST',  COUNT(*) FROM prod_price_list;

PROMPT ✅ S03 terminé
EXIT;
