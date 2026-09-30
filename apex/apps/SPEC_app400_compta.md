# Spécifications UI — App 400 « Comptabilité OHADA » (APEX 26.1)

Schéma : `APP_GL` (+ `APP_AR`, `APP_HR`, `APP_PARTY`) · Rôles : `REGAL_COMPTABLE`, `REGAL_ADMIN`

## Vue d'ensemble fonctionnelle

L'app 400 couvre la **comptabilité SYSCOHADA révisée** + les **déclarations fiscales CEMAC**
adaptées au Congo Brazzaville (Pointe-Noire). Elle s'appuie sur :

- `app_gl.gl_account_ohada` (plan comptable officiel SYSCOHADA révisé, script 38)
- `app_gl.gl_entry` / `gl_entry_line` / `gl_entry_line_v2` partitionné (script 56)
- `app_gl.gl_journal` / `gl_fiscal_year` / `gl_fiscal_period` / `gl_cost_center`
- `app_gl.tax_form_type` (6 types CG, script 47 + 49) — TVA 18.9%, IS, IRCM, Patente, TFPB
- `app_gl.tax_declaration` + `tax_declaration_line` + `tax_payment` + `tax_credit`
- `app_gl.imm_asset` / `imm_depreciation` / `imm_disposal` / `imm_revaluation` (script 46)
- `app_gl.fn_cg_irpp()` (script 49) — barème IRPP Congo 8 tranches
- `app_hr.payroll_slip` (script 48) — bulletins de paie LITOKO
- `app_ar.invoice` + `app_ar.payment_history_v2` (script 56 partitionné)

## Pages

| # | Page | Type | Source | Composants APEX 26.1 | Actions / Packages |
|---|---|---|---|---|---|
| 1 | Dashboard comptable | Home | KPIs financiers | 8 cards KPI + Chart courbes | Drill-down vers pages spécialisées |
| 10 | Plan comptable OHADA | IR arborescente | `gl_account_ohada` | Tree View (classes 1-9) | Filtres par classe / nature |
| 11 | Fiche compte | Master-Detail | `gl_account_ohada` + soldes | 3 onglets : Identité / Mouvements / Budget | Vue `v_gl_account_balance` |
| 20 | Journaux | IR | `gl_journal` | Cards par type (ACH/VTE/BQ/OD) | "Nouvelle écriture" → page 21 |
| 21 | Saisie écritures | Form multi-lignes | `gl_entry` + `gl_entry_line_v2` | IG lignes équilibrées (Debit = Credit) | `pkg_gl.create_entry` |
| 22 | Lettrage | Wizard | `gl_entry_lettering` + `gl_entry` | Tableau de lettrage par compte auxiliaire | `pkg_gl.letter_entries` |
| 30 | Grand livre | Report | Vue `v_general_ledger` | Filtres période + compte + auxiliaire | Export PDF/Excel |
| 31 | Balance | Report | Vue `v_trial_balance` | 6 colonnes (Mvt débit/crédit, Solde débit/crédit, Cumul) | Comparatif N vs N-1 |
| 32 | Bilan SYSCOHADA | Report | Vue `v_balance_sheet` | Actif / Passif / Capitaux propres | Export PDF |
| 33 | CPC | Report | Vue `v_income_statement` | Charges / Produits | Comparatif mensuel |
| 40 | **Déclarations TVA Congo** | Wizard | `tax_declaration` + `tax_declaration_line` | Wizard 4 étapes : période, lignes, validation, paiement | Auto-calcul TVA nette due |
| 41 | Historique déclarations | IR | `tax_declaration` WHERE jurisdiction='CG' | Faceted Search (centre impôts, type, statut) | Drill-down → page 42 |
| 42 | Détail déclaration | Form | `tax_declaration` + lignes | Lecture + impression DGI (CERFA) | "Marquer payé" + lien `tax_payment` |
| 43 | Paiements DGI | IR | `tax_payment` | Centre des impôts CG-PNR (Pointe-Noire) | Générer virement BGFI |
| 50 | IRPP progressif (Congo) | Simulator | `app_gl.fn_cg_irpp()` | Form : revenu annuel + nb enfants → IRPP calculé | Test barème 8 tranches |
| 60 | **Immobilisations** | IR | `imm_asset` + `v_imm_summary` | IG éditable | Acquisition / Cession / Réévaluation |
| 61 | Plan d'amortissement | Report | `imm_depreciation` | Par bien : dotations mensuelles sur durée | Cumul annuel |
| 62 | Cession / Sortie | Wizard | `imm_disposal` | Calcul +/- value | Écriture automatique 775/281 |
| 63 | Réévaluation | Form | `imm_revaluation` | Calcul coefficient indexation | "Appliquer" → écritures 106 |
| 70 | Paie LITOKO | IR | `v_payroll_bulletin` (script 48) | Filtres mois/employé | Lien bulletins PDF |
| 71 | Charges sociales CNSS | Report | Vue `v_cnss_charges` | Détail 10% sal + 19.5% pat | Versement mensuel |
| 80 | États financiers SYSCOHADA | Reports | Multiples | Bilan + CPC + TAFIRE | Export PDF signés DG |
| 90 | Audit comptable | IR | `sys_audit_trail` WHERE entity_type LIKE '%gl%' | Timeline | Filtres user / date |

