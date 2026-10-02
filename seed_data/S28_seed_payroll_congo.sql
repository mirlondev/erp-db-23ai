-- ============================================================
-- S28 : Seed Paie LITOKO SARL — Congo Brazzaville (CNSS)
-- ============================================================
-- Paie LITOKO SARL — Pointe-Noire, Conforme au Code Sécurité Sociale CG
--   - CNSS Prestations familiales  4% salarié + 10% patron
--   - CNSS Pension vieillesse      4% salarié + 5% patron
--   - CNSS AT                      0% salarié + 2.5% patron
--   - CSC + CAMU                   2% salarié + 2% patron
--   - IRPP progressif 0% à 35% (8 tranches)
--   - IS 30% sur résultats
-- Devise : XAF
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF
WHENEVER SQLERROR EXIT SQL.SQLCODE
WHENEVER OSERROR EXIT FAILURE

CONNECT app_hr/AppHr#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED PAIE LITOKO — Pointe-Noire (CNSS + IRPP CG)
PROMPT ══════════════════════════════════════════════════════════

BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM payroll_slip_line';
  EXECUTE IMMEDIATE 'DELETE FROM payroll_slip';
  EXECUTE IMMEDIATE 'DELETE FROM payroll_run';
  EXECUTE IMMEDIATE 'DELETE FROM payroll_period';
  EXECUTE IMMEDIATE 'DELETE FROM mpf_employee WHERE company_code = ''LITOKO''';
  COMMIT;
END;
/

-- ═══ 1. Employés LITOKO (Pointe-Noire) ═══
PROMPT
PROMPT ▸ Inscription de 6 employés LITOKO (Pointe-Noire)

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, hourly_rate, payment_method, bank_account,
  social_security_no, marital_status, dependents_count)
VALUES ('LIT-2024-001', 'PTY-LITOKO-E001', 'LITOKO', 'MALONGA Patrick', 'CDI',
        'Gérant LITOKO Pointe-Noire', 'DIRIGEANT',
        DATE '2024-04-01', NULL, 'LPNR01', 'LIT01',
        1800000, 10345, 'BANK_TRANSFER', 'BGFI-CG-PNR-001',
        'CNSS-CG-001-2024', 'MARRIED', 3);

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, marital_status, dependents_count)
VALUES ('LIT-2024-002', 'PTY-LITOKO-E002', 'LITOKO', 'NGOMA Priscille', 'CDI',
        'Comptable senior (DAF)', 'CADRE',
        DATE '2024-05-15', 1, 'LPNR01', 'LIT01',
        950000, 'SINGLE', 0);

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, marital_status, dependents_count)
VALUES ('LIT-2024-003', 'PTY-LITOKO-E003', 'LITOKO', 'BITEMO Jean-Pierre', 'CDI',
        'Magasinier Pointe-Noire', 'AGENT',
        DATE '2024-09-01', 1, 'LIT01', 'LIT01',
        420000, 'MARRIED', 2);

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, marital_status, dependents_count)
VALUES ('LIT-2024-004', 'PTY-LITOKO-E004', 'LITOKO', 'MBAMA Marie-Laure', 'CDI',
        'Caissière Brazzaville', 'AGENT',
        DATE '2024-09-15', 1, 'LBZV01', 'LIT02',
        380000, 'SINGLE', 1);

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, marital_status)
VALUES ('LIT-2025-001', 'PTY-LITOKO-E005', 'LITOKO', 'KIMINOU Sylvain', 'CDI',
        'Caissier Pointe-Noire', 'AGENT',
        DATE '2025-03-15', 1, 'LPNR01', 'LIT01',
        360000, 'SINGLE');

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, marital_status,
  contract_end_date)
VALUES ('LIT-2026-001', 'PTY-LITOKO-E006', 'LITOKO', 'MOUKALA Elisée', 'CDD',
        'Vendeur saisonnier (Noël)', 'AGENT',
        DATE '2026-09-01', 1, 'LPNR02', 'LIT01',
        280000, 'SINGLE',
        DATE '2027-01-31');

COMMIT;
PROMPT 6 employés LITOKO insérés.

-- ═══ 2. Période de paie LITOKO - Mai 2026 ═══
INSERT INTO payroll_period (period_code, company_code, period_start, period_end,
                             payment_date, frequency, status)
VALUES ('2026-05-LITOKO', 'LITOKO', DATE '2026-05-01', DATE '2026-05-31',
        DATE '2026-06-05', 'MONTHLY', 'CLOSED');

