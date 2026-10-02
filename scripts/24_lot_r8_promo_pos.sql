-- ============================================================
-- SCRIPT 24 : LOT R8 — Promotions POS avancé
-- Migration Oracle 11g (CEPCFPROMO, CEPCFPROMO_HR, CFID_STATUT*)
--                  → Oracle 23ai/26ai (app_product)
-- ============================================================
-- 5 nouvelles tables dans app_product (cf. procedure.txt — procédure dit 4,
-- mais le script complet en livre 5 : loyalty_status_rule est le bonus) :
--   promo_pos_config, promo_pos_product, promo_pos_hours,
--   loyalty_status_config, loyalty_status_rule
--
-- Complément des Lots R1 (promotions catalogue) et R7 (POS avancé).
-- R8 ajoute la dimension temporelle (heures, jours) + niveaux fidélité.
--
-- Notes de modernisation (vs procedure.txt d'origine) :
--  * BOOLEAN pour is_active (legacy 'A'/'I')
--  * VARCHAR2(20) pour user_code (vs 5 legacy)
--  * loyalty app_code harmonisé à VARCHAR2(8) (vs 3 incohérent)
--  * weekday VARCHAR2(7) conservé pour pattern 'YYYYYYY' (1=lundi)
--  * action_type ouvert avec CHECK explicite
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   LOT R8 : PROMOTIONS POS AVANCÉ (5 tables)
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [1/5] promo_pos_config  (← CEPCFPROMO) — entête promotion POS
CREATE TABLE promo_pos_config (
  pos_promo_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  promo_code          VARCHAR2(12)  NOT NULL,
  promo_name          VARCHAR2(120) NOT NULL,
  is_active           BOOLEAN       DEFAULT TRUE,
  start_date          DATE,
  end_date            DATE,
  weekday_mask        VARCHAR2(7)   DEFAULT '1111111',     -- 'YYYYYYY' : 1=actif par jour, 1=lundi
  hour_start          NUMBER(4),                            -- ex. 900 (= 09:00)
  hour_end            NUMBER(4),                            -- ex. 2000 (= 20:00)
  action_type         VARCHAR2(2)   NOT NULL,              -- MT = multi, BG = BOGO, PN = points+, -1 = -1€
  bonus_points        NUMBER(6),
  multiplier          NUMBER(5,1),                          -- ex. 2.0 (points x2)
  min_amount          NUMBER(16,4),                         -- seuil d'achat minimum
  priority            NUMBER(3)     DEFAULT 100,
  memo                VARCHAR2(500),
  updated_by          VARCHAR2(20)  NOT NULL,
  updated_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  created_by          VARCHAR2(20),
  created_at          TIMESTAMP,
  CONSTRAINT pk_promo_pos_config        PRIMARY KEY (pos_promo_id),
  CONSTRAINT uk_promo_pos_code          UNIQUE (promo_code),
  CONSTRAINT ck_promo_pos_action        CHECK (action_type IN ('MT','BG','PN','FX','-1')),
  CONSTRAINT ck_promo_pos_mask          CHECK (weekday_mask IS NULL OR LENGTH(weekday_mask) = 7),
  CONSTRAINT ck_promo_pos_hours         CHECK (hour_start IS NULL OR hour_end IS NULL OR hour_end > hour_start),
  CONSTRAINT ck_promo_pos_dates         CHECK (end_date IS NULL OR start_date IS NULL OR end_date >= start_date),
  CONSTRAINT ck_promo_pos_multiplier    CHECK (multiplier IS NULL OR multiplier > 0)
);

CREATE INDEX ix_promo_pos_active        ON promo_pos_config(is_active, start_date, end_date);
CREATE INDEX ix_promo_pos_priority      ON promo_pos_config(priority, promo_code);

PROMPT
PROMPT [2/5] promo_pos_product  (← CEPCFPROMO_ART) — produits éligibles
CREATE TABLE promo_pos_product (
  pos_promo_id        NUMBER        NOT NULL,
  line_no             NUMBER(4)     NOT NULL,
  nature_code         VARCHAR2(12),
  category_code       VARCHAR2(16),
  subcategory_code    VARCHAR2(16),
  product_group       VARCHAR2(6),
  product_code        VARCHAR2(80),                          -- si renseigné, override la sélection par catégorie
  product_label       VARCHAR2(120),
  promo_price         NUMBER(16,4),                         -- prix spécial
  discount_rate       NUMBER(5,2),                          -- remise %
  updated_by          VARCHAR2(20)  NOT NULL,
  updated_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_promo_pos_product       PRIMARY KEY (pos_promo_id, line_no),
  CONSTRAINT fk_promo_pos_product_hdr   FOREIGN KEY (pos_promo_id)
    REFERENCES promo_pos_config(pos_promo_id) ON DELETE CASCADE,
  CONSTRAINT ck_promo_pos_prod_amounts  CHECK ((promo_price IS NOT NULL) OR (discount_rate IS NOT NULL)),
  CONSTRAINT ck_promo_pos_prod_disc     CHECK (discount_rate IS NULL OR (discount_rate > 0 AND discount_rate <= 100))
);

CREATE INDEX ix_promo_pos_prod_code     ON promo_pos_product(product_code);
CREATE INDEX ix_promo_pos_prod_cat      ON promo_pos_product(category_code, subcategory_code);

PROMPT
PROMPT [3/5] promo_pos_hours  (← CEPCFPROMO_HR) — plages horaires d'application
CREATE TABLE promo_pos_hours (
  pos_promo_id        NUMBER        NOT NULL,
  weekday             NUMBER(1)     NOT NULL,               -- 1=lundi ... 7=dimanche (ISO)
  start_time          NUMBER(4)     NOT NULL,               -- HH24*100 (ex. 900 = 09:00)
  end_time            NUMBER(4)     NOT NULL,               -- ex. 1200 = 12:00
  updated_by          VARCHAR2(20)  NOT NULL,
  updated_at          TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_promo_pos_hours         PRIMARY KEY (pos_promo_id, weekday, start_time),
  CONSTRAINT fk_promo_pos_hours_hdr     FOREIGN KEY (pos_promo_id)
    REFERENCES promo_pos_config(pos_promo_id) ON DELETE CASCADE,
  CONSTRAINT ck_promo_pos_hr_weekday    CHECK (weekday BETWEEN 1 AND 7),
  CONSTRAINT ck_promo_pos_hr_range      CHECK (end_time > start_time),
  CONSTRAINT ck_promo_pos_hr_format     CHECK (start_time BETWEEN 0 AND 2359)
);

CREATE INDEX ix_promo_pos_hours_wh       ON promo_pos_hours(weekday, start_time);

PROMPT
PROMPT [4/5] loyalty_status_config  (← CFID_STATUT) — niveaux fidélité
CREATE TABLE loyalty_status_config (
  status_id             NUMBER GENERATED ALWAYS AS IDENTITY,
  app_code              VARCHAR2(8)   NOT NULL,             -- harmonisé avec loyalty_app.app_code
  status_level          NUMBER(2)     NOT NULL,             -- 1=Bronze, 2=Silver, 3=Gold, 4=Platinum, 5=Diamond
  status_name           VARCHAR2(60)  NOT NULL,
  customer_type_code    VARCHAR2(30)  NOT NULL,             -- code type client API externe
  points_threshold      NUMBER(12),                         -- points requis pour atteindre ce niveau
  inactivity_delay      NUMBER(5),                          -- jours avant déclassement
  point_value           NUMBER(8),                          -- valeur d'1 point en devise
  display_color         VARCHAR2(7),                        -- code couleur hex (#RRGGBB) pour UI
  icon_code             VARCHAR2(20),                       -- icône UI
  memo                  VARCHAR2(255),
  is_active             BOOLEAN       DEFAULT TRUE,
  created_at            TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT pk_loyalty_status_config      PRIMARY KEY (status_id),
  CONSTRAINT uk_loyalty_status_app_level   UNIQUE (app_code, status_level),
  CONSTRAINT ck_loyalty_status_level       CHECK (status_level BETWEEN 1 AND 10),
  CONSTRAINT ck_loyalty_status_threshold   CHECK (points_threshold IS NULL OR points_threshold >= 0)
);

PROMPT
PROMPT [5/5] loyalty_status_rule — règles de valeur de point par POS (bonus)
CREATE TABLE loyalty_status_rule (
  app_code              VARCHAR2(8)   NOT NULL,
  status_level          NUMBER(2)     NOT NULL,
  pos_code              VARCHAR2(5)   NOT NULL,
  point_value_override  NUMBER(8),                          -- override du loyalty_status_config.point_value
  bonus_rate_override   NUMBER(5,2),                        -- bonus % spécifique à ce POS
  updated_at            TIMESTAMP     DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_loyalty_status_rule        PRIMARY KEY (app_code, status_level, pos_code),
  CONSTRAINT fk_lsr_status                 FOREIGN KEY (app_code, status_level)
    REFERENCES loyalty_status_config(app_code, status_level) ON DELETE CASCADE,
  CONSTRAINT ck_lsr_point_value            CHECK (point_value_override IS NULL OR point_value_override > 0),
  CONSTRAINT ck_lsr_bonus_rate             CHECK (bonus_rate_override IS NULL OR (bonus_rate_override >= 0 AND bonus_rate_override <= 100))
);

CREATE INDEX ix_loyalty_status_rule_pos    ON loyalty_status_rule(pos_code);

PROMPT
PROMPT ═══ Privilèges croisés ═══
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

GRANT SELECT ON app_product.promo_pos_config         TO app_sales;
GRANT SELECT ON app_product.promo_pos_product       TO app_sales;
GRANT SELECT ON app_product.promo_pos_hours         TO app_sales;
GRANT SELECT ON app_product.loyalty_status_config   TO app_sales;
GRANT SELECT ON app_product.loyalty_status_rule     TO app_sales;

GRANT SELECT ON app_product.promo_pos_config         TO app_pos;
GRANT SELECT ON app_product.promo_pos_product       TO app_pos;

GRANT SELECT ON app_product.loyalty_status_config   TO app_party;

GRANT SELECT ON app_product.promo_pos_config         TO app_api;
GRANT SELECT ON app_product.promo_pos_product       TO app_api;
GRANT SELECT ON app_product.promo_pos_hours         TO app_api;
GRANT SELECT ON app_product.loyalty_status_config   TO app_api;
GRANT SELECT ON app_product.loyalty_status_rule     TO app_api;

PROMPT
PROMPT ═══ Validation — Tables créées ═══
CONNECT app_product/AppProduct#2026@localhost:1521/FREEPDB1
SELECT table_name, num_rows
  FROM user_tables
 WHERE table_name IN ('PROMO_POS_CONFIG','PROMO_POS_PRODUCT','PROMO_POS_HOURS',
                      'LOYALTY_STATUS_CONFIG','LOYALTY_STATUS_RULE')
 ORDER BY table_name;

PROMPT
PROMPT [Validation] Contraintes
SELECT constraint_name, constraint_type, status
  FROM user_constraints
 WHERE table_name IN ('PROMO_POS_CONFIG','PROMO_POS_PRODUCT','PROMO_POS_HOURS',
                      'LOYALTY_STATUS_CONFIG','LOYALTY_STATUS_RULE')
 ORDER BY table_name, constraint_name;

PROMPT
PROMPT [Validation] Objets invalides (doit être vide)
SELECT object_name, object_type, status
  FROM user_objects
 WHERE status = 'INVALID';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ LOT R8 TERMINÉ (5 tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
