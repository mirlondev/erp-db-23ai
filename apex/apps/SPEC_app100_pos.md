# Spécifications UI — App 100 « POS / Ventes » (APEX 26.1)

Schéma : `APP_SALES` (+ synonymes dans `APP_API`) · Rôles : `REGAL_CAISSIER`, `REGAL_ADMIN`

## Pages

| Page | Type | Source | Composants | Actions |
|---|---|---|---|---|
| 1 | Accueil caisse | — | Cards sessions ouvertes, terminal courant | lien → page 10 |
| 10 | Ticket live (caisse) | `app_sales.ticket` + `ticket_line` | IG lignes, scan code-barres (PDA), Search+Enter | `pkg_sales.add_line / remove_line / total` |
| 11 | Encaissement | `ticket_payment` | Boutons modes (CASH/MOBILE/CARD/CREDIT), montant exact/arrondi | `pkg_sales.settle_ticket` → trigger outbox |
| 12 | Formats tickets LITOKO | `app_pos.pos_format` + `pos_format_zone` (script 53) | Form + preview HTML | DML admin uniquement |
| 20 | Sessions de caisse | `pos_session` | IR | Ouverture/fermeture (`pkg_pos_sales.open/close_session`), Z de caisse → PDF/print |
| 21 | Historique tickets | MV/reporting (script 28) | Faceted Search (date, site, caissier) | drill-down ligne → `payment_history` (ex CP_HISTO_RGL) |
| 30 | Retours / avoirs | `ticket` type=RET | Formulaire wizard | `pkg_sales.refund` (audit REFUND dans sys_audit_trail) |

## Contraintes compatibilité WS legacy

1. **Toutes** les écritures passent par les packages (`pkg_sales`, `pkg_pos_sales`) ;
   jamais d'IG DML direct sur `ticket*` — le déclencheur outbox (script 52) qui alimente
   les `TT_*` des boutiques est attaché aux tables, mais l'ETL inverse (script 55/57)
   attend les colonnes de traçabilité posées uniquement par les packages.
2. Les écrans lisent les vues `*_V2` (script 56) pour tout ce qui touchait
   `CETICKET`/`GCBRDD` côté WS.
3. Filtre multi-sites : chaque région/page applique
   `site_code IN (SELECT * FROM TABLE(regal_split(app_sys.pkg_apex_auth.user_site_codes(:APP_USER))))`
   (NULL = admin, tous sites).
4. Parité de test : scenario « même ticket créé via APEX puis repris par un WS boutique »
   doit produire des lignes `TT_BRD_OFFICE` identiques à la création 100% WS.

## KPIs

- CA du jour par site / terminal, panier moyen, temps moyen d'encaissement.
- Écart Z de caisse vs total tickets (alerte si ≠ 0).
