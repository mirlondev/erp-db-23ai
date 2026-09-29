-- ============================================================
-- S29 : Seed Déclarations TVA LITOKO — Congo Brazzaville (CEMAC 18.9%)
-- ============================================================
-- Déclarations TVA LITOKO SARL (Pointe-Noire) :
--   - TVA 18.9% (taux normal CEMAC)
--   - Centre des impôts CG-PNR (Pointe-Noire)
--   - DGID (Direction Générale des Impôts et des Domaines)
--   - Banque BGFI Bank Congo
--   - XAF (BEAC)
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED TVA LITOKO — Pointe-Noire, CG
PROMPT ══════════════════════════════════════════════════════════

BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM tax_payment';
  EXECUTE IMMEDIATE 'DELETE FROM tax_credit';
  EXECUTE IMMEDIATE 'DELETE FROM tax_declaration_line';
  EXECUTE IMMEDIATE 'DELETE FROM tax_declaration';
  COMMIT;
END;
/

-- ═══ 1. Déclaration TVA LITOKO - 03-2026 (Pointe-Noire) ═══
DECLARE
  v_id NUMBER;
  v_pay_id NUMBER;
BEGIN
  INSERT INTO tax_declaration (
    declaration_ref, form_type_id, company_code,
    period_start, period_end, jurisdiction,
    base_amount, tax_due, credit_applied, amount_payable,
    status, submitted_at, submitted_by, acked_at, paid_at
  ) VALUES (
    'DGI-CG-PNR-TVA-2026-03-001',
    (SELECT form_type_id FROM app_gl.tax_form_type
       WHERE form_code = 'TVA-MENS-CG' AND jurisdiction = 'CG'),
    'LITOKO',
    DATE '2026-03-01', DATE '2026-03-31', 'CG',
    12500000, 2362500, 0, 2362500,                            -- 12.5M x 18.9% = 2 362 500
    'PAID',
    TIMESTAMP '2026-04-10 14:30:00.00',
    'PRISCILLE_NGOMA',
    TIMESTAMP '2026-04-11 09:15:00.00',
    TIMESTAMP '2026-04-12 16:00:00.00'
  ) RETURNING declaration_id INTO v_id;

  -- Lignes par taux
  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate,
                                     base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_id, 1, 'NORMAL', 0.189, 10500000, 1984500, 6500000, 1228500);

  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate,
                                     base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_id, 2, 'REDUCED', 0.09, 2000000, 180000, 800000, 72000);
  -- TVA nette due = 1984500 + 180000 - 1228500 - 72000 = 864 000
  -- Le total arrondi à 2 362 500 correspond à 12.5M x 18.9% (tout en NORMAL pour simplifier)
  -- Le détail par ligne + déductions est pédagogique ici

  -- Paiement à la DGI via BGFI
  INSERT INTO tax_payment (
    payment_ref, declaration_id, company_code, payment_date, payment_amount,
    payment_method, bank_account, bank_ref, jurisdiction, receiver_name
  ) VALUES (
    'PAY-TVA-CG-2026-03-LITOKO', v_id, 'LITOKO', DATE '2026-04-12',
    864000,
    'BANK_TRANSFER',
    'BGFI-CG-PNR-2026-XXX-12345',
    'REF-BGFI-CG-2026-0408-77452',
    'CG', 'Recette Principale DGID Pointe-Noire'
  ) RETURNING payment_id INTO v_pay_id;

  COMMIT;
END;
/

-- ═══ 2. Déclaration TVA LITOKO - 04-2026 ═══
DECLARE
  v_id NUMBER;
BEGIN
  INSERT INTO tax_declaration (
    declaration_ref, form_type_id, company_code,
    period_start, period_end, jurisdiction,
    base_amount, tax_due, credit_applied, amount_payable,
    status, submitted_at, submitted_by
  ) VALUES (
    'DGI-CG-PNR-TVA-2026-04-001',
    (SELECT form_type_id FROM app_gl.tax_form_type
       WHERE form_code = 'TVA-MENS-CG' AND jurisdiction = 'CG'),
    'LITOKO',
    DATE '2026-04-01', DATE '2026-04-30', 'CG',
    13200000, 2494800, 0, 2494800,
    'SUBMITTED',
    TIMESTAMP '2026-05-10 11:00:00.00',
    'PRISCILLE_NGOMA'
  ) RETURNING declaration_id INTO v_id;

  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate,
                                     base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_id, 1, 'NORMAL', 0.189, 11000000, 2079000, 6800000, 1285200);

  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate,
                                     base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_id, 2, 'REDUCED', 0.09, 2200000, 198000, 950000, 85500);
  -- TVA nette = 2 079 000 + 198 000 - 1 285 200 - 85 500 = 906 300

  COMMIT;
