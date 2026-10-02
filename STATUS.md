# 📊 STATUS — État du projet erp-db-23ai

> Dernière mise à jour : 2026-10-01 — audit des runners, ETL CSV et cohérence legacy
> **⚠️ Note** : seed_data S23-S31 référençaient des codes inventés (DEP01/POS01).
> DEP01/DEP02 sont maintenant créés par **S32_re_seed_real_codes.sql** + tous
> les seeds sont re-exécutés avec les VRAIS codes (W90, CAI01, CAI02, ...).
> Scripts de correction batch : `55c`, `56b`, `57b`, `apex/setup/06`, `S32`.
> Contexte : Migration ERP REGAL (Congo Brazzaville) Oracle 11g → 23ai/26ai Free + APEX 26.1 UI

## 🎯 Résumé exécutif

| | Valeur | % |
|---|---:|---:|
| Tables du modèle cible | **~195** | la couverture de lignes legacy n'est pas mesurée |
| Schémas APP_* | **17** | cible 17 |
| Scripts DDL | **64** (60 + 55b/55c/56b/57b + apex 07/08/09/10/11) | - |
| Seeds | **32** (S01-S31 + S32 re-seed) | - |
| Packages PL/SQL | **9** (+ `pkg_apex_auth`) | - |
| Triggers | **9** | - |
| Tables partitionnées | **4** | - |
| Tables externes ETL | **6** | - |
| **APEX 26.1** | **5 spécifications**; exports SQL d'applications absents | setup à valider |
| Sites REGAL mappés | **7** | - |

## 📈 État de la migration des données legacy

| Legacy | Tables | Cible | Statut |
|---|---:|---:|---|
| **CSV CAISSE** articles/stock/prix/tiers | snapshots dans `docs/` | ETL défini | chargement et rapprochement à exécuter |
| **CAISSE** tickets/documents | nombreuses tables | cibles définies | ETL réel à vérifier |
| **TRANSFERT** GCBRDE/GCBRDD | volume annoncé dans l’inventaire legacy | cibles définies | dispatcher réel non implémenté |
| **XCPTA** écritures/analytique | volume à mesurer | `app_gl` | ETL et réconciliation à vérifier |
| **KERNEL/CASH/XAPP_BI** | inventaire à vérifier | plusieurs cibles | taux non établi |

**Couverture réelle : non mesurée.** Les nombres de schémas et tables décrivent le
modèle cible, pas des lignes importées. Les anciens pourcentages ont été retirés
faute de rapport de rapprochement source/cible reproductible.

## 🏛️ Schémas modernes (17)

| Schéma | Tables | Rôle | Statut |
|---|---:|---|---|
| `app_sys` | 30 | Noyau, fiscal CG, sites, outbox | ✅ |
| `app_org` | 6 | Société, dépôts, POS | ✅ |
| `app_product` | 8 | Catalogue, marques, promos, unités par région | ✅ |
| `app_party` | 5 | Tiers, loyauté | ✅ |
| `app_inv` | 15 | Stock, lots, transferts (partitionné) | ✅ |
| `app_doc` | 5 | Documents | ✅ |
| `app_pos` | 8 | POS, sessions, formats tickets, auth PC | ✅ |
| `app_sales` | 4 | Tickets (partitionné) | ✅ |
| `app_gl` | 18 | OHADA, immobilisations, fiscal CG (partitionné) | ✅ |
| `app_cash` | 5 | Caisses | ✅ |
| `app_hist` | 3 | Archivage | ✅ |
| `app_api` | 5 | Duality Views, ETL | ✅ |
| `app_ar` | 8 | AR, échéances, litiges (partitionné) | ✅ |
| `app_ship` | 7 | Expéditions | 🟡 (figé) |
| `app_purchase` | 4 | Achats, articles fournisseurs | ✅ |
| `app_hr` | 5 | RH/Paie Congo | ✅ |
| `app_audit` | 0+ | Audit consolidé | 🆕 |

## 🇨🇬 Fisc Congo Brazzaville (CEMAC) — modèle et scripts présents

- ✅ **TVA 18.9%** (vs UEMOA 18%)
- ✅ **CNSS** 10% salarié + 19.5% patron
- ✅ **IRPP** 8 tranches 0%-35% + fonction `fn_cg_irpp()`
- ✅ **IS 30%** + IRCM 5% dividendes
- ✅ **Patente** + TFPB 5%
- ✅ **DGID** centres : BZV, PNR, DLS, NKY, OYO, IMP, SIB
- ✅ **XAF (BEAC)** devise

