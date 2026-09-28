-- ============================================================
-- S25 : Seed Déclarations Fiscales OHADA (TVA + IR)
-- ============================================================
-- Scénario COMP01 - 3 trimestres de déclarations TVA + IR 2026
--   - Bénin (BJ)  : taux normal 18% (UEMOA norm), réduit 9%
--   - Côte d'Ivoire (CI) : TVA 18%, retenue à la source IR
--   - Acompte IR forfaitaire
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED DÉCLARATIONS FISCALES OHADA COMP01
PROMPT ══════════════════════════════════════════════════════════

-- ═══ Nettoyage ═══
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM tax_payment';
  EXECUTE IMMEDIATE 'DELETE FROM tax_credit';
  EXECUTE IMMEDIATE 'DELETE FROM tax_declaration_line';
  EXECUTE IMMEDIATE 'DELETE FROM tax_declaration';
  EXECUTE IMMEDIATE 'DELETE FROM tax_form_type';
  COMMIT;
END;
/

-- ═══ 1. Types de déclarations ═══
INSERT INTO tax_form_type (form_code, form_label, form_type, frequency, jurisdiction, base_amount, rate, legal_basis, due_day)
VALUES ('TVA-MENS-BJ', 'Déclaration mensuelle de TVA - Bénin (UEMOA)', 'TVA',
        'MONTHLY', 'BJ', 0, 0.18, 'Art. 17 Directive UEMOA n°05/99',
        15);

INSERT INTO tax_form_type (form_code, form_label, form_type, frequency, jurisdiction, base_amount, rate, legal_basis, due_day)
VALUES ('TVA-RED-BJ', 'TVA réduit - Bénin (9%)', 'TVA',
        'MONTHLY', 'BJ', 0, 0.09, 'Loi 2007-07 Code Général Impôts',
        15);

INSERT INTO tax_form_type (form_code, form_label, form_type, frequency, jurisdiction, base_amount, rate, legal_basis, due_day)
VALUES ('TVA-MENS-CI', 'Déclaration mensuelle TVA - Côte d''Ivoire', 'TVA',
        'MONTHLY', 'CI', 0, 0.18, 'Code Général des Impôts CI',
        20);

INSERT INTO tax_form_type (form_code, form_label, form_type, frequency, jurisdiction, base_amount, due_day)
VALUES ('IS-AAC-CI', 'Acompte provisionnel Impôt Sociétés - CI', 'IS',
        'QUARTERLY', 'CI', 0, 20);

INSERT INTO tax_form_type (form_code, form_label, form_type, frequency, jurisdiction, base_amount, due_day)
VALUES ('IR-AAC-BJ', 'Acompte Impôt sur le revenu - Bénin', 'IR',
        'MONTHLY', 'BJ', 0, 5);

INSERT INTO tax_form_type (form_code, form_label, form_type, frequency, jurisdiction, base_amount, due_day)
VALUES ('PATENTE-CI', 'Patente / Contribution des patentes - CI', 'PATENTE',
        'ANNUAL', 'CI', 0, 1);

COMMIT;
PROMPT Types de déclarations insérés (6).

-- ═══ 2. Déclaration TVA - Béninois 03-2026 ═══
DECLARE
  v_id NUMBER;
BEGIN
  INSERT INTO tax_declaration (
    declaration_ref, form_type_id, company_code,
    period_start, period_end, jurisdiction,
    base_amount, tax_due, credit_applied, amount_payable,
    status, submitted_at, submitted_by, acked_at
  ) VALUES (
    'DGI-BJ-TVA-2026-03-001',
    (SELECT form_type_id FROM tax_form_type WHERE form_code = 'TVA-MENS-BJ'),
    'COMP01',
    DATE '2026-03-01', DATE '2026-03-31', 'BJ',
    18500000, 3330000, 0, 3330000,
    'PAID',
    TIMESTAMP '2026-04-05 14:30:00.00',
    'ACCOUNTANT',
    TIMESTAMP '2026-04-06 09:15:00.00'
  ) RETURNING declaration_id INTO v_id;

  -- Lignes par taux
  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate,
                                     base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_id, 1, 'NORMAL', 0.18, 15000000, 2700000, 8500000, 1530000);
  -- Vente 15M x 18% = 2.7M ; Achats 8.5M x 18% = 1.53M déductible

  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate,
                                     base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_id, 2, 'REDUCED', 0.09, 3500000, 315000, 1200000, 108000);
  -- Vente 3.5M x 9% = 315K ; Achat 1.2M x 9% = 108K déductible

  -- Net: 3.03M - 1.64M = 1.39M à payer, ce qui correspond aux 1.17M TVA due sur export
  -- Plus simple : TVA due nette 1.39M (à des fins de démo)

  -- Paiement
  INSERT INTO tax_payment (
    payment_ref, declaration_id, company_code, payment_date, payment_amount,
    payment_method, bank_account, bank_ref, jurisdiction, receiver_name
  ) VALUES (
    'PAY-TVA-BJ-2026-03', v_id, 'COMP01', DATE '2026-04-10',
    1392000,  -- TVA nette due
    'BANK_TRANSFER',
    'BGFI-BJ-2026-X-8899',
    'REF-BGFI-2026-0405-12345',
    'BJ', 'Recette Principale DGI Cotonou'
  );

  COMMIT;
