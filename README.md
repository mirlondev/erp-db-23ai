# 🏛️ erp-db-23ai — Migration ERP Oracle 11g → 23ai/26ai Free + APEX 26.1

> **REGAL** : ERP retail multi-sites du Congo Brazzaville (Pointe-Noire)
> Migration 391 tables legacy (6 schémas) → Oracle 23ai/26ai Free + **APEX 26.1 UI**

[![Legacy coverage](https://img.shields.io/badge/legacy%20coverage-not%20measured-lightgrey)] [![Schemas](https://img.shields.io/badge/schemas-17-blue)] [![APEX](https://img.shields.io/badge/APEX-26.1-red)]

## ⚡ Quickstart

```bash
# Prérequis : Oracle 23ai Free + APEX 26.1, SQLcl
cd /home/oracle/erp-db-23ai

# Rebuild destructif : sauvegarder la base avant de confirmer.
ALLOW_DESTRUCTIVE_RESET=YES ./scripts/run_all.sh

# DDL + seeds + chargement CSV + validation (supprime/recrée APP_*).
ALLOW_DESTRUCTIVE_RESET=YES ./scripts/run_all_with_seeds.sh

# 3. APEX : workspace REGAL + ORDS + auth
sqlplus sys/oracle@FREEPDB1 as sysdba @apex/setup/01_apex_workspace.sql
sqlplus sys/oracle@FREEPDB1 as sysdba @apex/setup/02_ords_enable_parsers.sql
sqlplus app_sys/AppSys#2026 @apex/setup/03_apex_auth_setup.sql
sqlplus app_api/AppApi#2026 @apex/setup/04_apex_components.sql
sqlplus app_api/AppApi#2026 @apex/setup/05_apex_litoko_branding.sql

# 4. APEX IDE : App Builder → Import des apps 100..500
```

## 📊 État du projet (au 2026-09-30)

| | Valeur | Évolution |
|---|---:|---:|
| Scripts SQL | **62** | 0 → 62 |
| Tables du modèle cible | **~195** | 0 → 195 |
| Schémas APP_* | **17** | 0 → 17 |
| Packages PL/SQL | **9** (+ `pkg_apex_auth`) | 0 → 9 |
| Triggers CDC | **3** | nouveau |
| Triggers métier | **6** | nouveau |
| Mat. Views | **3** | nouveau |
| Duality Views | **5** | nouveau |
| Schedulers | **5** | nouveau |
| Sites REGAL | **7** | nouveau |
| Seeds | **40** | nouveau |
| Tables partitionnées | **4** | nouveau |
| Tables externes (ETL) | **6** | nouveau |
| **APEX 26.1 apps** | **5 specs + 12 vues partagées** | nouveau |
| Deprecated 26ai fixes | **4 patterns** | 0 → 4 |
| **Couverture des données legacy** | **Non mesurée** | Inventaire source/cible à établir |

## 🏛️ Schémas (17)

| Schéma | Rôle |
|---|---|
| `app_sys` | Noyau : users, fiscal CG, sites, outbox, messages i18n |
| `app_org` | Société, dépôts, points de vente, régions |
| `app_product` | Catalogue, marques, promotions POS, unités par région |
| `app_party` | Tiers (clients, fournisseurs, employés, loyauté) |
| `app_inv` | Stock, lots, DLC, transferts (incl. partitionné) |
| `app_doc` | Documents commerciaux |
| `app_pos` | Terminaux, sessions, formats tickets LITOKO |
| `app_sales` | Tickets (incl. ticket_line_v2 partitionné) |
| `app_gl` | Compta OHADA, immobilisations, déclarations (incl. gl_entry_line_v2) |
| `app_cash` | Caisses & mouvements |
| `app_hist` | Archivage |
| `app_api` | Duality Views + ETL |
| `app_ar` | Accounts Receivable, échéances, litiges (incl. payment_history_v2) |
| `app_ship` | Expéditions (figé) |
| `app_purchase` | Achats, articles fournisseurs |
| `app_hr` | RH/Paie, CNSS Congo |
| `app_audit` | Audit consolidé |

## 🇨🇬 Localisation Congo Brazzaville (Pointe-Noire)

- **TVA 18.9 %** (CEMAC, vs UEMOA 18 %)
- **CNSS** : 10 % salarié + 19.5 % patron
- **IRPP** : 8 tranches progressif 0 % → 35 %
- **IS 30 %** + IRCM 5 %
- **Patente + TFPB 5 %**
- **XAF (BEAC)** — pas BCEAO
- **DGID** (Direction Générale des Impôts et des Domaines)
- **Centres d'impôts** : Brazzaville, Pointe-Noire, Dolisie, Nkayi, Oyo, Impfondo, Sibiti
- **Sites REGAL** : Siège PNR-OFC (master) + 4 boutiques + 2 dépôts

## 🌐 Architecture Hub-and-Spoke

```
                ┌─────────────────────────────┐
                │  SIÈGE  PNR-OFC  (MASTER)   │
                │  Pointe-Noire                │
                │  Oracle 23ai Free            │
                │  Schémas : APP_* (17)        │
                └──┬──────────┬──────────┬────┘
                   │          │          │
              fibre 2Mb  fibre 2Mb  satellite 1Mb
              (45 ms)    (45 ms)    (120 ms)
                   │          │          │
        ┌──────────┴──┐  ┌────┴─────┐  ┌┴──────────┐
        │ PNR-B01     │  │ BZV-B01/02│  │ DLS-B01   │
        │ Oracle 21c  │  │ Oracle 21c│  │ Oracle 21c│
        └─────────────┘  └───────────┘  └───────────┘
```

**Sync** :
- Master → Boutique : produits, prix, fournisseurs (PUSH NIGHTLY 02:00)
- Boutique → Master : tickets, sessions, mouvements (PULL NIGHTLY 04:30)
- Inter-sites : transferts (BIDIRECTIONAL, MANUAL_REVIEW)

Voir [ARCHITECTURE_HUB_SPOKE.md](./ARCHITECTURE_HUB_SPOKE.md) pour le détail.

## 📈 Mapping legacy → moderne (cibles, pas un taux de migration)

Le nombre de tables et les mappings décrivent le modèle cible. Ils ne prouvent pas
que les lignes legacy ont été chargées. Les seules sources CSV actuellement traitées
par un ETL sont articles, stocks, listes/prix et tiers; leur exécution et leur
réconciliation avec la source restent à valider. Le dispatch de `GCBRDE/GCBRDD`
est explicitement non implémenté et ne doit pas être compté comme migration.

| Legacy | Lignes | Moderne |
|---|---:|---|
| `CAISSE.GCPART` | CSV présent | `app_product.product` | ETL défini, import à valider |
| `CAISSE.GCSTOCK` | CSV présent | `app_inv.inv_stock` | ETL défini, import à valider |
| `CAISSE.GCPTARIF*` | CSV présents | `app_product.prod_price_list/product_price` | ETL défini, import à valider |
| `CAISSE.GCPTIE` | CSV présent | `app_party.party` | ETL défini, import à valider |
| `CAISSE.CETICKET*`, `TRANSFERT.GCBRD*` | non mesuré | tables POS/doc/stock | ETL réel non vérifié; GCBRDD non implémenté |
| `XCPTA.CP_ECR*`, `KERNEL.UTLOG` | non mesuré | `app_gl`, `app_sys` | Mapping cible seulement |

## 🚀 Déploiement

```bash
# 1. Connexion system/oracle
sqlplus system/oracle@localhost:1521/FREEPDB1

# 2. DDL complet
@scripts/00_init_schemas.sql
@scripts/01_app_sys.sql
... (57 scripts)
@scripts/99_validation.sql

# 3. Seeds (optionnel mais recommandé)
@seed_data/S00_seed_demo_minimal.sql
... (31 seeds)
```

Ou via les scripts bash :
```bash
ALLOW_DESTRUCTIVE_RESET=YES ./scripts/run_all.sh
ALLOW_DESTRUCTIVE_RESET=YES ./scripts/run_all_with_seeds.sh
```

Le pipeline complet requiert SQLcl, `SYS AS SYSDBA`, les CSV sous `docs/` et
reconstruit les schémas `APP_*`. La validation finale échoue s’il reste un objet
APP_* invalide. Il ne faut pas exécuter le rebuild sur une base à conserver.

## ⚙️ Features Oracle 23ai exploitées

| Feature | Usage |
|---|---|
| `GENERATED ALWAYS AS IDENTITY` | PKs modernes (fin des séquences) |
| `BOOLEAN` natif | Suppression `VARCHAR2(1)` Y/N |
| `JSON Relational Duality Views` | API REST sans réécrire le modèle |
| `VECTOR(384, FLOAT32)` | Table `product_search` pour AI |
| `BLOB SecureFile` | Photos produit compressées |
| `Materialized Views FAST REFRESH` | Sync incrémentale |
| `INTERVAL PARTITION` | RANGE auto par mois |
| `SUBPARTITION BY LIST` | 8 sous-partitions par site |
| `Outbox pattern` | Sync Master → Boutique transactionnel |

## 🐛 Deprecated patterns (26ai) fixés

| Pattern | Action |
|---|---|
| `CREATE INDEX` (privilege) | ❌ Retiré (n'existe pas) |
| `CREATE DOMAIN` | ❌ Retiré (déprécié 26ai) |
| `DECODE` | ✅ → `CASE WHEN` |
| `EXCEPTION WHEN OTHERS THEN NULL` | ✅ + whitelist SQLCODE |

## 📂 Structure

```
erp-db-23ai/
├── scripts/         # 57 scripts DDL
│   ├── 00_init_schemas.sql
│   ├── 01-48_*        # Modules + lots R + quick wins
│   ├── 49_congo_fiscal.sql
│   ├── 50_grants_cross_schema.sql
│   ├── 51_hub_spoke_topology.sql
│   ├── 52_sync_framework.sql
│   ├── 53_legacy_gap_filler.sql
│   ├── 54_partition_tables_volumineuses.sql
│   ├── 55_pkg_etl_legacy_v2.sql
│   ├── 56_partition_effectives.sql
│   ├── 57_etl_legacy_csv.sql
│   └── 99_validation.sql
├── apex/            # UI APEX 26.1
│   ├── README_APEX_26_1.md
│   ├── setup/
│   │   ├── 01_apex_workspace.sql       (workspace REGAL)
│   │   ├── 02_ords_enable_parsers.sql  (ORDS sur APP_*)
│   │   ├── 03_apex_auth_setup.sql      (pkg_apex_auth)
│   │   ├── 04_apex_components.sql      (12 vues partagées)
│   │   └── 05_apex_litoko_branding.sql (logo/CSS/JS)
│   └── apps/
│       ├── SPEC_app100_pos.md          (POS/Ventes)
│       ├── SPEC_app200_stock.md        (Stock hub-spoke)
│       ├── SPEC_app300_achats.md       (Achats/Fournisseurs)
│       ├── SPEC_app400_compta.md       (Compta OHADA + Fiscal CG)
│       ├── SPEC_app500_admin.md        (Admin système)
│       └── import_app.sql              (helper import)
├── seed_data/       # 40 fichiers de seed
├── docs/            # CSV legacy REGAL + docs
├── old-office/      # Architecture legacy complète
├── ARCHITECTURE_HUB_SPOKE.md
├── CHANGELOG.md
├── DOC.md
├── README.md
├── STATUS.md
├── erp-old-oracle-11g.json
└── procedure.txt
```

## 📚 Documentation

- [CHANGELOG.md](./CHANGELOG.md) : historique des versions
- [DOC.md](./DOC.md) : documentation technique complète
- [ARCHITECTURE_HUB_SPOKE.md](./ARCHITECTURE_HUB_SPOKE.md) : architecture multi-sites REGAL
- [STATUS.md](./STATUS.md) : état du projet vs legacy

## ⚠️ Sécurité

Les **Personal Access Tokens** GitHub sont régulièrement révoqués. Si vous voyez un token dans le chat, révoquez-le sur https://github.com/settings/tokens.