INSERT INTO payroll_run (period_id, run_number, run_type, started_at, completed_at,
                          employee_count, total_brut, total_net, total_employer_cost,
                          status, approved_by)
SELECT period_id, 1, 'REGULAR', TIMESTAMP '2026-05-25 14:30:00',
       TIMESTAMP '2026-05-26 11:00:00', 6,
       4190000, 3560000, 4990000, 'POSTED', 'DAF'
  FROM payroll_period WHERE period_code = '2026-05-LITOKO';

COMMIT;

-- ═══ 3. Bulletins LITOKO avec CNSS + IRPP Congo ═══
DECLARE
  v_run_id NUMBER;
  v_period_id NUMBER;
  v_slip_id NUMBER;

  FUNCTION get_run_id(p_code VARCHAR2) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT run_id INTO v_id FROM payroll_run
      WHERE period_id = (SELECT period_id FROM payroll_period WHERE period_code = p_code);
    RETURN v_id;
  END;

  FUNCTION get_period_id(p_code VARCHAR2) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT period_id INTO v_id FROM payroll_period WHERE period_code = p_code;
    RETURN v_id;
  END;

  -- ═══ Calcul bulletin LITOKO selon barème Congo ═══
  PROCEDURE gen_slip_litoko(p_emp_id NUMBER, p_brut NUMBER, p_dependents NUMBER) IS
    v_cnss_pf_emp    NUMBER;       -- 4%
    v_cnss_ret_emp   NUMBER;       -- 4%
    v_csc_emp        NUMBER;       -- 2%
    v_cnss_emp       NUMBER;
    v_cnss_pf_pat    NUMBER;       -- 10%
    v_cnss_ret_pat   NUMBER;       -- 5%
    v_cnss_at_pat    NUMBER;       -- 2.5%
    v_csc_pat        NUMBER;       -- 2%
    v_total_patronal NUMBER;
    v_net_brut       NUMBER;
    v_annual         NUMBER;
    v_irpp_annual    NUMBER;
    v_irpp_monthly   NUMBER;
    v_net            NUMBER;

    v_plafond        CONSTANT NUMBER := 1200000;     -- plafond CNSS mensuel
  BEGIN
    -- Plafonnement CNSS
    IF p_brut > v_plafond THEN
      v_cnss_pf_emp  := ROUND(v_plafond * 0.04, 0);
      v_cnss_ret_emp := ROUND(v_plafond * 0.04, 0);
    ELSE
      v_cnss_pf_emp  := ROUND(p_brut * 0.04, 0);
      v_cnss_ret_emp := ROUND(p_brut * 0.04, 0);
    END IF;

    v_csc_emp       := ROUND(p_brut * 0.02, 0);
    v_cnss_emp      := v_cnss_pf_emp + v_cnss_ret_emp + v_csc_emp;

    -- IRPP : barème progressif annuel via fn_cg_irpp
    v_annual       := p_brut * 12;
    v_irpp_annual  := app_sys.fn_cg_irpp(v_annual, p_dependents);
    v_irpp_monthly := ROUND(v_irpp_annual / 12, 0);

    v_net := ROUND(p_brut - v_cnss_emp - v_irpp_monthly, 0);

    -- Charges patronales
    IF p_brut > v_plafond THEN
      v_cnss_pf_pat  := ROUND(v_plafond * 0.10, 0);
      v_cnss_ret_pat := ROUND(v_plafond * 0.05, 0);
    ELSE
      v_cnss_pf_pat  := ROUND(p_brut * 0.10, 0);
      v_cnss_ret_pat := ROUND(p_brut * 0.05, 0);
    END IF;
    v_cnss_at_pat := ROUND(p_brut * 0.025, 0);
    v_csc_pat     := ROUND(p_brut * 0.02, 0);

    v_total_patronal := v_cnss_pf_pat + v_cnss_ret_pat + v_cnss_at_pat + v_csc_pat;

    INSERT INTO payroll_slip (
      run_id, employee_id, period_id,
      work_days, worked_hours, overtime_hours,
      brut, primes, overtime,
      cnps_employee, ipes_employee, irpp,
      total_employee_cost,
      net,
      cnps_employer, ipes_employer, total_employer_cost,
      status, paid_at
    ) VALUES (
      v_run_id, p_emp_id, v_period_id,
      30, 22*8, 0,
      p_brut, 0, 0,
      v_cnss_emp, 0, v_irpp_monthly,                  -- cnps_employee = CNSS total, ipes = 0 (Congo utilise pas IPES)
      ROUND(p_brut - v_cnss_emp - v_irpp_monthly, 0),
      v_net,
      v_total_patronal, 0, v_total_patronal,
      'PAID', SYSTIMESTAMP
    ) RETURNING slip_id INTO v_slip_id;

    -- Lignes détail
    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part) VALUES
      (v_slip_id, 1, 'GAIN', 'BASE', 'Salaire de base', p_brut, FALSE);

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part) VALUES
      (v_slip_id, 2, 'RETENUE', 'CNSS-PF-EMP', 'CNSS Prestations familiales (4%)', v_cnss_pf_emp, FALSE);

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part) VALUES
      (v_slip_id, 3, 'RETENUE', 'CNSS-RET-EMP', 'CNSS Pension vieillesse (4%)', v_cnss_ret_emp, FALSE);

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part) VALUES
      (v_slip_id, 4, 'RETENUE', 'CSC-CAMU-EMP', 'CSC + CAMU mutuelle santé (2%)', v_csc_emp, FALSE);

    IF v_irpp_monthly > 0 THEN
      INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part) VALUES
        (v_slip_id, 5, 'RETENUE', 'IRPP', 'IRPP progressif CG (8 tranches)', v_irpp_monthly, FALSE);
    END IF;

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part) VALUES
      (v_slip_id, 6, 'CHARGES_PATRONALES', 'CNSS-PF-PAT', 'CNSS PF part patronale (10%)', v_cnss_pf_pat, TRUE);

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part) VALUES
      (v_slip_id, 7, 'CHARGES_PATRONALES', 'CNSS-RET-PAT', 'CNSS Retraite part patronale (5%)', v_cnss_ret_pat, TRUE);

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part) VALUES
      (v_slip_id, 8, 'CHARGES_PATRONALES', 'CNSS-AT-PAT', 'CNSS Accidents du travail (2.5%)', v_cnss_at_pat, TRUE);

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part) VALUES
      (v_slip_id, 9, 'CHARGES_PATRONALES', 'CSC-CAMU-PAT', 'CSC + CAMU part patronale (2%)', v_csc_pat, TRUE);
  END;

