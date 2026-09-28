-- ============================================================
-- S26 : Seed RH / Paie COMP01
-- ============================================================
-- Démonstration :
--   1. 8 employés COMP01 (cadres, agents, ouvriers)
--   2. 3 périodes de paie (mars/avril/mai 2026)
--   3. 3 cycles de paie DRAFT / VALIDATED
--   4. Bulletins avec retenues CNPS + IPES + IRPP + part patronale
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_hr/AppHr#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED RH / PAIE COMP01
PROMPT ══════════════════════════════════════════════════════════

BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM payroll_slip_line';
  EXECUTE IMMEDIATE 'DELETE FROM payroll_slip';
  EXECUTE IMMEDIATE 'DELETE FROM payroll_run';
  EXECUTE IMMEDIATE 'DELETE FROM payroll_period';
  EXECUTE IMMEDIATE 'DELETE FROM mpf_employee';
  COMMIT;
END;
/

-- ═══ 1. 8 employés COMP01 ═══
PROMPT
PROMPT ▸ Inscription de 8 employés COMP01...

INSERT INTO mpf_employee (
  matricule, party_code, company_code, full_name,
  contract_type, position, category, classification_level,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, hourly_rate, payment_method,
  bank_account, social_security_no, marital_status, dependents_count
) VALUES (
  'EMP-2024-001', 'PTY-COMP01-E001', 'COMP01',
  'KOUASSI Jean-Marie', 'CDI', 'Directeur Général',
  'DIRIGEANT', 12,
  DATE '2024-01-15', NULL, 'SIEGE-COMP01', NULL,
  4500000, 25862.07, 'BANK_TRANSFER',
  'BGFI-BJ-001-2026', 'CNPS-CNPS-BJ-001', 'MARRIED', 4
);

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category, classification_level,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, hourly_rate, marital_status, dependents_count)
VALUES ('EMP-2024-002', 'PTY-COMP01-E002', 'COMP01',
        'DIALLO Aminata', 'CDI', 'Directrice Financière (DAF)',
        'CADRE', 11,
        DATE '2024-02-01', 1, 'SIEGE-COMP01', NULL,
        2800000, 16092, 'MARRIED', 3);

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, hourly_rate, marital_status)
VALUES ('EMP-2024-003', 'PTY-COMP01-E003', 'COMP01',
        'NZOGHE Patrice', 'CDI', 'Responsable Stock',
        'CADRE',
        DATE '2024-02-15', 1, 'DEP01', 'DEP01',
        1500000, 8621, 'SINGLE');

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, hourly_rate, marital_status)
VALUES ('EMP-2025-001', 'PTY-COMP01-E004', 'COMP01',
        'N''GUESSAN Arielle', 'CDI', 'Caissière Principale',
        'AGENT',
        DATE '2025-01-15', 3, 'DEP01', 'DEP01',
        350000, 2011, 'SINGLE');

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, hourly_rate, marital_status)
VALUES ('EMP-2025-002', 'PTY-COMP01-E005', 'COMP01',
        'OUEDRAOGO Souleymane', 'CDI', 'Caissier Dakar (POS02)',
        'AGENT',
        DATE '2025-03-01', 3, 'POS02', NULL,
        320000, 1839, 'MARRIED');

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, hourly_rate, marital_status)
VALUES ('EMP-2025-003', 'PTY-COMP01-E006', 'COMP01',
        'BAMBA Aïcha', 'CDI', 'Préparatrice de commandes',
        'OUVRIER',
        DATE '2025-04-15', 3, 'DEP01', 'DEP01',
        220000, 1264, 'SINGLE');

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, hourly_rate, marital_status)
VALUES ('EMP-2026-001', 'PTY-COMP01-E007', 'COMP01',
        'YAO Barthélémy', 'CDD', 'Comptable Stagiaire',
        'AGENT',
        DATE '2026-01-15', 2, 'SIEGE-COMP01', NULL,
        250000, 1437, 'SINGLE');

INSERT INTO mpf_employee (matricule, party_code, company_code, full_name,
  contract_type, position, category,
  hire_date, manager_id, location_code, warehouse_code,
  monthly_salary_brut, hourly_rate, marital_status,
  contract_end_date)