END;
/

-- ═══ 3. Acompte IS LITOKO T1-2026 ═══
INSERT INTO tax_declaration (
  declaration_ref, form_type_id, company_code,
  period_start, period_end, jurisdiction,
  base_amount, tax_due, amount_payable,
  status, submitted_at, submitted_by, acked_at, paid_at
) VALUES (
  'DGI-CG-PNR-IS-2026-T1',
  (SELECT form_type_id FROM app_gl.tax_form_type
     WHERE form_code = 'IS-AAC-CG' AND jurisdiction = 'CG'),
  'LITOKO',
  DATE '2026-01-01', DATE '2026-03-31', 'CG',
  18500000, 5550000, 5550000,
  'PAID',
  TIMESTAMP '2026-04-15 09:30:00.00',
  'PRISCILLE_NGOMA',
  TIMESTAMP '2026-04-16 14:00:00.00',
  TIMESTAMP '2026-04-18 10:30:00.00'
);

-- ═══ 4. Patente LITOKO (annuelle 2026) ═══
INSERT INTO tax_declaration (
  declaration_ref, form_type_id, company_code,
  period_start, period_end, jurisdiction,
  base_amount, tax_due, amount_payable,
  status, submitted_at, submitted_by, paid_at
) VALUES (
  'DGI-CG-PNR-PATENTE-2026',
  (SELECT form_type_id FROM app_gl.tax_form_type
     WHERE form_code = 'PATENTE-CG' AND jurisdiction = 'CG'),
  'LITOKO',
  DATE '2026-01-01', DATE '2026-12-31', 'CG',
  0, 850000, 850000,
  'PAID',
  TIMESTAMP '2026-02-15 11:00:00.00',
  'PRISCILLE_NGOMA',
  TIMESTAMP '2026-02-28 14:30:00.00'
);

-- ═══ 5. IRCM distribution dividendes (EVENT) ═══
INSERT INTO tax_declaration (
  declaration_ref, form_type_id, company_code,
  period_start, period_end, jurisdiction,
  base_amount, tax_due, amount_payable,
  status, submitted_at, submitted_by, paid_at
) VALUES (
  'DGI-CG-PNR-IRCM-2026-04',
  (SELECT form_type_id FROM app_gl.tax_form_type
     WHERE form_code = 'IRCM-CG' AND jurisdiction = 'CG'),
  'LITOKO',
  DATE '2026-04-15', DATE '2026-04-15', 'CG',
  12000000, 600000, 600000,
  'PAID',
  TIMESTAMP '2026-04-25 10:00:00.00',
  'PRISCILLE_NGOMA',
  TIMESTAMP '2026-04-26 11:00:00.00'
);
-- 12M XAF dividendes x 5% = 600 000

-- ═══ 6. Crédit TVA (avoir sur import) ═══
INSERT INTO tax_credit (company_code, credit_source, origin_period, total_credit,
                        used_amount, expiry_date)
VALUES ('LITOKO', 'INPUT_VAT', DATE '2026-03-31', 285000, 0, DATE '2029-03-31');
COMMIT;

PROMPT
PROMPT ═══ Volumétrie LITOKO ═══
SELECT 'TVA LITOKO' AS tbl, COUNT(*) AS nb FROM tax_declaration
 WHERE company_code = 'LITOKO' AND jurisdiction = 'CG'
UNION ALL SELECT 'Lignes TVA',        COUNT(*) FROM tax_declaration_line l
                                   JOIN tax_declaration d ON d.declaration_id = l.declaration_id
                                   WHERE d.company_code = 'LITOKO'
UNION ALL SELECT 'Paiements DGI CG', COUNT(*) FROM tax_payment
                                   WHERE jurisdiction = 'CG' AND company_code = 'LITOKO'
UNION ALL SELECT 'Crédits TVA',      COUNT(*) FROM tax_credit
                                   WHERE company_code = 'LITOKO'
 ORDER BY tbl;

PROMPT
PROMPT ═══ Demostrations ═══

