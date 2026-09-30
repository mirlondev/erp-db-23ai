# Spécifications UI — App 300 « Achats & Fournisseurs » (APEX 26.1)

Schéma : `APP_PURCHASE` (+ `APP_PARTY`, `APP_PRODUCT`) · Rôles : `REGAL_ACHETEUR`, `REGAL_ADMIN`

## Vue d'ensemble fonctionnelle

L'app 300 gère le **cycle complet des achats** :
- Fournisseurs (création, mise à jour, conditions commerciales)
- Articles par fournisseur (catalogues, prix, délais)
- Demandes de prix / appels d'offres
- Bons de commande fournisseurs
- Réceptions (partielles ou totales)
- Factures fournisseurs + rapprochement avec réception
- Évaluation fournisseur (OTD : On-Time Delivery)

Elle s'appuie sur :
- `app_purchase.purchase_order` / `purchase_order_line` (Lot 1F)
- `app_purchase.supplier_product` (script 53, ex-`CAISSE.GCPFRNART` 821 rows)
- `app_party.party` WHERE party_type='SUPPLIER'
- `app_doc.doc_header` / `doc_line` (commandes + factures)
- `app_ar.invoice` (factures fournisseurs + paiements)
- `pkg_doc` (scripts 40-41) pour `create_quote / convert_quote_to_order / validate_document`

## Pages

| # | Page | Type | Source | Composants APEX 26.1 | Actions / Packages |
|---|---|---|---|---|---|
| 1 | Dashboard fournisseurs | Home | KPIs agrégés | 6 cards KPI + Chart topo | Drill-down → page 10 |
| 10 | Liste fournisseurs | IR | `party` WHERE party_type='SUPPLIER' | Faceted Search (pays, catégorie, OTD%) | "Nouveau" → page 11 |
| 11 | Fiche fournisseur | Master-Detail | `party` + `party_address` + `supplier_product` + `purchase_order` | 4 onglets : Identité / Catalogue / Commandes / Factures | DML + audit |
| 12 | Évaluation OTD | IR + Chart | Vue `v_supplier_otd` | Indicateur On-Time Delivery % | Drill-down → BL retardés |
| 20 | Catalogue articles fournisseur | IR + IG | `supplier_product` | IG éditable (prix, délai, min_qty) | DML direct (admin/acheteur) |
| 21 | Demandes de prix (RFQ) | Wizard | `doc_header` type='RFQ' | Wizard 5 étapes : sélection fournisseur, sélection produits, quantités, dates, envoi | `pkg_doc.create_quote` puis `convert_quote_to_order` |
| 30 | Bons de commande | IR + Form | `purchase_order` + `purchase_order_line` | Status indicator (DRAFT/VALIDATED/RECEIVED/CLOSED) | Création depuis RFQ ou direct |
| 31 | Création BC | Wizard | — | 4 étapes : fournisseur, lignes, conditions, validation | `pkg_doc.create_purchase_order` |
| 40 | Réceptions | Wizard | `purchase_order` + nouveaux records `app_inv.inv_movement` | Scanner code-barres + photo BL | Génère automatiquement le mouvement stock |
| 50 | Factures fournisseurs | IR | `invoice` WHERE type='PURCHASE' | Match icon (rapproché / à rapprocher / écart) | Rapprochement avec BL |
| 51 | Contrôle 3-way match | IR | Vue `v_three_way_match` | BL ↔ Commande ↔ Facture | Validation automatique |
| 60 | Rapports | Reports | Multiples vues | IG saved reports | Export |

## Vue 3-way match (à créer)

```sql
CREATE OR REPLACE VIEW app_api.v_three_way_match AS
SELECT po.po_id,
       po.po_number,
       po.po_date,
       s.party_code    AS supplier_code,
       s.party_name    AS supplier_name,
       po.total_ht     AS po_amount,
       bl.total_ht     AS bl_amount,
       inv.amount      AS invoice_amount,
       CASE
         WHEN po.total_ht = bl.total_ht AND bl.total_ht = inv.amount THEN 'MATCHED'
         WHEN ABS(po.total_ht - inv.amount) / NULLIF(po.total_ht,0) < 0.05 THEN 'TOLERATED'
         WHEN po.total_ht > inv.amount THEN 'SHORT_RECEIPT'
         ELSE 'OVER_RECEIPT'
       END AS match_status
  FROM app_purchase.purchase_order po
  JOIN app_party.party s ON s.party_code = po.supplier_code
  LEFT JOIN app_doc.doc_header bl ON bl.source_doc_id = po.po_id
                                  AND bl.doc_type_code = 'BL_PURCHASE'
  LEFT JOIN app_ar.invoice inv    ON inv.po_id = po.po_id
 WHERE po.status IN ('VALIDATED','RECEIVED','CLOSED');
```

## KPIs Dashboard

```sql
-- Top 5 fournisseurs par CA achats YTD
SELECT s.party_name,
       COUNT(DISTINCT po.po_id)            AS nb_orders,
       SUM(po.total_ttc)                   AS total_ytd_xaf,
       SUM(po.total_ttc) / NULLIF(SUM(po.total_ht),0) AS ratio_ttc_ht
  FROM app_purchase.purchase_order po
  JOIN app_party.party s ON s.party_code = po.supplier_code
 WHERE EXTRACT(YEAR FROM po.po_date) = EXTRACT(YEAR FROM SYSDATE)
   AND po.status IN ('RECEIVED','CLOSED')
 GROUP BY s.party_name
 ORDER BY total_ytd_xaf DESC
 FETCH FIRST 5 ROWS ONLY;
```

## Contraintes compatibilité WS legacy

1. Les fournisseurs créés via APEX doivent utiliser le même format `party_code`
   que la convention WS (8 chars max, ex: `SUPP01`, `FOURN12`).
2. Les `supplier_product` créés par APEX doivent être synchronisés vers les boutiques
   via l'outbox event (script 52) — **ne pas écrire directement dans `KERNEL.TT_GCPPAR`**.
3. Les réceptions (page 40) doivent déclencher un mouvement stock
   (`app_inv.inv_movement` direction='I') ET mettre à jour `inv_stock` —
   utiliser `pkg_doc.validate_document` plutôt qu'un DML direct.
4. La page 50 (factures fournisseurs) lit `app_ar.invoice` — qui peut aussi recevoir
   des factures saisies en WS boutique (`XCPTA.CP_FACT_FOUR` legacy) ; le mapping
   `LEGACY_FACT_FOUR.invoice_id = app_ar.invoice.invoice_id` est fait par `pkg_etl_legacy`.

## Règles métier spécifiques Congo

- **DGID** : taux TVA déductible **18.9%** (CEMAC, vs UEMOA 18%)
- **CNSS** : la paie est calculée via `pkg_apex_auth` mais les fournisseurs n'ont
  pas de retenue à la source (sauf sous-traitance BTP)
- **Devise** : `XAF` uniquement (pas de multi-devise pour l'instant)
- **Banque par défaut** : BGFI Congo (`BGFI-CG-PNR-2026-XXX-...`)
- **RCCM** : validation du numéro contribuable sur la fiche fournisseur
