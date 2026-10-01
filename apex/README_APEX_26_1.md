# REGAL ERP — Interface Oracle APEX 26.1

> Suite du projet `erp-db-23ai` : le noyau base de données (scripts 00→57, hub-spoke,
> outbox/CDC, partitionnement 23ai) est en place et compatible avec les anciens
> scripts WS legacy (`KERNEL.TT_*`, `CAISSE.*`, `XCPTA.*` → schémas `APP_*`).
> Ce dossier couvre la **couche UI APEX 26.1** — 11 scripts de setup + 5 apps.
>
> **🎯 État APEX 26.1 (2026-10-01)** : 11/11 scripts setup + 5/5 apps spec.
> Setup couvre : workspace, ORDS, auth, vues, branding LITOKO, **LOVs, authorizations,
> nav menus, PDF reports, locale Congo**.

---

## 1. Prérequis

| Composant | Version | Vérification |
|---|---|---|
| Oracle DB | 23ai Free (PDB `FREEPDB1`) | `SELECT version FROM v$instance;` |
| APEX | 26.1+ | schéma `APEX_xxxxxxx` présent dans le CDB/PDB |
| ORDS | 25.x+ (Tomcat ou standalone) | page `/ords/health` |
| Workspace admin | `ADMIN` par défaut après install | http://host:8080/apex/apex_admin |

Si APEX n'est pas encore installé sur 23ai :

```bash
cd apex_261/apex
sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba @apexins.sql SYSAUX SYSAUX TEMP /i/
sqlplus sys/oracle@localhost:1521/FREEPDB1 as sysdba @apex_rest_config.sql
```

Puis ORDS (mode standalone simplifié pour le dev) :

```bash
java -jar ords.war simple --db-hostname localhost --db-port 1521 \
     --db-servicename FREEPDB1 --repository-user ORDS --port 8080
```

## 2. Configuration de l'environnement APEX

Scripts PL/SQL à jouer dans l'ordre (connecté en `SYS as sysdba` sur `FREEPDB1`) :

| Étape | Fichier | Rôle |
|---|---|---|
| 1 | `setup/01_apex_workspace.sql` | Crée le workspace **REGAL** (schéma principal `APP_API` + groupes `APP_SALES`, `APP_INV`, `APP_GL`, `APP_SYS`), tablespace, quotas, privilèges REST |
| 2 | `setup/02_ords_enable_parsers.sql` | Active ORDS sur les schémas APP_* (URL mapping `/ords/regal/...`) |
| 3 | `setup/03_apex_auth_setup.sql` | Comptes/rôles applicatifs REGAL_* pour le schéma d'authentification |
| 4 | `setup/04_apex_components.sql` | 12 vues métier partagées + fonction `regal_split` (CSV → table pour filtres APEX) |
| 5 | `setup/05_apex_litoko_branding.sql` | Branding LITOKO SARL : logo SVG, thème CSS (couleurs Congo), JS utilitaires |
| 6 | `setup/06_apex_components_fix.sql` | **FIX** des 12 vues (colonnes réelles : PK composite `pos_session`, `pos_code` au lieu de `city`) |
| 7 | `setup/07_apex_lovs.sql` | **11 Listes de valeurs (LOV) partagées** : sites, warehouses, POS, products, parties, GL accounts, payment methods, IRPP CG, VAT CG, CEMAC countries, doc types |
| 8 | `setup/08_apex_authorizations.sql` | **6 rôles APEX** (CAISSIER, VENDEUR, MANAGER, COMPTABLE, ADMIN, SUPERADMIN) + `pkg_apex_auth_v2` |
| 9 | `setup/09_apex_nav_menus.sql` | **5 menus hiérarchiques** (33 entrées) pour les 5 apps + vue CONNECT BY |
| 10 | `setup/10_apex_pdf_reports.sql` | **6 templates PDF** (Ticket 80mm, Facture A4, BL A5, Z caisse, TVA CG, bulletin paie) |
| 11 | `setup/11_apex_congo_locale.sql` | **Locale Congo Brazzaville** (XAF, fr_CG, Africa/Brazzaville, TVA 18.9%) + CSS mobile + `apex_messages_v` i18n |

Exécution globale :
```bash
cd /workspace/erp-db-23ai
./scripts/run_apex_setup.sh
```

### 2.1 Tables de référence APEX

