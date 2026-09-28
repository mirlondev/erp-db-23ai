-- ============================================================
-- S24 : Seed Immobilisations OHADA
-- ============================================================
-- Scénario : société COMP01 acquiert 6 immobilisations en 2024-2026
--   1. Camion Mercedes Sprinter 2026
--   2. Mobilier de bureau (siège Abidjan)
--   3. Ordinateur portable Dell Latitude
--   4. Imprimante multifonction Kyocera
--   5. Bâtiment dépôt DEP02 (acquis en 2024)
--   6. Logiciel ERP Oracle 26ai (licence perpétuelle)
-- Calcul plan d'amortissement complet + cessions / sorties
-- ============================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET DEFINE OFF

CONNECT app_gl/AppGl#2026@localhost:1521/FREEPDB1

PROMPT ══════════════════════════════════════════════════════════
PROMPT   SEED IMMOBILISATIONS OHADA COMP01 (6 biens)
PROMPT ══════════════════════════════════════════════════════════

-- ═══ 1. Nettoyage ═══
BEGIN
  EXECUTE IMMEDIATE 'DELETE FROM imm_revaluation';
  EXECUTE IMMEDIATE 'DELETE FROM imm_disposal';
  EXECUTE IMMEDIATE 'DELETE FROM imm_depreciation';
  EXECUTE IMMEDIATE 'DELETE FROM imm_asset';
  EXECUTE IMMEDIATE 'DELETE FROM imm_method';
  COMMIT;
END;
/

-- ═══ 2. Méthodes d'amortissement SYSCOHADA ═══
INSERT INTO imm_method (method_code, method_label, method_type, formula, applicable_to)
VALUES ('LINEAR', 'Amortissement linéaire', 'LINEAR',
        'Dotation annuelle = (Valeur d''origine - Valeur résiduelle) / Durée utile (années)', 'ALL');

INSERT INTO imm_method (method_code, method_label, method_type, formula, applicable_to)
VALUES ('DEG-BUILDING', 'Dégressif bâtiment (Bureau/UEMOA)', 'DEGRESSIVE',
        'Taux linéaire x Coefficient dégressif (1,5 si n=4 ; 2 si 5-6 ans ; 3 si >6)', 'BUILDING');

INSERT INTO imm_method (method_code, method_label, method_type, formula, applicable_to)
VALUES ('DEG-EQ', 'Dégressif matériel (SYSCOHADA révisé)', 'DEGRESSIVE',
        'Taux dégressif = (1 / n) x coefficient (1,5 - 3)', 'MACHINERY|EQUIPMENT|VEHICLE');

INSERT INTO imm_method (method_code, method_label, method_type, formula, applicable_to)
VALUES ('SOFT-L', 'Linéraire logiciels (5 ans)', 'LINEAR',
        'Taux = 20% annuel, durée 5 ans (OHADA révisé art. 39)', 'SOFTWARE|INTANGIBLE');

COMMIT;
PROMPT Méthodes d'amortissement chargées.

-- ═══ 3. Acquisition de 6 immobilisations ═══
PROMPT Inscription des 6 immobilisations COMP01...

INSERT INTO imm_asset (
  asset_code, company_code, asset_name, category,
  acquisition_date, acquisition_value, residual_value, useful_life_months,
  depreciation_method, gl_account_code, serial_number, location_code, supplier_code
) VALUES (
  'IMM-2026-001', 'COMP01', 'Camion Mercedes Sprinter 316 CDI 2026',
  'VEHICLE', DATE '2026-01-15', 25000000, 5000000, 60,
  'DEGRESSIVE', '24510000', 'VIN-WDB9061331N123456',
  'DEP01', 'FOURN01'
);
-- 1er janvier 2026 → 25M FCFA, durée 60 mois linéaire ou dégressif

INSERT INTO imm_asset (asset_code, company_code, asset_name, category,
  acquisition_date, acquisition_value, residual_value, useful_life_months,
  depreciation_method, gl_account_code, location_code, supplier_code)
VALUES ('IMM-2024-010', 'COMP01', 'Mobilier de bureau (15 postes, direction)',
        'FURNITURE', DATE '2024-06-01', 4500000, 0, 120,
        'LINEAR', '24410000', 'SIEGE-COMP01', 'FOURN02');

INSERT INTO imm_asset (asset_code, company_code, asset_name, category,
  acquisition_date, acquisition_value, residual_value, useful_life_months,
  depreciation_method, gl_account_code, serial_number, location_code)
VALUES ('IMM-2025-003', 'COMP01', 'Ordinateur portable Dell Latitude 7440',
        'IT', DATE '2025-09-10', 1850000, 0, 36,
        'LINEAR', '24430000', 'SN-DELL-7440-987654', 'DEP01');

