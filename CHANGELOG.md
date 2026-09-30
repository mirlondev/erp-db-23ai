# 📋 CHANGELOG — erp-db-23ai

> Migration d'un ERP Oracle 11g (391 tables, 6 schémas REGAL) vers Oracle 23ai/26ai Free.

## 🎯 Résumé global

| | Début | Maintenant | Évolution |
|---|---:|---:|---:|
| Scripts SQL | 0 | **57** | +57 |
| Tables modernes | 0 | **~195** | +195 |
| Schémas APP_* | 0 | **17** | +17 |
| Packages PL/SQL | 0 | **8** | +8 |
| Triggers CDC | 0 | **3** | +3 |
| Triggers métier | 0 | **6** | +6 |
| Mat. Views | 0 | **3** | +3 |
| Duality Views | 0 | **5** | +5 |
| Schedulers | 0 | **5** | +5 |
| Sites REGAL | 0 | **7** | +7 |
| Seeds | 0 | **40** | +40 |
| Couverture legacy | 0% | **49%** | +49% |

## 📜 Historique détaillé

### v0.0.1 — Bootstrap initial (R0-R2)
- 17 schémas `APP_*` créés
- Cœur retail : product, party, stock, doc, pos, sales, gl, cash, hist
- 4 packages initiaux : `pkg_pricing`, `pkg_inventory`, `pkg_sales`, `pkg_gl`
- 4 triggers : ticket, inventory, stock alert, audit document
- 3 Materialized Views initiales
- 3 DBMS_SCHEDULER jobs
- 5 Duality Views (avec workaround PK composite via `v_*_json`)

### v0.0.2 — Lots R3-R14 (stock avancé, lots, marketing)
- R3 : inv_product_lot, inv_avg_cost, inv_stock_status
- R4 : transfer_header/line (entrepôts)
- R5 : invoicing (app_ar)
- R6 : payments_advanced
- R7 : pos_advanced
- R8 : promo_pos
- R9 : inventory_count (zone, double-comptage)
- R10 : vouchers (gift cards, lots)
- R11 : alerts + KPI catalogue
- R12 : reporting
- R13 : security + sys_audit_trail
- R14 : interfaces

### v0.0.3 — Quick wins & orchestration
- `pkg_pos_sales` (orchestration ticket+promo+loyalty)
- `trg_invoice_overdue` (auto-update balance)
- `dv_invoice` / `dv_payment` / `dv_customer_credit`
- `v_dashboard_executive` (16 KPIs)

