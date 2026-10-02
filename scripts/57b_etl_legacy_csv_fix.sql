-- ============================================================
-- SCRIPT 57b : Import contrôlé des CSV legacy vers le modèle moderne
-- ============================================================
-- BUGS du 57b précédent :
--   1. PLS-00103 END; ligne 56 : END LOOP manquant dans le bloc GCPART
--   2. ORA-01031 sur app_inv.inv_stock : app_api n'a que SELECT (manque INSERT/UPDATE)
--   3. ORA-00942 sur app_product.prod_price_list : pas de GRANT SELECT
--   4. Les CSV ont des en-têtes et des ordres de colonnes distincts du modèle cible.
--   5. Les codes non mappés sont rabattus vers les référentiels 999 de S03.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

-- Étape préalable : GRANTs manquants (connecté en system)
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA

PROMPT ══════════════════════════════════════════════════════════
PROMPT   FIX ETL CSV legacy v2 — GRANTs + END LOOP + bonnes colonnes
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [0/9] GRANTs manquants pour app_api
GRANT SELECT, INSERT, UPDATE ON app_inv.inv_stock                TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_product.product              TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_product.prod_price_list       TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_product.product_price        TO app_api;
GRANT SELECT ON app_product.prod_nature TO app_api;
GRANT SELECT ON app_product.prod_category TO app_api;
GRANT SELECT ON app_product.prod_subcategory TO app_api;
GRANT SELECT ON app_product.prod_brand TO app_api;
GRANT SELECT ON app_product.prod_shelf TO app_api;
GRANT SELECT, INSERT, UPDATE ON app_party.party                  TO app_api;
GRANT SELECT ON app_party.party_nature TO app_api;
GRANT SELECT ON app_org.org_warehouse TO app_api;

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

-- Drop des anciennes tables externes
BEGIN
  FOR t IN (SELECT table_name FROM user_tables WHERE table_name LIKE 'EXT_%') LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name;
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE != -942 THEN RAISE; END IF;
    END;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('  → Tables externes précédentes droppées.');
END;
/

-- Directory DATA_DIR
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA
CREATE OR REPLACE DIRECTORY data_dir AS '/home/oracle/erp-db-23ai/docs';
GRANT READ ON DIRECTORY data_dir TO app_api;
PROMPT ✓ Directory DATA_DIR prêt.

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

-- ====================================================================
-- 1) ext_gcpart
-- ====================================================================
PROMPT
PROMPT [1/9] ext_gcpart (articles legacy)
CREATE TABLE ext_gcpart (
  codart VARCHAR2(80), tensto VARCHAR2(120), libartr VARCHAR2(120),
  libart VARCHAR2(120), libart2 VARCHAR2(120), unistk VARCHAR2(12),
  uniach VARCHAR2(12), univen VARCHAR2(12), part_type VARCHAR2(20),
  codnata VARCHAR2(12), codfam VARCHAR2(16), codsfam VARCHAR2(16),
  pdsnet VARCHAR2(40), pdsbrut VARCHAR2(40), volume VARCHAR2(40),
  stkmin VARCHAR2(40), stkmax VARCHAR2(40), stksec VARCHAR2(40),
  tarifstd VARCHAR2(40), tarifpro VARCHAR2(40), promo VARCHAR2(12),
  pro_ddeb VARCHAR2(40), pro_dfin VARCHAR2(40), prmp VARCHAR2(40),
  codbarre VARCHAR2(120), datcre VARCHAR2(40), cuti VARCHAR2(20),
  datmod VARCHAR2(40), muti VARCHAR2(20), codcrit VARCHAR2(20),
  mrgmin VARCHAR2(40), kit VARCHAR2(12), geslot VARCHAR2(12),
  coeff_ach VARCHAR2(40), coeff_ven VARCHAR2(40), codray VARCHAR2(12),
  pro_tauxrem VARCHAR2(40), etat VARCHAR2(4), codrtax VARCHAR2(12),
  divers VARCHAR2(12), liquidation VARCHAR2(12), gestion_locale VARCHAR2(12),
  cb_manuel VARCHAR2(12), posdoua VARCHAR2(20), codfrnprinc VARCHAR2(32),
  tarifstd_ht VARCHAR2(40), unistk_sec VARCHAR2(12), nbunit VARCHAR2(40),
  memo_ccial VARCHAR2(500), reforigine VARCHAR2(120), codgrpe VARCHAR2(20),
  gesnserie VARCHAR2(12), code_marque VARCHAR2(20), codtaxe_unite VARCHAR2(20),
  transfert VARCHAR2(12)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE SKIP 1
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPART_20260612d1759-articles.csv')
) REJECT LIMIT UNLIMITED;

