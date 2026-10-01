-- ============================================================
-- APEX SETUP 11 : Locale Congo Brazzaville + Mobile CSS
-- ============================================================
-- Configure :
--   1. Locale fr_CG (Congo Brazzaville) — devise XAF, format date
--   2. Timezone Africa/Brazzaville
--   3. Mobile-friendly CSS breakpoints (boutiques terrain)
--   4. Messages i18n FR/EN déjà dans sys_message (seed S32)
--   5. Vue apex_messages_v (lookup message_key)
--
-- APEX 26.1 applique la locale via :
--   Shared Components → Globalization :
--     - Application Primary Language: French (fr)
//   Application Language Derived From: Session
--   Automatic Time Zone: Yes
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET FEEDBACK ON
SET DEFINE OFF
WHENEVER SQLERROR CONTINUE

CONNECT app_api/AppApi#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   APEX SETUP 11 — Locale Congo + Mobile
PROMPT ══════════════════════════════════════════════════════════

-- ============================================================
-- 1) Table de configuration de la locale
-- ============================================================
BEGIN
  EXECUTE IMMEDIATE 'DROP TABLE apex_locale_config CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE apex_locale_config (
  config_id        NUMBER GENERATED ALWAYS AS IDENTITY,
  config_code      VARCHAR2(40)  NOT NULL,
  config_value     VARCHAR2(200) NOT NULL,
  description      VARCHAR2(500),
  CONSTRAINT pk_apex_locale_cfg PRIMARY KEY (config_id),
  CONSTRAINT uk_apex_locale_cfg UNIQUE (config_code)
);

-- ============================================================
-- 2) Seed : locale Congo Brazzaville
-- ============================================================
PROMPT
PROMPT [1] Locale Congo Brazzaville (CEMAC)
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('APP_PRIMARY_LANG',     'fr',                    'Langue principale APEX');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('APP_LANG_DERIVED',     'SESSION',               'Dérivation langue (SESSION/BROWSER/APP)');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('APP_AUTO_TIMEZONE',    'Y',                     'Auto-détection timezone navigateur');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('APP_DEFAULT_TZ',       'Africa/Brazzaville',    'Timezone par défaut (UTC+1, pas de DST)');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('CURRENCY_CODE',        'XAF',                   'Code devise ISO 4217 (BEAC)');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('CURRENCY_SYMBOL',      'FCFA',                  'Symbole affiché');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('CURRENCY_DECIMALS',    '0',                     'XAF n''a pas de centimes');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('CURRENCY_THOUSAND',    ' ',                     'Séparateur milliers : espace');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('CURRENCY_DECIMAL',     '.',                     'Séparateur décimal : point');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('NUMBER_FORMAT_MASK',   '999G999G999G990',       'Format numérique (zéro décimale)');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('DATE_FORMAT_MASK',     'DD/MM/YYYY',            'Format date court');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('DATETIME_FORMAT_MASK', 'DD/MM/YYYY HH24:MI',    'Format date-heure');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('FIRST_DAY_OF_WEEK',    '2',                     'Lundi (ISO 8601)');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('COUNTRY_CODE',         'CG',                    'Code pays ISO');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('VAT_DEFAULT_RATE',     '18.9',                  'TVA par défaut (CEMAC Congo)');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('VAT_REDUCED_RATE',     '9',                     'TVA réduite (produits de base)');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('VAT_EXEMPT_RATE',      '0',                     'Exonéré (export, médical, etc.)');
INSERT INTO apex_locale_config (config_code, config_value, description) VALUES
  ('INVOICE_TAX_INCLUDED', 'Y',                     'TVA incluse dans prix affichés');
COMMIT;

-- ============================================================
-- 3) Vue apex_messages_v (lookup rapide i18n)
-- ============================================================
PROMPT
PROMPT [2] Vue apex_messages_v
CREATE OR REPLACE VIEW apex_messages_v AS
SELECT m.message_key,
       m.default_text,
       m.message_type,
       MAX(CASE WHEN ml.lang_code = 'fr' THEN ml.translated_text END) AS fr,
       MAX(CASE WHEN ml.lang_code = 'en' THEN ml.translated_text END) AS en
  FROM app_sys.sys_message m
  LEFT JOIN app_sys.sys_message_lang ml ON ml.message_id = m.message_id
 GROUP BY m.message_key, m.default_text, m.message_type;

GRANT SELECT ON apex_messages_v TO app_sales, app_inv, app_purchase, app_gl, app_hr, app_ar;
PROMPT ✓ apex_messages_v créé.

