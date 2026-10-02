# Guide d'installation APEX 26.1 — REGAL (méthode IDE)

> ⚠️ **Important** : tu as 2 options pour créer les apps.
>
> **Option 1 (recommandée)** : utiliser ce guide pour créer manuellement
> chaque app et chaque page dans l'IDE. Le plus sûr, ne dépend pas d'une API
> qui change entre versions APEX.
>
> **Option 2** : essayer `install_all_apps.sql` (utilise `WWV_FLOW_API.CREATE_FLOW`
> qui existe dans APEX 26.1, MAIS certaines versions l'ont en `WWV_FLOW_IMP`).
> En cas d'erreur PLS-00302 sur `WWV_FLOW_IMP.CREATE_APPLICATION`, revenir à
> l'Option 1.
>
> **Pages 20, 30, 40, etc.** : ce guide fournit les **requêtes SQL exactes**
> à copier-coller dans l'assistant de création de page.

---

## 📋 Prérequis vérifiés

Avant de commencer, lance ce script pour valider l'état :

```bash
sql sys/oracle@localhost:1521/FREEPDB1 as sysdba @apex/setup/12_apex_health_check.sql
```

Tu dois voir :
- ✅ APEX version : 26.XX
- ✅ Workspace REGAL : OK (#XXX)
- ✅ Schémas APP_* : 17/17
- ⚠️ Apps REGAL : 0/5 → à créer dans ce guide

---

## 🚀 Création des 5 applications (Étape 1)

Dans l'IDE APEX (`http://localhost:8080/apex`), connecte-toi ADMIN
→ bouton **Create** → **New Application** pour chaque app :

| App | Name | Schema | App ID |
|---|---|---|---|
| 100 | POS / Ventes LITOKO | APP_API | 100 |
| 200 | Stock / Transferts LITOKO | APP_API | 200 |
| 300 | Achats / Fournisseurs | APP_API | 300 |
| 400 | Comptabilité OHADA / Fiscal CG | APP_API | 400 |
| 500 | Administration REGAL | APP_API | 500 |

Paramètres communs pour chaque app (Shared Components → Edit Application Properties) :
- **Authentication Scheme** : PLSQL → `app_sys.pkg_apex_auth.authenticate`
- **Language** : French (fr)
- **Time Zone** : Africa/Brazzaville
- **Date Format** : `DD/MM/YYYY`
- **Number Format** : `999G999G999G990`

---

## 🎯 App 100 — POS / Ventes LITOKO

### Page 10 — Tableau de bord (Interactive Report)

**Type** : Interactive Report
**Page Number** : 10
**Name** : Tableau de bord
**Source Type** : SQL Query

```sql
SELECT terminal_code,
       terminal_name,
       status,
       nb_tickets,
       ca_session_xaf,
       hours_open
  FROM app_api.v_pos_session_kpi
 ORDER BY opened_at DESC
```

Puis ajoute une 2e region (Classic Report) "CA du jour" :

```sql
SELECT terminal_code,
       terminal_name,
       nb_tickets,
       total_ht,
       total_ttc,
       total_tva,
       avg_basket,
       TO_CHAR(last_ticket_at, 'DD/MM/YYYY HH24:MI') AS last_ticket_at
  FROM app_api.v_today_sales
 ORDER BY total_ttc DESC
```

### Page 20 — Sessions de caisse (Interactive Report)

**Type** : Interactive Report
**Page Number** : 20
**Name** : Sessions de caisse
**Source Type** : SQL Query

```sql
SELECT s.terminal_id,
       s.session_no,
       s.user_code,
       t.terminal_name,
       t.warehouse_code,
       TO_CHAR(s.opened_at, 'DD/MM/YYYY HH24:MI') AS opened,
       TO_CHAR(s.closed_at, 'DD/MM/YYYY HH24:MI') AS closed,
       CASE WHEN s.closed_at IS NULL THEN 'OUVERTE' ELSE 'FERMÉE' END AS status,
       s.opening_balance,
       s.closing_balance,
       (SELECT COUNT(*)
          FROM app_sales.ticket tk
         WHERE tk.terminal_id = t.terminal_code
           AND tk.session_no  = s.session_no) AS nb_tickets,
       ROUND((NVL(s.closed_at, SYSDATE) - s.opened_at) * 24, 1) AS hours
  FROM app_pos.pos_session s
  JOIN app_pos.pos_terminal t ON t.terminal_id = s.terminal_id
 ORDER BY s.opened_at DESC
```

Format colonnes :
- `STATUS` → Plain Text, vert si `OUVERTE`
- `NB_TICKETS` → alignement droite
- `HOURS` → format `999.9`

### Page 30 — Historique tickets (Interactive Report)

**Type** : Interactive Report
**Page Number** : 30
**Name** : Historique tickets
**Source Type** : SQL Query

```sql
SELECT t.terminal_id,
       t.ticket_no,
       TO_CHAR(t.ticket_date, 'DD/MM/YYYY HH24:MI') AS ticket_at,
       t.invoice_no,
       t.customer_name,
       t.user_code,
       t.total_ht,
       t.total_ttc,
       t.tax_amount_1 AS total_tva,
       t.status
  FROM app_sales.ticket t
 WHERE TRUNC(t.ticket_date) >= TRUNC(SYSDATE) - 30
 ORDER BY t.ticket_date DESC, t.ticket_no DESC
```

### Page 40 — Z de caisse (Form)

**Type** : Form + Interactive Report
**Page Number** : 40
**Name** : Z de caisse / Clôture

**Page 40a** (Form) — Items :
- `P40_TERMINAL_ID` (Select List) :
  - LOV : `SELECT terminal_id d, terminal_name || ' (' || terminal_code || ')' r FROM app_pos.pos_terminal WHERE is_active = 'Y' ORDER BY terminal_code`
  - Required
- `P40_SESSION_NO` (Number Field)

**Page 40b** (Report sous le form) :

```sql
SELECT s.terminal_id, s.session_no, s.user_code,
       t.terminal_name, t.warehouse_code,
       TO_CHAR(s.opened_at, 'DD/MM/YYYY HH24:MI') AS opened,
       TO_CHAR(s.closed_at, 'DD/MM/YYYY HH24:MI') AS closed,
       CASE WHEN s.closed_at IS NULL THEN 'OUVERTE' ELSE 'FERMÉE' END AS status,
       s.opening_balance, s.closing_balance, s.theoretical_balance,
       (s.closing_balance - s.theoretical_balance) AS ecart,
       (SELECT COUNT(*) FROM app_sales.ticket tk
         WHERE tk.terminal_id = t.terminal_code
           AND tk.session_no  = s.session_no) AS nb_tickets,
       (SELECT NVL(SUM(total_ht), 0) FROM app_sales.ticket tk
         WHERE tk.terminal_id = t.terminal_code
           AND tk.session_no  = s.session_no) AS ca_ht,
       (SELECT NVL(SUM(total_ttc), 0) FROM app_sales.ticket tk
         WHERE tk.terminal_id = t.terminal_code
           AND tk.session_no  = s.session_no) AS ca_ttc
  FROM app_pos.pos_session s
  JOIN app_pos.pos_terminal t ON t.terminal_id = s.terminal_id
 WHERE s.terminal_id = :P40_TERMINAL_ID
   AND s.session_no  = :P40_SESSION_NO
```

**Bouton** : "Imprimer Z" → action Submit (déclenche impression navigateur).

---

## 🎯 App 200 — Stock / Transferts LITOKO

### Page 10 — Tableau de bord (Interactive Report)

```sql
SELECT site_code,
       site_name,
       nb_references,
       total_units,
       total_value_xaf,
       nb_low_stock,
       TO_CHAR(last_movement_at, 'DD/MM/YYYY HH24:MI') AS last_movement_at
  FROM app_api.v_inv_stock_kpi
 ORDER BY total_value_xaf DESC
```

### Page 20 — Transferts en cours (Interactive Report)

```sql
SELECT transfer_id,
       transfer_number,
       TO_CHAR(transfer_date, 'DD/MM/YYYY HH24:MI') AS transfer_at,
       source_warehouse,
       target_warehouse,
       status,
       nb_lines,
       total_requested_qty,
       total_sent_qty,
       total_received_qty,
       days_in_process
  FROM app_api.v_transfer_pipeline
 ORDER BY transfer_date DESC
```

### Page 30 — Mouvements stock (Interactive Report, 100 lignes)

```sql
SELECT s.warehouse_code,
       s.product_code,
       p.product_name,
       s.stock_qty,
       p.standard_price,
       ROUND(s.stock_qty * p.standard_price, 0) AS valeur_xaf,
       TO_CHAR(s.last_in_at,  'DD/MM/YYYY HH24:MI') AS last_in,
       TO_CHAR(s.last_out_at, 'DD/MM/YYYY HH24:MI') AS last_out
  FROM app_inv.inv_stock s
  JOIN app_product.product p ON p.product_code = s.product_code
 WHERE s.stock_qty > 0
 ORDER BY s.stock_qty DESC
 FETCH FIRST 100 ROWS ONLY
```

### Page 40 — Alertes stock bas (Interactive Report)

```sql
SELECT s.warehouse_code,
       s.product_code,
       p.product_name,
       s.stock_qty,
       p.min_stock_qty,
       p.max_stock_qty,
       CASE WHEN s.stock_qty = 0                    THEN 'RUPTURE'
            WHEN s.stock_qty <= p.min_stock_qty     THEN 'BAS'
            ELSE 'OK' END AS alert_level
  FROM app_inv.inv_stock s
  JOIN app_product.product p ON p.product_code = s.product_code
 WHERE s.stock_qty <= NVL(p.min_stock_qty, 0)
 ORDER BY s.stock_qty ASC
```

Format : colonne `ALERT_LEVEL` → rouge si RUPTURE, orange si BAS.

---

## 🎯 App 300 — Achats / Fournisseurs

### Page 10 — Tableau de bord (Interactive Report, top 20)

```sql
SELECT party_code,
       party_name,
       total_orders,
       closed_orders,
       total_ytd
  FROM app_api.v_supplier_otd
 ORDER BY total_ytd DESC NULLS LAST
 FETCH FIRST 20 ROWS ONLY
```

### Page 20 — Bons de commande (Interactive Report)

```sql
SELECT po.po_id,
       po.po_number,
       TO_CHAR(po.po_date, 'DD/MM/YYYY') AS po_date,
       po.supplier_code,
       s.party_name AS supplier_name,
       po.status,
       po.total_ht,
       po.total_tva,
       po.total_ttc,
       po.delivery_date,
       po.created_by
  FROM app_purchase.purchase_order po
  LEFT JOIN app_party.party s ON s.party_code = po.supplier_code
 ORDER BY po.po_date DESC
 FETCH FIRST 100 ROWS ONLY
```

### Page 30 — Fournisseurs (Interactive Report)

```sql
SELECT p.party_code,
       p.party_name,
       p.city,
       p.country,
       p.tax_regime,
       p.payment_terms,
       p.credit_days,
       CASE WHEN p.is_blocked = 'Y' THEN 'OUI' ELSE 'NON' END AS blocked
  FROM app_party.party p
 WHERE p.is_blocked = 'N'
 ORDER BY p.party_name
```

### Page 40 — Catalogue articles (Interactive Report, 100 lignes)

```sql
SELECT p.product_code,
       p.product_name,
       p.short_name,
       p.stock_unit,
       p.standard_price,
       p.standard_price_ht,
       p.average_cost,
       CASE WHEN p.is_stock_managed = 'Y' THEN 'OUI' ELSE 'NON' END AS stock_mng,
       CASE WHEN p.is_promo = 'Y' THEN 'OUI' ELSE 'NON' END AS promo,
       p.promo_price
  FROM app_product.product p
 WHERE p.status = 'ACTIVE'
 ORDER BY p.product_name
 FETCH FIRST 100 ROWS ONLY
```

---

## 🎯 App 400 — Comptabilité OHADA / Fiscal CG

### Page 10 — Tableau de bord (Interactive Report)

```sql
SELECT account_code,
       account_name,
       account_class,
       normal_balance,
       mvt_debit,
       mvt_credit,
       solde,
       ROUND(ABS(solde) / 1000, 0) AS solde_kf
  FROM app_api.v_gl_account_balance
 WHERE ABS(solde) > 0
 ORDER BY ABS(solde) DESC
 FETCH FIRST 30 ROWS ONLY
```

### Page 20 — Plan comptable OHADA (Interactive Report)

```sql
SELECT account_code,
       account_name,
       account_class,
       account_type,
       normal_balance,
       CASE WHEN is_active = 'Y' THEN 'OUI' ELSE 'NON' END AS active
  FROM app_gl.gl_account_ohada
 WHERE is_active = 'Y'
 ORDER BY account_code
```

### Page 30 — Écritures (Interactive Report, 100 dernières)

```sql
SELECT entry_no,
       TO_CHAR(entry_date, 'DD/MM/YYYY') AS entry_at,
       journal_code,
       document_no,
       currency_code,
       company_total,
       CASE WHEN is_posted = 'Y' THEN 'Validée' ELSE 'Brouillon' END AS posted,
       entry_label,
       created_by
  FROM app_gl.gl_entry
 WHERE entry_date >= ADD_MONTHS(SYSDATE, -3)
 ORDER BY entry_date DESC, entry_no DESC
 FETCH FIRST 100 ROWS ONLY
```

### Page 40 — Déclarations fiscales CG (Interactive Report)

```sql
SELECT d.declaration_ref,
       TO_CHAR(d.period_start, 'DD/MM/YYYY') AS period_start,
       TO_CHAR(d.period_end,   'DD/MM/YYYY') AS period_end,
       d.jurisdiction,
       d.company_code,
       d.base_amount,
       d.tax_due,
       d.amount_payable,
       d.status,
       f.form_code,
       f.form_label
  FROM app_gl.tax_declaration d
  JOIN app_gl.tax_form_type f ON f.form_type_id = d.form_type_id
 ORDER BY d.period_end DESC
 FETCH FIRST 50 ROWS ONLY
```

### Page 50 — Immobilisations (Interactive Report)

```sql
SELECT asset_code,
       company_code,
       asset_name,
       category,
       TO_CHAR(acquisition_date, 'DD/MM/YYYY') AS acquired,
       acquisition_value,
       residual_value,
       useful_life_months,
       depreciation_method,
       accumulated_dep,
       net_book_value,
       status
  FROM app_gl.imm_asset
 ORDER BY acquisition_date DESC
 FETCH FIRST 50 ROWS ONLY
```

---

## 🎯 App 500 — Administration REGAL

### Page 10 — Tableau de bord (Classic Report)

```sql
SELECT 'Utilisateurs' AS component,
       COUNT(*) AS total,
       SUM(CASE WHEN is_active = 'Y' THEN 1 ELSE 0 END) AS actifs
  FROM app_sys.sys_user
UNION ALL
SELECT 'Rôles REGAL',     COUNT(*), 0 FROM app_sys.sys_role WHERE role_code LIKE 'REGAL_%'
UNION ALL
SELECT 'Sites REGAL',     COUNT(*), 0 FROM app_sys.site_master
UNION ALL
SELECT 'Events outbox',   COUNT(*), 0 FROM app_sys.outbox_event
UNION ALL
SELECT 'Events pending',  COUNT(*), 0 FROM app_sys.outbox_event WHERE status = 'PENDING'
UNION ALL
SELECT 'Sys messages',    COUNT(*), 0 FROM app_sys.sys_message
UNION ALL
SELECT 'APEX apps REGAL', COUNT(*), 0 FROM apex_applications
  WHERE workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
  AND application_id IN (100, 200, 300, 400, 500)
```

### Page 20 — Utilisateurs (Interactive Report)

```sql
SELECT user_id,
       user_code,
       user_name,
       email,
       language_code,
       CASE WHEN is_active = 'Y' THEN 'Actif' ELSE 'Inactif' END AS status,
       TO_CHAR(password_changed_at, 'DD/MM/YYYY') AS pw_changed
  FROM app_sys.sys_user
 ORDER BY user_code
```

### Page 30 — Rôles REGAL (Interactive Report)

```sql
SELECT r.role_id,
       r.role_code,
       r.role_name,
       r.role_level,
       r.description
  FROM app_sys.sys_role r
 ORDER BY r.role_level
```

### Page 40 — Sites REGAL (Interactive Report)

```sql
SELECT site_code,
       site_name,
       site_type,
       site_address,
       site_city,
       CASE WHEN is_active = 'Y' THEN 'Actif' ELSE 'Inactif' END AS status,
       sync_priority
  FROM app_sys.site_master
 ORDER BY site_type, site_code
```

### Page 50 — ETL runs (Interactive Report)

```sql
SELECT etl_id,
       source_table,
       target_table,
       rows_processed,
       status,
       TO_CHAR(started_at,  'DD/MM/YYYY HH24:MI') AS started,
       TO_CHAR(finished_at, 'DD/MM/YYYY HH24:MI') AS finished,
       SUBSTR(error_message, 1, 100) AS error
  FROM app_api.etl_run_progress
 ORDER BY started_at DESC
 FETCH FIRST 50 ROWS ONLY
```

### Page 60 — Outbox CDC (Interactive Report)

```sql
SELECT event_id,
       object_owner,
       object_name,
       primary_key_value,
       operation,
       status,
       site_code_origin,
       TO_CHAR(created_at, 'DD/MM/YYYY HH24:MI:SS') AS created
  FROM app_sys.outbox_event
 ORDER BY event_id DESC
 FETCH FIRST 50 ROWS ONLY
```

---

## 🔧 Configuration commune (toutes apps)

Une fois chaque app et ses pages créées, va dans **Shared Components** :

### 1. Navigation Menu
Pour chaque app, va dans **Lists** et crée une Navigation List avec ces items (utilise les pages que tu viens de créer) :

**App 100** : 10=Dashboard, 20=Sessions, 30=Tickets, 40=Z
**App 200** : 10=Dashboard, 20=Transferts, 30=Mouvements, 40=Alertes
**App 300** : 10=Dashboard, 20=PO, 30=Fournisseurs, 40=Catalogue
**App 400** : 10=Dashboard, 20=Plan, 30=Écritures, 40=Fiscal, 50=Immos
**App 500** : 10=Dashboard, 20=Users, 30=Rôles, 40=Sites, 50=ETL, 60=Outbox

### 2. Theme / Branding
Va dans **Theme Roller** puis importe `regal_mobile.css` depuis apex_static_file.

### 3. Static Application Files
Pour chaque app, va dans **Shared Components → Static Application Files** et uploade :
- `litoko_logo.svg`
- `regal_mobile.css`

---

## 🖥️ Écran client (WebSocket) — BONUS

L'écran client nécessite une vraie communication temps-réel. APEX seul ne peut pas.
Voici 2 options **réalistes** avec APEX 26.1 :

### Option A — Long Polling (simple, sans WebSocket)

Dans App 100 → Page 10 (Dashboard), ajoute une page cachée `display_customer.html` :

```javascript
// Dans l'URL du caissier : ouvrir une fenêtre popup sur écran 2
window.open('f?p=100:99:', 'customer_screen', 'width=800,height=600');
```

Page 99 = écran client qui lit la table `app_pos.display_customer_state` (créer une table 1 row 1 col pour partager l'état) avec un meta-refresh de 1s.

### Option B — WebSocket réel (recommandé)

Ajoute un service **Node.js** simple comme relai :

```javascript
// server.js
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8081 });

wss.on('connection', ws => {
  ws.on('message', msg => {
    // Broadcast à tous les clients connectés
    wss.clients.forEach(c => c.send(msg));
  });
});
```

Côté APEX : utilise le JavaScript `apex.server.process` pour pousser vers ton relai Node.js :
```javascript
apex.server.process('WS_PUSH', { data: {total: total} }, {
  success: function() { /* OK */ }
});
```

Process PL/SQL côté serveur :
```sql
-- Dans Page 10 → Processing → AJAX Callback Process
owa_util.mime_header('application/json');
htp.p('{"ok":true}');
owa_util.http_header_close;
```

---

## ✅ Validation finale

Quand tu as fini toutes les apps, lance :

```sql
SELECT application_id, application_name, alias,
       (SELECT COUNT(*) FROM apex_application_pages
         WHERE application_id = a.application_id) AS nb_pages
  FROM apex_applications a
 WHERE workspace = (SELECT workspace_id FROM apex_workspaces WHERE workspace = 'REGAL')
   AND application_id IN (100, 200, 300, 400, 500)
 ORDER BY application_id;
```

Tu dois voir 23 pages au total (4+4+4+5+6).

---

## 💾 Export pour réinstallation future

Une fois tes apps configurées dans l'IDE, exporte-les pour pouvoir les réinstaller plus tard :

```bash
sqlcl sys/oracle@localhost:1521/FREEPDB1 as sysdba
SQL> apex export 100
SQL> apex export 200
SQL> apex export 300
SQL> apex export 400
SQL> apex export 500
```

Ça génère `f100.sql`, `f200.sql`, etc. dans le dossier courant.

Pour réinstaller depuis ces exports :
```bash
./scripts/import_apex_app.sh 100 f100.sql
./scripts/import_apex_app.sh 200 f200.sql
# etc.
```

---

**Auteur** : Mavis · Dernière mise à jour : 2026-10-02