| Table | Rôle | Source |
|---|---|---|
| `app_api.apex_static_file` | Stockage logo / CSS / JS (équivalent Static App Files) | `setup/05_litoko_branding.sql` |
| `app_api.apex_lov` | 11 LOVs (clé + SQL query) | `setup/07_apex_lovs.sql` |
| `app_sys.sys_role` + `sys_user_role` | 6 rôles REGAL + affectations par site | `setup/08_apex_authorizations.sql` |
| `app_api.apex_nav_menu` | 5 menus (33 entrées) | `setup/09_apex_nav_menus.sql` |
| `app_api.apex_report_template` | 6 templates PDF | `setup/10_apex_pdf_reports.sql` |
| `app_api.apex_locale_config` | 17 paramètres locale (XAF, fr_CG, Africa/Brazzaville) | `setup/11_apex_congo_locale.sql` |

### 2.2 Packages helpers APEX

| Package | Fonctions clés | Source |
|---|---|---|
| `app_sys.pkg_apex_auth` | `authenticate(user, pw)` (PBKDF2) | `setup/03_apex_auth_setup.sql` |
| `app_sys.pkg_apex_auth_v2` | `has_role`, `has_any_role`, `user_sites`, `user_role_level` | `setup/08_apex_authorizations.sql` |
| `app_api.apex_lov_api` | `get_lov_sql`, `lov_exists` | `setup/07_apex_lovs.sql` |
| `app_api.apex_report_api` | `get_query`, `get_layout`, `get_format` | `setup/10_apex_pdf_reports.sql` |

### 2.3 Vues APEX-ready

| Vue | Source | Utilisation |
|---|---|---|
| `app_api.v_pos_session_kpi` | `setup/06_apex_components_fix.sql` | Sessions caisse (PK composite) |
| `app_api.v_today_sales` | idem | CA jour par terminal |
| `app_api.v_inv_stock_kpi` | idem | Stock par site avec valeur XAF |
| `app_api.v_transfer_pipeline` | idem | Pipeline transferts cross-type |
| `app_api.v_gl_account_balance` | idem | Soldes comptes OHADA |
| `app_api.v_general_ledger` | idem | Grand livre (jointure composite) |
| `app_api.v_supplier_otd` | idem | Fournisseurs OTD |
| `app_api.apex_nav_menu_v` | `setup/09_apex_nav_menus.sql` | Menu hiérarchique CONNECT BY |
| `app_api.apex_messages_v` | `setup/11_apex_congo_locale.sql` | Lookup i18n FR/EN |
| `app_api.apex_locale_v` | idem | Paramètres locale |

## 3. Applications APEX par module

| App | Module | Schéma | Spec | Pages clés |
|---|---|---|---|---|
| 100 | **POS / Ventes** (caisse LITOKO) | `APP_SALES` via synonymes `APP_API` | `apps/SPEC_app100_pos.md` | Ticket live, encaissement multi-modes, Z de caisse, formats tickets (`pos_format`) |
| 200 | **Stock hub-spoke** | `APP_INV` | `apps/SPEC_app200_stock.md` | Transferts Master→Boutiques (`v_tt_pending`), mouvements, inventaires, alertes stock |
| 300 | **Achats & Fournisseurs** | `APP_PURCHASE` | `apps/SPEC_app300_achats.md` | Commandes, réception 3-way match, articles fournisseurs (`supplier_product`, ex-`GCPFRNART`) |
| 400 | **Comptabilité OHADA** | `APP_GL` | `apps/SPEC_app400_compta.md` | Écritures (`gl_entry_line_v2` partitionné), lettrage, déclarations fiscales Congo CEMAC, grand livre |
| 500 | **Administration système** | `APP_SYS` | `apps/SPEC_app500_admin.md` | Outbox/CDC (`outbox_event`), jobs, i18n (`sys_message*`), sécurité PC/dépôt (`warehouse_pc_auth`) |

Les fichiers `SPEC_app*.md` décrivent les pages, mais ne sont pas des exports
importables. Après avoir créé/exporté une application depuis APEX au format SQL,
importer son fichier avec :

```bash
export APEX_DB_CONNECT='sys@localhost:1521/FREEPDB1 as sysdba'
scripts/import_apex_app.sh 100 /chemin/vers/f100.sql
```

L’importateur limite les IDs à 100, 200, 300, 400 et 500, cible le workspace
`REGAL`, puis vérifie que l’application est présente dans ce workspace.
Les exports SQL ne sont pas encore versionnés dans `apex/apps/`.

### 3.1 Vues & fonctions partagées (`setup/04`)

