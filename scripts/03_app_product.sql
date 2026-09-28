-- ============================================================
-- SCRIPT 03 : Schéma app_product (Catalogue)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON

CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

PROMPT ═══════════════════════════════════════════════════════
PROMPT   CRÉATION DU SCHÉMA app_product
PROMPT ═══════════════════════════════════════════════════════

PROMPT [1] Table prod_nature
CREATE TABLE prod_nature (
  nature_id       NUMBER GENERATED ALWAYS AS IDENTITY,
  nature_code     VARCHAR2(12)  NOT NULL,
  nature_name     VARCHAR2(120) NOT NULL,
  nature_type     VARCHAR2(12),
  is_active       BOOLEAN       DEFAULT TRUE,
  tax_rate        NUMBER(16,3),
  CONSTRAINT pk_prod_nature      PRIMARY KEY (nature_id),
  CONSTRAINT uk_prod_nature_code UNIQUE (nature_code)
);

PROMPT [2] Table prod_category
CREATE TABLE prod_category (
  category_id     NUMBER GENERATED ALWAYS AS IDENTITY,
  category_code   VARCHAR2(16)  NOT NULL,
  category_name   VARCHAR2(50)  NOT NULL,
  department_code VARCHAR2(3),
  CONSTRAINT pk_prod_category      PRIMARY KEY (category_id),
  CONSTRAINT uk_prod_category_code UNIQUE (category_code)
);

PROMPT [3] Table prod_subcategory
CREATE TABLE prod_subcategory (
  subcategory_id  NUMBER GENERATED ALWAYS AS IDENTITY,
  category_id     NUMBER        NOT NULL,
  subcategory_code VARCHAR2(16) NOT NULL,
  subcategory_name VARCHAR2(50),
  CONSTRAINT pk_prod_subcategory      PRIMARY KEY (subcategory_id),
  CONSTRAINT uk_prod_subcategory_code UNIQUE (category_id, subcategory_code),
  CONSTRAINT fk_prod_subcategory_cat FOREIGN KEY (category_id) 
    REFERENCES prod_category(category_id)
);

PROMPT [4] Table prod_shelf
CREATE TABLE prod_shelf (
  shelf_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  shelf_code      VARCHAR2(5)  NOT NULL,
  shelf_name      VARCHAR2(50) NOT NULL,
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_prod_shelf      PRIMARY KEY (shelf_id),
  CONSTRAINT uk_prod_shelf_code UNIQUE (shelf_code)
);

PROMPT [5] Table prod_brand
CREATE TABLE prod_brand (
  brand_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  brand_code      VARCHAR2(5)  NOT NULL,
  brand_name      VARCHAR2(50) NOT NULL,
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_prod_brand      PRIMARY KEY (brand_id),
  CONSTRAINT uk_prod_brand_code UNIQUE (brand_code)
);

PROMPT [6] Table prod_price_list
CREATE TABLE prod_price_list (
  price_list_id   NUMBER GENERATED ALWAYS AS IDENTITY,
  price_list_code VARCHAR2(12)  NOT NULL,
  price_list_name VARCHAR2(120) NOT NULL,
  tax_rate        NUMBER(6,3),
  is_active       BOOLEAN       DEFAULT TRUE,
  rounding_value  NUMBER(5),
  CONSTRAINT pk_prod_price_list      PRIMARY KEY (price_list_id),
  CONSTRAINT uk_prod_price_list_code UNIQUE (price_list_code)
);

PROMPT [7] Table product (avec BOOLEAN natif)
CREATE TABLE product (
  product_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  product_code        VARCHAR2(80)  NOT NULL,
  short_name          VARCHAR2(80)  NOT NULL,
  product_name        VARCHAR2(120),
  product_name_2      VARCHAR2(120),
  nature_id           NUMBER        NOT NULL,
  category_id         NUMBER        NOT NULL,
  subcategory_id      NUMBER        NOT NULL,
  brand_id            NUMBER,
  shelf_id            NUMBER,
  stock_unit          VARCHAR2(12)  NOT NULL,
  purchase_unit       VARCHAR2(12),
  sale_unit           VARCHAR2(12),
  net_weight          NUMBER(16,4),
  gross_weight        NUMBER(16,4),
  volume              NUMBER(16,4),
  is_stock_managed    BOOLEAN       DEFAULT TRUE,
  is_lot_managed      BOOLEAN       DEFAULT FALSE,
  is_serial_managed   VARCHAR2(1),
  min_stock_qty       NUMBER(16,4),
  max_stock_qty       NUMBER(16,4),
  safety_stock_qty    NUMBER(16,4),
  standard_price      NUMBER(16,4),
  standard_price_ht   NUMBER(16,4),
  average_cost        NUMBER(16,4),
  is_promo            BOOLEAN       DEFAULT FALSE,
  promo_start_date    DATE,
  promo_end_date      DATE,
  promo_price         NUMBER(16,4),
  promo_discount_rate NUMBER(5,2),
  barcode             VARCHAR2(120),
  is_barcode_manual   BOOLEAN       DEFAULT FALSE,
  is_kit              BOOLEAN       DEFAULT FALSE,
  is_misc             BOOLEAN       DEFAULT FALSE,
  is_clearance        BOOLEAN       DEFAULT FALSE,
  product_group       VARCHAR2(6),
  tax_regime          VARCHAR2(12),
  status              VARCHAR2(10)  DEFAULT 'ACTIVE',
  created_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  created_by          VARCHAR2(20),
  updated_at          TIMESTAMP,
  updated_by          VARCHAR2(20),
  CONSTRAINT pk_product             PRIMARY KEY (product_id),
  CONSTRAINT uk_product_code        UNIQUE (product_code),
  CONSTRAINT fk_product_nature      FOREIGN KEY (nature_id) 
    REFERENCES prod_nature(nature_id),
  CONSTRAINT fk_product_category    FOREIGN KEY (category_id) 
    REFERENCES prod_category(category_id),
  CONSTRAINT fk_product_subcategory FOREIGN KEY (subcategory_id) 
    REFERENCES prod_subcategory(subcategory_id),
  CONSTRAINT fk_product_brand       FOREIGN KEY (brand_id) 
    REFERENCES prod_brand(brand_id),
  CONSTRAINT fk_product_shelf       FOREIGN KEY (shelf_id) 
    REFERENCES prod_shelf(shelf_id),
  CONSTRAINT ck_product_status      CHECK (status IN ('ACTIVE','INACTIVE','DELETED'))
);

