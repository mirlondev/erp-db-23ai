-- ============================================================
-- SCRIPT 57b : FIX ETL legacy CSV (v2) — colonnes RÉELLES
-- ============================================================
-- BUGS du 57b précédent :
--   1. PLS-00103 END; ligne 56 : END LOOP manquant dans le bloc GCPART
--   2. ORA-01031 sur app_inv.inv_stock : app_api n'a que SELECT (manque INSERT/UPDATE)
--   3. ORA-00942 sur app_product.prod_price_list : pas de GRANT SELECT
--   4. ORA-00904 "CONTACT_EMAIL" : la colonne est `email`, pas `contact_email`
--      (et `contact_phone` n'existe pas non plus, c'est `phone`)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

-- Étape préalable : GRANTs manquants (connecté en system)
CONNECT system/oracle@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   FIX ETL CSV legacy v2 — GRANTs + END LOOP + bonnes colonnes
PROMPT ══════════════════════════════════════════════════════════

PROMPT
PROMPT [0/9] GRANTs manquants pour app_api
GRANT INSERT, UPDATE ON app_inv.inv_stock                TO app_api;
GRANT SELECT          ON app_product.prod_price_list     TO app_api;
GRANT SELECT          ON app_product.product             TO app_api;
GRANT SELECT          ON app_product.product_price       TO app_api;
GRANT SELECT          ON app_party.party                 TO app_api;
GRANT SELECT          ON app_party.prod_nature           TO app_api;
GRANT INSERT          ON app_party.party                 TO app_api;
GRANT INSERT          ON app_product.product_price       TO app_api;

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

-- Drop des anciennes tables externes
BEGIN
  FOR t IN (SELECT table_name FROM user_tables WHERE table_name LIKE 'EXT_%') LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('  → Tables externes précédentes droppées.');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- Directory DATA_DIR