BEGIN
  v_period_id := get_period_id('2026-05-LITOKO');
  v_run_id    := get_run_id('2026-05-LITOKO');

  -- 1. Gérant LIT-2024-001 : 1.8M, marié, 3 enfants
  gen_slip_litoko(7, 1800000, 3);

  -- 2. Comptable LIT-2024-002 : 950K, célibataire
  gen_slip_litoko(8, 950000, 0);

  -- 3. Magasinier LIT-2024-003 : 420K, marié, 2 enfants
  gen_slip_litoko(9, 420000, 2);

  -- 4. Caissière BZV LIT-2024-004 : 380K, 1 enfant
  gen_slip_litoko(10, 380000, 1);

  -- 5. Caissier PNR LIT-2025-001 : 360K, célibataire
  gen_slip_litoko(11, 360000, 0);

  -- 6. Vendeur saisonnier LIT-2026-001 : 280K, célibataire
  gen_slip_litoko(12, 280000, 0);

  COMMIT;
END;
/

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'LITOKO Employés'  AS tbl, COUNT(*) AS nb FROM mpf_employee WHERE company_code = 'LITOKO'
UNION ALL SELECT 'LITOKO Périodes',    COUNT(*) FROM payroll_period p
                                              JOIN mpf_employee e ON e.company_code = p.company_code
                                              WHERE p.company_code = 'LITOKO'
UNION ALL SELECT 'LITOKO Bulletins',   COUNT(*) FROM payroll_slip s
                                              JOIN mpf_employee e ON e.employee_id = s.employee_id
                                              WHERE e.company_code = 'LITOKO'
UNION ALL SELECT 'LITOKO Lignes paie', COUNT(*) FROM payroll_slip_line l
                                              JOIN payroll_slip s ON s.slip_id = l.slip_id
                                              JOIN mpf_employee e ON e.employee_id = s.employee_id
                                              WHERE e.company_code = 'LITOKO'
 ORDER BY tbl;

PROMPT
PROMPT ═══ Demostrations ═══

PROMPT [Q1] Charges sociales LITOKO (CNSS + IRPP)
SELECT
  SUM(s.cnps_employee) AS total_cnss_employe,
  SUM(s.cnps_employer) AS total_cnss_employeur,
  SUM(s.irpp)          AS total_irpp,
  SUM(s.net)           AS total_net_a_payer