## 🌐 Architecture multi-sites — modèle et scripts présents; sync réelle à valider

- ✅ **7 sites** : PNR-OFC (master), 4 boutiques, 2 dépôts
- ✅ **Topologie réseau** : latence, bande passante, fiabilité
- ✅ **Outbox pattern** : events transactionnels CDC
- 🟡 **pkg_sync_hub** + **pkg_sync_boutique** : packages présents; publication intersite réelle non validée
- ✅ **3 stratégies sync** : MASTER_WINS, LAST_WRITE_WINS, MANUAL_REVIEW
- 🟡 **DBMS_SCHEDULER** : job défini; exécution réelle à valider
- ✅ **Triggers CDC** sur `app_product.product`

## 🚀 Performance & partitionnement

- ✅ **4 tables partitionnées** : `ticket_line_v2`, `transfer_line_v2`, `gl_entry_line_v2`, `payment_history_v2`
- ✅ **Stratégie RANGE + LIST** : RANGE par mois + LIST par site (8 sous-partitions)
- ✅ **JOB_PARTITION_MAINT** : drop auto partitions > 36 mois
- ✅ **fn_predict_growth()** : projection volumétrie 5 ans

## 📊 Projection volumétrique (estimation, non issue d'un import validé)

| Table | Actuel | 5 ans |
|---|---:|---:|
| ticket_line | 65.5M | **248M** |
| transfer_line | 54.7M | **207M** |
| ticket | 16.1M | **61M** |
| gl_entry_line | 2.8M | **10.6M** |
| payment_history | 501K | **1.9M** |

## 🎯 APEX 26.1 — 11 scripts setup (commit 9e61bc9)

| # | Script | Contenu |
|---|---|---|
| 01 | workspace REGAL | Schéma APP_API, groupes APP_SALES/INV/GL/SYS, ORDS enable |
| 02 | ORDS parsers | JSON/CSV/SOAP/WSS sur schémas APP_* |
| 03 | auth setup | `pkg_apex_auth` (SHA-256 selon le seed actuel), rôles REGAL_* |
| 04 | components | 12 vues métier partagées (1ère version — cassée) |
| 05 | LITOKO branding | Logo SVG, CSS Congo, JS utils (`apex_static_file`) |
| 06 | **FIX components** | 7 vues recréées (PK composite pos_session, etc.) |
| **07** | **LOVs** | **11 Listes de valeurs partagées** + `apex_lov_api` |
| **08** | **Authorizations** | **6 rôles REGAL** + `sys_role`/`sys_user_role` + `pkg_apex_auth_v2` |
| **09** | **Nav menus** | **5 menus (33 entrées)** + `apex_nav_menu_v` CONNECT BY |
| **10** | **PDF reports** | **6 templates** (Ticket 80mm, Facture A4, BL A5, Z caisse, TVA CG, paie LITOKO) |
| **11** | **Locale Congo** | fr_CG, XAF, Africa/Brazzaville, CSS mobile 768px, `apex_messages_v` i18n |

Apps métier (specs) :
- **App 100 POS/Ventes** — caisse LITOKO, sessions, Z, formats tickets
- **App 200 Stock** — hub-spoke, transferts, inventaires, alertes
- **App 300 Achats** — BC, réceptions, fournisseurs, OTD
- **App 400 Compta** — OHADA, écritures, fiscal CG (TVA 18.9%, IS), immos
- **App 500 Admin** — users, rôles, sites, ETL, audit

## 🩹 Patch de cohérence (commit 687a40e)

Les 5 bugs remontés ont été corrigés :

