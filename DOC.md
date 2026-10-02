# erp-db-23ai — Documentation complète

> Migration d'un ERP Oracle 11g vers Oracle 23ai / 26ai Free (FREEPDB1).
> Document de référence : architecture, schémas, fonctionnalités, déploiement, API, ETL, tests.

---

## 📚 Table des matières

1. [Vision et objectifs](#-1-vision-et-objectifs)
2. [Architecture générale](#-2-architecture-générale)
3. [Schémas déployés](#-3-schémas-déployés)
4. [Référence des tables (par schéma)](#-4-référence-des-tables-par-schéma)
5. [Mapping legacy → moderne](#-5-mapping-legacy--moderne)
6. [Features Oracle 23ai exploitées](#-6-features-oracle-23ai-exploitées)
7. [API exposées (Duality Views + vues classiques)](#-7-api-exposées-duality-views--vues-classiques)
8. [Packages PL/SQL](#-8-packages-plsql)
9. [Triggers](#-9-triggers)
10. [Vues matérialisées + jobs](#-10-vues-matérialisées--jobs)
11. [Déploiement](#-11-déploiement)
12. [Données de seed](#-12-données-de-seed)
13. [Migration legacy (ETL)](#-13-migration-legacy-etl)
14. [Catalogue KPI & alertes](#-14-catalogue-kpi--alertes)
15. [Sécurité & RBAC](#-15-sécurité--rbac)
16. [Tests & recettes SQL](#-16-tests--recettes-sql)
17. [Roadmap](#-17-roadmap)
18. [Annexes](#-18-annexes)

---

## 🎯 1. Vision et objectifs

### Problème business
Le client disposait d'un ERP Oracle 11g (~ 391 tables, 6 schémas, ~ 60 packages PL/SQL) datant du début des années 2010. Limites identifiées :

- Pas de BOOLEAN natif (codes `Y`/`N` partout)
- JSON en `VARCHAR2(4000)` ou `CLOB` non indexable
- API web impossible (pas de Duality Views)
- Aucun support embeddings / IA / vector search
- Pas de PK simple uniforme (souvent PK composées)
- Aucune séparation par domaine métier (toutes tables dans `CAISSE` ou `KERNEL`)

### Solution
Refactoring complet vers **Oracle 23ai / 26ai Free**, avec exploitation des nouvelles features :

| Feature 11g | Modernisation 23ai |
|---|---|
| Séquences + triggers INSERT | `GENERATED ALWAYS AS IDENTITY` |
| `VARCHAR2(1)` Y/N | BOOLEAN natif |
| Tables/colonnes legacy | 14 schémas métiers séparés |
| Pas d'API REST | **JSON Relational Duality Views** |
| Recherche texte simple | **`VECTOR(384, FLOAT32)`** + AI Vector Search |
| Aucune analytics live | **Matérialized Views** avec refresh horaire |

### Métriques cibles

- **Couverture des données legacy** : non mesurée; les modules décrivent le modèle cible, pas les lignes chargées
- **Performance** : latence p95 des requêtes clés < 200 ms (cible à valider sur la vraie volumétrie)
- **DX** : durée de déploiement à mesurer après un run complet réussi
- **Sécurité** : RBAC granulaire (15 actions × 9 ressources)

---

## 🏗 2. Architecture générale

### Diagramme de couches

```
┌──────────────────────────────────────────────────────────────┐
│                  Couche présentation (UI)                    │
│      (consomme Duality Views via REST ou drivers JSON)       │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│           Couche API (app_api) — Duality Views + MV         │
│                                                              │
│  dv_product            v_ticket_json       mv_hourly_sales   │
│  dv_party              v_stock_json        mv_monthly_top    │
│  dv_invoice            v_dashboard_exec    mv_cust_perf      │
│  dv_payment            v_top_kpi_dashboard                    │
│  dv_customer_credit    v_critical_stock   v_customer_balance │
│                                                              │
│  pkg_etl_legacy (migration)   kpi_definition/report_exec    │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│         Couche métier (packages PL/SQL)                     │
│                                                              │
│  pkg_pricing (app_product)  pkg_inventory (app_inv)         │
│  pkg_sales (app_sales)      pkg_gl (app_gl)                 │
│  pkg_pos_sales (app_sales)  pkg_doc (app_doc)               │
└────────────────────┬─────────────────────────────────────────┘
                     │
┌────────────────────▼─────────────────────────────────────────┐
│         Couche données (14 schémas métier)                   │
│                                                              │
│  app_sys     — noyau (users, rôles, audit, alertes, intf)   │
│  app_org     — société, dépôts, points de vente               │
│  app_product — catalogue, prix, promotions, paliers          │
│  app_party   — clients, fournisseurs, fidélité, vouchers     │
│  app_inv     — stock, lots, statuts, transferts, inventaire  │
│  app_doc     — documents commerciaux (devis→factures)         │
│  app_pos     — terminaux, sessions POS                        │
│  app_sales   — tickets, retours, remises, fidélité appliquée  │
│  app_gl      — comptabilité OHADA + analytique + budget       │
│  app_cash    — caisses, mouvements                            │
│  app_hist    — archives (cold storage)                        │
│  app_api     — Duality Views + vues JSON + ETL + KPI         │
│  app_ar      — Accounts Receivable (factures/avoirs/règlemt) │
│  app_ship    — expéditions                                    │
│  app_purchase — achats / demandes de prix                     │
└──────────────────────────────────────────────────────────────┘
```

### Pattern PK utilisé
- **PK simple (Identity)** : tables modernes créées depuis R1 → recommandé en 23ai
- **PK composite** : tables héritées du 11g (legacy `*_code + *_no`) → conservées pour la compat ETL
- Duality Views **uniquement sur PK simple** (contrainte Oracle 23ai Free)

### Pattern GRANT
- Cross-schema en **lecture** majoritairement (chaque métier ne fait que ce qui le concerne)
- Cross-schema en **écriture** pour : audit (`app_sys.sys_audit_trail`), stock (triggers de décrément), alertes
- `app_api` est la seule à avoir `INSERT/UPDATE/DELETE` sur les tables d'orchestration (interfaces, sync, exports)

---

## 📦 3. Schémas déployés

| # | Schéma | Rôle | Tables | Réf script bootstrap |
|---|---|---|---:|---|
| 1 | `app_sys` | Noyau + audit + alertes + interfaces + sécurité | ~ 25 | `00_init_schemas.sql` |
| 2 | `app_org` | Société, dépôts, points de vente | 3 | `02_app_org.sql` |
| 3 | `app_product` | Catalogue, prix, promotions, paliers, search | ~ 25 | `03_app_product.sql` + R1 + R8 |
| 4 | `app_party` | Tiers + fidélité + vouchers | ~ 18 | `04_app_party.sql` + R2 + R10 |
| 5 | `app_inv` | Stock + lots + statuts + inventaire + transferts | ~ 25 | `05_app_inv.sql` + R3 + R4 + R9 |
| 6 | `app_doc` | Documents commerciaux (devis, commandes, …) | ~ 25 | `06_app_doc.sql` + Lot 1A-1D |
| 7 | `app_pos` | Terminaux, sessions POS | ~ 5 | `07_app_pos.sql` |
| 8 | `app_sales` | Tickets, retours, remises, fidélité appliquée | ~ 12 | `08_app_sales.sql` + R7 |
| 9 | `app_gl` | Comptabilité OHADA + analytique + budget | ~ 18 | `09_app_gl.sql` + OHADA skeleton |
| 10 | `app_cash` | Caisses, mouvements | 4 | `10_app_cash.sql` |
| 11 | `app_hist` | Archives | 6 | `11_app_hist.sql` |
| 12 | `app_api` | Duality Views + JSON + ETL + KPI | ~ 15 | `12_app_api.sql` + R12 + R14 |
| 13 | `app_ar` | Accounts Receivable (factures/avoirs/règlemt) | 13 | R5 + R6 |
| 14 | `app_ship` | Expéditions | 7 | Lot 1E |
| 15 | `app_purchase` | Achats / demandes de prix | 4 | Lot 1F |

**Total** : ~ 200 tables, 50+ contraintes FK, 5+ Materialized Views, 6+ Duality Views, 6 packages.

---

## 📚 4. Référence des tables (par schéma)

### 4.1 `app_sys` — Noyau

| Table | Description | PK | Réf script |
|---|---|---|---|
| `sys_user` | Utilisateurs | `user_id` | `01_app_sys.sql` |
| `sys_access_key` | Clés d'accès applicatives | `access_key_id` | `01_app_sys.sql` |
| `sys_user_access` | Liaison user × access_key | composite | `01_app_sys.sql` |
| `sys_program` | Programmes (menus) | `program_id` | `01_app_sys.sql` |
| `sys_parameter` | Paramètres système | `parameter_id` | `01_app_sys.sql` |
| `sys_currency` | Devises (XOF, EUR, USD) | `currency_code` | `01_app_sys.sql` |
| `sys_country` | Pays | `country_code` | `01_app_sys.sql` |
| `sys_city` | Villes | `city_code` | `01_app_sys.sql` |
| `alert_type` | Référentiel alertes | `alert_type_code` | R11 |
| `alert_rule` | Règles de détection | `rule_id` | R11 |
| `alert_instance` | Alertes déclenchées | `alert_id` | R11 |
| `notification_channel` | Canaux (EMAIL/SMS/PUSH/...) | `channel_id` | R11 |
| `notification_subscription` | Abonnements user × canal × type | composite | R11 |
| `notification_queue` | File envois | `queue_id` | R11 |
| `sys_role` | Rôles RBAC | `role_code` | R13 |
| `sys_user_role` | User × role | composite | R13 |
| `sys_permission` | Permissions atomiques | `permission_code` | R13 |
| `sys_role_permission` | Matrice rôle × permission | composite | R13 |
| `sys_audit_trail` | Audit complet | `audit_id` | R13 |
| `interface_endpoint` | Endpoints API externes | `endpoint_id` | R14 |
| `interface_log` | Logs inter-systèmes | `log_id` | R14 |
| `sync_queue` | File synchro cross-system | `queue_id` | R14 |
| `import_batch` | Imports par lot | `batch_id` | R14 |
| `export_config` | Exports récurrents | `export_id` | R14 |

### 4.2 `app_product` — Catalogue (extrait)

| Table | Description | Lot |
|---|---|---|
| `prod_nature` | Natures (FINISHED, RAW) | R0 |
| `prod_category` | Catégories | R0 |
| `prod_subcategory` | Sous-catégories | R0 |
| `prod_shelf` | Rayons | R0 |
| `prod_brand` | Marques | R0 |
| `prod_price_list` | Listes de prix | R0 |
| `product` | Articles | R0 |
| `product_unit` | Unités multiples | R0 |
| `product_barcode` | Codes-barres | R0 |
| `product_price` | Prix par liste × produit | R0 |
| `product_price_hist` | Historique prix | R0 |
| `product_photo` | Photos (BLOB SecureFile) | R0 |
| `product_search` | Description + **VECTOR(384, FLOAT32)** | R0 |
| `promo_header` | Promotions catalogue | R1 |
| `promo_product` | Produits en promotion | R1 |
| `promo_quantity` | Règles BOGO / qté | R1 |
| `promo_customer_family` | Familles client ciblées | R1 |
| `promo_pos` | POS ciblés | R1 |
| `price_tier` | Paliers tarifaires | R1 |
| `price_tier_quantity` | Seuils paliers | R1 |
| `price_tier_product` | Produits paliers | R1 |
| `promo_pos_config` | Promos POS temporelles | R8 |
| `promo_pos_product` | Produits promos POS | R8 |
| `promo_pos_hours` | Plages horaires promos POS | R8 |
| `loyalty_status_config` | Niveaux fidélité (Bronze→Diamond) | R8 |
| `loyalty_status_rule` | Règles par POS | R8 |

### 4.3 `app_inv` — Stock (extrait)

| Table | Description | Lot |
|---|---|---|
| `inv_stock` | Stock par (warehouse, product) PK composite | R0 |
| `inv_stock_alert` | Alertes stock négatif | R0 |
| `inv_count_header` | Entête inventaire tournant | R0 |
| `inv_count_line` | Lignes comptage | R0 |
| `inv_movement` | Mouvements de stock | R0 |
| `inv_avg_cost` | Coût moyen pondéré (PRMP) | R3 |
| `inv_product_lot` | Lots produit (DLC) | R3 |
| `inv_status_ref` | Référentiel 8 statuts | R3 |
| `inv_stock_status` | Stock par statut | R3 |
| `inv_count_zone` | Lignes comptage zones (legacy) | R3 |
| `inv_movement_status` | Statut par mouvement (FEFO) | R3 |
| `inv_reorder` | Propositions réappro | R3 |
| `transfer_header` | Transferts inter-dépôts | R4 |
| `transfer_line` | Lignes de transfert | R4 |
| `replenishment_suggestion` | Suggestions auto | R4 |
| `purchase_order_header` | Bons de commande fournisseur | R4 |
| `purchase_order_line` | Lignes BC | R4 |
| `stock_valuation` | Snapshot valeur stock | R4 |
| `inventory_count_zone` | Zones physiques inventaire | R9 |
| `inventory_count_detail` | Double-comptage aveugle | R9 |
| `inventory_adjustment` | Ajustements post-comptage | R9 |

### 4.4 `app_ar` — Accounts Receivable (R5 + R6)

Tables créées dans R5 et R6, voir section README.md dédiée.

### 4.5-4.15 — Autres schémas

Voir le sommaire — chaque schéma suit la même logique : entête + lignes + journaux.

---

## 🔄 5. Mapping legacy → moderne

### Approche de migration

L'objectif n'est **pas** une migration 1:1 exhaustive. Les 391 tables legacy peuvent être décomposées en :

| Catégorie | Volume legacy | Action | Couvert |
|---|---:|---|---:|
| **Tables actives** (données live) | à mesurer | Migration avec mapping | non vérifié |
| **Tables d'historique** (logs, audits) | à mesurer | Migration optionnelle | non vérifié |
| **Tables obsolètes** (codes morts) | à mesurer | À supprimer avant migration | non vérifié |
| **Tables intermédiaires** (batch, ETL) | à mesurer | Réécriture propre | partiel; dispatch GCBRDD absent |

### Mapping schémas

| Legacy 11g (6 schémas) | Moderne 23ai (17 schémas cibles) | État des données |
|---|---|---|
| `CAISSE` (200 tables) | `app_pos`, `app_sales`, `app_cash`, `app_party` | ETL CSV partiel; tickets non vérifiés |
| `KERNEL` (56 tables) | `app_sys`, `app_product`, `app_org` | mapping cible; import non mesuré |
| `XCPTA` (94 tables — compta) | `app_gl` | squelette cible; ETL non vérifié |
| `TRANSFERT` (32 tables) | `app_inv` + `app_ship` | dispatcher GCBRDD non implémenté |
| `CASH` (8 tables) | `app_cash` + `app_ar` | mapping cible; import non mesuré |
| `ERP_APP` (1 table) | divers | mapping non établi |

### Mapping champs-clés (exemples)

| Legacy | Moderne | Commentaire |
|---|---|---|
| `GCARTICLE` (CAISSE) | `app_product.product` | 1:1 — pk = `product_id`, code = `product_code` |
| `GCPROMO.GCPROMO_CODE` (CAISSE) | `app_product.promo_header.promo_code` | 1:1, harmonisation VARCHAR2(12) |
| `CP_COMPTE.CP_COMPTE_NO` (XCPTA) | `app_gl.gl_account_ohada.account_code` | Direct — code OHADA officiel |
| `CP_PIECE.CP_PIECE_NO` (XCPTA) | `app_gl.gl_entry.entry_no` | 1:1 |
| `CETICKET.CETICKET_NO` (CAISSE) | `app_sales.ticket.ticket_no` | PK composite conservée |
| `GCEXPEDITION.GCEXP_NO` (CAISSE) | `app_ship.shipment.shipment_number` | 1:1 — préfixe modernisé |
| `CEPCFCARTE.CEPCF_NUMERO` (CAISSE) | `app_party.loyalty_card.card_number` | 1:1 |

### Tables obsolètes identifiées (à NE PAS migrer)

- `*_TMP`, `*_BAK`, `*_SAUV` — tables de sauvegarde
- `*_LOG` de plus de 2 ans — archiver puis supprimer
- Tables vides (COUNT = 0 sur la base de référence)

---

## ⚡ 6. Features Oracle 23ai exploitées

### 6.1 Identity columns
Toutes les nouvelles tables utilisent `GENERATED ALWAYS AS IDENTITY` (R1+). Suppression des anciennes séquences + triggers d'incrément.

```sql
CREATE TABLE invoice (
  invoice_id  NUMBER GENERATED ALWAYS AS IDENTITY,
  ...
);
```

### 6.2 BOOLEAN natif
Remplacement de `VARCHAR2(1)` Y/N par BOOLEAN 23ai natif.

```sql
-- AVANT (legacy) :
is_active VARCHAR2(1) DEFAULT 'Y'  -- CHECK IN ('Y','N')

-- APRÈS (moderne) :
is_active BOOLEAN DEFAULT TRUE
```

### 6.3 BLOB SecureFile
Photos produit avec compression + déduplication.

```sql
CREATE TABLE product_photo (
  photo BLOB
) LOB(photo) STORE AS SECUREFILE (
  COMPRESS MEDIUM  DEDUPLICATE  CACHE READS
);
```

### 6.4 VECTOR(384, FLOAT32) — AI Vector Search
Table `product_search` prête pour intégration embedding (modèles type all-MiniLM-L6-v2).

```sql
CREATE TABLE product_search (
  product_id  NUMBER PRIMARY KEY,
  description CLOB,
  embedding   VECTOR(384, FLOAT32)
);

-- Recherche sémantique :
SELECT product_name FROM product_search
ORDER BY VECTOR_DISTANCE(embedding, :query_vector)
FETCH FIRST 10 ROWS ONLY;
```

### 6.5 JSON Relational Duality Views
Exposition REST/JSON des tables sans réécrire le modèle.

```sql
CREATE JSON RELATIONAL DUALITY VIEW dv_invoice AS
  SELECT JSON {
    '_id'     : i.invoice_id,
    'number'  : i.invoice_number,
    'lines'   : [ JSON { ... } FOR il IN ... ]
  }
  FROM app_ar.invoice i
 WITH CHECK OPTION;

-- Lecture :
SELECT JSON_SERIALIZE(data PRETTY) FROM dv_invoice;

-- Écriture (23ai magic !) :
INSERT INTO dv_invoice(data) VALUES ('{"_id":999, ...}');
-- → se traduit automatiquement en INSERT dans invoice + invoice_line
```

**⚠ Limite** : les Duality Views **ne marchent PAS sur PK composites** (Oracle 23ai Free limitation). Voir `12_app_api.sql` pour le workaround avec vues classiques JSON.

### 6.6 JSON natif (vs CLOB legacy)

```sql
-- AVANT (legacy) :
payload CLOB

-- APRÈS (moderne, 23ai) :
payload JSON  -- validation auto, indexation, opérateurs JSON natifs
```

Interrogeable avec :
```sql
SELECT JSON_VALUE(payload, '$.difference') FROM pos_cash_closure;
```

### 6.7 Computed columns (GENERATED ALWAYS)

```sql
CREATE TABLE kpi_daily_snapshot (
  value         NUMBER(16,4),
  target_value  NUMBER(16,4),
  variance      NUMBER(16,4) GENERATED ALWAYS AS (value - target_value),
  achieved      BOOLEAN     GENERATED ALWAYS AS (
    CASE WHEN target_value IS NULL THEN NULL
         WHEN value >= target_value THEN TRUE
         ELSE FALSE END
  )
);
```

### 6.8 ROW STORE COMPRESS ADVANCED

Sur les Materialized Views, économie ~ 60% d'espace :

```sql
CREATE MATERIALIZED VIEW mv_hourly_sales
  ROW STORE COMPRESS ADVANCED
  BUILD IMMEDIATE
  REFRESH COMPLETE ON DEMAND
AS ...
```

### 6.9 Index partiels (WHERE)

```sql
CREATE INDEX ix_alert_open ON alert_instance(status, triggered_at)
  WHERE status = 'OPEN';  -- seulement les alertes ouvertes
```

### 6.10 BOOLEAN natif dans CHECKs

```sql
CONSTRAINT ck_alert_inst_ack
  CHECK ((status = 'ACK') = (acknowledged_at IS NOT NULL))
```

---

## 🌐 7. API exposées (Duality Views + vues classiques)

### 7.1 Duality Views (lecture/écriture JSON REST)

| View | Basée sur | Endpoint pattern |
|---|---|---|
| `dv_product` | `app_product.product` | `GET/POST/PUT /products/{id}` |
| `dv_party` | `app_party.party` | `GET/POST/PUT /customers/{id}` |
| `dv_invoice` | `app_ar.invoice` + `invoice_line` | `GET/POST /invoices/{id}` |
| `dv_payment` | `app_ar.payment` | `GET/POST /payments/{id}` |
| `dv_customer_credit` | `app_ar.customer_credit` | `GET /credit/{partyCode-companyCode}` |

### 7.2 Vues classiques JSON (workaround PK composite)

| View | Description |
|---|---|
| `v_ticket_json` | Ticket complet avec lignes + payments (PK composite) |
| `v_stock_json` | Stock par produit/dépôt |
| `v_dashboard_executive` | **16 KPI temps réel** (revenu_jour, ruptures, alerts_critical, etc.) |
| `v_top_kpi_dashboard` | Top KPI pour exécution |
| `v_critical_stock` | Stock sous le seuil (statut RUPTURE/CRITIQUE/ALERTE) |
| `v_customer_balance` | Encours clients + utilization_pct |

### 7.3 Connexion REST typique

```bash
# Lecture
curl -u user:pwd http://localhost:8080/ords/app_api/dv_product/1

# Recherche JSON
SELECT JSON_SERIALIZE(data PRETTY)
  FROM dv_product
 WHERE JSON_VALUE(data, '$.productCode') = 'ART001';

# Écriture via Duality View (INSERT magic)
INSERT INTO dv_invoice (data) VALUES (
  '{"_id":999,
    "number":"FA-2026-999",
    "date":"2026-09-30",
    "partyCode":"CLI001",
    "lines":[{"lineNo":1,"product":"ART001","quantity":2,"unitPrice":2500}]}'
);
COMMIT;
```

---

## 📦 8. Packages PL/SQL

| Package | Schéma | Fonctions | Lot |
|---|---|---|---|
| `pkg_pricing` | `app_product` | `get_price`, `get_price_ht`, `calc_tax` | R0 |
| `pkg_inventory` | `app_inv` | `get_stock`, `update_stock`, `check_availability` | R0 |
| `pkg_sales` | `app_sales` | `create_ticket`, `get_ticket_total` | R0 |
| `pkg_gl` | `app_gl` | `get_account_balance`, `get_party_balance` | R0 |
| `pkg_pos_sales` | `app_sales` | `create_ticket_with_loyalty`, `apply_best_promo`, `close_pos_session`, `cancel_ticket` | Quick win |
| `pkg_doc` | `app_doc` | `create_quote`, `convert_quote_to_order`, `validate_document`, `cancel_document`, `link_documents` | Lot 1 |
| `pkg_etl_legacy` | `app_api` | `migrate_table`, `migrate_lot`, `verify_mapping`, `get_migration_report` | ETL |

### Exemple d'usage `pkg_pos_sales`

```sql
-- Créer un ticket avec calcul auto des points
DECLARE
  v_ticket_no NUMBER;
BEGIN
  v_ticket_no := app_sales.pkg_pos_sales.create_ticket_with_loyalty(
    p_terminal_id      => 'CAI01',
    p_session_no       => 5,
    p_customer_code    => 'CLI001',
    p_loyalty_card_id  => 1,
    p_user_code        => 'CAISSIER1'
  );
  DBMS_OUTPUT.PUT_LINE('Ticket créé: ' || v_ticket_no);
END;
/

-- Clôturer une session POS avec détection d'écart
CALL app_sales.pkg_pos_sales.close_pos_session(
  p_terminal_code      => 'CAI01',
  p_session_no         => 5,
  p_actual_cash        => 234000,
  p_closed_by          => 'CAISSIER1',
  p_variance_threshold => 1000
);
-- Si |écart| > 1000, crée une alerte CASH_DRAWER_MISMATCH automatiquement
```

---

## 🎯 9. Triggers

| Trigger | Schéma | Table | Action |
|---|---|---|---|
| `trg_ticket_line_after_insert` | `app_sales` | `ticket_line` | Décrémente `app_inv.inv_stock` |
| `trg_ticket_audit` | `app_sales` | `ticket` | Update `pos_terminal.last_ticket_no` |
| `trg_product_audit` | `app_product` | `product` | Set `updated_at`, `updated_by` |
| `trg_inv_stock_alert` | `app_inv` | `inv_stock` | Si stock < 0, insert dans `inv_stock_alert` |
| `trg_doc_header_audit` | `app_doc` | `doc_header` | Insert log dans `doc_log` |
| `trg_invoice_overdue` | `app_ar` | `invoice` | Auto-update statut OVERDUE + calcul balance |

---

## 🔁 10. Vues matérialisées + jobs

### Materialized Views (3 + dashboard live)

| MV | Schéma | Refresh | Usage |
|---|---|---|---|
| `mv_hourly_sales` | `app_api` | `C` omplete ON DEMAND | CA groupé par heure/terminal |
| `mv_monthly_top_products` | `app_api` | `C` ON DEMAND | Top articles par mois (sortable DESC) |
| `mv_customer_performance` | `app_api` | `C` ON DEMAND | Synthèse RFM client |

### Jobs (3 schedulés)

| Job | Fréquence | Action |
|---|---|---|
| `JOB_REFRESH_MVIEWS` | HOURLY | Refresh des 3 MV |
| `JOB_PURGE_LOGS` | DAILY 02:00 | Purge `pos_session_log` + `doc_log` > 12-24 mois |
| `JOB_ARCHIVE_TICKETS` | MONTHLY | Archivage tickets > 24 mois (désactivé par défaut) |

---

## 🚀 11. Déploiement

### Pré-requis
- Oracle Database 23ai Free ou 26ai
- SQLcl installé; connexion `SYS AS SYSDBA` autorisée
- TNS : `localhost:1521/FREEPDB1`
- Tablespace USERS
- CSV requis présents dans `docs/`

### Déploiement complet

```bash
cd /home/oracle/erp-db-23ai
export ORACLE_CONNECT='sys/oracle@localhost:1521/FREEPDB1 as sysdba'

# Les deux runners suppriment/recréent tous les schémas APP_*.
# Sauvegarder la base avant de confirmer cette opération.
export ALLOW_DESTRUCTIVE_RESET=YES

# DDL → seeds → import CSV → validation
./scripts/run_all_with_seeds.sh

# Smoke test SQLcl
sql "$ORACLE_CONNECT"
SELECT 'app_product.product' AS t, COUNT(*) FROM app_product.product
UNION ALL SELECT 'app_sales.ticket', COUNT(*) FROM app_sales.ticket
UNION ALL SELECT 'app_gl.gl_account_ohada', COUNT(*) FROM app_gl.gl_account_ohada;
```

### Déploiement détaillé par couche

```bash
# Bootstrap destructif (supprime tous les schémas APP_*)
sql "$ORACLE_CONNECT" @scripts/00_init_schemas.sql

# Schémas métier (1-12)
@01_app_sys.sql
@02_app_org.sql
...
@12_app_api.sql

# Couche fonctionnelle (13-29)
@13_triggers.sql
@14_packages.sql
@15_mviews.sql
@16_jobs.sql
@17_lot_r1_promotions.sql
...
@30_lot_r14_interfaces.sql

# Quick wins + Lots fonctionnels (31-42)
@31_pkg_pos_sales.sql
@32_pkg_pos_sales_body.sql
...

# Validation
@99_validation.sql
```

### Variables d'environnement supportées

```bash
# Pour modifier la connexion
export DB_USER=system
export DB_PWD=oracle
export DB_HOST=localhost
export DB_PORT=1521
export DB_SERVICE=FREEPDB1

# Editer run_all.sh pour utiliser ces variables à la place des valeurs hardcodées.
```

---

## 🌱 12. Données de seed

33 fichiers `seed_data/S*.sql` (S00-S32), couvrant :

| Seed | Tables ciblées | Volumétrie |
|---|---|---|
| `S00_reset` | toutes (DELETE) | - |
| `S01-S08` | schéma par schéma | 5-50 lignes/table |
| `S09` | `app_product.promo_*`, `price_tier_*` | 4 promos + 1 palier |
| `S10` | `app_party.voucher_*` | 5 bons + 8 transactions |
| `S11` | `app_inv.inv_*` (R3) | 8 statuts + 5 lots |
| `S12` | `app_inv.inv_reorder`, `transfer_*`, etc. | 2 transferts + 1 BC |
| `S13` | `app_ar.invoice`, `payment`, `credit_note`, etc. | 3 factures + 1 avoir |
| `S14` | `app_ar.cash_register_session`, `dunning_log`, etc. | 3 sessions + 4 relances |
| `S15` | `app_sales.ticket_return`, `pos_cash_closure`, etc. | 2 retours + 1 clôture |
| `S16` | `app_product.promo_pos_*`, `loyalty_status_*` | 3 promos POS + 5 niveaux |
| `S17` | `app_inv.inv_count_*`, `inventory_*` | 1 inventaire + 4 ajustements |
| `S18` | `app_party.voucher_*` | 5 bons + 8 transactions |
| `S19` | `app_sys.alert_*`, `notification_*` | 8 types + 6 alertes |
| `S20` | `app_api.kpi_*`, `report_*` | 8 KPIs + 60 snapshots |
| `S21` | `app_sys.sys_role`, `sys_permission`, etc. | 6 rôles + 14 audit |
| `S22` | `app_sys.interface_*`, `sync_queue`, etc. | 6 endpoints + 12 logs |

### Volume total après seed

- **~ 350 lignes de référence** réparties sur **~ 140 tables**
- Assez pour tester toutes les requêtes de la doc sans monter un jeu réaliste
- **Non-adapté à la perf** (tester sur 1M+ lignes pour valider)

---

## 🔁 13. Migration legacy (ETL)

Voir le package `pkg_etl_legacy` (script 42). Étapes clés :

### Step 1 : Créer le DB_LINK

```sql
CREATE DATABASE LINK legacy
  CONNECT TO legacy_user IDENTIFIED BY legacy_pwd
  USING 'LEGACY_TNS';
```

### Step 2 : Tester en DRY_RUN

```sql
SET SERVEROUTPUT ON
BEGIN
  pkg_etl_legacy.migrate_lot('R1', p_dry_run => TRUE);
  pkg_etl_legacy.migrate_lot('R3', p_dry_run => TRUE);
  pkg_etl_legacy.migrate_lot('R5', p_dry_run => TRUE);
END;
/
```

### Step 3 : Vérifier les comptages

```sql
-- Comparer COUNT(*) source et cible
SELECT 'source' AS scope, COUNT(*) FROM legacy.GCPROMO@legacy
UNION ALL
SELECT 'cible',   COUNT(*) FROM app_product.promo_header;
```

### Step 4 : Lancer en production

```sql
BEGIN
  pkg_etl_legacy.migrate_lot('R1', p_dry_run => FALSE);
  ...
END;
/
```

### Step 5 : Valider l'intégrité

```sql
-- Vérifier que toutes les FK pointent vers des enregistrements existants
SELECT fk.owner, fk.table_name, fk.constraint_name
  FROM all_constraints fk
 WHERE fk.owner LIKE 'APP\_%' ESCAPE '\'
   AND fk.constraint_type = 'R'
   AND fk.validated = 'NOT VALIDATED';

-- Re-valider :
BEGIN
  FOR c IN (SELECT owner, constraint_name FROM all_constraints
             WHERE constraint_type = 'R' AND validated = 'NOT VALIDATED') LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE '||c.owner||'.'||
      (SELECT table_name FROM all_constraints WHERE owner=c.owner AND constraint_name=c.constraint_name)
      ||' ENABLE VALIDATE CONSTRAINT '||c.constraint_name;
  END LOOP;
END;
/
```

### Mapping de référence rapide

Voir table 5.2. Pour le mapping champ-à-champ précis, adapter chaque `migrate_table()` selon vos réels champs legacy.

---

## 📊 14. Catalogue KPI & alertes

### KPIs en place (8 définis + 60 snapshots)

| Code | Nom | Cible | Fréquence |
|---|---|---:|---|
| `DAILY_REVENUE` | CA journalier | 200 000 XOF | REALTIME |
| `DAILY_TICKETS` | Tickets par jour | 50 | DAILY |
| `AVG_TICKET` | Panier moyen | 8 000 XOF | DAILY |
| `STOCK_TURNOVER` | Rotation stock | - | MONTHLY |
| `CASH_VARIANCE` | Écart caisse | < 5 000 XOF/mois | DAILY |
| `LOYALTY_MEMBERS` | Adhérents | - | DAILY |
| `OVERDUE_RATIO` | Ratio en retard | < 20% | WEEKLY |
| `PRODUCTS_BELOW_MIN` | Produits sous min | < 5 | HOURLY |

### Alertes configurées (8 types, 5 règles seed)

Voir seeds `S19` pour les détails.

### Requêtes dashboard utiles

```sql
-- Dashboard exécution (top 5 KPIs)
SELECT label, unit, valeur, cible,
       CASE WHEN cible IS NULL THEN 'N/A'
            ELSE TO_CHAR(ROUND((valeur-cible)*100/cible,1))||'%'
       END AS realisation
  FROM v_top_kpi_dashboard
 ORDER BY CASE label
   WHEN 'CA jour' THEN 1 WHEN 'Tickets jour' THEN 2
   WHEN 'Panier moyen jour' THEN 3 WHEN 'CA MTD' THEN 4
   ELSE 99 END;

-- Alertes critiques ouvertes
SELECT alert_id, alert_type_code, entity_label, severity, triggered_at
  FROM alert_instance
 WHERE status = 'OPEN' AND severity IN ('HIGH','CRITICAL')
 ORDER BY triggered_at DESC;
```

---

## 🔐 15. Sécurité & RBAC

### Rôles (6 seedés)

| Rôle | Level | MFA | Sessions |
|---|---:|:---:|---:|
| `ADMIN` | 5 | OUI | 8h |
| `MANAGER` | 4 | non | 10h |
| `ACCOUNT` | 3 | OUI | 8h |
| `STOCK` | 3 | non | 8h |
| `CASHIER` | 2 | non | 8h |
| `VIEWER` | 1 | non | 4h |

### Permissions (15 atomiques)

15 actions × 9 ressources, ex. `SALES_CREATE`, `STOCK_ADJUST`, `PRICE_EDIT`, `REPORT_EXPORT`, `USER_MANAGE`, etc.

### Audit (R13)

```sql
-- Toutes les actions des 30 derniers jours
SELECT user_code, action_type, entity_type, severity, performed_at
  FROM sys_audit_trail
 WHERE performed_at > SYSDATE - 30
 ORDER BY performed_at DESC;

-- Tentatives d'intrusion (login échoué)
SELECT user_code, ip_address, performed_at,
       JSON_VALUE(new_values, '$.reason') AS raison
  FROM sys_audit_trail
 WHERE action_type = 'LOGIN' AND severity = 'CRITICAL';

-- Activité utilisateur
SELECT user_code, COUNT(*) AS nb, severity
  FROM sys_audit_trail
 GROUP BY user_code, severity
 ORDER BY nb DESC;
```

---

## 🧪 16. Tests & recettes SQL

### Smoke test (à exécuter après déploiement)

```sql
-- Versions
SELECT banner_full FROM v$version;

-- Schémas créés
SELECT username FROM dba_users
 WHERE username LIKE 'APP\_%' ESCAPE '\'
   AND oracle_maintained = 'N';

-- Pas d'objets invalides
SELECT owner, object_type, object_name
  FROM dba_objects WHERE status = 'INVALID' AND owner LIKE 'APP\_%' ESCAPE '\';

-- Features 23ai fonctionnent
SELECT 'BOOLEAN'     AS test, is_active FROM app_product.product WHERE ROWNUM = 1;
SELECT 'IDENTITY'    AS test, product_id FROM app_product.product WHERE ROWNUM = 1;
SELECT 'VECTOR'      AS test, embedding IS NOT NULL FROM app_product.product_search WHERE ROWNUM = 1;
SELECT 'JSON_NATIVE' AS test, JSON_VALUE(payload, '$.note') FROM app_sys.alert_instance WHERE payload IS NOT NULL AND ROWNUM = 1;

-- Duality View
SELECT JSON_SERIALIZE(data PRETTY)
  FROM app_api.dv_product WHERE ROWNUM = 1;

-- MV populate
SELECT mview_name, num_rows
  FROM user_mviews WHERE ROWNUM <= 5;
```

### Tests fonctionnels

Voir sections 14, 15 pour requêtes prêtes à l'emploi.

### Tests de charge (à planifier)

```sql
-- Génération massive
DECLARE
  v_id NUMBER;
BEGIN
  FOR i IN 1..10000 LOOP
    INSERT INTO app_sales.ticket (terminal_id, ticket_no, ticket_date, session_no,
                                  customer_code, user_code, total_ht, total_ttc, status)
    VALUES ('CAI01', SEQ_TICKET_TEST.NEXTVAL, SYSTIMESTAMP, 1,
            'CLI'||MOD(i,100), 'TEST', 5000, 5000, 'V');
  END LOOP;
  COMMIT;
END;
/

-- Refresh MV et mesure
SET TIMING ON
BEGIN
  DBMS_MVIEW.REFRESH('app_api.mv_hourly_sales', 'C');
END;
/
```

---

## 🛣 17. Roadmap

### 🟡 État des scripts (la validation de bout en bout reste à faire)

**Architecture & socle**
- 🟡 17 schémas et environ 195 tables définis dans les scripts; rebuild et validation complète non exécutés dans ce contrôle
- 🟡 Scripts DDL, seeds, packages, triggers, vues et jobs présents; statut runtime à confirmer par `99_validation.sql`
- ℹ La couverture des lignes legacy n'est pas mesurée par rapport à la source

**Modules métier**
- 🟡 Modèle cible défini pour POS, stock, AR, achats, documents, OHADA, RH et multi-sites
- 🟡 ETL CSV défini pour articles, stocks, prix et tiers; exécution et rapprochement à valider
- 🔴 Aucune migration GCBRDE/GCBRDD réelle : le dispatcher refuse les succès simulés
- 🟡 Outbox/scheduler définis; transport DBLINK et application distante non réalisés par le code actuel

**Performance & partitionnement**
- ✅ 4 tables partitionnées (ticket_line_v2, transfer_line_v2, gl_entry_line_v2, payment_history_v2)
- ✅ Stratégie RANGE(month) + LIST(site, 8 sous-partitions)
- ✅ JOB_PARTITION_MAINT : drop auto > 36 mois
- ✅ fn_predict_growth() : projection 5 ans

**ETL legacy**
- 🟡 Tables externes Oracle Loader pour les CSV REGAL; chargement à valider sur les fichiers réels
- 🔴 `pkg_etl_legacy` ne déplace pas les lignes GCBRDD vers les neuf cibles; ETL à développer
- 🟡 `etl_run_progress` conserve le statut, mais la reprise réelle par PK/batch reste à vérifier

**Localisation Congo Brazzaville**
- ✅ TVA 18.9% (CEMAC), XAF (BEAC), 7 centres DGID
- ✅ CNSS 10% salarié + 19.5% patron, IRPP 8 tranches
- ✅ Litoko SARL Pointe-Noire : société + 2 dépôts + 5 magasins

**Deprecated 26ai**
- ✅ CREATE INDEX retiré (pas un privilège système)
- ✅ CREATE DOMAIN retiré (déprécié 26ai)
- ✅ DECODE → CASE WHEN
- ✅ EXCEPTION WHEN OTHERS THEN NULL + whitelist SQLCODE

### 🟠 Court terme (à venir)

- [ ] **Tests unitaires PL/SQL** (utPLSQL) : couverture 8 packages
- [ ] **Pilote BZV-B01** : installation boutique moderne + ETL réel
- [ ] **Migration en production** : basculement progressif depuis 11g

### 🟠 Moyen terme (1-3 mois)

- [ ] **Module compta XCPTA complet** (~ 50 tables : CP_ECR_LET_DET, CP_HISTO_RGL, etc.)
- [ ] **Index manquants** + tuning performance sur volumétrie réelle
- [ ] **VPD/RLS** — politiques de sécurité au niveau ligne (multi-société)
- [ ] **CI/CD GitHub Actions** : run_all_with_seeds.sh auto
- [ ] **Mode dégradé** : boutique autonome si sync échoue > 3 fois

### 🔴 Long terme (3-12 mois)

- [ ] **Module logistique avancée** (cross-docking, wave picking)
- [ ] **Oracle GoldenGate** : CDC temps réel (licence)
- [ ] **IoT / shop floor** — capteurs + tables time-series
- [ ] **Multi-tenant natif** — colonne `company_code` comme discriminator
- [ ] **Sauvegarde PITR** + restauration testée mensuellement

---

## 📋 18. Annexes

### Annexe A : Historique des commits

Voir `git log --oneline` ou la section "Commits" du README.md.

### Annexe B : Glossaire

| Terme | Définition |
|---|---|
| **SYSCOHADA** | Système comptable OHADA révisé (normes comptables Afrique de l'Ouest/Centre) |
| **Duality View** | Vue relationnelle + JSON, lecture/écriture REST natif (Oracle 23ai) |
| **PRMP** | Prix Moyen Pondéré (méthode d'évaluation stock) |
| **FEFO** | First Expired First Out (méthode d'utilisation stock avec DLC) |
| **POS** | Point of Sale |
| **MV** | Materialized View (vue matérialisée) |
| **OHADA** | Organisation pour l'Harmonisation en Afrique du Droit des Affaires |
| **MVTO** | Macro d'écart de caisse |
| **OA** | Open Account (modalité achat) |
| **DDP/CIF/...** | Incoterms (termes commerciaux internationaux) |

### Annexe C : Références

- Oracle 23ai New Features — Documentation officielle
- OHADA — Plan comptable SYSCOHADA révisé (2017)
- ISO 20022 — Paiements interbancaires (inspiré pour `payment.*`)
- RGPD / PCI-DSS — Implémenter via audit R13 + VPD

### Annexe D : Limites connues

- **Tokens GitHub** : ne JAMAIS partager un PAT dans un chat persisté (compromis garanti)
- **Duality Views / PK composites** : limitation Oracle 23ai Free — workaround via vues JSON classiques
- **Schema binding** : le DDL avec `CONNECT`/`SET` dans SQL*Plus ne marche pas dans tous les outils
- **Performance** : testée sur volumétrie seed (10k tickets), à valider en prod réelle (10k+ tickets/jour)
- **Free 23ai RAM limit (32 Go)** : d'où le partitionnement RANGE+SUBPARTITION pour ticket_line_v2 (65.5M rows)
- **Réseau Congo** : satellite 1 Mbps Dolisie, fibre coupée → mode dégradé boutique autonome prévu

### Annexe E : Architecture Hub-and-Spoke (REGAL multi-sites)

Voir `ARCHITECTURE_HUB_SPOKE.md` pour le détail complet.

**Sites** : 1 siège MASTER (PNR-OFC) + 4 boutiques + 2 dépôts
**Sync** : Outbox pattern (transactionnel) + DBLINK + 3 stratégies (MASTER_WINS, LAST_WRITE_WINS, MANUAL_REVIEW)
**Scheduler** : JOB_SYNC_HUB_PUBLISH toutes les 30 min
**CDC** : triggers `trg_outbox_product_ai/_au/_ad` sur `app_product.product`

### Annexe F : Partitionnement 23ai

**4 tables partitionnées** :
| Table | Stratégie | Volume cible |
|---|---|---:|
| `ticket_line_v2` | RANGE(month) + LIST(site, 8 sp) | 248M rows en 5 ans |
| `transfer_line_v2` | RANGE(month) + LIST(site, 8 sp) | 207M rows |
| `gl_entry_line_v2` | RANGE(year, 5 p) | 10.6M rows |
| `payment_history_v2` | RANGE(month) | 1.9M rows |

**Helpers** :
- `fn_partition_info(owner, table)` : SYS_REFCURSOR
- `fn_total_partitions(table)` : count
- `JOB_PARTITION_MAINT` : drop auto > 36 mois

### Annexe G : Contacts / contributeurs

- Auteur : mirlondev (https://github.com/mirlondev)
- Repo : https://github.com/mirlondev/erp-db-23ai.git
- Localisation : Pointe-Noire, Congo Brazzaville

---

**Dernière mise à jour** : 2026-09-29 (couverture **~ 49 %** du legacy 391 tables).
**~195 tables modernes / 17 schémas / 57 scripts / 31 seeds / 8 packages / 4 tables partitionnées / 6 tables externes ETL**.