PROMPT
PROMPT  ETL GCPART → app_product.product (codes source + références de repli)
DECLARE
  v_total NUMBER := 0;
  v_unmapped NUMBER := 0;
BEGIN
  SELECT COUNT(*) INTO v_unmapped
    FROM ext_gcpart e
   WHERE e.codart IS NOT NULL
     AND (NOT EXISTS (SELECT 1 FROM app_product.prod_nature n WHERE n.nature_code = TRIM(e.codnata))
       OR NOT EXISTS (SELECT 1 FROM app_product.prod_category c WHERE c.category_code = TRIM(e.codfam))
       OR NOT EXISTS (SELECT 1 FROM app_product.prod_brand b WHERE b.brand_code = TRIM(e.code_marque)));

  MERGE INTO app_product.product tgt
  USING (
    SELECT TRIM(e.codart) AS product_code,
           SUBSTR(NVL(NULLIF(TRIM(e.libartr), ''), TRIM(e.libart)), 1, 80) AS short_name,
           SUBSTR(TRIM(e.libart), 1, 120) AS product_name,
           SUBSTR(TRIM(e.libart2), 1, 120) AS product_name_2,
           NVL(n.nature_id, default_nature.nature_id) AS nature_id,
           NVL(c.category_id, default_category.category_id) AS category_id,
           NVL(sc.subcategory_id, default_subcategory.subcategory_id) AS subcategory_id,
           NVL(b.brand_id, default_brand.brand_id) AS brand_id,
           NVL(sh.shelf_id, default_shelf.shelf_id) AS shelf_id,
           NVL(NULLIF(TRIM(e.unistk), ''), 'PCS') AS stock_unit,
           TO_NUMBER(NULLIF(TRIM(e.tarifstd), '')) AS standard_price,
           TO_NUMBER(NULLIF(TRIM(e.tarifstd_ht), '')) AS standard_price_ht,
           TO_NUMBER(NULLIF(TRIM(e.prmp), '')) AS average_cost,
           TO_NUMBER(NULLIF(TRIM(e.stkmin), '')) AS min_stock_qty,
           TO_NUMBER(NULLIF(TRIM(e.stkmax), '')) AS max_stock_qty,
           TO_NUMBER(NULLIF(TRIM(e.stksec), '')) AS safety_stock_qty,
           SUBSTR(TRIM(e.codbarre), 1, 120) AS barcode,
           CASE WHEN UPPER(TRIM(e.etat)) = 'I' THEN 'INACTIVE' ELSE 'ACTIVE' END AS status,
           CASE WHEN UPPER(TRIM(e.geslot)) IN ('O','Y','1') THEN TRUE ELSE FALSE END AS is_lot_managed
      FROM ext_gcpart e
      CROSS JOIN app_product.prod_nature default_nature
      CROSS JOIN app_product.prod_category default_category
      CROSS JOIN app_product.prod_subcategory default_subcategory
      CROSS JOIN app_product.prod_brand default_brand
      CROSS JOIN app_product.prod_shelf default_shelf
      LEFT JOIN app_product.prod_nature n ON n.nature_code = TRIM(e.codnata)
      LEFT JOIN app_product.prod_category c ON c.category_code = TRIM(e.codfam)
      LEFT JOIN app_product.prod_subcategory sc
        ON sc.category_id = c.category_id AND sc.subcategory_code = TRIM(e.codsfam)
      LEFT JOIN app_product.prod_brand b ON b.brand_code = TRIM(e.code_marque)
      LEFT JOIN app_product.prod_shelf sh ON sh.shelf_code = TRIM(e.codray)
     WHERE e.codart IS NOT NULL
       AND default_nature.nature_code = '999'
       AND default_category.category_code = '999'
       AND default_subcategory.category_id = default_category.category_id
       AND default_subcategory.subcategory_code = 'SF999'
       AND default_brand.brand_code = 'DIN'
       AND default_shelf.shelf_code = 'R99'
  ) src
  ON (tgt.product_code = src.product_code)
  WHEN MATCHED THEN UPDATE SET
    tgt.short_name = src.short_name,
    tgt.product_name = src.product_name,
    tgt.product_name_2 = src.product_name_2,
    tgt.nature_id = src.nature_id,
    tgt.category_id = src.category_id,
    tgt.subcategory_id = src.subcategory_id,
    tgt.brand_id = src.brand_id,
    tgt.shelf_id = src.shelf_id,
    tgt.stock_unit = src.stock_unit,
    tgt.standard_price = src.standard_price,
    tgt.standard_price_ht = src.standard_price_ht,
    tgt.average_cost = src.average_cost,
    tgt.min_stock_qty = src.min_stock_qty,
    tgt.max_stock_qty = src.max_stock_qty,
    tgt.safety_stock_qty = src.safety_stock_qty,
    tgt.barcode = src.barcode,
    tgt.status = src.status,
    tgt.is_lot_managed = src.is_lot_managed,
    tgt.updated_at = SYSTIMESTAMP,
    tgt.updated_by = 'ETL57'
  WHEN NOT MATCHED THEN INSERT (
    product_code, short_name, product_name, product_name_2,
    nature_id, category_id, subcategory_id, brand_id, shelf_id,
    stock_unit, is_stock_managed, is_lot_managed,
    standard_price, standard_price_ht, average_cost,
    min_stock_qty, max_stock_qty, safety_stock_qty, barcode, status, created_by
  ) VALUES (
    src.product_code, src.short_name, src.product_name, src.product_name_2,
    src.nature_id, src.category_id, src.subcategory_id, src.brand_id, src.shelf_id,
    src.stock_unit, TRUE, src.is_lot_managed,
    src.standard_price, src.standard_price_ht, src.average_cost,
    src.min_stock_qty, src.max_stock_qty, src.safety_stock_qty, src.barcode, src.status, 'ETL_57'
  );
  v_total := SQL%ROWCOUNT;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' produits insérés/mis à jour; ' ||
                       v_unmapped || ' lignes utilisent les référentiels de repli.');