## KPI Dashboard (page 1)

```sql
-- CA mensuel (compte 701) YTD
SELECT EXTRACT(MONTH FROM e.entry_date) AS mois,
       SUM(el.debit) - SUM(el.credit)    AS ca_xaf,
       COUNT(DISTINCT e.entry_id)        AS nb_ecritures
  FROM app_gl.gl_entry e
  JOIN app_gl.gl_entry_line el ON el.entry_id = e.entry_id
  JOIN app_gl.gl_account_ohada a ON a.account_code = el.account_code
 WHERE a.account_code LIKE '701%'
   AND EXTRACT(YEAR FROM e.entry_date) = EXTRACT(YEAR FROM SYSDATE)
 GROUP BY EXTRACT(MONTH FROM e.entry_date)
 ORDER BY 1;

-- TVA nette à payer ce mois (CG)
SELECT d.declaration_ref,
       d.period_end, d.tax_due, d.credit_applied, d.amount_payable, d.status
  FROM app_gl.tax_declaration d
  JOIN app_gl.tax_form_type ft ON ft.form_type_id = d.form_type_id
 WHERE ft.form_type = 'TVA'
   AND d.jurisdiction = 'CG'
   AND d.status IN ('SUBMITTED','ACKED')
   AND EXTRACT(MONTH FROM d.period_end) = EXTRACT(MONTH FROM SYSDATE);
```

## Wizard déclaration TVA (page 40) — détail

| Étape | Composant | Calcul auto |
|---|---|---|
| 1. Période | Date picker | `period_start` / `period_end` |
| 2. Lignes | IG pré-rempli depuis `app_sales.ticket` du mois | TVA collectée 18.9% sur ventes + 9% sur produits spécifiques |
| 3. Validation | Vue équilibrage | Calcul TVA nette due = collectée - déductible |
| 4. Paiement | Form | Sélection centre impôts (CG-PNR, CG-BZV, ...) + mode paiement |

## Page simulator IRPP (page 50)

```sql
-- Pour un revenu annuel donné et nb enfants, calcule IRPP progressif
SELECT app_gl.fn_cg_irpp(:P4_REVENU_ANNUEL, :P4_NB_ENFANTS) AS irpp_annuel,
       ROUND(app_gl.fn_cg_irpp(:P4_REVENU_ANNUEL, :P4_NB_ENFANTS) / 12, 0) AS irpp_mensuel,
       CASE
         WHEN :P4_REVENU_ANNUEL <= 464000 THEN 'Tranche 1 (0%)'
         WHEN :P4_REVENU_ANNUEL <= 1000000 THEN 'Tranche 2 (5%)'
         WHEN :P4_REVENU_ANNUEL <= 2000000 THEN 'Tranche 3 (10%)'
         WHEN :P4_REVENU_ANNUEL <= 4000000 THEN 'Tranche 4 (15%)'
         WHEN :P4_REVENU_ANNUEL <= 8000000 THEN 'Tranche 5 (20%)'
         WHEN :P4_REVENU_ANNUEL <= 16000000 THEN 'Tranche 6 (25%)'
         WHEN :P4_REVENU_ANNUEL <= 32000000 THEN 'Tranche 7 (30%)'
         ELSE 'Tranche 8 (35%)'
       END AS tranche
  FROM dual;
```

## Contraintes compatibilité WS legacy

1. Les écritures créées par APEX sont insérées via `pkg_gl.create_entry` (script 14)
   qui génère automatiquement le N° de pièce (`gl_entry.entry_no`).
2. Le lettrage (page 22) doit passer par `pkg_gl.letter_entries` plutôt que par DML
   direct — sinon les vues `*_V2` (script 56) ne sont pas synchronisées.
3. Les déclarations TVA Congo (page 40) utilisent les taux CEMAC : 18.9% / 9% / 0%.
   Les taux UEMOA (18%) sont rejetés via une contrainte CHECK sur `tax_declaration_line`.
4. Les bulletins de paie LITOKO (page 70) sont en XAF et utilisent la CNSS Congo,
   **pas** la CNPS UEMOA — restriction au niveau de `app_hr.mpf_employee.country_code='CG'`.

## Sécurité APEX

- Toutes les pages requièrent rôle `REGAL_COMPTABLE` minimum
- Page 80 (états financiers) : rôle `REGAL_ADMIN` requis
- Audit toutes consultations dans `sys_audit_trail` (severity INFO)
- Filtrage par `company_code` via `app_sys.pkg_apex_auth.user_companies(:APP_USER)`
  (à ajouter au package d'auth)