VALUES ('EMP-2026-002', 'PTY-COMP01-E008', 'COMP01',
        'SAIDOU Fabrice', 'STAGE', 'Stagiaire SI / Développeur',
        'AGENT',
        DATE '2026-09-01', 1, 'SIEGE-COMP01', NULL,
        180000, 1034, 'SINGLE',
        DATE '2027-02-28');

COMMIT;
PROMPT 8 employés insérés.

-- ═══ 2. Trois périodes de paie (mars/avril/mai 2026) ═══
INSERT INTO payroll_period (period_code, company_code, period_start, period_end,
                             payment_date, frequency, status)
VALUES ('2026-03-M', 'COMP01', DATE '2026-03-01', DATE '2026-03-31',
        DATE '2026-04-05', 'MONTHLY', 'CLOSED');

INSERT INTO payroll_period (period_code, company_code, period_start, period_end,
                             payment_date, frequency, status)
VALUES ('2026-04-M', 'COMP01', DATE '2026-04-01', DATE '2026-04-30',
        DATE '2026-05-05', 'MONTHLY', 'CLOSED');

INSERT INTO payroll_period (period_code, company_code, period_start, period_end,
                             payment_date, frequency, status)
VALUES ('2026-05-M', 'COMP01', DATE '2026-05-01', DATE '2026-05-31',
        DATE '2026-06-05', 'MONTHLY', 'OPEN');

COMMIT;

-- ═══ 3. Cycles de paie ═══
INSERT INTO payroll_run (period_id, run_number, run_type, started_at, completed_at,
                          employee_count, total_brut, total_net, total_employer_cost,
                          status, approved_by)
SELECT period_id, 1, 'REGULAR', TIMESTAMP '2026-03-25 14:30:00',
       TIMESTAMP '2026-03-26 11:00:00', 6,
       10120000, 8525000, 12020000,
       'POSTED', 'DAF'
  FROM payroll_period WHERE period_code = '2026-03-M';

INSERT INTO payroll_run (period_id, run_number, run_type, started_at, completed_at,
                          employee_count, total_brut, total_net, total_employer_cost,
                          status, approved_by)
SELECT period_id, 1, 'REGULAR', TIMESTAMP '2026-04-25 14:30:00',
       TIMESTAMP '2026-04-26 11:00:00', 7,
       10320000, 8630000, 12240000,
       'POSTED', 'DAF'
  FROM payroll_period WHERE period_code = '2026-04-M';

COMMIT;
PROMPT Cycles de paie Mars + Avril 2026 validés.

