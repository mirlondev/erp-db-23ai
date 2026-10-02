-- ============================================================
-- APEX SETUP 07 : Listes de valeurs (LOV) partagées — REGAL
-- ============================================================
-- Crée les LOVs réutilisables dans toutes les apps APEX REGAL :
--   - Sites (PNR-OFC, PNR-B01, ...) avec code + nom
--   - Dépôts (W90, DEP01, DEP02)
--   - Terminaux (CAI01, CAI02)
--   - Produits (avec recherche code-barres)
--   - Tiers (clients/fournisseurs filtrés par nature)
--   - Comptes OHADA (8 classes SYSCOHADA révisé)
--   - Modes de paiement (CASH, MOBILE, CARD, ...)
--   - Tranches IRPP CG (8 tranches + taux)
--   - Codes TVA CG (NORMAL 18.9%, REDUIT 9%, EXONORE 0%)
--   - Pays CEMAC (CG, CM, GA, TD, CF, GQ)
--   - Jours période paie (1-31)
--
-- Pattern APEX 26.1 : on stocke la définition dans une table
-- apex_lov (similaire à APEX_LOV mais versionné/source) et on expose
-- des fonctions fn_lov_* que les pages appellent via "List of Values"
-- type "PL/SQL Function Body returning SQL query".
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 07 — Listes de valeurs partagees
PROMPT ══════════════════════════════════════════════════════════

-- Table de reference des LOV (utilisee par l'IDE APEX pour lister)
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE apex_lov CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE apex_lov (
  lov_id           NUMBER GENERATED ALWAYS AS IDENTITY,
  lov_code         VARCHAR2(40)  NOT NULL,
  lov_name         VARCHAR2(120) NOT NULL,
  sql_query        CLOB         NOT NULL,
  is_active        BOOLEAN      DEFAULT TRUE,
  description      VARCHAR2(500),
  created_at       TIMESTAMP    DEFAULT SYSTIMESTAMP,
  CONSTRAINT pk_apex_lov PRIMARY KEY (lov_id),
  CONSTRAINT uk_apex_lov UNIQUE (lov_code)
);

PROMPT
PROMPT [1/11] LOV Sites (PNR-OFC, PNR-B01, ...)
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'SITES_REGAL',
  'Sites REGAL (7 sites)',
  q'[SELECT site_code AS d, site_name || ' (' || site_code || ')' AS r, site_type
       FROM app_sys.site_master
      WHERE is_active = TRUE
      ORDER BY site_type, site_code]'
);
COMMIT;

PROMPT [2/11] LOV Dépôts
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'WAREHOUSES',
  'Entrepôts / Dépôts',
  q'~SELECT warehouse_code AS d, warehouse_name || ' [' || warehouse_code || ']' AS r
       FROM app_org.org_warehouse
      ORDER BY warehouse_code~'
);
COMMIT;

PROMPT [3/11] LOV Terminaux POS
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'POS_TERMINALS',
  'Terminaux de caisse',
  q'[SELECT terminal_id AS d, terminal_name || ' (' || terminal_code || ')' AS r
       FROM app_pos.pos_terminal
      WHERE is_active = TRUE
      ORDER BY terminal_code]'
);
COMMIT;

PROMPT [4/11] LOV Produits
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'PRODUCTS',
  'Produits (recherche code/libellé)',
  q'[SELECT product_id AS d, product_code || ' — ' || product_name AS r
       FROM app_product.product
      WHERE status = 'ACTIVE'
      ORDER BY product_name]'
);
COMMIT;

PROMPT [5/11] LOV Tiers
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'PARTIES',
  'Tiers (clients + fournisseurs)',
  q'[SELECT party_id AS d, party_code || ' — ' || party_name AS r
       FROM app_party.party
      WHERE is_blocked = FALSE
      ORDER BY party_name]'
);
COMMIT;

PROMPT [6/11] LOV Comptes OHADA (SYSCOHADA révisé)
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'GL_ACCOUNTS',
  'Comptes OHADA',
  q'[SELECT account_code AS d, account_code || ' — ' || account_name AS r
       FROM app_gl.gl_account_ohada
      WHERE is_active = TRUE
      ORDER BY account_code]'
);
COMMIT;

PROMPT [7/11] LOV Modes de paiement
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'PAYMENT_METHODS',
  'Modes de paiement',
  q'[SELECT method_code AS d, method_name AS r
       FROM app_ar.payment_method_ref
      WHERE is_active = TRUE
      ORDER BY method_code]'
);
COMMIT;

PROMPT [8/11] LOV Tranches IRPP Congo (8 tranches 0%→35%)
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'IRPP_BRACKETS_CG',
  'Tranches IRPP Congo Brazzaville (8)',
  q'[SELECT bracket_order AS d,
              TO_CHAR(income_min_xaf, 'FM999G999G999G990') || ' FCFA — ' ||
              TO_CHAR(rate * 100, 'FM990D00') || '%' AS r
       FROM app_sys.cg_irpp_bracket
      ORDER BY bracket_order]'
);
COMMIT;

