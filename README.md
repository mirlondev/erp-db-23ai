# erp-db-23ai

Migration d'un ERP classique **Oracle 11g** (391 tables, 6 schémas) vers **Oracle 23ai / 26ai Free** (12 schémas modernes), en activant les features natives de la nouvelle plateforme :

- ✅ **Identity columns** (`GENERATED ALWAYS AS IDENTITY`) — fin des séquences manuelles
- ✅ **BOOLEAN natif** — suppression des `VARCHAR2(1)` 'Y'/'N' hérités du legacy
- ✅ **BLOB SecureFile** + compression + déduplication pour les photos produit
- ✅ **VECTOR(384, FLOAT32)** — table `product_search` prête pour l'**AI Vector Search** 23ai
- ✅ **JSON Relational Duality Views** (`dv_product`, `dv_party`) — exposition REST sans réécrire le modèle
- ✅ **Vues classiques JSON** (`v_ticket_json`, `v_stock_json`) — workaround pour PK composites non supportées par les Duality Views en Free
- ✅ **Matérialized views** + **DBMS_SCHEDULER** pour le rafraîchissement horaire et la purge
- ✅ **Packages PL/SQL** : `pkg_pricing`, `pkg_inventory`, `pkg_sales`, `pkg_gl`

## Schémas cibles (12)

| Schéma        | Rôle                                                                 |
|---------------|----------------------------------------------------------------------|
| `app_sys`     | Noyau : utilisateurs, paramètres, devises, pays                     |
| `app_org`     | Société, dépôts, points de vente                                    |
| `app_product` | Catalogue : produits, catégories, marques, **promotions (R1)**        |
| `app_party`   | Tiers : clients / fournisseurs / employés                            |
| `app_inv`     | Stock & inventaires                                                  |
| `app_doc`     | Documents commerciaux (Bons d'achat, Factures, etc.)                |
| `app_pos`     | Terminaux et sessions de caisse                                      |
| `app_sales`   | Tickets de caisse                                                    |
| `app_gl`      | Comptabilité générale (journal, écritures, lettrage)                 |
| `app_cash`    | Caisses & mouvements                                                |
| `app_hist`    | Schéma d'archivage (cold storage)                                    |
| `app_api`     | Vues exposées (Duality + classiques JSON)                           |
| `app_ar`      | **Accounts Receivable** — factures, avoirs, règlements (R5)         |

## Démarrage rapide

### Pré-requis
- Oracle Database 23ai Free ou 26ai (conteneur `FREEPDB1`)
- Schéma `system` avec mot de passe `oracle`
- TNS : `localhost:1521/FREEPDB1`

### Déploiement complet (DDL + seeds + validation)

```bash
cd scripts
./run_all_with_seeds.sh
```

### Déploiement DDL seul (si seeds déjà faits)

```bash
cd scripts
./run_all.sh
```

### Reset complet + reseed

```bash
cd scripts
./run_all_with_seeds.sh   # le pipeline inclut S00_reset.sql avant les seeds
```

## Roadmap de migration

| Lot  | Domaine                          | Tables | Schéma          | Statut        |
|------|----------------------------------|:------:|-----------------|---------------|
| 0    | Bootstrap 12 schémas             |   —    | tous            | ✅            |
| 1A   | Lignes document complémentaires  |   5    | app_doc         | ✅ (en partie, voir procédure) |
| 1B   | Entêtes document complémentaires |   6    | app_doc         | ✅            |
| 1C-1G | Proforma, expéditions, factures |  24    | app_doc/ship/ar | ⏸️ reporté    |
| **R1**  | **Promotions & Remises**     |  **8** | **app_product** | **✅ ici**    |
| **R2**  | **Fidélité client**          |  **7** | **app_party**   | **✅ ici**    |
| **R3**  | **Stock avancé**             |  **7** | **app_inv**     | **✅ ici**    |
| **R4**  | **Réappro & Transferts**      |  **6** | **app_inv**     | **✅ ici**    |
| **R5**  | **Facturation & Avoirs**       |  **7** | **app_ar (NEW)** | **✅ ici**   |
| **R6**  | **Règlements clients avancés**  |  **6** | **app_ar**      | **✅ ici**    |
| **R7**  | **POS : retours, remises ligne** | **5**  | **app_sales**   | **✅ ici**    |
| **R8**  | **Promotions POS avancé**       |  **5** | **app_product** | **✅ ici**    |
| **R9**  | **Inventaire physique complet**  | **3**  | **app_inv**     | **✅ ici**    |
| R10  | Cartes cadeaux / bons d'achat    |   5    | app_party       | ⏳ planifié   |
| R11  | Alertes & notifications          |   6    | app_sys         | ⏳ planifié   |
| R12  | KPI & reporting MV               |   5    | app_api         | ⏳ planifié   |
| R13  | Sécurité avancée & audit         |   5    | app_sys         | ⏳ planifié   |
| R14  | Interfaces & intégrations        |   5    | app_api         | ⏳ planifié   |

> Couverture actuelle : ~84 tables modernes / 391 legacy ≈ 22 %. Le modèle structure est en place, il reste à dérouler les lots suivants.

## Décisions techniques notables

1. **PK composites vs JSON Duality Views** : Oracle 23ai Free **refuse les Duality Views sur PK composites** (ORA-40607). Tables concernées (`ticket`, `ticket_line`, `ticket_payment`, `inv_stock`) → exposition via vues classiques `JSON_OBJECT`/`JSON_ARRAYAGG`. Voir `12_app_api.sql`.

2. **Identifiants métiers conservés** : on garde les `*_code` (ex. `product_code`, `party_code`, `terminal_code`) en plus des `*_id` pour faciliter la migration depuis l'ancien schéma où ces codes étaient les clés naturelles.

3. **Triggers inter-schémas** : le trigger `trg_ticket_line_after_insert` décompte le stock via un `MERGE`/`UPDATE` cross-schema (`app_sales` → `app_inv`). Les GRANTs requis sont accordés dans `13_triggers.sql`.

4. **Dénormalisation contrôlée** : `inv_stock.stock_qty` est mis à jour par trigger (compromis lecture rapide / cohérence garantie par le trigger). Les **mouvements réels** restent dans `inv_movement` pour l'auditabilité.

## Tests rapides

```sql
-- BOOLEAN natif
SELECT product_code, is_stock_managed, is_promo
  FROM app_product.product
 WHERE is_stock_managed = TRUE;

-- JSON Duality View
SELECT JSON_SERIALIZE(data PRETTY)
  FROM app_api.dv_product
 WHERE JSON_VALUE(data, '$.productCode') = 'ART001';

-- Package pricing
SELECT app_product.pkg_pricing.get_price('ART001', 1) FROM DUAL;

-- Volumétrie Lot R1
SELECT promo_code, promo_name, promo_type
  FROM app_product.promo_header
 ORDER BY priority;
```

## Licence

Interne — propriété du porteur du projet.