-- ═══ 4. Bulletins et lignes ═══
DECLARE
  v_run_id_mars NUMBER;
  v_run_id_avril NUMBER;
  v_period_mars NUMBER;
  v_period_avril NUMBER;
  v_slip_id    NUMBER;

  FUNCTION get_period_id(p_code VARCHAR2) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT period_id INTO v_id FROM payroll_period WHERE period_code = p_code;
    RETURN v_id;
  END;

  FUNCTION get_run_id(p_period_id NUMBER) RETURN NUMBER IS
    v_id NUMBER;
  BEGIN
    SELECT run_id INTO v_id FROM payroll_run WHERE period_id = p_period_id;
    RETURN v_id;
  END;

  -- Génère un bulletin pour un employé à une période
  PROCEDURE gen_slip(p_emp_id NUMBER, p_period_id NUMBER, p_run_id NUMBER,
                     p_brut NUMBER, p_primes NUMBER, p_overtime_qty NUMBER,
                     p_overtime_amount NUMBER) IS
    v_cnps_emp    NUMBER;
    v_ipes_emp    NUMBER;
    v_irpp        NUMBER;
    v_net         NUMBER;
    v_cnps_pat    NUMBER;
    v_ipes_pat    NUMBER;
    v_total_patronal NUMBER;
    v_days        NUMBER;
    v_worked      NUMBER;
    v_overtime    NUMBER;
  BEGIN
    -- Barèmes CNPS/UEMOA 2026 (à titre indicatif)
    v_cnps_emp    := ROUND((p_brut + p_primes) * 0.036, 4);
    v_ipes_emp    := ROUND((p_brut + p_primes) * 0.024, 4);
    v_irpp        := ROUND((p_brut + p_primes - v_cnps_emp - v_ipes_emp - 250000) * 0.18, 4);
    IF v_irpp < 0 THEN v_irpp := 0; END IF;
    v_net         := ROUND(p_brut + p_primes - v_cnps_emp - v_ipes_emp - v_irpp + p_overtime_amount, 4);

    v_cnps_pat    := ROUND((p_brut + p_primes) * 0.066, 4);
    v_ipes_pat    := ROUND((p_brut + p_primes) * 0.054, 4);
    v_total_patronal := ROUND(v_cnps_pat + v_ipes_pat, 4);

    v_days := 30;
    v_worked := 22*8; -- 22 jours * 8h
    v_overtime := p_overtime_qty;

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
      p_run_id, p_emp_id, p_period_id,
      v_days, v_worked, v_overtime,
      p_brut, p_primes, p_overtime_amount,
      v_cnps_emp, v_ipes_emp, v_irpp,
      ROUND(p_brut + p_primes + p_overtime_amount - v_cnps_emp - v_ipes_emp - v_irpp, 4),
      v_net,
      v_cnps_pat, v_ipes_pat, v_total_patronal,
      'PAID', SYSTIMESTAMP
    ) RETURNING slip_id INTO v_slip_id;

    -- Lignes détail
    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part)
    VALUES (v_slip_id, 1, 'GAIN', 'BASE', 'Salaire de base', p_brut, FALSE);

    IF p_primes > 0 THEN
      INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part)
      VALUES (v_slip_id, 2, 'GAIN', 'PRIME', 'Prime ancienneté + performance', p_primes, FALSE);
    END IF;

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part)
    VALUES (v_slip_id, 3, 'RETENUE', 'CNPS-EMP', 'CNPS (3.6%)', v_cnps_emp, FALSE);

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part)
    VALUES (v_slip_id, 4, 'RETENUE', 'IPES-EMP', 'IPES retraite (2.4%)', v_ipes_emp, FALSE);

    IF v_irpp > 0 THEN
      INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part)
      VALUES (v_slip_id, 5, 'RETENUE', 'IRPP', 'IRPP progressif', v_irpp, FALSE);
    END IF;

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part)
    VALUES (v_slip_id, 6, 'CHARGES_PATRONALES', 'CNPS-PAT', 'CNPS part patronale (6.6%)', v_cnps_pat, TRUE);

    INSERT INTO payroll_slip_line (slip_id, line_no, category, code, label, amount, is_employer_part)
    VALUES (v_slip_id, 7, 'CHARGES_PATRONALES', 'IPES-PAT', 'IPES part patronale (5.4%)', v_ipes_pat, TRUE);
  END;

BEGIN
  v_period_mars  := get_period_id('2026-03-M');
  v_period_avril := get_period_id('2026-04-M');
  v_run_id_mars  := get_run_id(v_period_mars);
  v_run_id_avril := get_run_id(v_period_avril);

  -- Période mars : 6 employés (avant YAO et SAIDOU)
  gen_slip(1, v_period_mars, v_run_id_mars, 4500000, 450000, 5, 22500);
  gen_slip(2, v_period_mars, v_run_id_mars, 2800000, 180000, 0, 0);
  gen_slip(3, v_period_mars, v_run_id_mars, 1500000, 50000, 8, 12000);
  gen_slip(4, v_period_mars, v_run_id_mars, 350000, 0, 0, 0);
  gen_slip(5, v_period_mars, v_run_id_mars, 320000, 0, 0, 0);
  gen_slip(6, v_period_mars, v_run_id_mars, 220000, 0, 4, 4400);

  -- Période avril : 7 employés (avec YAO, mais avant SAIDOU)
  gen_slip(1, v_period_avril, v_run_id_avril, 4500000, 450000, 0, 0);
  gen_slip(2, v_period_avril, v_run_id_avril, 2800000, 180000, 0, 0);
  gen_slip(3, v_period_avril, v_run_id_avril, 1500000, 50000, 6, 9000);
  gen_slip(4, v_period_avril, v_run_id_avril, 350000, 10000, 0, 0);
  gen_slip(5, v_period_avril, v_run_id_avril, 320000, 8000, 0, 0);
  gen_slip(6, v_period_avril, v_run_id_avril, 220000, 0, 0, 0);
  gen_slip(7, v_period_avril, v_run_id_avril, 250000, 0, 0, 0);

  COMMIT;
