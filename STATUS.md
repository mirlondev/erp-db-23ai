# STATUT RÉEL vs Legacy Oracle 11g

> Document honnête : **où on en est vs l'ancien système**, **quoi de fait**, **quoi à faire**, et **risques/biais**.

## 📊 Chiffres bruts

| | Legacy 11g | Cible 23ai/26ai | Actuel |
|---|---:|---:|---:|
| Schémas | 6 | 13 | 13 |
| Tables | 391 | (cible) | ~110 |
| Foreign keys | 277 | (héritage) | ~250 |
| Indexes | 182 | (optimisé 23ai) | ~80 |
| Vues | 5 | (à créer) | ~10 |
| Triggers | 21 | (réécriture) | 5 |
| Packages PL/SQL | 60 | (héritage) | 4 |
| Séquences | 17 | (Identity 23ai) | 0 (Identity utilisé) |
| Synonymes | 414 | 0 | 0 |

### Schémas legacy vs modernes

| Legacy 11g (6) | Cible moderne (13) | Couvert |
|---|---|---|
| `CAISSE` (200 tables) | app_pos, app_sales, app_cash | ~30 tables |
| `KERNEL` (56 tables) | app_sys, app_party | ~15 tables |
| `XCPTA` (94 tables — compta) | app_gl | **~8 tables** ⚠️ |
| `TRANSFERT` (32 tables) | app_inv (R3, R4) | ~7 tables |
| `CASH` (8 tables) | app_cash, app_ar | ~3 tables |
| `ERP_APP` (1 table) | plusieurs | minimal |

## ✅ Ce qui est FAIT (R1-R14 + bootstrap)

### Domaines retail à forte valeur

