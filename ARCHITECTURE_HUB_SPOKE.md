# 🏛️ Architecture Hub-and-Spoke REGAL — Modernisation 11g → 23ai

## 📋 Contexte legacy (Oracle 11g / 21c XE)

L'ERP **REGAL** (gestion commerciale du Congo) tourne sur **6 sites géographiques distribués** :

| Schéma legacy | Tables | Rôle |
|---|---:|---|
| `CAISSE` | 200 | POS, sessions, tickets, paiements, fidélité |
| `XCPTA` | 94 | Comptabilité (écritures, lettrage, balances) |
| `KERNEL` | 56 | Utilisateurs, sécurité, paramètres |
| `TRANSFERT` | 32 | Transferts inter-sites (bons de dépôt) |
| `CASH` | 8 | Caisses, gestion espèces |
| `ERP_APP` | 1 | Paramètres globaux |

**Total : 391 tables, 277 FK, 5 vues, 17 séquences, 414 synonymes.**

## 🌐 Topologie Hub-and-Spoke

```
                ┌─────────────────────────────┐
                │  SIÈGE  PNR-OFC  (MASTER)   │
                │  Pointe-Noire                │
                │  Oracle 23ai Free (modernisé)│
                │  Schémas : APP_* (17 schémas) │
                └──┬────────────┬──────────┬───┘
                   │            │          │
            fibre 2Mb     fibre 2Mb   satellite 1Mb
            (45 ms)       (45 ms)    (120 ms)
                   │            │          │
        ┌──────────┴──┐  ┌──────┴─────┐  ┌┴──────────┐
        │ PNR-B01     │  │ BZV-B01/02 │  │ DLS-B01   │
        │ Pointe-Noire│  │ Brazzaville│  │ Dolisie   │
        │ Oracle 21c  │  │ Oracle 21c │  │ Oracle 21c│
        │ CAISSE+CASH │  │ CAISSE+CASH│  │ CAISSE    │
        │ TRANSFERT   │  │ TRANSFERT  │  │ TRANSFERT │
        └──────┬──────┘  └──────┬─────┘  └────┬──────┘
               │                │             │
               └────── DEP ─────┴────── DEP ──┘
                  DEP-PNR (PNR)        DEP-BZV (BZV)
                  850 m²                320 m²
```

## 🚧 Contraintes réseau Congo Brazzaville

| Problème | Impact | Solution moderne |
|---|---|---|
| **WACS / SAT-3 sous-marin souvent coupé** | Connexions Pointe-Noire ↔ monde difficiles | Replicated DB local + sync asynchrone |
| **Satellite 1 Mbps Dolisie** | Sync lente, paquets perdus | Batch nocturne + compression + retry exponentiel |
| **Latence 120 ms Dolisie** | Real-time sync peu fiable | **Outbox pattern** + **CSV files** (legacy) |
| **Coupures fréquentes Brazzaville** | Dumps interrompus | Reprise depuis point de contrôle (sync_run) |
| **Pas de fibre dédiée** | Pas de GoldenGate possible | **DBLink** + **Materialized Views refresh FAST** |

## 🎯 Modernisation — 3 phases

### ✅ Phase 1 (déjà livrée) — Modernisation siège
- `00_init_schemas.sql` : 17 schémas APP_* créés
- Scripts 1-50 : **~165 tables modernes** créées
- Migration 11g → 23ai Free sur le siège PNR-OFC
- ETL legacy → moderne (`pkg_etl_legacy`)

### ✅ Phase 2 (nouveau) — Topologie multi-sites (S51-S52)
- **`site_master`** : registre des 7 sites REGAL
- **`site_link`** : topologie réseau (latence, bande passante)
- **`site_database`** : métadonnées BDs par site (21c XE, 23ai Free, etc.)
- **`site_sync_schedule`** : planification cron (NIGHTLY, HOURLY)
- **`site_sync_run`** : journal d'exécution (durée, rows, conflits)
- **`site_sync_conflict`** : détection de conflits (`MASTER_WINS`, `LAST_WRITE_WINS`)
- **`outbox_event`** : **Outbox pattern** (events CDC transactionnels)
- **`pkg_sync_hub`** : pousse les events vers sites distants
- **`pkg_sync_boutique`** : reçoit et applique sur boutique
- **Triggers `trg_outbox_product_***` : capture auto changements produit

### 🔜 Phase 3 (à venir) — Déploiement progressif
1. **Migration boutiques** Brazzaville (BZV-B01, BZV-B02) en premier (fibre stable)
2. **Pilote Dolisie** (DLS-B01) en satellite (1 Mbps, sync nocturne uniquement)
3. **Dépôts DEP-PNR, DEP-BZV** en parallèle (LAN rapide)
4. **Mode dégradé** : si sync échoue > 3 fois, on bascule en mode "boutique autonome"