END;
/

-- ====================================================================
-- 2) ext_gcstock
-- ====================================================================
PROMPT
PROMPT [2/9] ext_gcstock (stock legacy)
CREATE TABLE ext_gcstock (
  coddep VARCHAR2(5), codart VARCHAR2(80), qte_stock VARCHAR2(40),
  qte_cde VARCHAR2(40), qte_reserv VARCHAR2(40), qte_pret VARCHAR2(40),
  dder_sor VARCHAR2(40), dder_ent VARCHAR2(40), qte_inv VARCHAR2(40),
  dder_inv VARCHAR2(40), emplac VARCHAR2(40), qte_da VARCHAR2(40)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE SKIP 1
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCSTOCK_202606121810.csv')
) REJECT LIMIT UNLIMITED;

PROMPT
PROMPT  ETL GCSTOCK → app_inv.inv_stock (MERGE idempotent)
DECLARE
  v_total NUMBER;
BEGIN
  MERGE INTO app_inv.inv_stock tgt
  USING (
    SELECT TRIM(e.coddep) AS warehouse_code,
           TRIM(e.codart) AS product_code,
           TO_NUMBER(NULLIF(TRIM(e.qte_stock), '')) AS stock_qty
      FROM ext_gcstock e
      JOIN app_product.product p ON p.product_code = TRIM(e.codart)
      JOIN app_org.org_warehouse w ON w.warehouse_code = TRIM(e.coddep)
     WHERE e.codart IS NOT NULL AND e.coddep IS NOT NULL
  ) src
  ON (tgt.warehouse_code = src.warehouse_code AND tgt.product_code = src.product_code)
  WHEN MATCHED THEN UPDATE SET
    tgt.stock_qty = src.stock_qty,
    tgt.updated_at = SYSTIMESTAMP
  WHEN NOT MATCHED THEN INSERT (warehouse_code, product_code, stock_qty, last_in_at)
    VALUES (src.warehouse_code, src.product_code, src.stock_qty, SYSDATE);
  v_total := SQL%ROWCOUNT;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' stocks insérés/mis à jour.');