-- ============================================================
-- 4) Vue apex_locale_v (paramètres accessibles)
-- ============================================================
PROMPT
PROMPT [3] Vue apex_locale_v
CREATE OR REPLACE VIEW apex_locale_v AS
SELECT config_code, config_value, description
  FROM apex_locale_config;
GRANT SELECT ON apex_locale_v TO app_sys, app_sales, app_inv, app_purchase, app_gl, app_hr;
PROMPT ✓ apex_locale_v créé.

-- ============================================================
-- 5) CSS mobile (snippet)
-- ============================================================
PROMPT
PROMPT [4] CSS Mobile-friendly (REGAL mobile breakpoints)
DECLARE
  v_css CLOB;
  v_id  NUMBER;
BEGIN
  v_css := q'[
/* =========================================================
   REGAL Mobile CSS — Congo Brazzaville boutiques terrain
   ========================================================= */

/* Tablette / mobile (tactile en boutique) */
@media (max-width: 768px) {
  .t-Body-content { padding: 8px !important; }
  .t-Region { margin-bottom: 12px; }
  .t-Button--large { width: 100%; padding: 14px; }
  .t-Form-inputContainer input { font-size: 16px; } /* évite zoom iOS */
  .u-color-1 { color: #0F4C81; }  /* LITOKO bleu */
  .u-color-2 { color: #D4AF37; }  /* LITOKO or */
  .u-color-3 { color: #009543; }  /* Congo vert */
  .u-color-4 { color: #DC241F; }  /* Congo rouge */
}

/* Impression 80mm ticket */
@media print {
  @page { size: 80mm 297mm; margin: 2mm; }
  .t-Body, .t-Body-main, .t-Region { background: white !important; }
  .no-print { display: none !important; }
  body { font-family: 'Courier New', monospace; font-size: 10pt; }
}

/* Boutons POS (gros doigts) */
button.t-Button--hot, .t-Button--primary {
  min-height: 48px; min-width: 48px;
  font-weight: 600;
}

/* Mise en surbrillance touche Enter (caisse) */
.t-Form-inputContainer input:focus {
  background-color: #FFF9E6;
  border-color: #D4AF37;
  box-shadow: 0 0 0 3px rgba(212, 175, 55, 0.3);
}

/* Alerte stock bas */
.alert-low-stock { background: #FFE4B5; border-left: 4px solid #FF8C00; padding: 8px; }
.alert-out-of-stock { background: #FFC0CB; border-left: 4px solid #DC241F; padding: 8px; }
]';

  -- Stocker dans apex_static_file (cf. setup 05 LITOKO)
  SELECT file_id INTO v_id FROM app_api.apex_static_file WHERE file_name = 'regal_mobile.css';
  UPDATE app_api.apex_static_file
     SET file_blob   = UTL_RAW.CAST_TO_RAW(v_css),
         uploaded_by = 'SETUP_11'
   WHERE file_id = v_id;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    INSERT INTO app_api.apex_static_file (file_name, mime_type, file_blob, description, uploaded_by)
    VALUES ('regal_mobile.css', 'text/css', UTL_RAW.CAST_TO_RAW(v_css),
            'REGAL mobile + print CSS (Congo boutiques)', 'SETUP_11');
END;
/
PROMPT ✓ CSS Mobile stocké dans apex_static_file (regal_mobile.css).

-- ============================================================
-- 6) Validation
-- ============================================================
PROMPT
PROMPT ═══ Validation ═══
SELECT config_code, config_value FROM apex_locale_v ORDER BY config_code;

PROMPT
PROMPT ═══ Test apex_messages_v ═══
SELECT message_key, fr, en
  FROM apex_messages_v
 WHERE message_type = 'WARN'
 ORDER BY message_key;

PROMPT
PROMPT ═══ Exemple formatage XAF ═══
SELECT TO_CHAR(1234567.89, (SELECT config_value FROM apex_locale_v
                            WHERE config_code = 'NUMBER_FORMAT_MASK')) AS xaf_format
  FROM DUAL;

PROMPT
PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ APEX SETUP 11 — Locale Congo + Mobile
PROMPT   - fr_CG, XAF (FCFA), DD/MM/YYYY
PROMPT   - Timezone Africa/Brazzaville (UTC+1)
PROMPT   - Mobile breakpoints (768px) + impression 80mm
PROMPT   - apex_messages_v i18n (FR/EN)
PROMPT ══════════════════════════════════════════════════════════
EXIT;