12 vues métier réutilisables par toutes les apps :

| Vue | Module | Usage APEX |
|---|---|---|
| `v_inv_stock_kpi` | Stock | Dashboard 200 |
| `v_transfer_pipeline` | Stock | Wizard 200 (transferts en cours) |
| `v_pos_session_kpi` | POS | Sessions actives 100 |
| `v_today_sales` | POS | CA du jour 100 |
| `v_gl_account_balance` | Compta | Soldes par compte 400 |
| `v_general_ledger` | Compta | Grand livre 400 |
| `v_trial_balance` | Compta | Balance 400 |
| `v_cg_tax_due` | Compta Congo | TVA CEMAC 18.9% 400 |
| `v_supplier_otd` | Achats | On-Time Delivery 300 |
| `v_three_way_match` | Achats | 3-way match BL/Cmd/Fact 300 |
| `v_imm_progress` | Compta | Amortissement immo 400 |
| `v_cnss_charges` | RH Congo | Charges CNSS LITOKO 400 |

### 3.2 Branding LITOKO SARL (`setup/05`)

- **Logo SVG** : bleu Congo (#0F4C81) + or (#D4AF37), 240×80
- **Thème CSS** : variables CSS couleurs drapeau Congo, responsive mobile (Pointe-Noire)
- **JS utilitaires** : `litFormatXAF()` (séparateur espace + FCFA), `litBadgeStatus()` (8 statuts transferts), `litFilterSites()` (filtre sites via `pkg_apex_auth`)
- **Badges statut** : DRAFT (gris), REQUESTED (bleu), APPROVED (vert), PACKED (jaune), IN_TRANSIT (orange), RECEIVED/CLOSED (vert), CANCELLED (rouge)

## 4. Composants natifs APEX 26.1 utilisés

- **Interactive Grid** sur les lignes de ticket / écritures (édition inline, DML via `pkg_sales`/`pkg_gl`).
- **JSON Duality Views** (script 12) exposées via ORDS pour l'app mobile hors-ligne des boutiques.
- **Authorization Schemes** basés sur les rôles `REGAL_CAISSIER`, `REGAL_MAGASINIER`, `REGAL_COMPTABLE`, `REGAL_ADMIN`.
- **APEX_EXEC** pour les appels packages (Z de caisse, clôture de session).
- **Faceted Search** sur le catalogue produits.
- **IG saved reports** pour les états de transfert Master→Boutiques.

## 5. Intégration legacy WS (règle de compatibilité)

Les anciens écrans WS lisent/écrivent les tables `TT_*` et packages legacy. Pour que
l'UI APEX et les WS coexistent sans casser :

1. Les écrans APEX n'écrivent **jamais** directement dans `TT_*` : ils passent par
   `pkg_transfer_stock` / triggers outbox ; le CDC alimente `TT_*` côté boutique.
2. Toute vue/livrable APEX s'appuie sur les vues `*_V2` (script 56) qui mappent
   l'ancien modèle (`CETICKET`, `GCBRDD`, `CP_ECR_GEN`) vers le nouveau (`ticket`,
   `transfer_line`, `gl_entry_line`).
3. Le script `53_legacy_gap_filler.sql` doit être joué **avant** `54_partition…`
   (sinon l'index `payment_history` est skippé proprement — corrigé commit `3c88dde`).

## 6. Ordre d'exécution complet (base neuve)

```text
00→51  socle + hub-spoke              (déjà validé)
52_sync_framework                      OK
53_legacy_gap_filler                   OK (21 tables + v_tt_pending)
54_partition_tables_volumineuses       OK après fix 3c88dde (ORA-00942/01408 gérés)
55_pkg_etl_legacy_v2
56_partition_effectives                OK après fix 3c88dde (idempotent, grants self-schema retirés)
57_etl_legacy_csv
apex/setup/01→03                       workspace + ORDS + auth
apex/apps/*                            import des applications 100..500
```

## 7. Roadmap UI

- [ ] Sprint 1 : App 500 (admin/outbox) — faible risque, valide le workspace.
- [ ] Sprint 2 : App 200 stock hub-spoke + écran `v_tt_pending`.
- [ ] Sprint 3 : App 100 POS (critique, tests parallèles avec WS legacy).
- [ ] Sprint 4 : App 400 OHADA + déclarations Congo (script 49).
- [ ] Sprint 5 : App 300 achats/fournisseurs + promotions/loyauté (lots R1–R14).