END;
/

-- ====================================================================
-- 3) Référentiel GCPTARIF (y compris les listes A/B/3 absentes des seeds)
-- ====================================================================
PROMPT
PROMPT [3/9] ext_gcptarif (listes de prix legacy)
CREATE TABLE ext_gcptarif (
  codtarif VARCHAR2(8), libtarif VARCHAR2(120), ttaxe_tarif VARCHAR2(40),
  calc VARCHAR2(4), formule VARCHAR2(120), actif VARCHAR2(4),
  cle_auto VARCHAR2(20), valeur_arrondi VARCHAR2(40)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE SKIP 1
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPTARIF_202606121806.csv')
) REJECT LIMIT UNLIMITED;

MERGE INTO app_product.prod_price_list tgt
USING (
  SELECT TRIM(codtarif) AS price_list_code,
         SUBSTR(TRIM(libtarif), 1, 120) AS price_list_name,
         TO_NUMBER(NULLIF(TRIM(ttaxe_tarif), '')) AS tax_rate,
         CASE WHEN UPPER(TRIM(actif)) IN ('O','Y','1') THEN TRUE ELSE FALSE END AS is_active,
         TO_NUMBER(NULLIF(TRIM(valeur_arrondi), '')) AS rounding_value
    FROM ext_gcptarif
   WHERE codtarif IS NOT NULL
) src
ON (tgt.price_list_code = src.price_list_code)
WHEN MATCHED THEN UPDATE SET
  tgt.price_list_name = src.price_list_name,
  tgt.tax_rate = src.tax_rate,
  tgt.is_active = src.is_active,
  tgt.rounding_value = src.rounding_value
WHEN NOT MATCHED THEN INSERT (price_list_code, price_list_name, tax_rate, is_active, rounding_value)
  VALUES (src.price_list_code, src.price_list_name, src.tax_rate, src.is_active, src.rounding_value);
COMMIT;

PROMPT [4/9] ext_gcptarif_art (prix legacy)
CREATE TABLE ext_gcptarif_art (
  codtarif   VARCHAR2(8),
  codart     VARCHAR2(80),
  tarif      VARCHAR2(40),
  tarif_ht   VARCHAR2(40),
  datmaj     VARCHAR2(40),
  coduti     VARCHAR2(20)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE SKIP 1
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPTARIF_ART_202606121807-prix.csv')
) REJECT LIMIT UNLIMITED;

PROMPT
PROMPT  ETL GCPTARIF_ART → app_product.product_price (upsert)
DECLARE
  v_total NUMBER;
  v_unmatched NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_unmatched
    FROM ext_gcptarif_art e
   WHERE e.codart IS NOT NULL
     AND (NOT EXISTS (SELECT 1 FROM app_product.product p WHERE p.product_code = TRIM(e.codart))
       OR NOT EXISTS (SELECT 1 FROM app_product.prod_price_list pl WHERE pl.price_list_code = TRIM(e.codtarif)));

  MERGE INTO app_product.product_price tgt
  USING (
    SELECT pl.price_list_id, p.product_id,
           TO_NUMBER(NULLIF(TRIM(e.tarif), '')) AS price,
           TO_NUMBER(NULLIF(TRIM(e.tarif_ht), '')) AS price_ht
      FROM ext_gcptarif_art e
      JOIN app_product.prod_price_list pl ON pl.price_list_code = TRIM(e.codtarif)
      JOIN app_product.product p ON p.product_code = TRIM(e.codart)
     WHERE e.codart IS NOT NULL
  ) src
  ON (tgt.price_list_id = src.price_list_id AND tgt.product_id = src.product_id)
  WHEN MATCHED THEN UPDATE SET
    tgt.price = src.price,
    tgt.price_ht = src.price_ht,
    tgt.updated_at = SYSDATE,
    tgt.updated_by = 'ETL57'
  WHEN NOT MATCHED THEN INSERT (price_list_id, product_id, price, price_ht, updated_at, updated_by)
    VALUES (src.price_list_id, src.product_id, src.price, src.price_ht, SYSDATE, 'ETL57');
  v_total := SQL%ROWCOUNT;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' prix insérés/mis à jour.');
  IF v_unmatched > 0 THEN
    RAISE_APPLICATION_ERROR(-20571, v_unmatched || ' prix sans article ou liste de prix correspondante.');
  END IF;