INSERT INTO imm_asset (asset_code, company_code, asset_name, category,
  acquisition_date, acquisition_value, residual_value, useful_life_months,
  depreciation_method, gl_account_code, serial_number, location_code)
VALUES ('IMM-2025-007', 'COMP01', 'Imprimante Kyocera TASKalfa 4054ci',
        'IT', DATE '2025-11-05', 950000, 0, 60,
        'LINEAR', '24430000', 'SN-KYOC-4054-112233', 'SIEGE-COMP01');

INSERT INTO imm_asset (asset_code, company_code, asset_name, category,
  acquisition_date, acquisition_value, residual_value, useful_life_months,
  depreciation_method, gl_account_code, location_code, notes)
VALUES ('IMM-2024-002', 'COMP01', 'Bâtiment entrepôt DEP02 (Ouagadougou)',
        'BUILDING', DATE '2024-02-15', 85000000, 10000000, 240,
        'LINEAR', '22110000', 'DEP02',
        'Bâtiment acquis fin 2024, 20 ans durée amort, résiduelle 10M');

INSERT INTO imm_asset (asset_code, company_code, asset_name, category,
  acquisition_date, acquisition_value, residual_value, useful_life_months,
  depreciation_method, gl_account_code, supplier_code, notes)
VALUES ('IMM-2026-LIC', 'COMP01', 'Licence Oracle 26ai Entreprise Édition',
        'SOFTWARE', DATE '2026-09-15', 6500000, 0, 60,
        'LINEAR', '24110000', 'Oracle',
        'Licence perpétuelle, 5 ans amortissement SYSCOHADA révisé');

COMMIT;

-- ═══ 4. Calcul du plan d'amortissement ═══
PROMPT
PROMPT ═══ Calcul du plan d''amortissement pour les 6 biens ═══

DECLARE
  TYPE asset_rec IS RECORD (
    asset_id NUMBER,
    acq_val  NUMBER,
    resid    NUMBER,
    duration NUMBER,
    acq_date DATE,
    method   VARCHAR2(20)
  );

  TYPE asset_tab IS TABLE OF asset_rec;
  v_assets  asset_tab := asset_tab();

  v_monthly_depr  NUMBER(16,4);
  v_first_period  DATE;
  v_start         DATE;
  v_period_end    DATE;

BEGIN
  -- Récupération des actifs acquis
  FOR r IN (SELECT asset_id, acquisition_value, residual_value,
                   useful_life_months, acquisition_date, depreciation_method
              FROM imm_asset
             WHERE company_code = 'COMP01') LOOP
    v_assets.EXTEND;
    v_assets(v_assets.LAST) := asset_rec(r.asset_id, r.acquisition_value,
                                          r.residual_value, r.useful_life_months,
                                          r.acquisition_date, r.depreciation_method);
  END LOOP;

  -- Pour chaque bien, mensualité = valeur_amortissable / durée
  FOR i IN 1..v_assets.COUNT LOOP
    DECLARE
      v_a asset_rec := v_assets(i);
      v_monthly NUMBER(16,4);
    BEGIN
      v_monthly := ROUND((v_a.acq_val - v_a.resid) / v_a.duration, 4);

      -- Génère les lignes mensuelles
      v_start := v_a.acq_date;
      <<months_loop>>
      FOR m IN 1..v_a.duration LOOP
        v_first_period := ADD_MONTHS(TRUNC(v_start, 'MM'), m - 1);
        v_period_end   := LAST_DAY(v_first_period);

        INSERT INTO imm_depreciation (
          asset_id, fiscal_year, period_no, period_start, period_end,
          depr_amount, cumulative_depr, residual_value_at
        ) VALUES (
          v_a.asset_id,
          EXTRACT(YEAR FROM v_period_end),
          EXTRACT(MONTH FROM v_period_end),
          v_first_period,
          v_period_end,
          v_monthly,
          v_monthly * m,
          v_a.acq_val - (v_monthly * m)
        );
      END LOOP;

      -- Mise à jour asset : accumulated_dep et net_book_value
      UPDATE imm_asset
         SET accumulated_dep = v_a.duration * v_monthly,
             net_book_value  = v_a.acq_val - (v_a.duration * v_monthly),
             depreciation_rate = CASE
               WHEN v_a.method = 'LINEAR'
                 THEN ROUND(100 * 12 / v_a.duration, 2)
               WHEN v_a.method = 'DEGRESSIVE' AND v_a.duration BETWEEN 1 AND 60
                 THEN ROUND(100 * 12 / v_a.duration * 1.5, 2)
               ELSE 0
             END
       WHERE asset_id = v_a.asset_id;
    END;
  END LOOP;

  COMMIT;
END;
/

