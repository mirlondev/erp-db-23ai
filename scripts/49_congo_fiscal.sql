-- ============================================================
-- SCRIPT 49 : Référentiel fiscal CONGO BRAZZAVILLE (CG)
-- ============================================================
-- Adapté aux structures réelles :
--   * sys_country  : (COUNTRY_CODE, COUNTRY_NAME) seulement
--   * sys_currency : structure vérifiée dynamiquement
--   * tax_form_type: (form_code, form_label, form_type, frequency,
--                     jurisdiction, base_amount, rate, legal_basis, due_day)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF

CONNECT app_sys/AppSys#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   RÉFÉRENTIEL FISCAL CONGO BRAZZAVILLE
PROMPT ══════════════════════════════════════════════════════════

-- ═══ 1. Pays : République du Congo (CG) ═══
PROMPT
PROMPT [1/8] Inscription du Congo Brazzaville dans sys_country
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM sys_country WHERE country_code = 'CG';
  IF v_count = 0 THEN
    -- Table sys_country n'a QUE 2 colonnes : COUNTRY_CODE + COUNTRY_NAME
    INSERT INTO sys_country (country_code, country_name)
    VALUES ('CG', 'République du Congo');
    DBMS_OUTPUT.PUT_LINE('  -> CG inséré.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  -> CG déjà présent.');
  END IF;
  COMMIT;
END;
/

-- ═══ 2. Devise : XAF (BEAC) ═══
PROMPT
PROMPT [2/8] Devise XAF (BEAC) — franc CFA d'Afrique Centrale
-- ═══ 2. Devise : XAF (BEAC) ═══
PROMPT
PROMPT [2/8] Devise XAF (BEAC) — franc CFA d'Afrique Centrale
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM sys_currency WHERE currency_code = 'XAF';

  IF v_count = 0 THEN
    -- Structure réelle : (CURRENCY_CODE, CURRENCY_NAME, IS_FIXED_RATE, DECIMAL_PLACES)
    INSERT INTO sys_currency (
      currency_code, currency_name, is_fixed_rate, decimal_places
    ) VALUES (
      'XAF', 'Franc CFA (BEAC)', TRUE, 0
    );
    DBMS_OUTPUT.PUT_LINE('  -> XAF inséré.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  -> XAF déjà présent.');
  END IF;
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('  ERREUR : ' || SQLERRM);
    RAISE;
END;
/
-- ═══ 3. Villes & centres des impôts du Congo ═══
PROMPT
PROMPT [3/8] Centres des impôts du Congo