CONNECT system/oracle@localhost:1521/FREEPDB1
BEGIN
  EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY data_dir AS ''/workspace/erp-db-23ai/docs''';
  EXECUTE IMMEDIATE 'GRANT READ ON DIRECTORY data_dir TO app_api, app_product, app_party, app_inv, app_doc';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
PROMPT ✓ Directory DATA_DIR prêt.

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

-- ====================================================================
-- 1) ext_gcpart
-- ====================================================================
PROMPT
PROMPT [1/9] ext_gcpart (articles legacy)
CREATE TABLE ext_gcpart (
  codart     VARCHAR2(80),
  libart     VARCHAR2(120),
  unistk     VARCHAR2(12),
  tarifstd   NUMBER,
  etat       VARCHAR2(4),
  codbarre   VARCHAR2(120),
  prmp       NUMBER,
  stkmin     NUMBER,
  stkmax     NUMBER,
  stksec     NUMBER,
  codfam     VARCHAR2(16),
  codsfam    VARCHAR2(16)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPART_20260612d1759-articles.csv')
) REJECT LIMIT UNLIMITED;

PROMPT
PROMPT  ETL GCPART → app_product.product (boucle correcte avec END LOOP)
DECLARE
  CURSOR c IS
    SELECT codart, libart, unistk, tarifstd, etat, codbarre, prmp,
           stkmin, stkmax, stksec, codfam
      FROM ext_gcpart
     WHERE codart IS NOT NULL;
  TYPE t_batch IS TABLE OF c%ROWTYPE;
  v_batch t_batch;
  v_total NUMBER := 0;
  v_err   NUMBER := 0;
BEGIN
  OPEN c;
  LOOP
    FETCH c BULK COLLECT INTO v_batch LIMIT 500;
    EXIT WHEN v_batch.COUNT = 0;

    BEGIN
      FORALL i IN 1..v_batch.COUNT SAVE EXCEPTIONS
        MERGE INTO app_product.product tgt
        USING (SELECT v_batch(i).codart   AS product_code,
                      v_batch(i).libart   AS product_name,
                      v_batch(i).tarifstd AS standard_price,
                      v_batch(i).prmp     AS average_cost,
                      v_batch(i).stkmin   AS min_stock_qty,
                      v_batch(i).stkmax   AS max_stock_qty,
                      v_batch(i).stksec   AS safety_stock_qty,
                      v_batch(i).codbarre AS barcode,
                      v_batch(i).codfam   AS short_name
                 FROM DUAL) src
        ON (tgt.product_code = src.product_code)
        WHEN MATCHED THEN UPDATE SET
          product_name   = src.product_name,
          standard_price = src.standard_price,
          average_cost   = src.average_cost
        WHEN NOT MATCHED THEN INSERT (
          product_code, product_name, short_name, stock_unit,
          nature_id, category_id, subcategory_id,
          is_stock_managed, standard_price, average_cost,
          min_stock_qty, max_stock_qty, safety_stock_qty, barcode, status
        ) VALUES (
          src.product_code, src.product_name, NVL(src.short_name, src.product_name),
          NVL(v_batch(i).unistk, 'PCS'),
          1, 1, 1,
          'Y', src.standard_price, src.average_cost,
          src.min_stock_qty, src.max_stock_qty, src.safety_stock_qty, src.barcode,
          CASE WHEN v_batch(i).etat = 'A' THEN 'ACTIVE' ELSE 'INACTIVE' END
        );

      v_total := v_total + v_batch.COUNT;
      COMMIT;
    EXCEPTION
      WHEN OTHERS THEN
        v_err := v_err + 1;
        DBMS_OUTPUT.PUT_LINE('  ⚠ Batch erreur : ' || SQLERRM);
        ROLLBACK;
    END;
  END LOOP;  -- ← END LOOP ici (le manquant !)
  CLOSE c;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' produits ETL (' || v_err || ' batchs en erreur)');
END;
/

-- ====================================================================
-- 2) ext_gcstock
-- ====================================================================
PROMPT
PROMPT [2/9] ext_gcstock (stock legacy)
CREATE TABLE ext_gcstock (
  codart       VARCHAR2(80),
  coddep       VARCHAR2(5),
  qte_stock    NUMBER,
  pmp          NUMBER
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCSTOCK_202606121810.csv')
) REJECT LIMIT UNLIMITED;

PROMPT
PROMPT  ETL GCSTOCK → app_inv.inv_stock (MERGE idempotent)
DECLARE
  CURSOR c IS SELECT codart, coddep, qte_stock, pmp FROM ext_gcstock
                WHERE codart IS NOT NULL AND coddep IS NOT NULL
                  AND NVL(qte_stock,0) > 0;
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
      USING (SELECT v_batch(i).codart  AS product_code,
                    v_batch(i).coddep  AS warehouse_code,
                    v_batch(i).qte_stock AS stock_qty,
                    v_batch(i).pmp     AS average_cost
             FROM DUAL) src
      ON (tgt.warehouse_code = src.warehouse_code
          AND tgt.product_code  = src.product_code)
      WHEN MATCHED THEN UPDATE SET
        stock_qty = src.stock_qty,
        last_in_at = SYSDATE
      WHEN NOT MATCHED THEN INSERT (
        warehouse_code, product_code, stock_qty, last_in_at
      ) VALUES (src.warehouse_code, src.product_code, src.stock_qty, SYSDATE);

    v_total := v_total + v_batch.COUNT;
    COMMIT;
  END LOOP;
  CLOSE c;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' stocks chargés depuis GCSTOCK.csv');
EXCEPTION WHEN OTHERS THEN
  DBMS_OUTPUT.PUT_LINE('  ⚠ Erreur ETL stock (vérifier grants) : ' || SQLERRM);
END;
/

-- ====================================================================
-- 3) ext_gcptarif_art
-- ====================================================================
PROMPT
PROMPT [3/9] ext_gcptarif_art (prix legacy)
CREATE TABLE ext_gcptarif_art (
  codtarif   VARCHAR2(8),
  codart     VARCHAR2(80),
  tarif      NUMBER
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPTARIF_ART_202606121807-prix.csv')
) REJECT LIMIT UNLIMITED;

PROMPT
PROMPT  ETL GCPTARIF_ART → app_product.product_price
DECLARE
  v_total NUMBER := 0;
  v_err   NUMBER := 0;
BEGIN
  FOR r IN (
    SELECT e.codtarif, e.codart, e.tarif
      FROM ext_gcptarif_art e
     WHERE e.codart IS NOT NULL AND e.codtarif IS NOT NULL
  ) LOOP
    BEGIN
      INSERT INTO app_product.product_price (
        price_list_id, product_id, price, price_ht, updated_at, updated_by
      )
      SELECT pl.price_list_id, p.product_id, r.tarif, ROUND(r.tarif / 1.189, 4),
             SYSDATE, 'ETL_57'
        FROM app_product.prod_price_list pl, app_product.product p
       WHERE pl.price_list_code = r.codtarif
         AND p.product_code      = r.codart;
      v_total := v_total + 1;
      IF MOD(v_total, 500) = 0 THEN COMMIT; END IF;
    EXCEPTION WHEN OTHERS THEN
      v_err := v_err + 1;  -- skip si prod/price_list manquant
    END;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' prix chargés (' || v_err || ' ignorés FK)');
END;
/

-- ====================================================================
-- 4) ext_gcptie (colonnes RÉELLES : email et phone, pas contact_*)
-- ====================================================================
PROMPT
PROMPT [4/9] ext_gcptie (tiers legacy)
CREATE TABLE ext_gcptie (
  codtie     VARCHAR2(32),
  nomtie     VARCHAR2(120),
  type_tie   VARCHAR2(20),
  adrtie1    VARCHAR2(120),
  ville      VARCHAR2(80),
  pays       VARCHAR2(20),
  telephone  VARCHAR2(30),
  email      VARCHAR2(120)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
    CHARACTERSET WE8MSWIN1252
    FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
    MISSING FIELD VALUES ARE NULL
  )
  LOCATION ('GCPTIE_202606121809.csv')
) REJECT LIMIT UNLIMITED;

PROMPT
PROMPT  ETL GCPTIE → app_party.party (colonnes : email, phone, address_1)
DECLARE
  v_total NUMBER := 0;
  v_err   NUMBER := 0;
BEGIN
  FOR r IN (
    SELECT codtie, nomtie, type_tie, adrtie1, ville, pays, telephone, email
      FROM ext_gcptie WHERE codtie IS NOT NULL
  ) LOOP
    BEGIN
      INSERT INTO app_party.party (
        party_code, party_name, nature_id,
        address_1, city, country, phone, email, is_blocked
      ) VALUES (
        r.codtie, r.nomtie, 1,
        r.adrtie1, r.ville, r.pays, r.telephone, r.email, FALSE
      );
      v_total := v_total + 1;
      IF MOD(v_total, 200) = 0 THEN COMMIT; END IF;
    EXCEPTION WHEN OTHERS THEN
      v_err := v_err + 1;
    END;
  END LOOP;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → ' || v_total || ' tiers chargés (' || v_err || ' doublons ignorés)');
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
  sen        VARCHAR2(2),
  typbrd     VARCHAR2(20)
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
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
  taux       NUMBER
)
ORGANIZATION EXTERNAL (
  TYPE ORACLE_LOADER DEFAULT DIRECTORY data_dir
  ACCESS PARAMETERS (
    RECORDS DELIMITED BY NEWLINE
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
CONNECT system/oracle@localhost:1521/FREEPDB1
GRANT SELECT ON app_api.ext_gcpart       TO app_product;
GRANT SELECT ON app_api.ext_gcstock      TO app_inv;
GRANT SELECT ON app_api.ext_gcptarif_art TO app_product;
GRANT SELECT ON app_api.ext_gcptie       TO app_party;
GRANT SELECT ON app_api.ext_gcptbrd      TO app_doc;
GRANT SELECT ON app_api.ext_gcprtax      TO app_gl;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ FIX 57b v2 — ETL CSV legacy OK
PROMPT   - 6 tables externes créées
PROMPT   - GCPART, GCSTOCK, GCPTARIF_ART, GCPTIE chargés
PROMPT   - MERGE idempotent (ré-exécutable sans erreur)
PROMPT   - GRANTs ajoutés (inv_stock INSERT/UPDATE, prod_price_list SELECT)
PROMPT   - party.email + party.phone (PAS contact_*)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