-- ═══ 5. Cession d'un bien (sortie) ═══
INSERT INTO imm_disposal (
  asset_id, disposal_date, disposal_type, disposal_value,
  net_book_value_at, gain_loss_amount, buyer, document_ref, notes
) VALUES (
  (SELECT asset_id FROM imm_asset WHERE asset_code = 'IMM-2026-001'),
  DATE '2026-12-31', 'SALE', 26000000,
  24500000, 1500000,
  'Transitaire DoualaPort SA', 'VENTE-CAMION-2026',
  'Cession du Mercedes Sprinter après 12 mois amortissement'
);

UPDATE imm_asset SET status = 'DISPOSED'
 WHERE asset_code = 'IMM-2026-001';
COMMIT;

-- ═══ 6. Réévaluation du bâtiment (indexation inflation) ═══
INSERT INTO imm_revaluation (
  asset_id, revaluation_date, revaluation_type, old_value, new_value,
  coefficient, legal_basis, authorizing_body
) VALUES (
  (SELECT asset_id FROM imm_asset WHERE asset_code = 'IMM-2024-002'),
  DATE '2025-12-31', 'INFLATIONARY', 85000000, 95500000, 1.1247,
  'Décision AG extraordinaire', 'Assemblée Générale Extraordinaire'
);
COMMIT;

PROMPT
PROMPT ═══ Volumétrie ═══
SELECT 'IMM_METHOD'              AS tbl, COUNT(*) AS nb FROM imm_method
UNION ALL SELECT 'IMM_ASSET',       COUNT(*) FROM imm_asset
UNION ALL SELECT 'IMM_DEPRECIATION',COUNT(*) FROM imm_depreciation
UNION ALL SELECT 'IMM_DISPOSAL',    COUNT(*) FROM imm_disposal
UNION ALL SELECT 'IMM_REVALUATION', COUNT(*) FROM imm_revaluation
 ORDER BY tbl;

PROMPT
PROMPT ═══ Demostrations ═══

PROMPT [Q1] État de l'immobilisation - vue v_imm_summary
SELECT category,
       COUNT(*) AS nb_assets,
       SUM(acquisition_value) AS total_acquisition,
       SUM(accumulated_dep)   AS total_depreciation,
       SUM(net_book_value)    AS total_vnc,
       ROUND(AVG(depr_progress_pct), 2) AS avg_progress_pct
  FROM v_imm_summary
 GROUP BY category
 ORDER BY total_acquisition DESC;

PROMPT [Q2] Plan d'amortissement du camion Mercedes (10 premières lignes)
SELECT asset_name,
       fiscal_year, period_no, period_end,
       depr_amount, cumulative_depr, residual_value_at, status
  FROM imm_depreciation
 WHERE asset_id = (SELECT asset_id FROM imm_asset WHERE asset_code = 'IMM-2026-001')
 ORDER BY fiscal_year, period_no
 FETCH FIRST 12 ROWS ONLY;

PROMPT [Q3] Cumul annuel d'amortissement (par exercice fiscal)
SELECT fiscal_year, COUNT(*) AS nb_lignes, SUM(depr_amount) AS total_dotation
  FROM imm_depreciation
 GROUP BY fiscal_year
 ORDER BY fiscal_year;

PROMPT [Q4] Biens totalement amortis (VNC=0)
SELECT asset_code, asset_name, acquisition_value, accumulated_dep, net_book_value
  FROM imm_asset
 WHERE NVL(net_book_value, 0) = 0 OR status != 'ACTIVE';

PROMPT [Q5] Immobilisations par méthode d'amortissement
SELECT depreciation_method, COUNT(*) AS nb_assets,
       SUM(acquisition_value) AS total_value
  FROM imm_asset
 GROUP BY depreciation_method
 ORDER BY 2 DESC;

PROMPT [Q6] Reporting plus value / moins value sur cessions
SELECT i.asset_code, i.asset_name,
       d.disposal_date, d.disposal_type,
       d.disposal_value, d.net_book_value_at,
       d.gain_loss_amount
  FROM imm_disposal d
  JOIN imm_asset i ON i.asset_id = d.asset_id
 ORDER BY d.disposal_date DESC;

PROMPT [Q7] Réévaluation (impact sur VNC)
SELECT i.asset_code, i.asset_name,
       r.old_value, r.new_value,
       ROUND(100 * (r.new_value - r.old_value) / r.old_value, 2) AS pct_augmentation,
       r.legal_basis
  FROM imm_revaluation r
  JOIN imm_asset i ON i.asset_id = r.asset_id;

PROMPT ══════════════════════════════════════════════════════════
PROMPT   ✅ OHADA IMMOBILISATIONS : 6 biens, ~ 924 lignes dotations
PROMPT ══════════════════════════════════════════════════════════
EXIT;