DECLARE
  PROCEDURE d(p_t VARCHAR2, p_n VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP '||p_t||' '||p_n||' CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('  DROP '||p_t||' '||p_n);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  d('TABLE','cg_tax_center');
END;
/

CREATE TABLE cg_tax_center (
  center_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  center_code        VARCHAR2(10)  NOT NULL,
  center_name        VARCHAR2(80)  NOT NULL,
  city               VARCHAR2(80)  NOT NULL,
  department         VARCHAR2(80),
  country_code       VARCHAR2(2)   DEFAULT 'CG' NOT NULL,
  phone              VARCHAR2(20),
  email              VARCHAR2(120),
  is_active          BOOLEAN       DEFAULT TRUE,
  CONSTRAINT pk_cg_tax_center        PRIMARY KEY (center_id),
  CONSTRAINT uk_cg_tax_center_code   UNIQUE (center_code)
);

INSERT INTO cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-BZV', 'Centre des Impôts de Brazzaville',  'Brazzaville',  'Pool',         '+242 05 555 0101', 'cdi-bzv@dgid.cg');
INSERT INTO cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-PNR', 'Centre des Impôts de Pointe-Noire', 'Pointe-Noire', 'Pointe-Noire', '+242 05 555 0202', 'cdi-pnr@dgid.cg');
INSERT INTO cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-DLS', 'Centre des Impôts de Dolisie',      'Dolisie',      'Niari',        '+242 05 555 0303', 'cdi-dls@dgid.cg');
INSERT INTO cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-NKY', 'Centre des Impôts de Nkayi',        'Nkayi',        'Bouenza',      '+242 05 555 0404', 'cdi-nky@dgid.cg');
INSERT INTO cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-OYO', 'Centre des Impôts d''Oyo',          'Oyo',          'Cuvette',      '+242 05 555 0505', 'cdi-oyo@dgid.cg');
INSERT INTO cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-IMP', 'Centre des Impôts d''Impfondo',     'Impfondo',     'Likouala',     '+242 05 555 0606', 'cdi-imp@dgid.cg');
INSERT INTO cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-SIB', 'Centre des Impôts de Sibiti',       'Sibiti',       'Lékoumou',     '+242 05 555 0707', 'cdi-sib@dgid.cg');
COMMIT;
DBMS_OUTPUT.PUT_LINE('  -> 7 centres des impôts CG insérés.');

-- ═══ 4. Taux applicables au Congo ═══
PROMPT
PROMPT [4/8] Taux TVA / IS / IRCM / Patente / TFPB Congo
DECLARE
  v_count NUMBER;

  PROCEDURE upsert_form(
    p_code      VARCHAR2,
    p_label     VARCHAR2,
    p_type      VARCHAR2,
    p_freq      VARCHAR2,
    p_rate      NUMBER,
    p_legal     VARCHAR2,
    p_due_day   NUMBER
  ) IS
    v_cnt NUMBER;
  BEGIN
    SELECT COUNT(*) INTO v_cnt FROM app_gl.tax_form_type
     WHERE form_code = p_code AND jurisdiction = 'CG';
    IF v_cnt = 0 THEN
      INSERT INTO app_gl.tax_form_type (
        form_code, form_label, form_type, frequency, jurisdiction,
        base_amount, rate, legal_basis, due_day
      ) VALUES (
        p_code, p_label, p_type, p_freq, 'CG',
        0, p_rate, p_legal, p_due_day
      );
      DBMS_OUTPUT.PUT_LINE('  + ' || p_code);
    ELSE
      DBMS_OUTPUT.PUT_LINE('  = ' || p_code || ' (déjà présent)');
    END IF;
  END upsert_form;

BEGIN
  upsert_form('TVA-MENS-CG',
    'Déclaration mensuelle TVA - Congo (CEMAC 18.9%)', 'TVA',
    'MONTHLY', 0.189,
    'Code Général des Impôts CG art. 200 et suivants (loi 36-2018)', 15);

  upsert_form('TVA-RED-CG',
    'TVA réduite Congo (9%) - biens de 1ère nécessité', 'TVA',
    'MONTHLY', 0.09,
    'CGI CG art. 215 - produits de base (médicaments, farine, etc.)', 15);

  upsert_form('IS-AAC-CG',
    'Acompte provisionnel IS - Congo (30%)', 'IS',
    'QUARTERLY', 0.30,
    'CGI CG art. 86 - taux ordinaire', 20);

  upsert_form('IRCM-CG',
    'IRCM dividendes distribués - Congo (5%)', 'OTHER',
    'EVENT', 0.05,
    'CGI CG art. 108 - retenue sur dividendes distribués', NULL);

  upsert_form('PATENTE-CG',
    'Patente / Contribution directe communale - Congo', 'PATENTE',
    'ANNUAL', NULL,
    'CGI CG Titre X - Contribution des patentes', 31);

  upsert_form('TFPB-CG',
    'Taxe Foncière Propriétés Bâties - Congo', 'OTHER',
    'ANNUAL', 0.05,
    'CGI CG Titre XII - 5% de la valeur locative', 30);

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  -> 6 types de déclarations CG traités.');
END;
/

-- ═══ 5. Barème IRPP Congo ═══
PROMPT
PROMPT [5/8] Barème IRPP Congo (8 tranches 0%-35%)

DECLARE
  PROCEDURE d(p_t VARCHAR2, p_n VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP '||p_t||' '||p_n||' CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('  DROP '||p_t||' '||p_n);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  d('TABLE','cg_irpp_bracket');
END;
/

CREATE TABLE cg_irpp_bracket (
  bracket_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  bracket_order     NUMBER(1)     NOT NULL,
  income_min_xaf    NUMBER(16,2)  NOT NULL,
  income_max_xaf    NUMBER(16,2),
  rate              NUMBER(5,4)   NOT NULL,
  CONSTRAINT pk_cg_irpp_bracket      PRIMARY KEY (bracket_id),
  CONSTRAINT uk_cg_irpp_bracket_ord  UNIQUE (bracket_order)
);

INSERT INTO cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES (1,          0,    464000, 0.0000);
INSERT INTO cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES (2,     464000,   1000000, 0.0500);
INSERT INTO cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES (3,    1000000,   2000000, 0.1000);
INSERT INTO cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES (4,    2000000,   4000000, 0.1500);
INSERT INTO cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES (5,    4000000,   8000000, 0.2000);
INSERT INTO cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES (6,    8000000,  16000000, 0.2500);
INSERT INTO cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES (7,   16000000,  32000000, 0.3000);
INSERT INTO cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES (8,   32000000,      NULL, 0.3500);
COMMIT;
DBMS_OUTPUT.PUT_LINE('  -> Barème IRPP Congo chargé (8 tranches).');

-- ═══ 6. Cotisations sociales CNSS Congo ═══
PROMPT
PROMPT [6/8] CNSS Congo - barème des cotisations

DECLARE
  PROCEDURE d(p_t VARCHAR2, p_n VARCHAR2) IS
  BEGIN
    EXECUTE IMMEDIATE 'DROP '||p_t||' '||p_n||' CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('  DROP '||p_t||' '||p_n);
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
BEGIN
  d('TABLE','cg_cnss_param');
END;
/

CREATE TABLE cg_cnss_param (
  param_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  param_code        VARCHAR2(20)  NOT NULL,
  param_label       VARCHAR2(80)  NOT NULL,
  rate_employee     NUMBER(5,4)   NOT NULL,
  rate_employer     NUMBER(5,4)   NOT NULL,
  rate_total        NUMBER(5,4)   GENERATED ALWAYS AS (rate_employee + rate_employer),
  ceiling_xaf       NUMBER(16,2),
  legal_basis       VARCHAR2(255),
  CONSTRAINT pk_cg_cnss_param    PRIMARY KEY (param_id),
  CONSTRAINT uk_cg_cnss_param_cd UNIQUE (param_code)
);

INSERT INTO cg_cnss_param (param_code, param_label, rate_employee, rate_employer, ceiling_xaf, legal_basis) VALUES
  ('CNSS-PREST',    'CNSS Prestations familiales', 0.0400, 0.1000, 1200000, 'Code Sécurité Sociale CG art. 92');
INSERT INTO cg_cnss_param (param_code, param_label, rate_employee, rate_employer, ceiling_xaf, legal_basis) VALUES
  ('CNSS-RETRAITE', 'CNSS Pension vieillesse',     0.0400, 0.0500, 1200000, 'Code Sécurité Sociale CG art. 89');
INSERT INTO cg_cnss_param (param_code, param_label, rate_employee, rate_employer, ceiling_xaf, legal_basis) VALUES
  ('CNSS-AT',       'CNSS Accidents du travail',   0.0000, 0.0250, 1200000, 'Code Sécurité Sociale CG art. 95');
INSERT INTO cg_cnss_param (param_code, param_label, rate_employee, rate_employer, ceiling_xaf, legal_basis) VALUES
  ('CSC-CAMU',      'CSC + CAMU (mutuelle santé)', 0.0200, 0.0200,  600000, 'Loi 2017-22 - Centre de Santé Communautaire');
COMMIT;
DBMS_OUTPUT.PUT_LINE('  -> Barème CNSS Congo chargé.');

-- ═══ 7. Fonction calcul IRPP Congo ═══
PROMPT
PROMPT [7/8] Fonction PL/SQL de calcul IRPP Congo
CREATE OR REPLACE FUNCTION fn_cg_irpp(
  p_annual_income    IN NUMBER,
  p_dependents       IN NUMBER DEFAULT 0
) RETURN NUMBER IS
  v_taxable          NUMBER(16,2);
  v_family_deduction NUMBER(16,2);
  v_total_irpp       NUMBER(16,2) := 0;
  v_remaining        NUMBER(16,2);
  v_bracket_min      NUMBER(16,2);
  v_bracket_max      NUMBER(16,2);
  v_rate             NUMBER(5,4);
BEGIN
  v_family_deduction := LEAST(NVL(p_dependents, 0) * 100000, 800000);
  v_taxable := GREATEST(0, p_annual_income - v_family_deduction);
  v_remaining := v_taxable;

  FOR r IN (
    SELECT income_min_xaf, income_max_xaf, rate
      FROM cg_irpp_bracket
     ORDER BY bracket_order
  ) LOOP
    EXIT WHEN v_remaining <= 0;

    v_bracket_min := r.income_min_xaf;
    v_bracket_max := NVL(r.income_max_xaf, v_taxable);
    v_rate        := r.rate;

    IF v_taxable > v_bracket_min THEN
      v_total_irpp := v_total_irpp +
        LEAST(v_remaining, v_bracket_max - v_bracket_min) * v_rate;
      v_remaining  := v_remaining - LEAST(v_remaining, v_bracket_max - v_bracket_min);
    END IF;
  END LOOP;

  RETURN ROUND(v_total_irpp, 2);
END fn_cg_irpp;
/
PROMPT  -> fn_cg_irpp installée.

-- ═══ 8. Tests ═══
PROMPT
PROMPT [8/8] Tests de calcul IRPP Congo
SELECT 'Salarié 2M XAF/an (1 enfant)'            AS cas, fn_cg_irpp(2000000, 1)   AS irpp_du FROM dual
UNION ALL SELECT 'Salarié 5M XAF/an (3 enfants)',    fn_cg_irpp(5000000, 3)   FROM dual
UNION ALL SELECT 'Salarié 12M XAF/an (5 enfants)',   fn_cg_irpp(12000000, 5)  FROM dual
UNION ALL SELECT 'Salarié 50M XAF/an (sans enfant)', fn_cg_irpp(50000000, 0)  FROM dual
UNION ALL SELECT 'Salarié 400K XAF/an (1 enfant)',   fn_cg_irpp(400000, 1)    FROM dual;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'SYS_COUNTRY (CG)' AS tbl, COUNT(*) AS nb FROM sys_country WHERE country_code='CG'
UNION ALL SELECT 'SYS_CURRENCY (XAF)',     COUNT(*) FROM sys_currency WHERE currency_code='XAF'
UNION ALL SELECT 'CG_TAX_CENTER',          COUNT(*) FROM cg_tax_center
UNION ALL SELECT 'CG_IRPP_BRACKET',        COUNT(*) FROM cg_irpp_bracket
UNION ALL SELECT 'CG_CNSS_PARAM',          COUNT(*) FROM cg_cnss_param
UNION ALL SELECT 'TAX_FORM_TYPE (CG)',     COUNT(*) FROM app_gl.tax_form_type WHERE jurisdiction='CG'
 ORDER BY tbl;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ RÉFÉRENTIEL FISCAL CONGO BRAZZAVILLE INSTALLÉ
PROMPT ══════════════════════════════════════════════════════════
EXIT;