PROMPT [8] Index product
CREATE INDEX ix_product_barcode      ON product(barcode);
CREATE INDEX ix_product_category     ON product(category_id, subcategory_id);
CREATE INDEX ix_product_nature       ON product(nature_id);
CREATE INDEX ix_product_status       ON product(status);

PROMPT [9] Table product_unit
CREATE TABLE product_unit (
  product_id      NUMBER        NOT NULL,
  unit_code       VARCHAR2(12)  NOT NULL,
  coefficient     NUMBER(10,5)  NOT NULL,
  divisor         NUMBER(10,2),
  unit_price      NUMBER(15,3),
  valid_until     DATE,
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  created_by      VARCHAR2(5),
  updated_at      TIMESTAMP,
  updated_by      VARCHAR2(5),
  CONSTRAINT pk_product_unit       PRIMARY KEY (product_id, unit_code),
  CONSTRAINT fk_product_unit_prod  FOREIGN KEY (product_id) 
    REFERENCES product(product_id),
  CONSTRAINT ck_product_unit_coeff CHECK (coefficient NOT IN (0,1))
);

PROMPT [10] Table product_barcode
CREATE TABLE product_barcode (
  product_id      NUMBER        NOT NULL,
  barcode         VARCHAR2(120) NOT NULL,
  barcode_label   VARCHAR2(120),
  nb_units        NUMBER(8),
  CONSTRAINT pk_product_barcode PRIMARY KEY (product_id, barcode),
  CONSTRAINT fk_product_barcode_prod FOREIGN KEY (product_id) 
    REFERENCES product(product_id)
);

CREATE INDEX ix_product_barcode_code ON product_barcode(barcode);

PROMPT [11] Table product_price
CREATE TABLE product_price (
  price_list_id   NUMBER        NOT NULL,
  product_id      NUMBER        NOT NULL,
  price           NUMBER(16,4)  NOT NULL,
  price_ht        NUMBER(16,4),
  updated_at      DATE,
  updated_by      VARCHAR2(5),
  CONSTRAINT pk_product_price      PRIMARY KEY (price_list_id, product_id),
  CONSTRAINT fk_product_price_list FOREIGN KEY (price_list_id) 
    REFERENCES prod_price_list(price_list_id),
  CONSTRAINT fk_product_price_prod FOREIGN KEY (product_id) 
    REFERENCES product(product_id)
);

PROMPT [12] Table product_price_hist
CREATE TABLE product_price_hist (
  price_list_id   NUMBER        NOT NULL,
  product_id      NUMBER        NOT NULL,
  sequence_no     NUMBER(4)     NOT NULL,
  changed_at      DATE          NOT NULL,
  old_price       NUMBER(16,4),
  new_price       NUMBER(16,4),
  reason          VARCHAR2(120),
  changed_by      VARCHAR2(5),
  CONSTRAINT pk_product_price_hist PRIMARY KEY (price_list_id, product_id, sequence_no)
);

PROMPT [13] Table product_photo (BLOB SecureFiles)
CREATE TABLE product_photo (
  product_id      NUMBER        NOT NULL,
  photo           BLOB,
  photo_name      VARCHAR2(255),
  photo_mime      VARCHAR2(100),
  photo_size      NUMBER,
  photo_hash      VARCHAR2(64),
  created_at      TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_product_photo PRIMARY KEY (product_id),
  CONSTRAINT fk_product_photo_prod FOREIGN KEY (product_id) 
    REFERENCES product(product_id) ON DELETE CASCADE
)
LOB(photo) STORE AS SECUREFILE (
  ENABLE STORAGE IN ROW
  CHUNK 8192
  RETENTION
  CACHE READS
  COMPRESS MEDIUM
  DEDUPLICATE
);