| Bug | Fichier cassé | Fix |
|---|---|---|
| `v_pos_session_kpi` : `s.session_id`, `s.status`, `t.city` | `apex/setup/04` | `apex/setup/06_apex_components_fix.sql` (7 vues) |
| `ticket_line_v2` FK vers `ticket(ticket_id)` (PK composite) | `56_partition_effectives` | `scripts/56b_partition_fix.sql` (drop+recreate sans FK) |
| `gl_entry_line_v2` : ORA-14761 MAXVALUE + INTERVAL | `56_partition_effectives` | `scripts/56b_partition_fix.sql` (RANGE simple) |
| `fn_partition_info` BYTES dans all_tab_partitions | `56_partition_effectives` | `scripts/56b_partition_fix.sql` (dba_segments) |
| `product.COMPANY_CODE`, `party.IS_ACTIVE`, `product_price.VALID_FROM` | `57_etl_legacy_csv` | `scripts/57b_etl_legacy_csv_fix.sql` v2 (MERGE + END LOOP + GRANTs + email) |
| PLS-00364 (utilisation `R` index), ORA-00942 tables absentes | `55b_pkg_etl_legacy_v2_fix` | `scripts/55c_pkg_etl_legacy_v3.sql` v3.1 (SQL runtime) |
| ORA-00942 `caisse.gcbrdd` à la compilation, FK gl_entry invalide, CASE dans EXECUTE IMMEDIATE | `56b_partition_fix`, `55c` | `scripts/55c_v3.1` (runtime SQL), `scripts/56b_v2` (DROP statique, FK conforme) |
| Seeds S23-S31 : codes inventés DEP01/POS01 | `seed_data/S23-S31` | `seed_data/S32_re_seed_real_codes.sql` (DEP01/02 créés, re-seed) |

## 🐛 Deprecated patterns (26ai) — Tous fixés

| Pattern | Action | Script |
|---|---|---|
| `CREATE INDEX` (priv) | ❌ Retiré | `00_init_schemas.sql` |
| `CREATE DOMAIN` | ❌ Retiré | `00_init_schemas.sql` |
| `DECODE` | ✅ `CASE WHEN` | `26_lot_r10_vouchers.sql` |
| `EXCEPTION WHEN OTHERS THEN NULL` | ✅ + whitelist SQLCODE | `12_app_api.sql`, `33_trg_invoice_overdue.sql` |
| `ALTER SESSION SET CONTAINER` (CDB-only) | ✅ Toléré | `00_init_schemas.sql` |

## 🟡 Modules modélisés; validation fonctionnelle de bout en bout en cours

- 🟡 **Catalogue produits** : cible `app_product.product`; snapshot CSV présent : 786 articles, import non vérifié
- 🟡 **Stock** : snapshot CSV présent : 1 033 lignes, import non vérifié; transfert multi-sites à valider
- 🟡 **POS, facturation, paie et fiscal CG** : schémas/packages présents; tests de bout en bout à faire
- 🟡 **Topologie** : 7 sites définis; synchronisation distante réelle non implémentée/validée
- 🟡 **ETL CSV** : chargement défini pour articles, stocks, prix et tiers; exécution/réconciliation à valider
- 🔴 **ETL GCBRDD** : aucun mapping de lignes exécuté; le script refuse maintenant le faux statut `DONE`

## 🟠 À compléter (moyen terme)

| Module | Cible | Effort |
|---|---|---|
| ETL GCBRDD 54.7M (lignes par CODTBRD) | dispatch 9 types | 2-3 jours |
| Tickets en masse depuis 21c XE (boutiques) | ETL | 3-5 jours/site |
| Pilot BZV-B01 (1 boutique) | déploiement complet | 1 semaine |
| Comptabilité XCPTA (manque 50 tables) | modules OHADA avancés | 2-3 semaines |
| Sécurité VPD / RLS (multi-tenant) | row-level security | 1 semaine |

## 🔴 Long terme (post-pilote)

| Tâche | Effort | Valeur |
|---|---|---|
| CI/CD GitHub Actions | 1 semaine | ⭐⭐⭐ |
| Tests utPLSQL | 2 semaines | ⭐⭐⭐ |
| Migration Discoverer → Dashboards modernes | 1 semaine | ⭐⭐ |
| Mode dégradé (boutique autonome) | 1 semaine | ⭐⭐⭐ |
| Oracle GoldenGate (CDC temps réel) | 3 jours (licence) | ⭐⭐⭐⭐ |

## ✅ Conclusion

**Le taux de migration des données n'est pas encore mesuré.** Le dépôt contient un
modèle cible et des scripts de migration, mais les erreurs de compilation observées
sur la base et l'absence de dispatcher GCBRDD empêchent d'affirmer que les modules
sont opérationnels de bout en bout. Le pipeline protégé exige désormais un opt-in
explicite avant de supprimer/recréer les schémas.

**Le prochain jalon** est la **migration pilote d'une boutique** (BZV-B01) en conditions réelles, puis l'industrialisation avec CI/CD + tests automatisés.
