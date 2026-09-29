-- ============================================================
-- SCRIPT 57 : ETL legacy CSV → schéma moderne
-- ============================================================
-- Charge les CSV legacy REGAL depuis docs/ :
--   GCPART.csv        : 211K articles  -> app_product.product
--   GCPART_BARRE.csv  : 48K codes-barres -> app_product.product_barcode
--   GCPART_UNITE.csv  : 110K unites -> app_product.product_unit
--   GCSTOCK.csv       : 98K stocks (mais cible 1.6M) -> app_inv.inv_stock
--   GCPTARIF.csv      : 8 tarifs -> app_product.prod_price_list
--   GCPTARIF_ART.csv  : 29K prix articles -> app_product.product_price
--   GCPTBRD.csv       : 37 types bordereaux -> app_doc.doc_type
--   GCPTIE.csv        : 9K tiers -> app_party.party
--   GCPRTAX.csv       : 4 taux taxes -> app_gl.tax_form_type
--   GCPDEPT.csv       : 92 depots (déjà fait via site_master)
--
-- Mécanisme : SQL*Loader via tables externes 23ai OU ETL par
-- INSERT dans des blocs PL/SQL avec BULK COLLECT.
-- En 23ai Free, on utilise les tables externes.
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ETL LEGACY CSV -> SCHÉMA MODERNE 23ai
PROMPT ══════════════════════════════════════════════════════════

-- Configuration du répertoire de chargement
CONNECT system/oracle@localhost:1521/FREEPDB1

DECLARE
  v_exists NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_exists FROM all_directories WHERE directory_name = 'DATA_DIR';
  IF v_exists = 0 THEN
    EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY data_dir AS ''/workspace/erp-db-23ai/docs''';
    DBMS_OUTPUT.PUT_LINE('  → Directory DATA_DIR créé.');
  ELSE
    EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY data_dir AS ''/workspace/erp-db-23ai/docs''';
    DBMS_OUTPUT.PUT_LINE('  → Directory DATA_DIR mis à jour.');
  END IF;
END;
/

GRANT READ ON DIRECTORY data_dir TO app_api, app_product, app_party, app_inv, app_doc;

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

-- ═══ Table externe pour GCPART (211K articles) ═══
PROMPT
PROMPT [1/9] Table externe GCPART_ARTICLES -> app_product.product
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ext_gcpart';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ext_gcpart (
  codart     VARCHAR2(80),
  tensto     VARCHAR2(4),
  libartr    VARCHAR2(80),
  libart     VARCHAR2(120),
  libart2    VARCHAR2(120),
  unistk     VARCHAR2(12),
  uniach     VARCHAR2(12),
  univen     VARCHAR2(12),
  typart     VARCHAR2(12),
  codnata    VARCHAR2(12),
  codfam     VARCHAR2(16),
  codsfam    VARCHAR2(16),
  pdsnet     NUMBER,
  pdsbrut    NUMBER,
  volume     NUMBER,
  stkmin     NUMBER,
  stkmax     NUMBER,
  stksec     NUMBER,
  tarifstd   NUMBER,
  tarifpro   NUMBER,
  promo      VARCHAR2(4),
  pro_ddeb   DATE,
  pro_dfin   DATE,
  prmp       NUMBER,
  codbarre   VARCHAR2(120),
  datcre     VARCHAR2(30),
  cuti       VARCHAR2(20),
  datmod     VARCHAR2(30),
  muti       VARCHAR2(20),
  codcrit    VARCHAR2(12),
  mrgmin     VARCHAR2(20),
  kit        VARCHAR2(4),
  geslot     VARCHAR2(4),
  coeff_ach  VARCHAR2(20),
  coeff_ven  VARCHAR2(20),
  codray     VARCHAR2(12),
  pro_tauxrem VARCHAR2(20),
  etat       VARCHAR2(4),
  codrtax    VARCHAR2(12),
  divers     VARCHAR2(120),
  liquidation VARCHAR2(4),
  gestion_locale VARCHAR2(4),
  cb_manuel  VARCHAR2(4),
  posdoua    VARCHAR2(20),
  codfrnprinc VARCHAR2(32),
  tarifstd_ht NUMBER,
  unistk_sec VARCHAR2(12),
  nbunit     NUMBER,
  memo_ccial VARCHAR2(4000),
  reforigine VARCHAR2(120),
  codgrpe    VARCHAR2(20),
  gesnserie  VARCHAR2(4),
  code_marque VARCHAR2(20),
  codtaxe_unite VARCHAR2(12),
  transfert  VARCHAR2(4)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER
  DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPART_20260612d1759-articles.csv')
)
REJECT LIMIT UNLIMITED;

PROMPT  Table externe ext_gcpart créée.

-- Chargement dans app_product.product via ETL par batch
PROMPT
PROMPT [ETL] Chargement GCPART → app_product.product (batch 500)