## 🔄 Stratégie de synchronisation

### 🔹 Master → Boutiques (PUSH)
- **Tables** : `product`, `party`, `tarif`, `promo_*`
- **Méthode** : DBLINK + JSON_OBJECT + outbox event
- **Fréquence** : NIGHTLY (02:00 heure locale)
- **Stratégie** : `MASTER_WINS` (le siège a toujours raison)

### 🔹 Boutique → Master (PULL)
- **Tables** : `ticket`, `session`, `cash_movement`, `transfer_line`
- **Méthode** : DBLINK + Materialized View FAST REFRESH
- **Fréquence** : NIGHTLY (04:30 heure locale)
- **Stratégie** : `LAST_WRITE_WINS` (le dernier gagne)

### 🔹 Inter-sites (BIDIRECTIONAL)
- **Table** : `transfer_header`, `transfer_line`
- **Méthode** : DBLINK + conflict resolution
- **Fréquence** : NIGHTLY
- **Stratégie** : `MANUAL_REVIEW` (car les deux bouts modifient)

## 📊 Mapping legacy → moderne

| Legacy | Tables | Moderne | Tables | Statut |
|---|---:|---|---:|---|
| `CAISSE.CEPSESSION` | 1393 | `app_pos.pos_session` | (R3+) | ✅ migré |
| `CAISSE.CETICKET` | 66854 | `app_sales.ticket` | (R0+) | ✅ migré |
| `CAISSE.CEBON` | 1690 | `app_doc.doc_header` (BON_LIVRAISON) | (R0+) | ✅ migré |
| `CAISSE.CECFLOT` | 0 | `app_cash.cash_register` | (R10+) | ✅ migré |
| `TRANSFERT.TR_GCBRDE` | 65467 | `app_inv.transfer_header` | (R4+) | ✅ migré |
| `TRANSFERT.TR_GCBRDD` | 201508 | `app_inv.transfer_line` | (R4+) | ✅ migré |
| `TRANSFERT.TR_GCPART` | 0 | `app_product.product` | (R0+) | ✅ migré |
| `XCPTA.CP_ECR` | 55615 | `app_gl.gl_entry` | (R0+) | ✅ migré |
| `XCPTA.CP_ECR_ANA` | 44205 | `app_gl.gl_analytical_entry` | (R11+) | ✅ migré |
| `KERNEL.KEUSERS` | (?) | `app_sys.sys_user` | (R0+) | ✅ migré |
| `CASH.CASH_JOURNAL` | 8 | `app_cash.cash_journal` | (R10+) | ✅ migré |

**Couverture actuelle : 42% (165/391 tables)**
- Tables migrées : ~70 (sessions, tickets, articles, écritures, transferts, RH, OHADA, fiscal CG)
- Tables à migrer : ~50 (fidélité avancée, marketing, logistique détaillée, RH, CRM, paie)
- Tables legacy à abandonner : ~270 (doublons, obsolètes, customs)

## 🔁 Pattern Outbox — pourquoi et comment

### Problème du dual-write
Quand on fait `INSERT INTO ticket` + `INSERT INTO sync_queue`, on a 2 écritures séparées qui peuvent ne pas être atomiques.

### Solution : Outbox pattern
```sql
-- Dans une SEULE transaction
BEGIN
  INSERT INTO ticket (...) VALUES (...);     -- métier
  INSERT INTO outbox_event (                -- sync
    object_name => 'TICKET',
    operation   => 'INSERT',
    row_data    => JSON_OBJECT(...)
  );
  COMMIT;
END;
/
```

Le scheduler `JOB_SYNC_HUB_PUBLISH` pousse les `outbox_event PENDING` toutes les 30 min.

## 🎯 Quand tu auras besoin d'autre chose

- **Multi-master actif-actif** : ajouter `MERGE INTO` avec détection de vecteurs (CRDT)
- **Sync temps réel** : remplacer DBLINK par **Oracle 23ai JSON Duality Views** (auto-sync via Kafka)
- **Reprise après sinistre** : archiver `outbox_event` dans object storage OCI
- **Audit centralisé** : envoyer tous les `outbox_event` vers un ELK (Elasticsearch)

## 📚 Références modernes utilisées

- **Oracle 23ai** : BOOLEAN natif, Identity columns, JSON Relational Duality Views
- **Outbox pattern** : reliable message publishing sans 2PC
- **Materialized View FAST REFRESH** : sync incrémentale sans lock
- **JSON Duality Views** : exposition API sans réécrire le modèle (23ai)
- **DBLink** : toujours supporté, simple et efficace pour Oracle-to-Oracle