### v0.0.4 — Lots 1A-1F (documents, expéditions, achats)
- 1A-1B : documents complémentaires (entêtes + lignes)
- 1C-1D : coûts / documents commerciaux
- 1E : expéditions (app_ship — 7 tables, n'enrichit pas le module)
- 1F : achats (app_purchase — 4 tables)

### v0.0.5 — pkg_doc + ETL
- `pkg_doc` package (create_quote, convert_quote_to_order, validate_document, cancel_document, link_documents)
- `pkg_etl_legacy` skeleton (DRY_RUN safe migration 11g→23ai)

### v0.0.6 — OHADA squelette
- 8 tables app_gl : gl_account_class, gl_account_ohada, gl_cost_center, gl_cost_center_axis, gl_analytical_entry, gl_fiscal_year, gl_fiscal_period, gl_budget
- Plan SYSCOHADA révisé seeds

### v0.0.7 — Package transfers + Lot 1G
- `pkg_transfer_stock` (12 fonctions : create_transfer, add_line, submit, approve, pack, ship, receive, cancel, get_status, get_value, get_active_transfers, get_available_qty)
- Workflow 6 étapes : DRAFT → REQUESTED → APPROVED → PACKED → IN_TRANSIT → RECEIVED → CLOSED
- Support cross-type : WH ↔ WH / WH ↔ STORE / STORE ↔ WH / STORE ↔ STORE
- Lot 1G : 5 tables app_ar (invoice_installment, invoice_dispute, dunning_schedule, collection_case, collection_case_invoice)

### v0.0.8 — OHADA Immobilisations & Déclarations fiscales
- 5 tables app_gl : imm_asset, imm_method, imm_depreciation, imm_disposal, imm_revaluation
- 5 tables app_gl : tax_form_type, tax_declaration, tax_declaration_line, tax_payment, tax_credit
- 2 vues : v_imm_summary, v_tax_summary_monthly

### v0.0.9 — Module RH/Paie
- 5 tables app_hr : mpf_employee, payroll_period, payroll_run, payroll_slip, payroll_slip_line
- Schéma app_hr + app_audit

### v0.1.0 — Correction deprecated 23ai/26ai
- `00_init_schemas.sql` : retrait `CREATE INDEX` (pas un privilège système valide) et `CREATE DOMAIN` (déprécié 26ai)
- `26_lot_r10_vouchers.sql` : `DECODE` → `CASE WHEN`
- `12_app_api.sql` / `33_trg_invoice_overdue.sql` : `EXCEPTION WHEN OTHERS THEN NULL` avec whitelist SQLCODE
- `50_grants_cross_schema.sql` : matrice 28 GRANT cross-schéma pour faire compiler tous les packages
- Recompilation automatique des PACKAGE BODY/TRIGGER/PROCEDURE/VIEW invalides

### v0.1.1 — Référentiel Congo Brazzaville (CEMAC)
- 1 pays CG (CEMAC) + 1 devise XAF (BEAC)
- 7 centres des impôts (BZV, PNR, DLS, NKY, OYO, IMP, SIB)
- 6 types déclarations CG : TVA 18.9%, IS 30%, IRCM 5%, Patente, TFPB
- Barème IRPP 8 tranches (0% → 35%) - CGI CG art. 84
- Barème CNSS Congo (10% salarié + 19.5% patron, plafond 1.2M XAF)
- Fonction `fn_cg_irpp()` : calcul progressif
- Seeds LITOKO SARL (Pointe-Noire) : société + 2 dépôts + 5 magasins

### v0.1.2 — Topologie Hub-and-Spoke REGAL
- 6 tables `site_*` : site_master, site_link, site_database, site_sync_schedule, site_sync_run, site_sync_conflict
- Outbox pattern : `outbox_event` + `pkg_sync_hub` + `pkg_sync_boutique`
- Triggers CDC : `trg_outbox_product_ai/_au/_ad` sur app_product.product
- DBMS_SCHEDULER : `JOB_SYNC_HUB_PUBLISH` toutes les 30 min
- `ARCHITECTURE_HUB_SPOKE.md` : doc complète

### v0.1.3 — Gap-filler legacy + partitionnement + ETL v2
- 22 tables legacy "À créer" (TT_BRD_OFFICE + 11 sœurs, supplier_product, product_unit_region, pos_format, payment_history, sys_message, sys_output)
- `fn_predict_growth()` : projection volumétrie 5 ans
- `pkg_etl_legacy` v2 : dispatcher GCBRDD 54.7M par CODTBRD (9 types)
- Table `etl_run_progress` : reprise après crash
- Table `etl_brd_mapping` : 9 types CODTBRD mappés

### v0.1.4 — Partitionnement EFFECTIF + ETL CSV legacy
- **4 tables partitionnées** : ticket_line_v2, transfer_line_v2, gl_entry_line_v2, payment_history_v2
- Stratégie 23ai : `PARTITION BY RANGE (date) INTERVAL` + `SUBPARTITION BY LIST (site_code)`
- `fn_partition_info()` + `fn_total_partitions()` : helpers
- `JOB_PARTITION_MAINT` : drop auto > 36 mois
- **ETL CSV legacy** : tables externes Oracle Loader pour GCPART, GCSTOCK, GCPTARIF_ART, GCPTIE, GCPTBRD, GCPRTAX
- BULK COLLECT 500 rows par batch

### v0.1.5 — Fix compatibilité WS legacy (branche `fix/ws-compat-fetch-failures`)
- `53_legacy_gap_filler.sql` : suppression GRANT self-schema `app_product.product TO app_product` (ORA-01749)
- `54_partition_tables_volumineuses.sql` :
  - index `payment_history` skip controlé si table absente (ORA-00942)
  - réutilise `ix_outbox_event_status` (ORA-01408)
  - MV log outbox idempotent + `WHENEVER SQLERROR EXIT`
- `56_partition_effectives.sql` :
  - retrait des 5 GRANT self-schema `*_v2 TO proprio` (ORA-01749)
  - garde-fou drop-before-create sur les 4 tables `_v2` (ORA-00955)
  - `JOB_PARTITION_MAINT` déplacé dans `app_sales` (owner des partitions)
  - bloc validation `CONNECT-in-UNION ALL` remplacé par `dba_tab_partitions`

### v0.1.6 — APEX 26.1 — Couche UI (actuelle)
- `apex/setup/01_apex_workspace.sql` : workspace **REGAL** (schéma principal `APP_API` + 6 schémas secondaires)
- `apex/setup/02_ords_enable_parsers.sql` : activation ORDS sur schémas APP_*
- `apex/setup/03_apex_auth_setup.sql` : package `pkg_apex_auth` (authenticate, user_roles, user_site_codes, log_login)
- `apex/setup/04_apex_components.sql` : **12 vues métier partagées** + fonction `regal_split` (CSV → table)
- `apex/setup/05_apex_litoko_branding.sql` : logo SVG + thème CSS (couleurs Congo) + JS utilitaires
- `apex/apps/SPEC_app100_pos.md` : spec POS/Ventes (7 pages)
- `apex/apps/SPEC_app200_stock.md` : spec Stock hub-spoke (8 pages + wizard 6 étapes)
- `apex/apps/SPEC_app300_achats.md` : spec Achats/Fournisseurs (12 pages + 3-way match)
- `apex/apps/SPEC_app400_compta.md` : spec Compta OHADA + Fiscal CG (18 pages)
- `apex/apps/SPEC_app500_admin.md` : spec Admin (7 pages)
- `apex/apps/import_app.sql` : helper d'import APEX
- `apex/README_APEX_26_1.md` : doc complète (compatibilité WS, roadmap UI 5 sprints)

## 🏛️ Schémas créés (17)

| Schéma | Tables (env.) | Rôle |
|---|---:|---|
| `app_sys` | 30+ | Noyau : utilisateurs, paramètres, **fiscal CG**, **sites**, **outbox**, **TT_***, messages i18n |
| `app_org` | 6+ | Société, dépôts, points de vente, **régions** |
| `app_product` | 8+ | Catalogue : produits, catégories, marques, **promotions POS**, **unités par région** |
| `app_party` | 5+ | Tiers : clients / fournisseurs / employés, **loyauté** |
| `app_inv` | 15+ | Stock, **lots, DLC**, **PRMP**, **transferts**, **inv_movement**, **transfer_line_v2** |
| `app_doc` | 5+ | Documents commerciaux |
| `app_pos` | 8+ | Terminaux, sessions, **formats tickets**, **auth PC par dépôt** |
| `app_sales` | 4+ | Tickets, **ticket_line_v2 partitionné** |
| `app_gl` | 15+ | Comptabilité OHADA + **immobilisations** + **déclarations fiscales** + **gl_entry_line_v2** |
| `app_cash` | 5+ | Caisses & mouvements |
| `app_hist` | 3+ | Archivage |
| `app_api` | 5+ | Vues exposées (Duality + classiques JSON) |
| `app_ar` | 8+ | Accounts Receivable : **échéances**, **litiges**, **relances**, **payment_history_v2** |
| `app_ship` | 7 | Expéditions (figé) |
| `app_purchase` | 4+ | Achats, **articles fournisseurs** |
| `app_hr` | 5+ | RH/Paie, **CNSS Congo** |
| `app_audit` | 0+ | Audit consolidé |

## 🎯 Mapping legacy → moderne (récap)

| Legacy | Lignes | Moderne | Statut |
|---|---:|---|---:|
| `CAISSE.GCPART` | 211K | `app_product.product` | ✅ ETL CSV |
| `CAISSE.GCSTOCK` | 1.6M | `app_inv.inv_stock` | ✅ ETL CSV |
| `CAISSE.CETICKETD` | 65.5M | `app_sales.ticket_line_v2` | ✅ partitionné |
| `CAISSE.CETICKET` | 16M | `app_sales.ticket` | ✅ |
| `CAISSE.GCBRDD` | 54.7M | dispatcher `pkg_etl_legacy v2` | ✅ 9 types CODTBRD |
| `CAISSE.GCBRDE` | 2.2M | `app_doc.doc_header` | ✅ |
| `XCPTA.CP_ECR_GEN` | 2.8M | `app_gl.gl_entry_line_v2` | ✅ partitionné |
| `XCPTA.CP_ECR_LET` | 2.4M | `app_gl.gl_entry_lettering` | ✅ |
| `XCPTA.CP_HISTO_RGL` | 501K | `app_ar.payment_history_v2` | ✅ partitionné |
| `KERNEL.TT_BRD_OFFICE` | 228K | `app_sys.tt_brd_office` | ✅ |
| `TRANSFERT.TR_GCBRDD` | 201K | `app_inv.inv_movement` | ✅ |
| `TRANSFERT.TR_GCBRDE` | 65K | `app_inv.transfer_header` | ✅ |
| `KERNEL.UTLOG` | 444K | `app_sys.sys_audit_trail` | ✅ |
| `KERNEL.UTSYNCHRO_LOG` | 120K | `app_sys.outbox_event` | ✅ |

## 📈 Projection 5 ans (volumétrie legacy +30%/an)

| Table | Actuel | 5 ans | Action |
|---|---:|---:|---|
| ticket_line | 65.5M | **248M** | ✅ partitionné (RANGE month + LIST site) |
| transfer_line | 54.7M | **207M** | ✅ partitionné |
| ticket | 16.1M | **61M** | 🔜 à partitionner |
| gl_entry_line | 2.8M | **10.6M** | ✅ partitionné (RANGE year) |
| payment_history | 501K | **1.9M** | ✅ partitionné (RANGE month) |
| tt_brd_office | 228K | 864K | 🚫 pas critique |

## 🔄 Stratégie de synchronisation (Hub-and-Spoke)

| Sens | Tables | Méthode | Fréquence | Stratégie |
|---|---|---|---|---|
| Master → Boutique | `product`, `party`, `tarif` | DBLINK + outbox | NIGHTLY 02:00 | MASTER_WINS |
| Boutique → Master | `ticket`, `session`, `cash_movement` | MV FAST REFRESH | NIGHTLY 04:30 | LAST_WRITE_WINS |
| Inter-sites | `transfer_header`, `transfer_line` | DBLINK + conflict | NIGHTLY | MANUAL_REVIEW |

## 🇨🇬 Fisc Congo Brazzaville (Pointe-Noire)

- **TVA 18.9%** (CEMAC, vs UEMOA 18%)
- **CNSS** : 10% salarié + 19.5% patron
- **IRPP** : 8 tranches 0% → 35% (CGI art. 84)
- **IS 30%** + IRCM 5% dividendes
- **Patente + TFPB 5%**
- **XAF (BEAC)** — pas BCEAO

## 🐛 Deprecated patterns fixés

| Pattern | Action | Scripts |
|---|---|---|
| `CREATE INDEX` (priv) | ❌ Retiré | 00_init_schemas.sql |
| `CREATE DOMAIN` | ❌ Retiré (26ai) | 00_init_schemas.sql |
| `DECODE` | ✅ → `CASE WHEN` | 26_lot_r10_vouchers.sql |
| `EXCEPTION WHEN OTHERS THEN NULL` | ✅ + whitelist SQLCODE | 12_app_api.sql, 33_trg_invoice_overdue.sql |

## 📦 Prochaines étapes (par priorité)

1. **Pilote BZV-B01** : installation boutique moderne + ETL CSV
2. **Migration en production** : basculement progressif depuis 11g
3. **Tests utPLSQL** : couverture packages PL/SQL
4. **CI/CD GitHub Actions** : run_all_with_seeds.sh
5. **Monitoring 23ai** : vues V$SQL + alertes

## 2026-09-29 — Couche UI APEX 26.1 (amorce) + push fix compat WS
- Push `fix/ws-compat-fetch-failures` et `main` (commit 3c88dde : ORA-00942/01408/01749/00955, idempotence 53/54/56).
- Nouveau dossier `apex/` :
  - `README_APEX_26_1.md` : plan complet UI APEX 26.1 (prérequis APEX/ORDS, apps 100–500, règles de coexistence avec les WS legacy TT_*).
  - `setup/01_apex_workspace.sql` : workspace REGAL (idempotent, APP_API + schémas modules).
  - `setup/02_ords_enable_parsers.sql` : activation ORDS via ORDS_METADATA.ENABLE_ORDS (fallback CLI si ORDS absent).
  - `setup/03_apex_auth_setup.sql` : pkg_apex_auth (auth sur app_sys.sys_user, rôles sys_user_role, sites via sys_user_access, audit sys_audit_trail, grant DBMS_CRYPTO).
  - `apps/import_app.sql`, `SPEC_app100_pos.md`, `SPEC_app500_admin.md`.