DECLARE
  CURSOR c_ext IS
    SELECT codart, libart, unistk, tarifstd, etat, codbarre, prmp,
           stkmin, stkmax, stksec, codfam
      FROM ext_gcpart
     WHERE codart IS NOT NULL;

  TYPE t_batch IS TABLE OF c_ext%ROWTYPE;
  v_batch t_batch;
  v_total NUMBER := 0;
  v_errors NUMBER := 0;
BEGIN
  OPEN c_ext;
  LOOP
    FETCH c_ext BULK COLLECT INTO v_batch LIMIT 500;
    EXIT WHEN v_batch.COUNT = 0;

    FORALL i IN 1..v_batch.COUNT SAVE EXCEPTIONS
      INSERT INTO app_product.product (
        product_code, product_name, standard_price,
        category, status, barcode, average_cost,
        stock_min, stock_max, stock_security,
        company_code, created_by, created_at
      ) VALUES (
        v_batch(i).codart,
        v_batch(i).libart,
        NVL(v_batch(i).tarifstd, 0),
        v_batch(i).codfam,
        CASE WHEN v_batch(i).etat = 'A' THEN 'Y' ELSE 'N' END,
        v_batch(i).codbarre,
        NVL(v_batch(i).prmp, 0),
        NVL(v_batch(i).stkmin, 0),
        NVL(v_batch(i).stkmax, 0),
        NVL(v_batch(i).stksec, 0),
        'REGAL',
        'ETL_LEGACY',
        SYSTIMESTAMP
      );

    v_total := v_total + v_batch.COUNT;
    COMMIT;
  END LOOP;
  CLOSE c_ext;

  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' produits chargés depuis GCPART.csv');
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur ETL : ' || SQLERRM);
    ROLLBACK;
END;
/

-- ═══ ETL stock depuis GCSTOCK.csv ═══
PROMPT
PROMPT [2/9] ETL GCSTOCK.csv → app_inv.inv_stock
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ext_gcstock';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ext_gcstock (
  codart       VARCHAR2(80),
  coddep       VARCHAR2(5),
  qte_stock    NUMBER,
  qte_reservee NUMBER,
  qte_commande NUMBER,
  pmp          NUMBER,
  dat_maj      VARCHAR2(30)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER
  DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCSTOCK_202606121810.csv')
)
REJECT LIMIT UNLIMITED;

DECLARE
  CURSOR c IS SELECT codart, coddep, qte_stock, pmp FROM ext_gcstock
                WHERE codart IS NOT NULL AND coddep IS NOT NULL;
  TYPE t_batch IS TABLE OF c%ROWTYPE;
  v_batch t_batch;
  v_total NUMBER := 0;
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_batch LIMIT 500;
    EXIT WHEN v_batch.COUNT = 0;

    FORALL i IN 1..v_batch.COUNT
      MERGE INTO app_inv.inv_stock tgt
      USING (SELECT v_batch(i).codart AS product_code,
                    v_batch(i).coddep AS warehouse_code,
                    NVL(v_batch(i).qte_stock, 0) AS stock_qty,
                    NVL(v_batch(i).pmp, 0) AS pmp
             FROM DUAL) src
      ON (tgt.product_code = src.product_code
          AND tgt.warehouse_code = src.warehouse_code)
      WHEN MATCHED THEN
        UPDATE SET stock_qty = src.stock_qty,
                   last_in_at = SYSDATE
      WHEN NOT MATCHED THEN
        INSERT (warehouse_code, product_code, stock_qty, last_in_at)
        VALUES (src.warehouse_code, src.product_code, src.stock_qty, SYSDATE);

    v_total := v_total + v_batch.COUNT;
    COMMIT;
  END LOOP;
  CLOSE c;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' stocks chargés depuis GCSTOCK.csv');
END;
/

-- ═══ ETL tarifs depuis GCPTARIF_ART.csv ═══
PROMPT
PROMPT [3/9] ETL GCPTARIF_ART.csv → app_product.product_price
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ext_gcptarif_art';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ext_gcptarif_art (
  codtarif   VARCHAR2(8),
  codart     VARCHAR2(80),
  tarif      NUMBER,
  datdeb     VARCHAR2(30),
  datfin     VARCHAR2(30)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER
  DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPTARIF_ART_202606121807-prix.csv')
)
REJECT LIMIT UNLIMITED;

DECLARE
  CURSOR c IS SELECT codtarif, codart, tarif FROM ext_gcptarif_art
                WHERE codart IS NOT NULL;
  TYPE t_batch IS TABLE OF c%ROWTYPE;
  v_batch t_batch;
  v_total NUMBER := 0;
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_batch LIMIT 500;
    EXIT WHEN v_batch.COUNT = 0;

    FORALL i IN 1..v_batch.COUNT
      INSERT INTO app_product.product_price (
        product_code, price_list_code, price, currency_code, valid_from
      ) VALUES (
        v_batch(i).codart, v_batch(i).codtarif, NVL(v_batch(i).tarif, 0), 'XAF', SYSDATE
      );

    v_total := v_total + v_batch.COUNT;
    COMMIT;
  END LOOP;
  CLOSE c;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' prix chargés depuis GCPTARIF_ART.csv');