END;
/

-- ====================================================================
-- 5) ext_gcptie — colonnes jusqu'à CODE_VILLE (offset 55)
-- ====================================================================
PROMPT
PROMPT [5/9] ext_gcptie (tiers legacy)
CREATE TABLE ext_gcptie (
  codtie VARCHAR2(32), nomtie VARCHAR2(120), codnatt VARCHAR2(20), codfam VARCHAR2(20),
  coddev VARCHAR2(20), susp VARCHAR2(4), divers VARCHAR2(4), codrem VARCHAR2(20),
  codrep VARCHAR2(20), numcont VARCHAR2(40), codreg VARCHAR2(20), adresse1 VARCHAR2(120),
  adresse2 VARCHAR2(120), adresse3 VARCHAR2(120), adresse4 VARCHAR2(120), cpostal VARCHAR2(80),
  pays VARCHAR2(20), contact VARCHAR2(120), fonction VARCHAR2(40), tel VARCHAR2(60),
  fax VARCHAR2(120), internet VARCHAR2(120), numcpt VARCHAR2(40), codrtax VARCHAR2(20),
  codmrgl VARCHAR2(20), codtarif VARCHAR2(8), modtarif VARCHAR2(20), modpuv VARCHAR2(20),
  codech VARCHAR2(20), opfac VARCHAR2(20), opgrp VARCHAR2(20), nbc_fre VARCHAR2(20),
  creaut VARCHAR2(20), rib_bq VARCHAR2(80), rib_adrbq VARCHAR2(120), rib_codbq VARCHAR2(40),
  rib_guichet VARCHAR2(40), rib_cpte VARCHAR2(80), rib_cle VARCHAR2(20), zlibre1 VARCHAR2(120),
  zlibre2 VARCHAR2(120), datran_com VARCHAR2(40), solderan_com VARCHAR2(40), nbj_credit VARCHAR2(20),
  numrc VARCHAR2(40), memo VARCHAR2(500), cuti VARCHAR2(20), datcre VARCHAR2(40),
  muti VARCHAR2(20), datmod VARCHAR2(40), code_localite VARCHAR2(20), email VARCHAR2(120),
  vtes_comptant VARCHAR2(20), vtes_terme VARCHAR2(20), code_ville VARCHAR2(10),
  sscls_vte VARCHAR2(20), numtie VARCHAR2(40), all_ptvte VARCHAR2(20),
  codsectact VARCHAR2(20), codtie_grpe VARCHAR2(32), codgest VARCHAR2(20),
  codsfam VARCHAR2(20)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE SKIP 1
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPTIE_202606121809.csv')
) REJECT LIMIT UNLIMITED;