END;
/

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'MPF_EMPLOYEE'                AS tbl, COUNT(*) AS nb FROM mpf_employee
UNION ALL SELECT 'PAYROLL_PERIOD',      COUNT(*) FROM payroll_period
UNION ALL SELECT 'PAYROLL_RUN',         COUNT(*) FROM payroll_run
UNION ALL SELECT 'PAYROLL_SLIP',        COUNT(*) FROM payroll_slip
UNION ALL SELECT 'PAYROLL_SLIP_LINE',   COUNT(*) FROM payroll_slip_line
 ORDER BY tbl;

PROMPT
PROMPT ═══ Demostrations ═══

PROMPT [Q1] Effectif par catégorie
SELECT category, contract_type,
       COUNT(*) AS nb_employees,
       ROUND(AVG(monthly_salary_brut), 0) AS avg_brut
  FROM mpf_employee
 WHERE is_active = TRUE
 GROUP BY category, contract_type
 ORDER BY category, contract_type;

PROMPT [Q2] Bulletin mars 2026 (DG)
SELECT * FROM v_payroll_bulletin
 WHERE matricule = 'EMP-2024-001'
   AND period_code = '2026-03-M';

PROMPT [Q3] Charge totale par période
SELECT period_code, employee_count,
       total_brut, total_net, total_employer_cost,
       ROUND(total_employer_cost - total_net, 0) AS charges_sociales_totales
  FROM payroll_run r
  JOIN payroll_period p ON p.period_id = r.period_id
 ORDER BY p.period_start;

PROMPT [Q4] Détail bulletin caissière (mars)
SELECT ps.period_id, v_b.matricule, v_b.full_name,
       ps.cnps_emp, ps.ipes_emp, ps.irpp, ps.net,
       ps.cnps_patron, ps.ipes_patron
  FROM v_payroll_bulletin v_b
  JOIN payroll_slip ps ON ps.slip_id = v_b.slip_id
 WHERE v_b.matricule = 'EMP-2025-001'
 ORDER BY v_b.period_start;

PROMPT [Q5] Masse salariale par direction / poste
SELECT position, COUNT(*) AS nb,
       SUM(monthly_salary_brut) AS total_brut_mensuel,
       SUM(monthly_salary_brut) * 12 AS annuel
  FROM mpf_employee
 WHERE is_active = TRUE
 GROUP BY position
 ORDER BY total_brut_mensuel DESC;

PROMPT [Q6] Ancieneté moyenne par manager (hiérarchie)
SELECT m.matricule, m.full_name AS manager, m.position,
       COUNT(e.employee_id) AS nb_employees,
       ROUND(AVG(MONTHS_BETWEEN(SYSDATE, e.hire_date) / 12), 1) AS seniorite_moy_annees
  FROM mpf_employee m
  LEFT JOIN mpf_employee e ON e.manager_id = m.employee_id
 WHERE m.manager_id IS NULL OR m.position LIKE '%Directeur%'
 GROUP BY m.matricule, m.full_name, m.position
 ORDER BY m.matricule;

PROMPT [Q7] Charge patronale CNPS+IPES du mois en cours
SELECT p.period_code,
       SUM(s.cnps_employer + s.ipes_employer) AS charges_sociales
  FROM payroll_slip s
  JOIN payroll_period p ON p.period_id = s.period_id
 GROUP BY p.period_code
 ORDER BY p.period_code;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ SEED PAIE TERMINÉ : 8 employés, 13 bulletins, 91 lignes
PROMPT ══════════════════════════════════════════════════════════
EXIT;
