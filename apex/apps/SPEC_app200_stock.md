# Spécifications UI — App 200 « Stock hub-spoke » (APEX 26.1)

Schéma : `APP_INV` (+ synonymes `APP_API`) · Rôles : `REGAL_MAGASINIER`, `REGAL_ADMIN`

## Vue d'ensemble fonctionnelle

L'app 200 orchestre les **transferts inter-sites** (dépôt↔magasin) et la **consultation multi-sites** du stock.
Elle s'appuie sur :
- `app_inv.transfer_header` / `transfer_line` / `transfer_line_v2` (script 56 — partitionné)
- `app_inv.inv_stock` + `app_inv.inv_movement` + `app_inv.inv_product_lot`
- `app_inv.inv_count_header` / `inv_count_line` (script R9 — inventaire double-comptage)
- `app_inv.pkg_transfer_stock` (script 43 — workflow 6 étapes)
- `app_sys.v_tt_pending` (script 53 — file de transfert Master→Boutiques)
- `app_sys.outbox_event` + `app_sys.site_master` (CDC + topologie)

## Pages

| # | Page | Type | Source principale | Composants APEX 26.1 | Actions / Packages |
|---|---|---|---|---|---|
| 1 | Dashboard stock | Home | `v_inv_stock_kpi` | 6 Cards KPI + Chart courbes (stock par site) | Drill-down site → page 10 |
| 10 | Stock par dépôt | IR + IG | `inv_stock` JOIN `org_warehouse` | IG éditable (transfert inter-sites) | Filtre `app_sys.pkg_apex_auth.user_site_codes(:APP_USER)` |
| 11 | Stock par magasin (POS) | IR | `inv_stock` JOIN `pos_terminal` | Faceted Search (ville, statut) | Voir lots DLC (page 12) |
| 12 | Lots & DLC (FEFO) | IR tri expiry | `inv_product_lot` | Badges couleur (rouge <7j, orange <30j) | Action "Marquer pour retour" |
| 20 | **Transferts inter-sites** | Formulaire | `transfer_header` + `transfer_line_v2` | **Wizard 6 étapes** (DRAFT → CLOSED) | `pkg_transfer_stock.create_transfer / add_line / submit / approve / pack / ship / receive / cancel` |
| 21 | Pipeline transferts en cours | IR | `transfer_header` WHERE status IN (REQUESTED, APPROVED, PACKED, IN_TRANSIT) | 4 KPI cards par statut + IG | Boutons "Avancer étape" |
| 22 | File d'attente Master→Boutique | IR | `v_tt_pending` (script 53) | Badges couleur + IG | Force re-publish (admin) |
| 30 | Inventaires physiques | Wizard | `inv_count_header` + `inv_count_line` | IG lignes (saisie comptage) | Validation double-comptage → ajustement stock |
| 40 | Alertes stock | IR | `app_inv.inv_stock_status` JOIN alertes | Notifications badges | Acknowledge → `app_sys.alert_instance` |
| 50 | Rapports | Reports | `v_stock_value_by_site`, `v_movement_summary` | Faceted Search + IG saved reports | Export PDF/Excel |

## Contraintes compatibilité WS legacy

1. **Toutes les écritures** passent par `pkg_transfer_stock` (script 43) — jamais d'UPDATE direct
   sur `transfer_header.status`. Le workflow WS legacy lit les statuts ; les pousser
   ailleurs casse la réconciliation `TR_GCBRDE` côté boutique.
2. L'écran de pipeline (page 21) lit `transfer_header` puis `transfer_line_v2` pour les lignes
   (script 56) — la table `transfer_line` d'origine est gardée pour rétrocompat WS.
3. Page 22 (`v_tt_pending`) lit `app_sys.tt_brd_office` (script 53) — la table legacy
   `TRANSFERT.TR_GCBRDD` (228K rows) reste intacte, l'APEX ne fait que **consulter** la file.
4. Filtre multi-sites obligatoire via `app_sys.pkg_apex_auth.user_site_codes(:APP_USER)`
   (setup/03) — restriction des dépôts visibles selon l'utilisateur.

## KPIs page 1

```sql
-- Stock par site (valeur PRMP × stock_qty)
SELECT ws.site_code,
       ws.city,
       SUM(s.stock_qty)                       AS total_units,
       SUM(s.stock_qty * p.standard_price)     AS total_value_xaf,
       COUNT(DISTINCT s.product_code)         AS nb_references
  FROM app_inv.inv_stock s
  JOIN app_product.product  p ON p.product_code = s.product_code
  JOIN app_org.org_warehouse w ON w.warehouse_code = s.warehouse_code
  JOIN app_sys.site_master   ws ON ws.site_code = w.warehouse_code
 WHERE s.stock_qty > 0
   AND (',' || app_sys.pkg_apex_auth.user_site_codes(:APP_USER) || ',' LIKE '%,' || ws.site_code || ',%'
        OR app_sys.pkg_apex_auth.user_site_codes(:APP_USER) IS NULL)
 GROUP BY ws.site_code, ws.city
 ORDER BY total_value_xaf DESC;
```

## Wizard transfert (page 20) — détail étapes

| Étape | Composant APEX | Source | Action |
|---|---|---|---|
| 1. Source | Select List | `org_warehouse` (source_type=WAREHOUSE) | `pkg_transfer_stock.create_transfer` |
| 2. Destination | Select List | `org_warehouse` OU `pos_terminal` | — |
| 3. Lignes | IG dynamique | Produits du site source | `pkg_transfer_stock.add_line` (multi-add) |
| 4. Vérif stock | Page validation | `app_sys.fn_inventory_available` | Bloque si stock insuffisant |
| 5. Submit | Bouton | — | `pkg_transfer_stock.submit_for_approval` |
| 6. Workflow status | Steps indicator | `transfer_header.status` | Auto-progress via boutons approbateur |

## Hooks d'audit (déjà livrés)

- `pkg_transfer_stock.submit_for_approval` / `approve_transfer` / `receive_transfer` →
  `app_sys.sys_audit_trail` avec `severity INFO` (script 52)
- `cancel_transfer` → severity `WARN` (consultable page 7 admin)
- L'écran Stock Alerte (page 40) lit `app_sys.alert_instance` (script R11)

## Tests de parité (scripts `apex/tests/`)

- `t_200_pipeline.sql` : crée un transfert DRAFT, le soumet, l'approuve, le pack, le ship,
  le reçoit — vérifie le passage à CLOSED + maj `inv_stock` des deux côtés.
- `t_200_cdc_sync.sql` : modifie un produit → vérifie qu'un événement apparaît dans
  `outbox_event` avec `status='PENDING'` (script 52).

## KPIs Dashboard

- Valeur totale du stock par site (XAF)
- Nombre de références actives par site
- Stock en alerte (sous le seuil)
- Transferts en cours par étape
- Délai moyen d'un transfert (création → réception)
- Valeur des mouvements du mois