| Domaine | Lots | Tables modernes | Estimé legacy couvert |
|---|---|---:|---:|
| Catalogue & Promotions | R1, R8 | 13 | ~80% (GCPROMO, GCPPALIER, CEPCFPROMO) |
| Clients & Fidélité | R2, R10 | 12 | ~70% (CEPCFCARTE, CFID, CEBON) |
| Stock | R3, R4, R9 | 16 | ~60% (GCPART_LOT, GCSTOCK_STATUT, transfers) |
| Ventes POS | R7 | 5 | ~50% (CETICKET, retours/remises) |
| Facturation & Avoirs | R5, R6 | 13 | ~70% (CP_FACTURE, GCRGLE) |
| Décisionnel | R11, R12 | 14 | nouveau (pas d'équivalent) |
| Sécurité | R13 | 5 | nouveau (pas d'équivalent) |
| Interfaces | R14 | 5 | nouveau (pas d'équivalent) |
| **Documents commerciaux (Lot 1A-1D)** | 1A-1D | **19** | **~70% (GCBRDD, GCBRDE)** |
| **Expéditions (Lot 1E)** | 1E | **7 (+ app_ship)** | **~80% (GCEXPEDITION)** |
| **Comptabilité OHADA (squelette)** | 38 | **8** | **~15% (CP_*)** |

### Features 23ai/26ai exploitées

| Feature | Usage | Tables concernées |
|---|---|---|
| Identity columns | `GENERATED ALWAYS AS IDENTITY` | toutes les nouvelles |
| BOOLEAN natif | (legacy `VARCHAR2(1)` Y/N) | partout |
| BLOB SecureFile | photos produit | product_photo |
| VECTOR(384, FLOAT32) | `product_search` (vide, prêt pour embeddings) | product_search |
| JSON Relational Duality Views | `dv_product`, `dv_party` | dv_* |
| JSON natif | `JSON_VALUE`, `JSON_OBJECT` | alert.payload, sys_audit.old_values, sync_queue.payload, etc. |
| Computed columns GENERATED | variance, achieved, total_value | kpi_daily_snapshot, voucher_lot |
| ROW STORE COMPRESS ADVANCED | MV reporting | mv_hourly_sales, mv_monthly_top_products, mv_customer_performance |
| Index partiels WHERE | alert open/audit critical/queue pending | plusieurs |

## ❌ Ce qui N'EST PAS FAIT (mis à jour)

### 1. Lot 1F (Achats) — reporté
- Demandes de prix — nouveau schéma `app_purchase` (4 tables) : GCPTIE_*

### 2. Module comptabilité complet (XCPTA — ~94 tables, préfixe CP*)
**Squelette OHADA posé** (8 tables + plan SYSCOHADA seeds). Manquent :
- Immobilisations (CP_IMMO_*)
- États financiers (bilan, compte de résultat, CPF selon normes)
- Lettrage / Rapprochements bancaires (~6 tables supplémentaires)
- Déclarations TVA (~3 tables)
- Immobilisations
- Provisions / Régularisations
- Sous-total à faire : **~80-90 tables**

### 3. Modules KERNEL/Utilitaires (UT* — 6 tables)
- Tables `UT*` legacy (utilisateurs avancés, préférences, sessions techniques)
- Non couvertes — peut-être déjà géré par R13 (sécurité)

### 4. Migration de données (legacy → 23ai)
**Aucun script ETL écrit**. La migration du contenu des 391 tables legacy vers les ~135 tables modernes demande :
- Mapping de champs legacy → modernes
- Troncature / concaténation de champs
- Gestion des NULL/valeurs par défaut
- Tests de cohérence
- Dry-run + validation

### 5. Couche PL/SQL métier (60 packages legacy → modernes)
- **5 packages modernes** : pkg_pricing, pkg_inventory, pkg_sales, pkg_gl, pkg_pos_sales
- Manque : facturation avancée, calculs comptables, génération PDF, exports

### 6. Données de test reales
- 22 seeds "vitrine" mais pas de jeu de données de **production-like** (millions de lignes)
- Pas de tests de charge / performance

## 🚨 Risques / Décisions à arbitrer

### Décision 1 : Faut-il tout migrer ?
Réponse courte : **NON**. La migration 1:1 n'a pas de sens business. Il faut :
- Identifier les **vraies données actives** (souvent 30-50% des 391 tables sont obsolètes)
- Refactoriser en profitant de 23ai (ex : `VARCHAR2(255)` legacy → valeur atomique + Duality View)

### Décision 2 : Lot 1C-1G (documents)
3 options :
| Option | Effort | Pour | Contre |
|---|---|---|---|
| A. Faire 1A-1D (doc complet) | ~1 session | ERP complet | Pas critique si on utilise R5 directement |
| B. Sauter, focus perf | - | Plus de temps pour tuning | Fonctionnel incomplet |
| C. Faire juste 1E (expéditions) | ~30 min | Couvre logistique retail | Pas d'achats, pas de stock avancé |

### Décision 3 : Module comptabilité OHADA
- L'ERP legacy est probablement **bilingue OHADA/SYSCOHADA** (plan comptable, états)
- Pas couvert par R5/R6
- Indispensable pour aller en production réelle

### Décision 4 : ETL legacy → moderne
- Pas urgent si on part d'une base vide
- Critique si on veut migrer un client existant
- Difficile sans accès à la base 11g réelle

## 🗺️ Roadmap proposée (priorités)

### Court terme (si tu veux continuer)

1. **ETL minimal** : script de migration pour les 8 schemas bootstrap (users, org, products, parties, etc.) — ~2h
2. **Lot 1A-1D Documents** : compléter `app_doc` avec ce qui manque — ~1h
3. **pkg_pos_sales** : package PL/SQL évoqué par procédure.txt pour orchestrer le ticket — ~30 min

### Moyen terme (production-ready)

4. **Module compta OHADA** : il faut ajouter ~50-80 tables et 5-10 packages comptables — c'est un vrai gros chantier
5. **Tuning performance** : index manquants, MV supplémentaires, partitioning
6. **Tests d'intégration** : package utPLSQL ou similaire

### Long terme (infrastructure)

7. **CI/CD** : automatiser le `run_all_with_seeds.sh` dans GitHub Actions
8. **Documentation** : data dictionary auto-généré
9. **Sécurité VPD / RLS** : politiques Oracle au niveau des lignes
10. **Monitoring Oracle 23ai** : vues `V$SQL`, alertes proactives

## 📋 Quick wins (faibles effort, forte valeur)

| Idée | Effort | Valeur |
|---|---|---|
| Script `pkg_pos_sales` (package POS) | 30 min | Élevée |
| MV supplémentaire `mv_daily_cash` | 15 min | Élevée |
| Trigger `trg_invoice_overdue` (auto-update balance) | 20 min | Élevée |
| Duality Views sur `invoice` & `payment` | 30 min | Élevée |
| Vue `v_dashboard_executive` | 30 min | Élevée |
| Tests unitaires de base | 1h | Moyenne |

## Conclusion

**On a couvert le cœur retail à ~70%** et la cible globale à ~28% en comptage de tables.
Le module compta OHADA est **le principal trou** (~94 tables legacy non couvertes).
Pour un ERP **retail complet opérationnel**, il manque : ~3 lots (1A-1G + compta + ETL).
Pour un ERP **généraliste complet** : il manque tout le module compta + logistique avancée.

➡️ **Dis-moi où tu veux aller** (priorité business) et je te fais un plan d'action ciblé.
