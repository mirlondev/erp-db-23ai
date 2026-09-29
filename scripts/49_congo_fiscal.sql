-- ============================================================
-- SCRIPT 49 : Référentiel fiscal CONGO BRAZZAVILLE (CG)
-- ============================================================
-- Adapte le projet au contexte congolais :
--   - Pays : République du Congo (CG / COG) — CEMAC
--   - Devise : XAF (BEAC) — même code ISO que UEMOA mais banque différente
--   - TVA : 18.9% (taux normal) / 9% (taux réduit) — loi 2018
--   - IRPP : barème progressif 0%-35% (8 tranches)
--   - IS : 30% + 5% IRCM
--   - CNSS (Caisse Nationale de Sécurité Sociale) — pas CNPS
--   - Patente : taxe communale (Brazzaville, Pointe-Noire)
--   - DGID : Direction Générale des Impôts et des Domaines
--
-- Centres des impôts du Congo :
--   - Brazzaville (capitale politique)
--   - Pointe-Noire (capitale économique) ← site du client
--   - Dolisie, Nkayi, Oyo, Impfondo, Sibiti
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
    INSERT INTO sys_country (
      country_code, country_name_fr, country_name_en, country_code_alpha3,
      currency_code, fiscal_zone, is_active
    ) VALUES (
      'CG', 'République du Congo', 'Republic of the Congo', 'COG',
      'XAF', 'CEMAC', 'Y'
    );
    DBMS_OUTPUT.PUT_LINE('  → CG inséré.');
  ELSE
    DBMS_OUTPUT.PUT_LINE('  → CG déjà présent.');
  END IF;
  COMMIT;
END;
/

-- ═══ 2. Devise : XAF (BEAC) ═══
PROMPT
PROMPT [2/8] Devise XAF (BEAC) — franc CFA d'Afrique Centrale
DECLARE
  v_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_count FROM sys_currency WHERE currency_code = 'XAF';
  IF v_count = 0 THEN
    INSERT INTO sys_currency (
      currency_code, currency_name, currency_symbol, decimal_places,
      is_active, central_bank
    ) VALUES (
      'XAF', 'Franc CFA (BEAC)', 'FCFA', 0,
      'Y', 'BEAC'
    );
    DBMS_OUTPUT.PUT_LINE('  → XAF (BEAC) inséré.');
  ELSE
    UPDATE sys_currency SET central_bank = 'BEAC' WHERE currency_code = 'XAF' AND central_bank IS NULL;
    DBMS_OUTPUT.PUT_LINE('  → XAF déjà présent.');
  END IF;
  COMMIT;
END;
/