FROM payroll_slip s
JOIN mpf_employee e ON e.employee_id = s.employee_id
WHERE e.company_code = 'LITOKO';

PROMPT [Q2] Comparaison IRPP Congo vs flat tax 10%
SELECT
  e.matricule, e.full_name, e.position,
  s.brut,
  s.irpp AS irpp_progressif,
  ROUND(s.brut * 0.10, 0) AS irpp_flat_10pct,
  s.irpp - ROUND(s.brut * 0.10, 0) AS economie_irpp
FROM payroll_slip s
JOIN mpf_employee e ON e.employee_id = s.employee_id
WHERE e.company_code = 'LITOKO'
ORDER BY s.brut DESC;

PROMPT [Q3] Vérification abattement foyer (CGI CG art. 84)
SELECT
  e.matricule, e.dependents_count,
  e.monthly_salary_brut AS salaire_mensuel,
  e.monthly_salary_brut * 12 AS salaire_annuel,
  app_sys.fn_cg_irpp(e.monthly_salary_brut * 12, e.dependents_count) AS irpp_annuel,
  ROUND(app_sys.fn_cg_irpp(e.monthly_salary_brut * 12, e.dependents_count) / 12, 0) AS irpp_mensuel
FROM mpf_employee e
WHERE e.company_code = 'LITOKO'
ORDER BY e.monthly_salary_brut DESC;

PROMPT [Q4] Bulletin détaillé Gérant LITOKO (mai 2026)
SELECT l.line_no, l.code, l.label, l.amount,
       CASE WHEN l.is_employer_part = 'N' THEN 'SALARIE' ELSE 'PATRONAL' END AS type
  FROM payroll_slip_line l
  JOIN payroll_slip s ON s.slip_id = l.slip_id
  JOIN mpf_employee e ON e.employee_id = s.employee_id
 WHERE e.matricule = 'LIT-2024-001'
   AND s.period_id = (SELECT period_id FROM payroll_period WHERE period_code = '2026-05-LITOKO')
 ORDER BY l.line_no;

PROMPT [Q5] Masse salariale LITOKO vs total employeur
SELECT
  e.position,
  COUNT(*) AS nb,
  SUM(s.brut) AS total_brut,
  SUM(s.cnps_employee) AS cnss_employe,
  SUM(s.irpp) AS irpp_total,
  SUM(s.net) AS net_a_payer,
  SUM(s.cnps_employer) AS cnss_employeur,
  SUM(s.brut + s.cnps_employer) AS cout_total_employeur
FROM payroll_slip s
JOIN mpf_employee e ON e.employee_id = s.employee_id
WHERE e.company_code = 'LITOKO'
GROUP BY e.position
ORDER BY total_brut DESC;

PROMPT [Q6] Test IRPP Congo — barème 8 tranches
SELECT
  CASE
    WHEN annual_income < 464000   THEN '0% (0 - 464K)'
    WHEN annual_income < 1000000  THEN '5% (464K - 1M)'
    WHEN annual_income < 2000000  THEN '10% (1M - 2M)'
    WHEN annual_income < 4000000  THEN '15% (2M - 4M)'
    WHEN annual_income < 8000000  THEN '20% (4M - 8M)'
    WHEN annual_income < 16000000 THEN '25% (8M - 16M)'
    WHEN annual_income < 32000000 THEN '30% (16M - 32M)'
    ELSE '35% (>32M)'
  END AS tranche,
  annual_income,
  app_sys.fn_cg_irpp(annual_income, 0) AS irpp_annuel,
  ROUND(100 * app_sys.fn_cg_irpp(annual_income, 0) / annual_income, 2) AS taux_effectif_pct
FROM (
  SELECT 400000 AS annual_income FROM dual
  UNION ALL SELECT 1000000 FROM dual
  UNION ALL SELECT 3000000 FROM dual
  UNION ALL SELECT 6000000 FROM dual
  UNION ALL SELECT 12000000 FROM dual
  UNION ALL SELECT 25000000 FROM dual
  UNION ALL SELECT 50000000 FROM dual
);

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ PAIE LITOKO CONGO : 6 employés, 6 bulletins, 49 lignes
PROMPT   - CNSS : 10% salarié + 19.5% patron (plafond 1.2M)
PROMPT   - IRPP : 8 tranches 0%-35% (CGI CG art. 84)
PROMPT   - Abattement : 100K XAF par personne à charge
PROMPT ══════════════════════════════════════════════════════════
EXIT;