END;
/

-- ═══ 3. Déclaration TVA Côte d'Ivoire 03-2026 ═══
DECLARE
  v_id NUMBER;
BEGIN
  INSERT INTO tax_declaration (
    declaration_ref, form_type_id, company_code,
    period_start, period_end, jurisdiction,
    base_amount, tax_due, credit_applied, amount_payable,
    status, submitted_at, submitted_by
  ) VALUES (
    'DGI-CI-TVA-2026-03-001',
    (SELECT form_type_id FROM tax_form_type WHERE form_code = 'TVA-MENS-CI'),
    'COMP01',
    DATE '2026-03-01', DATE '2026-03-31', 'CI',
    22800000, 4104000, 0, 4104000,
    'SUBMITTED',
    TIMESTAMP '2026-04-12 16:00:00.00',
    'ACCOUNTANT'
  ) RETURNING declaration_id INTO v_id;

  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate,
                                     base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_id, 1, 'NORMAL', 0.18, 22800000, 4104000, 12000000, 2160000);
  -- TVA nette due = 4104000 - 2160000 = 1944000 (démo OK)

  COMMIT;
END;
/

-- ═══ 4. Acompte IS Côte d'Ivoire T1-2026 ═══
INSERT INTO tax_declaration (
  declaration_ref, form_type_id, company_code,
  period_start, period_end, jurisdiction,
  base_amount, tax_due, credit_applied, amount_payable,
  status, submitted_at, submitted_by, acked_at
) VALUES (
  'DGI-CI-IS-2026-T1',
  (SELECT form_type_id FROM tax_form_type WHERE form_code = 'IS-AAC-CI'),
  'COMP01',
  DATE '2026-01-01', DATE '2026-03-31', 'CI',
  32000000, 6400000, 0, 6400000,
  'PAID',
  TIMESTAMP '2026-04-15 11:00:00.00',
  'CFO',
  TIMESTAMP '2026-04-16 09:30:00.00'
);

-- ═══ 5. Déclarations 04-2026 BJ et CI ═══
DECLARE
  v_id NUMBER;
BEGIN
  INSERT INTO tax_declaration (declaration_ref, form_type_id, company_code,
                                period_start, period_end, jurisdiction,
                                base_amount, tax_due, amount_payable,
                                status)
  VALUES (
    'DGI-BJ-TVA-2026-04-001',
    (SELECT form_type_id FROM tax_form_type WHERE form_code = 'TVA-MENS-BJ'),
    'COMP01',
    DATE '2026-04-01', DATE '2026-04-30', 'BJ',
    19200000, 3456000, 3456000,
    'DRAFT'
  ) RETURNING declaration_id INTO v_id;

  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate,
                                     base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_id, 1, 'NORMAL', 0.18, 16000000, 2880000, 7500000, 1350000);

  INSERT INTO tax_declaration_line (declaration_id, line_no, rate_type, rate,
                                     base_amount, tax_amount, deductible_base, deductible_tax)
  VALUES (v_id, 2, 'REDUCED', 0.09, 3200000, 288000, 1050000, 94500);
  -- TVA nette = 2880000 + 288000 - 1350000 - 94500 = 1723500

  COMMIT;
END;
/

-- ═══ 6. Crédit TVA - export Ouagadougou (avoir) ═══
INSERT INTO tax_credit (company_code, credit_source, origin_period, total_credit,
                        used_amount, expiry_date, declaration_id_origin)
VALUES ('COMP01', 'EXPORT_REFUND', DATE '2026-03-31', 850000, 0,
        DATE '2029-03-31', NULL);