-- ═══ 3. Villes & centres des impôts du Congo ═══
PROMPT
PROMPT [3/8] Centres des impôts du Congo
CREATE TABLE app_sys.cg_tax_center (
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

INSERT INTO app_sys.cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-BZV',  'Centre des Impôts de Brazzaville',     'Brazzaville',  'Pool',         '+242 05 555 0101', 'cdi-bzv@dgid.cg');
INSERT INTO app_sys.cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-PNR',  'Centre des Impôts de Pointe-Noire',    'Pointe-Noire', 'Pointe-Noire', '+242 05 555 0202', 'cdi-pnr@dgid.cg');
INSERT INTO app_sys.cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-DLS',  'Centre des Impôts de Dolisie',         'Dolisie',      'Niari',        '+242 05 555 0303', 'cdi-dls@dgid.cg');
INSERT INTO app_sys.cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-NKY',  'Centre des Impôts de Nkayi',           'Nkayi',        'Bouenza',      '+242 05 555 0404', 'cdi-nky@dgid.cg');
INSERT INTO app_sys.cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-OYO',  'Centre des Impôts d''Oyo',             'Oyo',          'Cuvette',      '+242 05 555 0505', 'cdi-oyo@dgid.cg');
INSERT INTO app_sys.cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-IMP',  'Centre des Impôts d''Impfondo',        'Impfondo',     'Likouala',     '+242 05 555 0606', 'cdi-imp@dgid.cg');
INSERT INTO app_sys.cg_tax_center (center_code, center_name, city, department, phone, email) VALUES
  ('CG-SIB',  'Centre des Impôts de Sibiti',          'Sibiti',       'Lékoumou',     '+242 05 555 0707', 'cdi-sib@dgid.cg');
COMMIT;
DBMS_OUTPUT.PUT_LINE('  → 7 centres des impôts CG insérés.');

-- ═══ 4. Taux TVA applicables au Congo ═══
PROMPT
PROMPT [4/8] Taux de TVA Congo (18.9% / 9% / 0%)
DECLARE
  v_count NUMBER;
BEGIN
  -- Taux normal 18.9%
  SELECT COUNT(*) INTO v_count FROM app_gl.tax_form_type
   WHERE form_code = 'TVA-MENS-CG' AND jurisdiction = 'CG';
  IF v_count = 0 THEN
    INSERT INTO app_gl.tax_form_type (
      form_code, form_label, form_type, frequency, jurisdiction,
      base_amount, rate, legal_basis, due_day
    ) VALUES (
      'TVA-MENS-CG', 'Déclaration mensuelle TVA - Congo (CEMAC 18.9%)', 'TVA',
      'MONTHLY', 'CG', 0, 0.189,
      'Code Général des Impôts CG art. 200 et suivants (loi 36-2018)',
      15
    );
  END IF;

  -- Taux réduit 9%
  SELECT COUNT(*) INTO v_count FROM app_gl.tax_form_type
   WHERE form_code = 'TVA-RED-CG' AND jurisdiction = 'CG';
  IF v_count = 0 THEN
    INSERT INTO app_gl.tax_form_type (
      form_code, form_label, form_type, frequency, jurisdiction,
      base_amount, rate, legal_basis, due_day
    ) VALUES (
      'TVA-RED-CG', 'TVA réduite Congo (9%) - biens de 1ère nécessité', 'TVA',
      'MONTHLY', 'CG', 0, 0.09,
      'CGI CG art. 215 - produits de base (médicaments, farine, etc.)',
      15
    );
  END IF;

  -- IS (Impôt sur les Sociétés)
  SELECT COUNT(*) INTO v_count FROM app_gl.tax_form_type
   WHERE form_code = 'IS-AAC-CG' AND jurisdiction = 'CG';
  IF v_count = 0 THEN
    INSERT INTO app_gl.tax_form_type (
      form_code, form_label, form_type, frequency, jurisdiction,
      base_amount, rate, legal_basis, due_day
    ) VALUES (
      'IS-AAC-CG', 'Acompte provisionnel IS - Congo (30%)', 'IS',
      'QUARTERLY', 'CG', 0, 0.30,
      'CGI CG art. 86 - taux ordinaire',
      20
    );
  END IF;

  -- IRCM (Impôt sur le Revenu des Capitaux Mobiliers)
  SELECT COUNT(*) INTO v_count FROM app_gl.tax_form_type
   WHERE form_code = 'IRCM-CG' AND jurisdiction = 'CG';
  IF v_count = 0 THEN
    INSERT INTO app_gl.tax_form_type (
      form_code, form_label, form_type, frequency, jurisdiction,
      base_amount, rate, legal_basis, due_day
    ) VALUES (
      'IRCM-CG', 'IRCM dividendes distribués - Congo (5%)', 'OTHER',
      'EVENT', 'CG', 0, 0.05,
      'CGI CG art. 108 - retenue sur dividendes distribués',
      NULL
    );
  END IF;

  -- Patente
  SELECT COUNT(*) INTO v_count FROM app_gl.tax_form_type
   WHERE form_code = 'PATENTE-CG' AND jurisdiction = 'CG';
  IF v_count = 0 THEN
    INSERT INTO app_gl.tax_form_type (
      form_code, form_label, form_type, frequency, jurisdiction,
      base_amount, legal_basis, due_day
    ) VALUES (
      'PATENTE-CG', 'Patente / Contribution directe communale - Congo', 'PATENTE',
      'ANNUAL', 'CG', 0,
      'CGI CG Titre X - Contribution des patentes',
      31
    );
  END IF;

  -- TFPB (Taxe Foncière sur les Propriétés Bâties)
  SELECT COUNT(*) INTO v_count FROM app_gl.tax_form_type
   WHERE form_code = 'TFPB-CG' AND jurisdiction = 'CG';
  IF v_count = 0 THEN
    INSERT INTO app_gl.tax_form_type (
      form_code, form_label, form_type, frequency, jurisdiction,
      base_amount, rate, legal_basis, due_day
    ) VALUES (
      'TFPB-CG', 'Taxe Foncière Propriétés Bâties - Congo (CG)', 'OTHER',
      'ANNUAL', 'CG', 0, 0.05,
      'CGI CG Titre XII - 5% de la valeur locative',
      30
    );
  END IF;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE('  → 6 types de déclarations CG insérés.');
END;
/

-- ═══ 5. Barème IRPP Congo (8 tranches progressives 2026) ═══
PROMPT
PROMPT [5/8] Barème IRPP Congo (8 tranches progressif)
CREATE TABLE app_sys.cg_irpp_bracket (
  bracket_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  bracket_order     NUMBER(1)     NOT NULL,
  income_min_xaf    NUMBER(16,2)  NOT NULL,
  income_max_xaf    NUMBER(16,2),                              -- NULL = dernière tranche
  rate              NUMBER(5,4)   NOT NULL,                    -- 0.0000 à 0.3500
  CONSTRAINT pk_cg_irpp_bracket      PRIMARY KEY (bracket_id),
  CONSTRAINT uk_cg_irpp_bracket_ord  UNIQUE (bracket_order)
);

-- Barème 2026 issu du CGI Congo (mise à jour annuelle par arrêté)
INSERT INTO app_sys.cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES
  (1, 0,         464000,    0.0000);   -- 0%     jusqu'à 464 000 XAF/an (~38 667 XAF/mois)
INSERT INTO app_sys.cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES
  (2, 464000,    1000000,   0.0500);   -- 5%     de 464 000 à 1 000 000
INSERT INTO app_sys.cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES
  (3, 1000000,   2000000,   0.1000);   -- 10%    de 1 000 000 à 2 000 000
INSERT INTO app_sys.cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES
  (4, 2000000,   4000000,   0.1500);   -- 15%    de 2 000 000 à 4 000 000
INSERT INTO app_sys.cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES
  (5, 4000000,   8000000,   0.2000);   -- 20%    de 4 000 000 à 8 000 000
INSERT INTO app_sys.cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES
  (6, 8000000,   16000000,  0.2500);   -- 25%    de 8 000 000 à 16 000 000
INSERT INTO app_sys.cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES
  (7, 16000000,  32000000,  0.3000);   -- 30%    de 16 000 000 à 32 000 000
INSERT INTO app_sys.cg_irpp_bracket (bracket_order, income_min_xaf, income_max_xaf, rate) VALUES
  (8, 32000000,  NULL,      0.3500);   -- 35%    au-delà de 32 000 000
COMMIT;
DBMS_OUTPUT.PUT_LINE('  → Barème IRPP Congo chargé (8 tranches 0%-35%).');

-- ═══ 6. Cotisations sociales CNSS Congo ═══
PROMPT
PROMPT [6/8] CNSS Congo - barème des cotisations
CREATE TABLE app_sys.cg_cnss_param (
  param_id          NUMBER GENERATED ALWAYS AS IDENTITY,
  param_code        VARCHAR2(20)  NOT NULL,
  param_label       VARCHAR2(80)  NOT NULL,
  rate_employee     NUMBER(5,4)   NOT NULL,                  -- part salariale
  rate_employer     NUMBER(5,4)   NOT NULL,                  -- part patronale
  rate_total        NUMBER(5,4)   GENERATED ALWAYS AS (rate_employee + rate_employer),
  ceiling_xaf       NUMBER(16,2),                            -- plafond mensuel
  legal_basis       VARCHAR2(255),
  CONSTRAINT pk_cg_cnss_param    PRIMARY KEY (param_id),
  CONSTRAINT uk_cg_cnss_param_cd UNIQUE (param_code)
);

-- Régime général CNSS Congo 2026 (caisse CNSS Brazzaville)
INSERT INTO app_sys.cg_cnss_param (param_code, param_label, rate_employee, rate_employer,
                                    ceiling_xaf, legal_basis) VALUES
  ('CNSS-PREST',     'CNSS Prestations familiales',     0.0400, 0.1000, 1200000,
   'Code Sécurité Sociale CG art. 92');

INSERT INTO app_sys.cg_cnss_param (param_code, param_label, rate_employee, rate_employer,
                                    ceiling_xaf, legal_basis) VALUES
  ('CNSS-RETRAITE',  'CNSS Pension vieillesse',         0.0400, 0.0500, 1200000,
   'Code Sécurité Sociale CG art. 89');

INSERT INTO app_sys.cg_cnss_param (param_code, param_label, rate_employee, rate_employer,
                                    ceiling_xaf, legal_basis) VALUES
  ('CNSS-AT',        'CNSS Accidents du travail',       0.0000, 0.0250, 1200000,
   'Code Sécurité Sociale CG art. 95 - variable selon secteur');

INSERT INTO app_sys.cg_cnss_param (param_code, param_label, rate_employee, rate_employer,
                                    ceiling_xaf, legal_basis) VALUES
  ('CSC-CAMU',       'CSC + CAMU (mutuelle santé)',    0.0200, 0.0200, 600000,
   'Loi 2017-22 - Centre de Santé Communautaire');

-- Total salarié  : 4% + 4% + 0% + 2% = 10%
-- Total patron   : 10% + 5% + 2.5% + 2% = 19.5%
COMMIT;
DBMS_OUTPUT.PUT_LINE('  → Barème CNSS Congo chargé (4 lignes, total 10% salarié + 19.5% patron).');

-- ═══ 7. Fonction de calcul IRPP Congo ═══
PROMPT
PROMPT [7/8] Fonction PL/SQL de calcul IRPP Congo
CREATE OR REPLACE FUNCTION app_sys.fn_cg_irpp(
  p_annual_income   IN NUMBER,
  p_dependents      IN NUMBER DEFAULT 0
) RETURN NUMBER IS
  v_taxable         NUMBER(16,2);
  v_family_deduction NUMBER(16,2);
  v_total_irpp      NUMBER(16,2) := 0;
  v_remaining       NUMBER(16,2);
  v_bracket_min     NUMBER(16,2);
  v_bracket_max     NUMBER(16,2);
  v_rate            NUMBER(5,4);
BEGIN
  -- Abattement foyer (parts fiscales) : 100 000 XAF par personne à charge (CGI art. 84)
  v_family_deduction := LEAST(NVL(p_dependents, 0) * 100000, 800000);
  v_taxable := GREATEST(0, p_annual_income - v_family_deduction);

  v_remaining := v_taxable;

  FOR r IN (
    SELECT income_min_xaf, income_max_xaf, rate
      FROM app_sys.cg_irpp_bracket
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
PROMPT  → fn_cg_irpp installée.

-- ═══ 8. Tests rapides ═══
PROMPT
PROMPT [8/8] Tests de calcul IRPP Congo
SELECT
  'Salarié 2M XAF/an (1 enfant)' AS cas,
  app_sys.fn_cg_irpp(2000000, 1) AS irpp_du
FROM dual
UNION ALL SELECT 'Salarié 5M XAF/an (3 enfants)',
       app_sys.fn_cg_irpp(5000000, 3)
FROM dual
UNION ALL SELECT 'Salarié 12M XAF/an (5 enfants)',
       app_sys.fn_cg_irpp(12000000, 5)
FROM dual
UNION ALL SELECT 'Salarié 50M XAF/an (sans enfant)',
       app_sys.fn_cg_irpp(50000000, 0)
FROM dual
UNION ALL SELECT 'Salarié 400K XAF/an (1 enfant, non imposable)',
       app_sys.fn_cg_irpp(400000, 1)
FROM dual;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'SYS_COUNTRY' AS tbl, COUNT(*) AS nb FROM sys_country WHERE country_code = 'CG'
UNION ALL SELECT 'SYS_CURRENCY', COUNT(*) FROM sys_currency WHERE currency_code = 'XAF'
UNION ALL SELECT 'CG_TAX_CENTER', COUNT(*) FROM cg_tax_center
UNION ALL SELECT 'CG_IRPP_BRACKET', COUNT(*) FROM cg_irpp_bracket
UNION ALL SELECT 'CG_CNSS_PARAM', COUNT(*) FROM cg_cnss_param
UNION ALL SELECT 'TAX_FORM_TYPE CG', COUNT(*) FROM app_gl.tax_form_type WHERE jurisdiction = 'CG'
 ORDER BY tbl;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ RÉFÉRENTIEL FISCAL CONGO BRAZZAVILLE INSTALLÉ
PROMPT   - 1 pays CG, 1 devise XAF (BEAC)
PROMPT   - 7 centres des impôts (Brazzaville, Pointe-Noire, etc.)
PROMPT   - 6 types de déclarations (TVA 18.9%, IS, IRCM, Patente, TFPB)
PROMPT   - Barème IRPP 8 tranches (0% à 35%)
PROMPT   - Barème CNSS (10% salarié + 19.5% patron)
PROMPT   - fn_cg_irpp() : fonction de calcul progressif
PROMPT ══════════════════════════════════════════════════════════
EXIT;