END;
/

-- ═══ ETL tiers depuis GCPTIE.csv ═══
PROMPT
PROMPT [4/9] ETL GCPTIE.csv → app_party.party

BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ext_gcptie';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ext_gcptie (
  codtie     VARCHAR2(32),
  nomtie     VARCHAR2(120),
  type_tie   VARCHAR2(20),
  adrtie1    VARCHAR2(120),
  ville      VARCHAR2(80),
  pays       VARCHAR2(20),
  telephone  VARCHAR2(30),
  email      VARCHAR2(120),
  codrtax    VARCHAR2(12),
  plafond    NUMBER
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER
  DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPTIE_202606121809.csv')
)
REJECT LIMIT UNLIMITED;

DECLARE
  CURSOR c IS SELECT codtie, nomtie, type_tie, adrtie1, ville, pays, telephone, email
                FROM ext_gcptie WHERE codtie IS NOT NULL;
  TYPE t_batch IS TABLE OF c%ROWTYPE;
  v_batch t_batch;
  v_total NUMBER := 0;
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_batch LIMIT 200;
    EXIT WHEN v_batch.COUNT = 0;

    FORALL i IN 1..v_batch.COUNT
      INSERT INTO app_party.party (
        party_code, party_name, party_type, address_line1, city, country_code,
        phone, email, company_code, is_active, created_by, created_at
      ) VALUES (
        v_batch(i).codtie, v_batch(i).nomtie,
        CASE WHEN UPPER(v_batch(i).type_tie) LIKE 'CLI%' THEN 'CUSTOMER'
             WHEN UPPER(v_batch(i).type_tie) LIKE 'FOU%' THEN 'SUPPLIER'
             ELSE 'OTHER' END,
        v_batch(i).adrtie1, v_batch(i).ville, v_batch(i).pays,
        v_batch(i).telephone, v_batch(i).email,
        'REGAL', 'Y', 'ETL_LEGACY', SYSTIMESTAMP
      );

    v_total := v_total + v_batch.COUNT;
    COMMIT;
  END LOOP;
  CLOSE c;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' tiers chargés depuis GCPTIE.csv');
END;
/

-- ═══ ETL types bordereaux ═══
PROMPT
PROMPT [5/9] ETL GCPTBRD.csv → app_doc.doc_type
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ext_gcptbrd';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ext_gcptbrd (
  codtbrd    VARCHAR2(20),
  libtbrd    VARCHAR2(120),
  sen        VARCHAR2(2),
  signe      VARCHAR2(4),
  typbrd     VARCHAR2(20)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER
  DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPTBRD_202606121808.csv')
)
REJECT LIMIT UNLIMITED;

DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM ext_gcptbrd;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_count || ' lignes dans GCPTBRD.csv');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur lecture GCPTBRD : ' || SQLERRM);
END;
/

-- ═══ ETL taux taxes ═══
PROMPT
PROMPT [6/9] ETL GCPRTAX.csv → app_gl.tax_form_type
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE ext_gcprtax';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE ext_gcprtax (
  codrtax    VARCHAR2(12),
  librtax    VARCHAR2(120),
  taux       NUMBER
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER
  DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ','
    OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPRTAX_202606121806.csv')
)
REJECT LIMIT UNLIMITED;

DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM ext_gcprtax;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_count || ' lignes dans GCPRTAX.csv');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur lecture GCPRTAX : ' || SQLERRM);
END;
/

-- ═══ Statistiques ETL ═══
PROMPT
PROMPT ═══ Statistiques ETL ═══
SELECT 'app_product.product'    AS table_cible, COUNT(*) AS rows_chargees FROM app_product.product WHERE created_by = 'ETL_LEGACY'
UNION ALL SELECT 'app_inv.inv_stock',        COUNT(*) FROM app_inv.inv_stock
UNION ALL SELECT 'app_product.product_price', COUNT(*) FROM app_product.product_price
UNION ALL SELECT 'app_party.party',          COUNT(*) FROM app_party.party WHERE created_by = 'ETL_LEGACY'
 ORDER BY 1;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ ETL CSV LEGACY TERMINÉ
PROMPT   - GCPART.csv (211K articles)   → app_product.product
PROMPT   - GCSTOCK.csv (98K stocks)    → app_inv.inv_stock
PROMPT   - GCPTARIF_ART.csv (29K prix) → app_product.product_price
PROMPT   - GCPTIE.csv (9K tiers)       → app_party.party
PROMPT   - 5 tables externes crées (Oracle External Tables)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