PROMPT
PROMPT  ETL GCPTIE → app_party.party (natures et champs par code source)
DECLARE
  v_total NUMBER;
  v_unmatched NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_unmatched
    FROM ext_gcptie e
   WHERE e.codtie IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM app_party.party_nature n WHERE n.nature_code = TRIM(e.codnatt));

  MERGE INTO app_party.party tgt
  USING (
    SELECT TRIM(e.codtie) AS party_code,
           SUBSTR(TRIM(e.nomtie), 1, 50) AS party_name,
           n.nature_id,
           'XAF' AS currency_code,
           SUBSTR(TRIM(e.adresse1), 1, 120) AS address_1,
           SUBSTR(TRIM(e.adresse2), 1, 120) AS address_2,
           SUBSTR(TRIM(e.adresse3), 1, 120) AS address_3,
           SUBSTR(TRIM(e.adresse4), 1, 120) AS address_4,
           SUBSTR(TRIM(e.cpostal), 1, 80) AS postal_code,
           SUBSTR(TRIM(e.pays), 1, 12) AS country,
           SUBSTR(TRIM(e.code_ville), 1, 3) AS city_code,
           SUBSTR(TRIM(e.contact), 1, 120) AS contact_name,
           SUBSTR(TRIM(e.fonction), 1, 12) AS contact_position,
           SUBSTR(TRIM(e.tel), 1, 60) AS phone,
           SUBSTR(TRIM(e.fax), 1, 120) AS fax,
           SUBSTR(TRIM(e.internet), 1, 120) AS website,
           SUBSTR(TRIM(e.email), 1, 120) AS email,
           pl.price_list_id,
           SUBSTR(TRIM(e.codrtax), 1, 12) AS tax_regime,
           SUBSTR(TRIM(e.codmrgl), 1, 12) AS payment_method,
           SUBSTR(TRIM(e.codech), 1, 12) AS payment_terms,
           TO_NUMBER(NULLIF(TRIM(e.nbj_credit), '')) AS credit_days,
           CASE WHEN UPPER(TRIM(e.susp)) IN ('O','Y','1') THEN TRUE ELSE FALSE END AS is_blocked,
           CASE WHEN TRIM(e.codnatt) = 'CPO' THEN TRUE ELSE FALSE END AS is_misc,
           CASE WHEN UPPER(TRIM(e.susp)) IN ('O','Y','1') THEN 'INACTIVE' ELSE 'ACTIVE' END AS status
      FROM ext_gcptie e
      JOIN app_party.party_nature n ON n.nature_code = TRIM(e.codnatt)
      LEFT JOIN app_product.prod_price_list pl ON pl.price_list_code = TRIM(e.codtarif)
     WHERE e.codtie IS NOT NULL
  ) src
  ON (tgt.party_code = src.party_code)
  WHEN MATCHED THEN UPDATE SET
    tgt.party_name = src.party_name,
    tgt.nature_id = src.nature_id,
    tgt.currency_code = src.currency_code,
    tgt.address_1 = src.address_1,
    tgt.address_2 = src.address_2,
    tgt.address_3 = src.address_3,
    tgt.address_4 = src.address_4,
    tgt.postal_code = src.postal_code,
    tgt.country = src.country,
    tgt.city_code = src.city_code,
    tgt.contact_name = src.contact_name,
    tgt.contact_position = src.contact_position,
    tgt.phone = src.phone,
    tgt.fax = src.fax,
    tgt.website = src.website,
    tgt.email = src.email,
    tgt.price_list_id = src.price_list_id,
    tgt.tax_regime = src.tax_regime,
    tgt.payment_method = src.payment_method,
    tgt.payment_terms = src.payment_terms,
    tgt.credit_days = src.credit_days,
    tgt.is_blocked = src.is_blocked,
    tgt.is_misc = src.is_misc,
    tgt.status = src.status,
    tgt.updated_at = SYSTIMESTAMP,
    tgt.updated_by = 'ETL57'
  WHEN NOT MATCHED THEN INSERT (
    party_code, party_name, nature_id, currency_code,
    address_1, address_2, address_3, address_4, postal_code,
    country, city_code, contact_name, contact_position, phone, fax, website, email,
    price_list_id, tax_regime, payment_method, payment_terms, credit_days,
    is_blocked, is_misc, status, created_by
  ) VALUES (
    src.party_code, src.party_name, src.nature_id, src.currency_code,
    src.address_1, src.address_2, src.address_3, src.address_4, src.postal_code,
    src.country, src.city_code, src.contact_name, src.contact_position, src.phone, src.fax, src.website, src.email,
    src.price_list_id, src.tax_regime, src.payment_method, src.payment_terms, src.credit_days,
    src.is_blocked, src.is_misc, src.status, 'ETL57'
  );
  v_total := SQL%ROWCOUNT;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' tiers insérés/mis à jour.');
  IF v_unmatched > 0 THEN
    RAISE_APPLICATION_ERROR(-20572, v_unmatched || ' tiers sans nature source correspondante.');
  END IF;
END;
/