PROMPT [14] Table product_search (AI Vector Search)
CREATE TABLE product_search (
  product_id      NUMBER        NOT NULL,
  product_name    VARCHAR2(120),
  description     CLOB,
  embedding       VECTOR(384, FLOAT32),
  updated_at      TIMESTAMP DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_product_search PRIMARY KEY (product_id),
  CONSTRAINT fk_product_search_prod FOREIGN KEY (product_id) 
    REFERENCES product(product_id) ON DELETE CASCADE
)
LOB(description) STORE AS SECUREFILE;

PROMPT
PROMPT [15] Insertion des données de base

-- Natures
INSERT INTO prod_nature (nature_code, nature_name, is_active, tax_rate)
VALUES ('FINISHED', 'Produits finis', TRUE, 18);
INSERT INTO prod_nature (nature_code, nature_name, is_active, tax_rate)
VALUES ('RAW', 'Matières premières', TRUE, 18);

-- Catégories
INSERT INTO prod_category (category_code, category_name)
VALUES ('STATIONERY', 'Papeterie');
INSERT INTO prod_category (category_code, category_name)
VALUES ('IT', 'Informatique');

-- Sous-catégories
INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
VALUES (1, 'NOTEBOOK', 'Cahiers');
INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
VALUES (1, 'PEN', 'Stylos');
INSERT INTO prod_subcategory (category_id, subcategory_code, subcategory_name)
VALUES (2, 'ACCESSORY', 'Accessoires');

-- Rayons
INSERT INTO prod_shelf (shelf_code, shelf_name) VALUES ('SH01', 'Rayon principal');

-- Marques
INSERT INTO prod_brand (brand_code, brand_name) VALUES ('BR01', 'Marque A');
INSERT INTO prod_brand (brand_code, brand_name) VALUES ('BR02', 'Marque B');

-- Listes de prix
INSERT INTO prod_price_list (price_list_code, price_list_name, tax_rate)
VALUES ('STANDARD', 'Tarif standard', 18);
INSERT INTO prod_price_list (price_list_code, price_list_name, tax_rate)
VALUES ('WHOLESALE', 'Tarif gros', 18);

-- Articles
INSERT INTO product (product_code, short_name, product_name, 
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, standard_price, barcode, status,
                     is_stock_managed, is_promo, is_barcode_manual, created_by)
VALUES ('ART001', 'Cahier 200p', 'Cahier 200 pages A4',
        1, 1, 1, 1, 1,
        'UNIT', 2500, '1234567890123', 'ACTIVE',
        TRUE, FALSE, FALSE, 'ADMIN');

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, standard_price, barcode, status,
                     is_stock_managed, is_promo, is_barcode_manual, created_by)
VALUES ('ART002', 'Stylo bleu', 'Stylo à bille bleu',
        1, 1, 2, 1, 1,
        'UNIT', 500, '1234567890124', 'ACTIVE',
        TRUE, FALSE, FALSE, 'ADMIN');

INSERT INTO product (product_code, short_name, product_name,
                     nature_id, category_id, subcategory_id, brand_id, shelf_id,
                     stock_unit, standard_price, barcode, status,
                     is_stock_managed, is_promo, is_barcode_manual, created_by)
VALUES ('ART003', 'USB 32Go', 'Clé USB 32 Go',
        1, 2, 3, 2, 1,
        'UNIT', 15000, '1234567890125', 'ACTIVE',
        TRUE, FALSE, FALSE, 'ADMIN');

-- Prix
INSERT INTO product_price (price_list_id, product_id, price, price_ht)
VALUES (1, 1, 2500, 2118.64);
INSERT INTO product_price (price_list_id, product_id, price, price_ht)
VALUES (1, 2, 500, 423.73);
INSERT INTO product_price (price_list_id, product_id, price, price_ht)
VALUES (1, 3, 15000, 12711.86);

COMMIT;

PROMPT
PROMPT [16] Validation
SELECT table_name FROM user_tables ORDER BY table_name;

PROMPT
PROMPT [17] Test BOOLEAN natif
SELECT product_code, short_name, is_stock_managed, is_promo, is_barcode_manual
  FROM product
 WHERE is_stock_managed = TRUE;

PROMPT
PROMPT [18] Volumétrie
SELECT 'product'            AS tbl, COUNT(*) AS nb FROM product
UNION ALL SELECT 'prod_nature',      COUNT(*) FROM prod_nature
UNION ALL SELECT 'prod_category',    COUNT(*) FROM prod_category
UNION ALL SELECT 'prod_subcategory', COUNT(*) FROM prod_subcategory
UNION ALL SELECT 'prod_brand',       COUNT(*) FROM prod_brand
UNION ALL SELECT 'prod_shelf',       COUNT(*) FROM prod_shelf
UNION ALL SELECT 'prod_price_list',  COUNT(*) FROM prod_price_list
UNION ALL SELECT 'product_price',    COUNT(*) FROM product_price;

PROMPT ═══════════════════════════════════════════════════════
PROMPT   ✅ SCHÉMA app_product TERMINÉ
PROMPT ═══════════════════════════════════════════════════════