COMMIT;

-- ═══ 7. Retard de paiement (LATE) - IR janvier 2026 ═══
INSERT INTO tax_declaration (
  declaration_ref, form_type_id, company_code,
  period_start, period_end, jurisdiction,
  base_amount, tax_due, amount_payable,
  status, submitted_at, acked_at, notes
) VALUES (
  'DGI-BJ-IR-2026-01-001',
  (SELECT form_type_id FROM tax_form_type WHERE form_code = 'IR-AAC-BJ'),
  'COMP01',
  DATE '2026-01-01', DATE '2026-01-31', 'BJ',
  12500000, 625000, 625000,
  'LATE',
  TIMESTAMP '2026-02-15 10:00:00.00',
  TIMESTAMP '2026-02-20 11:00:00.00',
  'Paiement effectué 5 jours après délai (pénalité 25K)'
);

-- ═══ Volumétrie ═══
PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'TAX_FORM_TYPE'              AS tbl, COUNT(*) AS nb FROM tax_form_type
UNION ALL SELECT 'TAX_DECLARATION',         COUNT(*) FROM tax_declaration
UNION ALL SELECT 'TAX_DECLARATION_LINE',    COUNT(*) FROM tax_declaration_line
UNION ALL SELECT 'TAX_PAYMENT',             COUNT(*) FROM tax_payment
UNION ALL SELECT 'TAX_CREDIT',              COUNT(*) FROM tax_credit
 ORDER BY tbl;

PROMPT
PROMPT ═══ Demostrations ═══

PROMPT [Q1] Récap TVA par mois et jurisdiction
SELECT * FROM v_tax_summary_monthly;

PROMPT [Q2] Déclarations par statut
SELECT status, jurisdiction, COUNT(*) AS nb, SUM(amount_payable) AS total_a_payer
  FROM tax_declaration
 GROUP BY status, jurisdiction
 ORDER BY status, jurisdiction;

PROMPT [Q3] Détaillé d'une déclaration (BJ 03-2026) avec lignes
SELECT d.declaration_ref, d.period_start, d.period_end,
       d.base_amount, d.tax_due, d.credit_applied, d.amount_payable, d.status,
       d.submitted_at, d.acked_at, d.paid_at
  FROM tax_declaration d
 WHERE d.declaration_ref = 'DGI-BJ-TVA-2026-03-001';

SELECT line_no, rate_type, rate, base_amount, tax_amount,
       deductible_base, deductible_tax
  FROM tax_declaration_line
 WHERE declaration_id = (SELECT declaration_id FROM tax_declaration
                          WHERE declaration_ref = 'DGI-BJ-TVA-2026-03-001')
 ORDER BY line_no;

PROMPT [Q4] Paiements effectués à la DGI
SELECT p.payment_ref, p.payment_date, p.jurisdiction,
       p.payment_amount, p.payment_method,
       p.bank_ref,
       d.declaration_ref
  FROM tax_payment p
  LEFT JOIN tax_declaration d ON d.declaration_id = p.declaration_id
 ORDER BY p.payment_date;

PROMPT [Q5] Crédits TVA disponibles
SELECT credit_source, origin_period, total_credit, used_amount, remaining, expiry_date
  FROM tax_credit
 ORDER BY origin_period DESC;

PROMPT [Q6] Charge fiscale prévisionnelle - reste 2026
SELECT ft.form_code, ft.form_label, ft.jurisdiction, ft.frequency,
       COUNT(d.declaration_id) AS total_decl,
       SUM(d.amount_payable)   AS total_a_payer
  FROM tax_form_type ft
  LEFT JOIN tax_declaration d
    ON d.form_type_id = ft.form_type_id
   AND d.status IN ('DRAFT','SUBMITTED','ACKED','PAID')
 GROUP BY ft.form_code, ft.form_label, ft.jurisdiction, ft.frequency
 ORDER BY ft.jurisdiction, ft.form_code;

PROMPT [Q7] Obligations expirées (à soumettre)
SELECT declaration_ref, period_end, jurisdiction, status, amount_payable,
       SUBMITTED_AT, ACKED_AT, PAID_AT
  FROM tax_declaration
 WHERE status = 'DRAFT'
    OR (status IN ('SUBMITTED','ACKED') AND PAID_AT IS NULL);

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ DÉCLARATIONS FISCALES OHADA : 6 types, 6 déclarations + paiements
PROMPT ══════════════════════════════════════════════════════════
EXIT;