-- ====================================================================
-- 5) ext_gcptbrd
-- ====================================================================
PROMPT
PROMPT [5/9] ext_gcptbrd (types bordereaux)
CREATE TABLE ext_gcptbrd (
  codtbrd    VARCHAR2(20),
  libtbrd    VARCHAR2(120),
  saisaut VARCHAR2(8), cle_saisie VARCHAR2(20), cle_modif VARCHAR2(20),
  cle_supp VARCHAR2(20), valbrd VARCHAR2(20), type VARCHAR2(20),
  saistie VARCHAR2(20), codtie_def VARCHAR2(32), opsais VARCHAR2(20),
  majstock VARCHAR2(8), sens VARCHAR2(8), transfert VARCHAR2(8),
  tbrdctrp VARCHAR2(20), majreserv VARCHAR2(8), majpret VARCHAR2(8),
  opnum VARCHAR2(20), codcpt VARCHAR2(20), opnum_doc VARCHAR2(20),
  cptdoc VARCHAR2(20), opfac VARCHAR2(20), optarif VARCHAR2(20),
  codtarif VARCHAR2(8), ed_msq VARCHAR2(20), all_nata VARCHAR2(20),
  all_natt VARCHAR2(20), memo VARCHAR2(500), cptfac VARCHAR2(20),
  opsais_ven VARCHAR2(20), majcde VARCHAR2(8), trans_maj VARCHAR2(8),
  op_trans VARCHAR2(20), coddep_def VARCHAR2(5), depctrp_def VARCHAR2(5),
  ven_comptant VARCHAR2(8), cle_reed VARCHAR2(20), majstatut VARCHAR2(8),
  comptab VARCHAR2(20)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE SKIP 1
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPTBRD_202606121808.csv')
) REJECT LIMIT UNLIMITED;
PROMPT  Table externe ext_gcptbrd créée.

-- ====================================================================
-- 6) ext_gcprtax
-- ====================================================================
PROMPT
PROMPT [6/9] ext_gcprtax (taux taxes)
CREATE TABLE ext_gcprtax (
  codrtax    VARCHAR2(12),
  librtax    VARCHAR2(120),
  codtax1 VARCHAR2(12), codtax2 VARCHAR2(12), codtax3 VARCHAR2(12),
  codtax4 VARCHAR2(12), app_art VARCHAR2(8), app_tie VARCHAR2(8),
  exonere VARCHAR2(8)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE SKIP 1
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPRTAX_202606121806.csv')
) REJECT LIMIT UNLIMITED;
PROMPT  Table externe ext_gcprtax créée.

-- ====================================================================
-- 7) Stats ETL (stats fonctionne maintenant avec GRANTs)
-- ====================================================================
PROMPT
PROMPT ═══ Stats ETL ═══
SELECT 'app_product.product'        AS tbl, COUNT(*) AS nb FROM app_product.product
UNION ALL SELECT 'app_inv.inv_stock',         COUNT(*) FROM app_inv.inv_stock
UNION ALL SELECT 'app_product.product_price', COUNT(*) FROM app_product.product_price
UNION ALL SELECT 'app_party.party',           COUNT(*) FROM app_party.party
UNION ALL SELECT 'app_product.prod_price_list', COUNT(*) FROM app_product.prod_price_list
 ORDER BY tbl;

-- ====================================================================
-- 8) Privilèges tables externes APP_API
-- ====================================================================
CONNECT sys/oracle@localhost:1521/FREEPDB1 AS SYSDBA
GRANT SELECT ON app_api.ext_gcpart       TO app_product;
GRANT SELECT ON app_api.ext_gcstock      TO app_inv;
GRANT SELECT ON app_api.ext_gcptarif_art TO app_product;
GRANT SELECT ON app_api.ext_gcptie       TO app_party;
GRANT SELECT ON app_api.ext_gcptbrd      TO app_doc;
GRANT SELECT ON app_api.ext_gcprtax      TO app_gl;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✓ Import CSV terminé : produits, stocks, listes/prix et tiers
PROMPT   - GCPART/GCPSTOCK/GCPRTAX/GCPTBRD/GCPTIE sont des tables de staging
PROMPT   - toutes les external tables ignorent leur ligne d'en-tête
PROMPT   - les lignes sans correspondance entraînent une erreur explicite
PROMPT ══════════════════════════════════════════════════════════
EXIT;
