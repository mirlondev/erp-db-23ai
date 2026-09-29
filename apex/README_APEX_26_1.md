# REGAL ERP — Interface Oracle APEX 26.1

> Suite du projet `erp-db-23ai` : le noyau base de données (scripts 00→57, hub-spoke,
> outbox/CDC, partitionnement 23ai) est en place et compatible avec les anciens
> scripts WS legacy (`KERNEL.TT_*`, `CAISSE.*`, `XCPTA.*` → schémas `APP_*`).
> Ce dossier couvre la **couche UI APEX 26.1**.

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

## 3. Applications APEX par module

| App | Module | Schéma | Pages clés |
|---|---|---|---|
| 100 | **POS / Ventes** (caisse LITOKO) | `APP_SALES` via synonymes `APP_API` | Ticket live, encaissement multi-modes, Z de caisse, formats tickets (`pos_format`) |
| 200 | **Stock hub-spoke** | `APP_INV` | Transferts Master→Boutiques (`v_tt_pending`), mouvements, inventaires, alertes stock |
| 300 | **Achats & Fournisseurs** | `APP_PURCHASE` | Commandes, réception, articles fournisseurs (`supplier_product`, ex-`GCPFRNART`) |
| 400 | **Comptabilité OHADA** | `APP_GL` | Écritures (`gl_entry_line` partitionné), lettrage, déclarations fiscales Congo, grand livre |
| 500 | **Administration système** | `APP_SYS` | Outbox/CDC (`outbox_event`), jobs, i18n (`sys_message*`), sécurité PC/dépôt (`warehouse_pc_auth`) |

Chaque application = un fichier d'export APEX dans `apps/` (généré depuis l'IDE),
importable via l'IDE (*App Builder → Import*) ou en ligne de commande.

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