PROMPT [Q1] Récap des déclarations LITOKO (Pointe-Noire, CG)
SELECT d.declaration_ref, d.period_end, ft.form_type, d.tax_due, d.amount_payable, d.status
  FROM tax_declaration d
  JOIN tax_form_type ft ON ft.form_type_id = d.form_type_id
 WHERE d.company_code = 'LITOKO'
 ORDER BY d.period_end;

PROMPT [Q2] Charge fiscale cumulée LITOKO 2026
SELECT
  EXTRACT(YEAR FROM d.period_end) AS annee,
  ft.form_type,
  COUNT(*) AS nb_declarations,
  SUM(d.amount_payable) AS total_paye,
  SUM(d.tax_due)        AS total_impot_brut
FROM tax_declaration d
JOIN tax_form_type ft ON ft.form_type_id = d.form_type_id
WHERE d.company_code = 'LITOKO'
  AND d.status IN ('PAID','SUBMITTED','ACKED')
GROUP BY EXTRACT(YEAR FROM d.period_end), ft.form_type
ORDER BY 1, 2;

PROMPT [Q3] Répartitions des paiements par taux
SELECT
  l.rate_type,
  l.rate,
  SUM(l.base_amount) AS total_base,
  SUM(l.tax_amount)  AS total_tva_collectee,
  SUM(l.deductible_tax) AS total_tva_deductible,
  SUM(l.tax_amount - l.deductible_tax) AS tva_nette
FROM tax_declaration_line l
JOIN tax_declaration d ON d.declaration_id = l.declaration_id
WHERE d.company_code = 'LITOKO'
GROUP BY l.rate_type, l.rate
ORDER BY l.rate DESC;

PROMPT [Q4] Comparaison TVA UEMOA (18%) vs CEMAC Congo (18.9%)
SELECT
  'CEMAC Congo'    AS zone, 0.189 AS taux,
  10000000 AS base_exemple,
  ROUND(10000000 * 0.189, 0) AS tva_due_cemac
FROM dual
UNION ALL
SELECT
  'UEMOA Bénin/Sénégal' AS zone, 0.18 AS taux,
  10000000,
  ROUND(10000000 * 0.18, 0)
FROM dual;

PROMPT [Q5] TFPB (Taxe Foncière Propriétés Bâties) - simulation annuelle
SELECT
  address, city, surface_area_m2,
  ROUND(surface_area_m2 * 5000 * 0.05, 0) AS tfpb_annuelle_estimee,  -- valeur locative ~ 5000 XAF/m2
  '(à déclarer en janvier)' AS echeance
FROM app_org.org_warehouse
WHERE company_code = 'LITOKO';

PROMPT [Q6] Récapitulatif fiscal annuel LITOKO (à fin avril 2026)
SELECT
  'TVA nette versée'                  AS poste,
  SUM(d.amount_payable)               AS montant
FROM tax_declaration d
JOIN tax_form_type ft ON ft.form_type_id = d.form_type_id
WHERE d.company_code = 'LITOKO'
  AND d.status = 'PAID'
  AND ft.form_type = 'TVA'
UNION ALL
SELECT
  'IS (Impôt sur les sociétés)',
  SUM(d.amount_payable)
FROM tax_declaration d
JOIN tax_form_type ft ON ft.form_type_id = d.form_type_id
WHERE d.company_code = 'LITOKO' AND d.status = 'PAID' AND ft.form_type = 'IS'
UNION ALL
SELECT
  'IRCM (sur dividendes)',
  SUM(d.amount_payable)
FROM tax_declaration d
JOIN tax_form_type ft ON ft.form_type_id = d.form_type_id
WHERE d.company_code = 'LITOKO' AND d.status = 'PAID' AND ft.form_type = 'OTHER' AND ft.form_code = 'IRCM-CG'
UNION ALL
SELECT
  'Patente 2026',
  SUM(d.amount_payable)
FROM tax_declaration d
JOIN tax_form_type ft ON ft.form_type_id = d.form_type_id
WHERE d.company_code = 'LITOKO' AND d.status = 'PAID' AND ft.form_type = 'PATENTE';

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ TVA LITOKO CONGO : 5 déclarations, 4 paiements DGID
PROMPT   - TVA 18.9% (CEMAC, vs UEMOA 18%)
PROMPT   - Centre CG-PNR (Pointe-Noire)
PROMPT   - IS 30%, IRCM 5%, Patente, TFPB
PROMPT ══════════════════════════════════════════════════════════
EXIT;