PROMPT [9/11] LOV Codes TVA CG
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'VAT_CODES_CG',
  'Codes TVA Congo (NORMAL/REDUIT/EXONORE)',
  q'[SELECT form_code AS d, form_label || ' (' || NVL(rate, 0) || '%)' AS r
       FROM app_gl.tax_form_type
      WHERE jurisdiction = 'CG'
      ORDER BY form_code]'
);
COMMIT;

PROMPT [10/11] LOV Pays CEMAC
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'CEMAC_COUNTRIES',
  'Pays CEMAC (6)',
  q'[SELECT country_code AS d, country_name AS r
       FROM app_sys.sys_country
       WHERE country_code IN ('CMR', 'CAF', 'TCD', 'CGO', 'GNQ', 'GAB')
      ORDER BY country_name]'
);
COMMIT;

PROMPT [11/11] LOV Type de transaction (VTE/ACH/TRSF/RET/BON/INV/FAC/PRO)
INSERT INTO apex_lov (lov_code, lov_name, sql_query) VALUES (
  'DOC_TYPES',
  'Types de documents REGAL',
  q'[SELECT codtbrd AS d, description AS r
       FROM app_api.etl_brd_mapping
      ORDER BY codtbrd]'
);
COMMIT;

-- ============================================================
-- Package plsql pour exposer les LOV (appelables par APEX 26.1)
-- ============================================================
PROMPT
PROMPT ═══ Package apex_lov_api (helpers) ═══
CREATE OR REPLACE PACKAGE apex_lov_api AS
  -- Renvoie la SQL query d'une LOV par code (utilisé par APEX dans
  -- List of Values > Type=PL/SQL Function Body returning SQL)
  FUNCTION get_lov_sql(p_lov_code VARCHAR2) RETURN CLOB;
  FUNCTION get_lov_name(p_lov_code VARCHAR2) RETURN VARCHAR2;
  FUNCTION lov_exists(p_lov_code VARCHAR2) RETURN BOOLEAN;
END apex_lov_api;
/

CREATE OR REPLACE PACKAGE BODY apex_lov_api AS
  FUNCTION get_lov_sql(p_lov_code VARCHAR2) RETURN CLOB IS
    v_sql CLOB;
  BEGIN
    SELECT sql_query INTO v_sql FROM apex_lov WHERE lov_code = p_lov_code AND is_active = TRUE;
    RETURN v_sql;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN 'SELECT ''LOV_NOT_FOUND'' AS d, ''LOV_NOT_FOUND'' AS r FROM DUAL';
  END get_lov_sql;

  FUNCTION get_lov_name(p_lov_code VARCHAR2) RETURN VARCHAR2 IS
    v_name VARCHAR2(120);
  BEGIN
    SELECT lov_name INTO v_name FROM apex_lov WHERE lov_code = p_lov_code;
    RETURN v_name;
  EXCEPTION WHEN NO_DATA_FOUND THEN
    RETURN p_lov_code;
  END get_lov_name;

  FUNCTION lov_exists(p_lov_code VARCHAR2) RETURN BOOLEAN IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_cnt FROM apex_lov WHERE lov_code = p_lov_code AND is_active = TRUE;
    RETURN v_cnt > 0;
  END lov_exists;
END apex_lov_api;
/

GRANT EXECUTE ON apex_lov_api TO app_sales, app_inv, app_purchase, app_gl, app_hr;
GRANT SELECT ON apex_lov TO app_sales, app_inv, app_purchase, app_gl, app_hr;

PROMPT
PROMPT ═══ Validation ═══
SELECT lov_id, lov_code, lov_name, description
  FROM apex_lov
 ORDER BY lov_id;

PROMPT
PROMPT ═══ Test 1 LOV ═══
DECLARE
  v_sql CLOB;
BEGIN
  v_sql := apex_lov_api.get_lov_sql('SITES_REGAL');
  DBMS_OUTPUT.PUT_LINE('  SITES_REGAL SQL = ' || SUBSTR(v_sql, 1, 200));
  DBMS_OUTPUT.PUT_LINE('  lov_exists(PRODUCTS) = ' ||
    CASE WHEN apex_lov_api.lov_exists('PRODUCTS') THEN 'TRUE' ELSE 'FALSE' END);
END;
/

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ APEX SETUP 07 — 11 LOVs partagées
PROMPT   - Sites (7), Warehouses, POS, Products, Parties
PROMPT   - GL accounts, Payment methods, IRPP CG, VAT CG
PROMPT   - CEMAC countries, Doc types
PROMPT ══════════════════════════════════════════════════════════
EXIT;
